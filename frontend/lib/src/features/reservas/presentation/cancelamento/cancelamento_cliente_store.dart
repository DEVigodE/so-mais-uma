import 'package:so_mais_uma/src/imports/imports.dart';

import 'prazo_cancelamento.dart';

/// Desfecho do sheet de cancelamento.
enum ResultadoCancelamento {
  /// `2xx`: a reserva foi cancelada.
  cancelada,

  /// 422 `TRANSICAO_INVALIDA`: a reserva mudou de situação e deve ser
  /// recarregada por quem abriu o sheet.
  mudouSituacao,
}

/// Estado do sheet de cancelamento do cliente
/// (`POST /reservas/{id}/cancelar`).
class CancelamentoClienteStore {
  CancelamentoClienteStore(this._reservas, this._relogio) {
    tamanho = computed(() => _motivo.value.length);
    motivoValido = computed(() => MotivoCancelamento.valido(_motivo.value));
    motivoCurto = computed(() => MotivoCancelamento.curto(_motivo.value));
    prazo = computed(() {
      final reserva = _reserva.value;
      if (reserva == null) return null;
      return calcularPrazoCancelamento(reserva, _relogio.agora());
    });
    podeConfirmar = computed(
      () =>
          motivoValido.value &&
          !_envio.value.isLoading &&
          _reserva.value != null,
    );
  }

  final ReservaRepository _reservas;
  final Relogio _relogio;

  final _reserva = signal<Reserva?>(null);
  final _motivo = signal('');
  final _envio = signal<RequestState<Reserva>>(const RequestInitial());
  final _erro = signal<String?>(null);
  final _resultado = signal<ResultadoCancelamento?>(null);
  bool _descartado = false;

  ReadonlySignal<Reserva?> get reserva => _reserva;
  ReadonlySignal<String> get motivo => _motivo;
  ReadonlySignal<RequestState<Reserva>> get envio => _envio;

  /// Mensagem de erro exibida dentro do sheet (422, rede...).
  ReadonlySignal<String?> get erro => _erro;

  /// Desfecho que fecha o sheet; consumido pelo contêiner.
  ReadonlySignal<ResultadoCancelamento?> get resultado => _resultado;

  /// Contador `x / 200` (caracteres digitados).
  late final ReadonlySignal<int> tamanho;

  /// Motivo de 5 a 200 caracteres depois do `trim`.
  late final ReadonlySignal<bool> motivoValido;

  /// "Por favor, insira pelo menos 5 caracteres." (1 a 4 caracteres).
  late final ReadonlySignal<bool> motivoCurto;

  /// Prazo calculado na abertura do sheet.
  late final ReadonlySignal<PrazoCancelamento?> prazo;

  /// "Confirmar cancelamento" habilitado.
  late final ReadonlySignal<bool> podeConfirmar;

  void iniciar(Reserva reserva) {
    if (_descartado) return;
    _reserva.value = reserva;
  }

  void alterarMotivo(String texto) {
    if (_descartado) return;
    batch(() {
      _motivo.value = texto;
      _erro.value = null;
    });
  }

  Future<void> confirmar() async {
    final reserva = _reserva.value;
    if (_descartado || reserva == null || !podeConfirmar.value) return;
    batch(() {
      _envio.value = const RequestLoading();
      _erro.value = null;
    });

    final resultado =
        await _reservas.cancelar(reserva.id, _motivo.value.trim());
    if (_descartado) return;

    batch(() {
      resultado.fold(
        (falha) {
          _envio.value = RequestFailure(falha);
          final codigo =
              falha is ApiFailure ? (falha.subcodigo ?? falha.codigo) : null;
          switch (codigo) {
            case 'CANCELAMENTO_FORA_DO_PRAZO':
              _erro.value =
                  'reservas.cancelamento_cliente.erro_fora_do_prazo'.tr();
            case 'TRANSICAO_INVALIDA':
              _erro.value =
                  'reservas.cancelamento_cliente.erro_mudou_situacao'.tr();
              _resultado.value = ResultadoCancelamento.mudouSituacao;
            default:
              _erro.value = falha.message;
          }
        },
        (cancelada) {
          _envio.value = RequestSuccess(cancelada);
          _resultado.value = ResultadoCancelamento.cancelada;
        },
      );
    });
  }

  void dispose() {
    if (_descartado) return;
    _descartado = true;
    tamanho.dispose();
    motivoValido.dispose();
    motivoCurto.dispose();
    prazo.dispose();
    podeConfirmar.dispose();
    _reserva.dispose();
    _motivo.dispose();
    _envio.dispose();
    _erro.dispose();
    _resultado.dispose();
  }
}
