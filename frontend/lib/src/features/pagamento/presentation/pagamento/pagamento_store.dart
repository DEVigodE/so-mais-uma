import 'dart:async';

import 'package:so_mais_uma/src/imports/imports.dart';

import 'contador_pix.dart';

/// Fase da tela Pagamento (D15).
enum FasePagamento {
  /// `GET /reservas/{id}` em andamento.
  carregando,

  /// Não foi possível obter a cobrança ("SemCodigo").
  erro,

  /// Cobrança pendente: QR, contador e consulta periódica.
  aguardando,

  /// Cobrança expirada: layout `pagamento_expirado`.
  expirada,

  /// Saindo da tela (pago, cancelado, não pendente ou 404).
  saindo,
}

/// Resultado do último ciclo da consulta.
enum StatusVerificacao {
  ok,

  /// "Aguardando conexão para verificar".
  semConexao,

  /// "Não foi possível verificar agora".
  falha,
}

/// Botão "Já realizei o pagamento".
enum VerificacaoManual {
  ociosa,

  /// "Verificando liquidação Pix...".
  verificando,

  /// "Aguardando compensação bancária" por 2 s.
  aguardandoCompensacao,
}

/// Saída da tela: sempre `go` para a DetalheReserva.
enum DestinoPagamento {
  detalhe,

  /// Cobrança cancelada durante a consulta: com "A reserva foi cancelada.".
  detalheCancelada,
}

/// Snackbar da tela Pagamento: chave de tradução ou texto pronto.
class AvisoPagamento {
  const AvisoPagamento.chave(String chave)
      : _chave = chave,
        _texto = null;

  const AvisoPagamento.texto(String texto)
      : _texto = texto,
        _chave = null;

  final String? _chave;
  final String? _texto;

  String? get chave => _chave;
  String get mensagem => _texto ?? _chave!.tr();
}

/// Estado da tela Pagamento e máquina de estados da consulta (D15).
///
/// - a consulta usa um único `Timer` reagendado a cada ciclo: 5 s enquanto o
///   tempo de tela visível acumulado é menor que 2 min, depois 10 s;
/// - pausa quando o app sai do primeiro plano (ou com o sheet de cancelamento
///   aberto) e, na volta, faz um ciclo imediato;
/// - o contador é recalculado a cada segundo a partir de `expiraEm`; em 00:00
///   dispara o último ciclo, e qualquer resultado que não seja `PAGO` expira;
/// - `PAGO`, `CANCELADO` e `EXPIRADO` encerram a consulta;
/// - "Já realizei o pagamento" e a simulação fazem um ciclo extra, sem mexer
///   na cadência.
class PagamentoStore {
  PagamentoStore(
    this._reservas,
    this._pagamentos,
    this._quadras,
    this._relogio,
  ) {
    _agora = signal(_relogio.agora());
    restante = computed(() {
      final expira = _pagamento.value?.expiraEm ?? _reserva.value?.expiraEm;
      return restantePix(expira, _agora.value);
    });
    progresso = computed(() => progressoPix(restante.value));
  }

  static const Duration cadenciaInicial = Duration(seconds: 5);
  static const Duration cadenciaReduzida = Duration(seconds: 10);
  static const Duration janelaCadenciaInicial = Duration(minutes: 2);
  static const Duration duracaoCompensacao = Duration(seconds: 2);
  static const Duration duracaoCopiado = Duration(milliseconds: 3500);

  final ReservaRepository _reservas;
  final PagamentoRepository _pagamentos;
  final QuadraRepository _quadras;
  final Relogio _relogio;

  final _fase = signal(FasePagamento.carregando);
  final _falhaCarga = signal<Failure?>(null);
  final _reserva = signal<Reserva?>(null);
  final _pagamento = signal<Pagamento?>(null);
  final _quadra = signal<Quadra?>(null);
  final _statusVerificacao = signal(StatusVerificacao.ok);
  final _verificacaoManual = signal(VerificacaoManual.ociosa);
  final _simulando = signal(false);
  final _copiado = signal(false);
  final _navegacao = signal<DestinoPagamento?>(null);
  final _aviso = signal<AvisoPagamento?>(null);
  final _marco = signal<int?>(null);
  late final Signal<DateTime> _agora;

  Timer? _timerConsulta;
  Timer? _ticker;
  Timer? _timerCompensacao;
  Timer? _timerCopiado;
  Future<void>? _cicloEmAndamento;

  bool _appVisivel = true;
  bool _suspensa = false;
  bool _ultimoCiclo = false;
  bool _descartado = false;
  Duration _visivelAcumulado = Duration.zero;
  DateTime? _visivelDesde;
  int? _ultimoRestanteSeg;
  int? _id;
  int _geracao = 0;

  ReadonlySignal<FasePagamento> get fase => _fase;

  /// Falha da carga inicial (fase `erro`); nula quando a cobrança veio sem
  /// código Pix.
  ReadonlySignal<Failure?> get falhaCarga => _falhaCarga;
  ReadonlySignal<Reserva?> get reserva => _reserva;
  ReadonlySignal<Pagamento?> get pagamento => _pagamento;

  /// Quadra da reserva (ícone do esporte e miniatura), best-effort.
  ReadonlySignal<Quadra?> get quadra => _quadra;
  ReadonlySignal<DateTime> get agora => _agora;
  ReadonlySignal<StatusVerificacao> get statusVerificacao => _statusVerificacao;
  ReadonlySignal<VerificacaoManual> get verificacaoManual => _verificacaoManual;
  ReadonlySignal<bool> get simulando => _simulando;

  /// "Código copiado!" visível por 3,5 s.
  ReadonlySignal<bool> get copiado => _copiado;

  /// Evento de saída da tela; consumido pelo contêiner.
  ReadonlySignal<DestinoPagamento?> get navegacao => _navegacao;
  ReadonlySignal<AvisoPagamento?> get aviso => _aviso;

  /// Marco do contador a anunciar ao leitor de tela (300, 60 ou 0 s).
  ReadonlySignal<int?> get marcoContador => _marco;

  /// `max(0, expiraEm - agora)`.
  late final ReadonlySignal<Duration> restante;

  /// `restante / 900 s`.
  late final ReadonlySignal<double> progresso;

  /// Tempo de tela visível acumulado com a cobrança pendente.
  Duration get tempoVisivel {
    final desde = _visivelDesde;
    if (desde == null) return _visivelAcumulado;
    return _visivelAcumulado + _relogio.agora().difference(desde);
  }

  bool get _ativa =>
      !_descartado &&
      _appVisivel &&
      !_suspensa &&
      _fase.value == FasePagamento.aguardando;

  // ── Carga ────────────────────────────────────────────────────────────────

  /// Carrega a reserva com a cobrança (`GET /reservas/{id}`).
  Future<void> carregar(int reservaId) async {
    if (_descartado) return;
    _id = reservaId;
    final geracao = ++_geracao;
    _pararTudo();
    _ultimoCiclo = false;
    batch(() {
      _fase.value = FasePagamento.carregando;
      _falhaCarga.value = null;
      _statusVerificacao.value = StatusVerificacao.ok;
    });

    final resultado = await _reservas.detalhar(reservaId);
    if (_descartado || geracao != _geracao) return;

    resultado.fold(
      (falha) {
        if (falha is ApiFailure && falha.naoEncontrado) {
          _sair(DestinoPagamento.detalhe);
          return;
        }
        batch(() {
          _falhaCarga.value = falha;
          _fase.value = FasePagamento.erro;
        });
      },
      _iniciar,
    );
  }

  /// "Tentar novamente" do estado de erro.
  Future<void> tentarNovamente() async {
    final id = _id;
    if (id != null) await carregar(id);
  }

  void _iniciar(Reserva reserva) {
    final pagamento = reserva.pagamento;
    batch(() {
      _reserva.value = reserva;
      _pagamento.value = pagamento;
      _agora.value = _relogio.agora();
    });
    unawaited(_carregarQuadra(reserva.quadraId));

    if (reserva.status != StatusReserva.pendentePagamento) {
      _sair(DestinoPagamento.detalhe);
      return;
    }
    if (pagamento == null) {
      _fase.value = FasePagamento.erro;
      return;
    }
    switch (pagamento.status) {
      case StatusPagamento.pago:
        _sair(DestinoPagamento.detalhe);
      case StatusPagamento.cancelado:
        _sair(DestinoPagamento.detalheCancelada);
      case StatusPagamento.expirado:
        _expirar();
      case StatusPagamento.pendente:
        if ((pagamento.pixCopiaECola ?? '').isEmpty) {
          _fase.value = FasePagamento.erro;
          return;
        }
        _fase.value = FasePagamento.aguardando;
        _ativar(cicloImediato: false);
    }
  }

  Future<void> _carregarQuadra(int quadraId) async {
    if (_quadra.value?.id == quadraId) return;
    final resultado = await _quadras.detalhar(quadraId);
    if (_descartado) return;
    resultado.fold((_) {}, (q) => _quadra.value = q);
  }

  // ── Consulta ─────────────────────────────────────────────────────────────

  Duration get _cadencia =>
      tempoVisivel < janelaCadenciaInicial ? cadenciaInicial : cadenciaReduzida;

  void _agendar() {
    _timerConsulta?.cancel();
    _timerConsulta = null;
    if (!_ativa || _ultimoCiclo) return;
    _timerConsulta = Timer(_cadencia, _aoDispararConsulta);
  }

  Future<void> _aoDispararConsulta() async {
    _timerConsulta = null;
    await _ciclo();
    if (_timerConsulta == null) _agendar();
  }

  /// Um ciclo da consulta; se já houver um em andamento, reaproveita-o.
  Future<void> _ciclo() {
    final emAndamento = _cicloEmAndamento;
    if (emAndamento != null) return emAndamento;
    final ciclo = _executarCiclo();
    _cicloEmAndamento = ciclo;
    return ciclo.whenComplete(() {
      if (identical(_cicloEmAndamento, ciclo)) _cicloEmAndamento = null;
    });
  }

  Future<void> _executarCiclo() async {
    final id = _id;
    if (id == null) return;
    final resultado = await _pagamentos.estado(id);
    if (_descartado || _fase.value != FasePagamento.aguardando) return;

    resultado.fold(
      (falha) {
        _statusVerificacao.value = falha is NetworkFailure
            ? StatusVerificacao.semConexao
            : StatusVerificacao.falha;
        if (_ultimoCiclo) _expirar();
      },
      (pagamento) {
        batch(() {
          _pagamento.value = pagamento;
          _statusVerificacao.value = StatusVerificacao.ok;
        });
        switch (pagamento.status) {
          case StatusPagamento.pago:
            _sair(DestinoPagamento.detalhe);
          case StatusPagamento.cancelado:
            _sair(DestinoPagamento.detalheCancelada);
          case StatusPagamento.expirado:
            _expirar();
          case StatusPagamento.pendente:
            if (_ultimoCiclo) _expirar();
        }
      },
    );
  }

  void _dispararUltimoCiclo() {
    _ultimoCiclo = true;
    _timerConsulta?.cancel();
    _timerConsulta = null;
    unawaited(_ciclo().then((_) {
      if (!_descartado && _fase.value == FasePagamento.aguardando) _expirar();
    }));
  }

  Future<void> _cicloImediato() async {
    await _ciclo();
    _agendar();
  }

  // ── Contador ─────────────────────────────────────────────────────────────

  void _iniciarTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (_descartado) return;
    _agora.value = _relogio.agora();
    final segundos = restante.value.inSeconds;
    final marco = marcoCruzado(_ultimoRestanteSeg, segundos);
    _ultimoRestanteSeg = segundos;
    if (marco != null) _marco.value = marco;
    if (segundos == 0 &&
        !_ultimoCiclo &&
        _fase.value == FasePagamento.aguardando) {
      _dispararUltimoCiclo();
    }
  }

  // ── Visibilidade ─────────────────────────────────────────────────────────

  void _ativar({required bool cicloImediato}) {
    if (!_ativa) return;
    _visivelDesde ??= _relogio.agora();
    _iniciarTicker();
    _tick();
    if (_fase.value != FasePagamento.aguardando || _ultimoCiclo) return;
    if (cicloImediato) {
      unawaited(_cicloImediato());
    } else {
      _agendar();
    }
  }

  void _pausar() {
    _timerConsulta?.cancel();
    _timerConsulta = null;
    _ticker?.cancel();
    _ticker = null;
    final desde = _visivelDesde;
    if (desde != null) {
      _visivelAcumulado += _relogio.agora().difference(desde);
      _visivelDesde = null;
    }
  }

  /// App saiu do primeiro plano (`AppLifecycleListener.onHide`).
  void aoOcultarApp() {
    if (_descartado || !_appVisivel) return;
    _appVisivel = false;
    _pausar();
  }

  /// App voltou (`AppLifecycleListener.onShow`): ciclo imediato.
  void aoMostrarApp() {
    if (_descartado || _appVisivel) return;
    _appVisivel = true;
    _ativar(cicloImediato: true);
  }

  /// Pausa a consulta enquanto o sheet de cancelamento está aberto.
  void suspenderConsulta() {
    if (_descartado || _suspensa) return;
    _suspensa = true;
    _pausar();
  }

  /// Retoma a consulta depois do sheet, com um ciclo imediato.
  void retomarConsulta() {
    if (_descartado || !_suspensa) return;
    _suspensa = false;
    _ativar(cicloImediato: true);
  }

  // ── Ações ────────────────────────────────────────────────────────────────

  /// "Já realizei o pagamento": ciclo extra imediato, sem mexer na cadência.
  Future<void> jaRealizeiPagamento() async {
    if (_descartado ||
        _fase.value != FasePagamento.aguardando ||
        _verificacaoManual.value != VerificacaoManual.ociosa) {
      return;
    }
    _verificacaoManual.value = VerificacaoManual.verificando;
    await _ciclo();
    if (_descartado) return;
    final continuaPendente = _fase.value == FasePagamento.aguardando &&
        _statusVerificacao.value == StatusVerificacao.ok;
    if (!continuaPendente) {
      _verificacaoManual.value = VerificacaoManual.ociosa;
      return;
    }
    _verificacaoManual.value = VerificacaoManual.aguardandoCompensacao;
    _timerCompensacao?.cancel();
    _timerCompensacao = Timer(duracaoCompensacao, () {
      if (!_descartado) _verificacaoManual.value = VerificacaoManual.ociosa;
    });
  }

  /// "Simular confirmação Pix (Dev Sandbox)" — só em debug.
  Future<void> simular() async {
    final txid = _pagamento.value?.txid;
    if (_descartado ||
        txid == null ||
        _simulando.value ||
        _fase.value != FasePagamento.aguardando) {
      return;
    }
    _simulando.value = true;
    final resultado = await _pagamentos.simular(txid);
    if (_descartado) return;
    if (resultado.isRight()) await _ciclo();
    if (_descartado) return;
    batch(() {
      _simulando.value = false;
      resultado.fold(
        (falha) => _aviso.value = falha is ApiFailure && falha.status == 403
            ? const AvisoPagamento.chave('pagamento.dev_chave_invalida')
            : AvisoPagamento.texto(falha.message),
        (_) {},
      );
    });
  }

  /// "Código copiado!" por 3,5 s, depois de copiar com sucesso.
  void marcarCopiado() {
    if (_descartado) return;
    _copiado.value = true;
    _timerCopiado?.cancel();
    _timerCopiado = Timer(duracaoCopiado, () {
      if (!_descartado) _copiado.value = false;
    });
  }

  void consumirNavegacao() => _navegacao.value = null;
  void consumirAviso() => _aviso.value = null;
  void consumirMarco() => _marco.value = null;

  // ── Transições finais ────────────────────────────────────────────────────

  void _pararTudo() {
    _pausar();
    _timerCompensacao?.cancel();
    _timerCompensacao = null;
  }

  void _sair(DestinoPagamento destino) {
    _pararTudo();
    batch(() {
      _fase.value = FasePagamento.saindo;
      _verificacaoManual.value = VerificacaoManual.ociosa;
      _navegacao.value = destino;
    });
  }

  void _expirar() {
    _pararTudo();
    batch(() {
      _agora.value = _relogio.agora();
      _fase.value = FasePagamento.expirada;
      _verificacaoManual.value = VerificacaoManual.ociosa;
    });
  }

  void dispose() {
    if (_descartado) return;
    _descartado = true;
    _pararTudo();
    _timerCopiado?.cancel();
    _timerCopiado = null;
    restante.dispose();
    progresso.dispose();
    _agora.dispose();
    _fase.dispose();
    _falhaCarga.dispose();
    _reserva.dispose();
    _pagamento.dispose();
    _quadra.dispose();
    _statusVerificacao.dispose();
    _verificacaoManual.dispose();
    _simulando.dispose();
    _copiado.dispose();
    _navegacao.dispose();
    _aviso.dispose();
    _marco.dispose();
  }
}
