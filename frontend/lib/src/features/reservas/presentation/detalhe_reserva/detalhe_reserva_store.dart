import 'dart:async';

import 'package:so_mais_uma/src/imports/imports.dart';

import '../cancelamento/prazo_cancelamento.dart';
import '../minhas_reservas/componentes_reserva.dart';

/// Item copiado na DetalheReserva ("Copiar" vira "Copiado!" por 2 s).
enum ItemCopiado { codigo, txid }

/// Estado da DetalheReserva (`GET /reservas/{id}`, com a cobrança).
class DetalheReservaStore {
  DetalheReservaStore(
    this._reservas,
    this._quadras,
    this._relogio,
    this._sessao,
  ) {
    _agora = signal(_relogio.agora());
    prazo = computed(() {
      final reserva = _reservaAtual;
      if (reserva == null) return null;
      return calcularPrazoCancelamento(reserva, _agora.value);
    });
    podeEditarObservacao = computed(() {
      final reserva = _reservaAtual;
      if (reserva == null) return false;
      return reserva.status.ativa && reserva.fim.isAfter(_agora.value);
    });
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
  }

  static const Duration duracaoCopiado = Duration(seconds: 2);
  static const Duration duracaoObservacaoSalva = Duration(seconds: 3);

  final ReservaRepository _reservas;
  final QuadraRepository _quadras;
  final Relogio _relogio;
  final SessionStore _sessao;

  final _estado = signal<RequestState<Reserva>>(const RequestInitial());
  final _quadra = signal<Quadra?>(null);
  final _editando = signal(false);
  final _salvando = signal(false);
  final _observacaoSalva = signal(false);
  final _copiado = signal<ItemCopiado?>(null);
  final _aviso = signal<AvisoTela?>(null);
  late final Signal<DateTime> _agora;

  Timer? _ticker;
  Timer? _timerCopiado;
  Timer? _timerObservacao;
  int? _id;
  int _geracao = 0;
  bool _descartado = false;

  ReadonlySignal<RequestState<Reserva>> get estado => _estado;

  /// Quadra da reserva (foto, esporte); nula enquanto não chega ou se saiu
  /// do catálogo.
  ReadonlySignal<Quadra?> get quadra => _quadra;
  ReadonlySignal<DateTime> get agora => _agora;
  ReadonlySignal<bool> get editando => _editando;
  ReadonlySignal<bool> get salvando => _salvando;

  /// "Observação atualizada com sucesso!" visível por 3 s.
  ReadonlySignal<bool> get observacaoSalva => _observacaoSalva;
  ReadonlySignal<ItemCopiado?> get copiado => _copiado;
  ReadonlySignal<AvisoTela?> get aviso => _aviso;

  /// Usuário da sessão (faixa do titular da reserva cancelada).
  ReadonlySignal<AppUser?> get usuario => _sessao.user;

  /// Prazo de cancelamento calculado (D14); nulo sem reserva.
  late final ReadonlySignal<PrazoCancelamento?> prazo;

  /// Observação editável: pendente ou confirmada que ainda não terminou.
  late final ReadonlySignal<bool> podeEditarObservacao;

  Reserva? get _reservaAtual => switch (_estado.value) {
        RequestSuccess(:final data) => data,
        _ => null,
      };

  /// Carrega a reserva [id]. Com a reserva na tela, atualiza sem voltar ao
  /// estado de carregando.
  Future<void> carregar(int id) async {
    if (_descartado) return;
    final trocouId = _id != id;
    _id = id;
    final geracao = ++_geracao;
    if (trocouId || _reservaAtual == null) {
      _estado.value = const RequestLoading();
    }

    final resultado = await _reservas.detalhar(id);
    if (_descartado || geracao != _geracao) return;

    batch(() {
      _agora.value = _relogio.agora();
      resultado.fold(
        (falha) {
          if (_reservaAtual != null && falha is NetworkFailure) {
            _aviso.value = AvisoTela.texto(falha.message);
          } else {
            _estado.value = RequestFailure(falha);
          }
        },
        (reserva) => _estado.value = RequestSuccess(reserva),
      );
    });

    final reserva = _reservaAtual;
    if (reserva != null && _quadra.value?.id != reserva.quadraId) {
      unawaited(_carregarQuadra(reserva.quadraId));
    }
  }

  /// Recarrega a reserva atual (depois do cancelamento, do pagamento ou de
  /// uma mudança de situação).
  Future<void> recarregar() async {
    final id = _id;
    if (id == null) return;
    await carregar(id);
  }

  Future<void> _carregarQuadra(int quadraId) async {
    final resultado = await _quadras.detalhar(quadraId);
    if (_descartado) return;
    resultado.fold((_) {}, (q) => _quadra.value = q);
  }

  void iniciarEdicao() {
    if (_descartado || !podeEditarObservacao.value) return;
    batch(() {
      _editando.value = true;
      _observacaoSalva.value = false;
    });
  }

  void cancelarEdicao() {
    if (_descartado || _salvando.value) return;
    _editando.value = false;
  }

  /// `PATCH /reservas/{id}` com a observação (vazia apaga).
  Future<void> salvarObservacao(String texto) async {
    final reserva = _reservaAtual;
    if (_descartado || reserva == null || _salvando.value) return;
    final limpo = texto.trim();
    _salvando.value = true;

    final resultado = await _reservas.atualizarObservacao(
      reserva.id,
      limpo.isEmpty ? null : limpo,
    );
    if (_descartado) return;

    var recarregarDepois = false;
    batch(() {
      _salvando.value = false;
      resultado.fold(
        (falha) {
          if (_transicaoInvalida(falha)) {
            _editando.value = false;
            _aviso.value = const AvisoTela.chave(
              'reservas.detalhe.mudou_situacao',
              erro: true,
            );
            recarregarDepois = true;
          } else {
            _aviso.value = AvisoTela.texto(falha.message);
          }
        },
        (nova) {
          _estado.value = RequestSuccess(_preservarPagamento(nova, reserva));
          _editando.value = false;
          _observacaoSalva.value = true;
        },
      );
    });

    if (resultado.isRight()) {
      _timerObservacao?.cancel();
      _timerObservacao = Timer(duracaoObservacaoSalva, () {
        if (!_descartado) _observacaoSalva.value = false;
      });
    }
    if (recarregarDepois) await recarregar();
  }

  /// Marca [item] como copiado por 2 s.
  void marcarCopiado(ItemCopiado item) {
    if (_descartado) return;
    _copiado.value = item;
    _timerCopiado?.cancel();
    _timerCopiado = Timer(duracaoCopiado, () {
      if (!_descartado) _copiado.value = null;
    });
  }

  void consumirAviso() => _aviso.value = null;

  void _tick() {
    if (!_descartado) _agora.value = _relogio.agora();
  }

  static bool _transicaoInvalida(Failure falha) =>
      falha is ApiFailure &&
      (falha.subcodigo == 'TRANSICAO_INVALIDA' ||
          falha.codigo == 'TRANSICAO_INVALIDA');

  /// O `PATCH` devolve a cobrança; se vier sem, mantém a que já estava.
  static Reserva _preservarPagamento(Reserva nova, Reserva anterior) {
    if (nova.pagamento != null || anterior.pagamento == null) return nova;
    return Reserva(
      id: nova.id,
      quadraId: nova.quadraId,
      quadraNome: nova.quadraNome,
      quadraEndereco: nova.quadraEndereco,
      clienteId: nova.clienteId,
      clienteNome: nova.clienteNome,
      clienteTelefone: nova.clienteTelefone,
      inicio: nova.inicio,
      fim: nova.fim,
      status: nova.status,
      valor: nova.valor,
      observacao: nova.observacao,
      expiraEm: nova.expiraEm,
      criadoEm: nova.criadoEm,
      canceladoEm: nova.canceladoEm,
      canceladoPor: nova.canceladoPor,
      motivoCancelamento: nova.motivoCancelamento,
      pagamento: anterior.pagamento,
    );
  }

  void dispose() {
    if (_descartado) return;
    _descartado = true;
    _ticker?.cancel();
    _timerCopiado?.cancel();
    _timerObservacao?.cancel();
    prazo.dispose();
    podeEditarObservacao.dispose();
    _agora.dispose();
    _estado.dispose();
    _quadra.dispose();
    _editando.dispose();
    _salvando.dispose();
    _observacaoSalva.dispose();
    _copiado.dispose();
    _aviso.dispose();
  }
}
