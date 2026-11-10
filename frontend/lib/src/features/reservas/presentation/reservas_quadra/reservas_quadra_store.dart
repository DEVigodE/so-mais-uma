import 'dart:async';

import 'package:so_mais_uma/src/imports/imports.dart';

import 'resumo_do_dia.dart';

/// Estado e ações da ReservasQuadra do DONO (design D4).
///
/// Na faixa de hoje a hoje + 14 a lista vem de `GET /reservas` (todas as
/// reservas das quadras do dono), filtrada por data e por quadra. Fora da
/// faixa ("Outro dia") a data é consultada online com
/// `GET /quadras/{id}/reservas?data=`, uma chamada por quadra do filtro. As
/// faixas de funcionamento (para a ocupação) são buscadas por quadra sem
/// bloquear a tela.
class ReservasQuadraStore {
  ReservasQuadraStore(
    this._quadrasRepo,
    this._reservasRepo,
    this._horariosRepo,
    this._relogio,
  );

  final QuadraRepository _quadrasRepo;
  final ReservaRepository _reservasRepo;
  final HorarioRepository _horariosRepo;
  final Relogio _relogio;

  /// Intervalo em que "agora" é relido (prazos do Pix e botão de cancelar).
  static const Duration intervaloRelogio = Duration(seconds: 30);

  final _carga = signal<RequestState<void>>(const RequestInitial());
  final _quadras = signal<List<Quadra>>(const []);
  final _reservas = signal<List<Reserva>>(const []);
  final _horarios = signal<Map<int, List<HorarioFuncionamento>>>(const {});
  final _quadraFiltro = signal<int?>(null);
  late final _agora = signal<DateTime>(_relogio.agora());
  late final _dataSelecionada =
      signal<DateTime>(Brasilia.dia(_relogio.agora()));
  final _agendaOutroDia = signal<Map<int, List<Reserva>>>(const {});
  final _cargaOutroDia = signal<RequestState<void>>(const RequestInitial());
  final _mensagem = signal<String?>(null);
  final _atualizando = signal<bool>(false);

  Timer? _ticker;
  bool _descartado = false;
  int _geracao = 0;
  int _geracaoOutroDia = 0;

  /// Carga principal (quadras e reservas da faixa).
  ReadonlySignal<RequestState<void>> get carga => _carga;

  /// Quadras do dono (`GET /quadras/minhas`), para os chips.
  ReadonlySignal<List<Quadra>> get quadras => _quadras;

  /// Quadra do chip selecionado; `null` = todas.
  ReadonlySignal<int?> get quadraFiltro => _quadraFiltro;

  /// Data de parede selecionada (meia-noite UTC com os campos de Brasília).
  ReadonlySignal<DateTime> get dataSelecionada => _dataSelecionada;

  ReadonlySignal<DateTime> get agora => _agora;

  /// Mensagem de erro de uma atualização que falhou com a lista já exibida
  /// (evento de uma leitura: o contêiner mostra e chama [consumirMensagem]).
  ReadonlySignal<String?> get mensagem => _mensagem;

  /// Atualização em andamento (puxar ou botão de atualizar).
  ReadonlySignal<bool> get atualizando => _atualizando;

  late final ReadonlySignal<DateTime> hoje =
      computed(() => Brasilia.dia(_agora.value));

  /// Datas da faixa: hoje até hoje + 14.
  late final ReadonlySignal<List<DateTime>> faixa =
      computed(() => faixaDeDatas(hoje.value));

  late final ReadonlySignal<bool> naFaixa =
      computed(() => dataNaFaixa(_dataSelecionada.value, hoje.value));

  /// Estado da lista: a carga principal na faixa; a consulta online fora dela.
  late final ReadonlySignal<RequestState<void>> cargaLista = computed(
    () => naFaixa.value ? _carga.value : _cargaOutroDia.value,
  );

  /// Reservas exibidas (data e chip selecionados), por início.
  late final ReadonlySignal<List<Reserva>> reservas = computed(() {
    final Iterable<Reserva> fonte = naFaixa.value
        ? _reservas.value
        : _agendaOutroDia.value.values.expand((l) => l);
    return reservasDoDia(
      fonte,
      data: _dataSelecionada.value,
      quadraId: _quadraFiltro.value,
    );
  });

  /// Soma dos slots do dia das quadras filtradas (`null` enquanto as faixas
  /// não chegam). Em "Todas", só as quadras ativas oferecem horários.
  late final ReadonlySignal<int?> slotsDoDia = computed(() {
    final filtro = _quadraFiltro.value;
    final Iterable<int> ids = filtro != null
        ? [filtro]
        : _quadras.value.where((q) => q.ativa).map((q) => q.id);
    return somarSlotsDoDia(
      quadraIds: ids,
      horarios: _horarios.value,
      diaSemana: _dataSelecionada.value.weekday,
    );
  });

  /// Resumo do dia (D14), recalculado a cada mudança da lista.
  late final ReadonlySignal<ResumoDia> resumo = computed(
    () => calcularResumoDoDia(
      reservas: reservas.value,
      slotsDoDia: slotsDoDia.value,
      agora: _agora.value,
      hoje: _dataSelecionada.value == hoje.value,
    ),
  );

  // ── Ações ─────────────────────────────────────────────────────────────────

  /// Primeira carga. [quadraId] pré-seleciona o chip da quadra.
  Future<void> carregar({int? quadraId}) {
    _quadraFiltro.value = quadraId;
    _ticker ??= Timer.periodic(intervaloRelogio, (_) => _relerAgora());
    return _sincronizar();
  }

  /// Puxar para atualizar e botão de atualizar.
  Future<void> atualizar() async {
    if (_descartado || _atualizando.value) return;
    _atualizando.value = true;
    try {
      _relerAgora();
      await _sincronizar();
      if (_descartado) return;
      if (!naFaixa.value) await _carregarOutroDia(recarregar: true);
    } finally {
      if (!_descartado) _atualizando.value = false;
    }
  }

  /// Seleciona uma data da faixa ou, fora dela, consulta a data online.
  Future<void> selecionarData(DateTime data) async {
    final dia = DateTime.utc(data.year, data.month, data.day);
    if (dia == _dataSelecionada.value) return;
    _geracaoOutroDia++;
    batch(() {
      _dataSelecionada.value = dia;
      _agendaOutroDia.value = const {};
      _cargaOutroDia.value = const RequestInitial();
    });
    if (!naFaixa.value) await _carregarOutroDia();
  }

  /// Seleciona o chip de uma quadra (`null` = todas).
  Future<void> selecionarQuadra(int? quadraId) async {
    if (quadraId == _quadraFiltro.value) return;
    _quadraFiltro.value = quadraId;
    if (!naFaixa.value) await _carregarOutroDia();
  }

  /// "Tentar novamente" da caixa de erro da lista.
  Future<void> tentarNovamente() =>
      naFaixa.value ? _sincronizar() : _carregarOutroDia(recarregar: true);

  /// Aplica a reserva devolvida por `POST /reservas/{id}/cancelar`; o resumo
  /// é recalculado pelos `computed`.
  void aplicarCancelamento(Reserva atualizada) {
    Reserva trocar(Reserva r) =>
        r.id == atualizada.id ? _mesclar(r, atualizada) : r;
    batch(() {
      _reservas.value = _reservas.value.map(trocar).toList(growable: false);
      _agendaOutroDia.value = {
        for (final e in _agendaOutroDia.value.entries)
          e.key: e.value.map(trocar).toList(growable: false),
      };
      _agora.value = _relogio.agora();
    });
  }

  void consumirMensagem() => _mensagem.value = null;

  // ── Internos ──────────────────────────────────────────────────────────────

  void _relerAgora() {
    if (_descartado) return;
    _agora.value = _relogio.agora();
  }

  Future<void> _sincronizar() async {
    final geracao = ++_geracao;
    final tinhaDados = _carga.value is RequestSuccess;
    if (!tinhaDados) _carga.value = const RequestLoading();

    final (rQuadras, rReservas) =
        await (_quadrasRepo.minhas(), _reservasRepo.listar()).wait;
    if (_descartado || geracao != _geracao) return;

    final falha = rQuadras.fold((f) => f, (_) => null) ??
        rReservas.fold((f) => f, (_) => null);
    if (falha != null) {
      if (tinhaDados) {
        _mensagem.value = falha.message;
      } else {
        _carga.value = RequestFailure(falha);
      }
      return;
    }

    final quadras = rQuadras.getOrElse((_) => const []);
    batch(() {
      _agora.value = _relogio.agora();
      _quadras.value = quadras;
      _reservas.value = rReservas.getOrElse((_) => const []);
      _carga.value = const RequestSuccess(null);
    });
    _carregarHorarios(quadras);
  }

  /// Faixas de funcionamento por quadra, em paralelo e sem bloquear a tela.
  /// Falha deixa a quadra sem faixas conhecidas (a ocupação é omitida).
  void _carregarHorarios(List<Quadra> quadras) {
    for (final q in quadras) {
      unawaited(
        _horariosRepo.listar(q.id).then((r) {
          if (_descartado) return;
          r.fold(
            (_) {},
            (faixas) => _horarios.value = {..._horarios.value, q.id: faixas},
          );
        }),
      );
    }
  }

  List<int> _idsDoFiltro() {
    final filtro = _quadraFiltro.value;
    if (filtro != null) return [filtro];
    return _quadras.value.map((q) => q.id).toList(growable: false);
  }

  /// Consulta online da data fora da faixa: uma chamada por quadra do filtro
  /// que ainda não foi consultada (todas, com [recarregar]).
  Future<void> _carregarOutroDia({bool recarregar = false}) async {
    final data = _dataSelecionada.value;
    final ids = _idsDoFiltro();
    final faltando = recarregar
        ? ids
        : ids.where((id) => !_agendaOutroDia.value.containsKey(id)).toList();
    final geracao = ++_geracaoOutroDia;
    if (faltando.isEmpty) {
      _cargaOutroDia.value = const RequestSuccess(null);
      return;
    }

    _cargaOutroDia.value = const RequestLoading();
    final resultados = await Future.wait(
      faltando.map((id) => _reservasRepo.agendaDaQuadra(id, data: data)),
    );
    if (_descartado ||
        geracao != _geracaoOutroDia ||
        data != _dataSelecionada.value) {
      return;
    }

    final agenda =
        recarregar ? <int, List<Reserva>>{} : {..._agendaOutroDia.value};
    Failure? falha;
    for (var i = 0; i < faltando.length; i++) {
      resultados[i].fold(
        (f) => falha ??= f,
        (lista) => agenda[faltando[i]] = lista,
      );
    }
    final falhaFinal = falha;
    batch(() {
      _agora.value = _relogio.agora();
      _agendaOutroDia.value = agenda;
      _cargaOutroDia.value = falhaFinal == null
          ? const RequestSuccess(null)
          : RequestFailure(falhaFinal);
    });
  }

  /// A resposta do cancelamento é a fonte da verdade; os dados de contato
  /// antigos ficam quando a resposta não os trouxer.
  static Reserva _mesclar(Reserva antiga, Reserva nova) => Reserva(
        id: nova.id,
        quadraId: nova.quadraId,
        quadraNome: nova.quadraNome,
        inicio: nova.inicio,
        fim: nova.fim,
        status: nova.status,
        valor: nova.valor,
        quadraEndereco: nova.quadraEndereco ?? antiga.quadraEndereco,
        clienteId: nova.clienteId ?? antiga.clienteId,
        clienteNome: nova.clienteNome ?? antiga.clienteNome,
        clienteTelefone: nova.clienteTelefone ?? antiga.clienteTelefone,
        observacao: nova.observacao,
        expiraEm: nova.expiraEm,
        criadoEm: nova.criadoEm ?? antiga.criadoEm,
        canceladoEm: nova.canceladoEm,
        canceladoPor: nova.canceladoPor,
        motivoCancelamento: nova.motivoCancelamento,
        pagamento: nova.pagamento,
      );

  void dispose() {
    _descartado = true;
    _ticker?.cancel();
    resumo.dispose();
    slotsDoDia.dispose();
    reservas.dispose();
    cargaLista.dispose();
    naFaixa.dispose();
    faixa.dispose();
    hoje.dispose();
    _carga.dispose();
    _quadras.dispose();
    _reservas.dispose();
    _horarios.dispose();
    _quadraFiltro.dispose();
    _agora.dispose();
    _dataSelecionada.dispose();
    _agendaOutroDia.dispose();
    _cargaOutroDia.dispose();
    _mensagem.dispose();
    _atualizando.dispose();
  }
}
