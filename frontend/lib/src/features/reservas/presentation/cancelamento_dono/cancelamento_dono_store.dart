import 'package:so_mais_uma/src/imports/imports.dart';

/// Motivos do cancelamento pelo dono (spec reservas-dono). As opções da lista
/// enviam o próprio texto; [outro] abre o campo livre de 5 a 200 caracteres.
enum MotivoCancelamentoDono {
  manutencao('reservas.cancelamento_dono.motivos.manutencao'),
  clima('reservas.cancelamento_dono.motivos.clima'),
  acordo('reservas.cancelamento_dono.motivos.acordo'),
  outro('reservas.cancelamento_dono.motivos.outro');

  const MotivoCancelamentoDono(this.rotuloKey);

  final String rotuloKey;
}

/// Limites do motivo livre ("Outro motivo operacional").
const int motivoMinimo = 5;
const int motivoMaximo = 200;

/// `true` quando o texto livre tem de 5 a 200 caracteres (sem os espaços das
/// pontas).
bool motivoLivreValido(String texto) {
  final t = texto.trim();
  return t.length >= motivoMinimo && t.length <= motivoMaximo;
}

/// Resultado entregue a quem abriu o sheet.
sealed class ResultadoCancelamentoDono {
  const ResultadoCancelamentoDono();
}

/// 2xx: a reserva atualizada (`CANCELADA`, `canceladoPor` = DONO).
final class CancelamentoConcluido extends ResultadoCancelamentoDono {
  const CancelamentoConcluido(this.reserva);
  final Reserva reserva;
}

/// 422 que invalida a tela (`CANCELAMENTO_FORA_DO_PRAZO`,
/// `TRANSICAO_INVALIDA`): quem abriu mostra [mensagem] e recarrega.
final class CancelamentoRecusado extends ResultadoCancelamentoDono {
  const CancelamentoRecusado(this.mensagem);
  final String mensagem;
}

/// Estado e ações do sheet de cancelamento pelo dono (design D4).
class CancelamentoDonoStore {
  CancelamentoDonoStore(this._reservas);

  final ReservaRepository _reservas;

  final _reserva = signal<Reserva?>(null);
  final _motivo = signal<MotivoCancelamentoDono>(
    MotivoCancelamentoDono.manutencao,
  );
  final _textoLivre = signal<String>('');
  final _envio = signal<RequestState<Reserva>>(const RequestInitial());
  final _erroMotivoApi = signal<String?>(null);
  final _erroGeral = signal<String?>(null);
  final _resultado = signal<ResultadoCancelamentoDono?>(null);
  bool _descartado = false;

  ReadonlySignal<Reserva?> get reserva => _reserva;
  ReadonlySignal<MotivoCancelamentoDono> get motivo => _motivo;
  ReadonlySignal<String> get textoLivre => _textoLivre;
  ReadonlySignal<RequestState<Reserva>> get envio => _envio;

  /// Erro que não é do motivo (rede, servidor...), mostrado no sheet.
  ReadonlySignal<String?> get erroGeral => _erroGeral;

  /// Evento de uma leitura: o contêiner fecha o sheet com o resultado.
  ReadonlySignal<ResultadoCancelamentoDono?> get resultado => _resultado;

  late final ReadonlySignal<bool> enviando =
      computed(() => _envio.value is RequestLoading);

  /// Aviso de estorno só para reserva já paga (`CONFIRMADA`).
  late final ReadonlySignal<bool> mostrarAvisoEstorno = computed(
    () => _reserva.value?.status == StatusReserva.confirmada,
  );

  late final ReadonlySignal<bool> motivoLivre =
      computed(() => _motivo.value == MotivoCancelamentoDono.outro);

  late final ReadonlySignal<bool> motivoValido = computed(
    () => !motivoLivre.value || motivoLivreValido(_textoLivre.value),
  );

  /// Erro do campo do motivo: o do 400 `VALIDACAO` ou, no texto livre já
  /// iniciado, o mínimo de caracteres.
  late final ReadonlySignal<String?> erroMotivo = computed(() {
    final api = _erroMotivoApi.value;
    if (api != null) return api;
    if (!motivoLivre.value) return null;
    final t = _textoLivre.value.trim();
    if (t.isEmpty || t.length >= motivoMinimo) return null;
    return 'reservas.cancelamento_dono.erro_minimo'.tr();
  });

  late final ReadonlySignal<bool> podeConfirmar = computed(
    () => _reserva.value != null && motivoValido.value && !enviando.value,
  );

  void iniciar(Reserva reserva) {
    batch(() {
      _reserva.value = reserva;
      _envio.value = const RequestInitial();
      _resultado.value = null;
    });
  }

  void selecionarMotivo(MotivoCancelamentoDono motivo) {
    batch(() {
      _motivo.value = motivo;
      _erroMotivoApi.value = null;
      _erroGeral.value = null;
    });
  }

  void alterarTextoLivre(String texto) {
    batch(() {
      _textoLivre.value = texto;
      _erroMotivoApi.value = null;
    });
  }

  /// Texto enviado como `motivo`: o da opção (no idioma ativo) ou o livre.
  String get motivoParaEnvio => motivoLivre.value
      ? _textoLivre.value.trim()
      : _motivo.value.rotuloKey.tr();

  /// `POST /reservas/{id}/cancelar` com `{motivo}`.
  Future<void> confirmar() async {
    final reserva = _reserva.value;
    if (reserva == null || !podeConfirmar.value) return;

    batch(() {
      _envio.value = const RequestLoading();
      _erroGeral.value = null;
      _erroMotivoApi.value = null;
    });
    final r = await _reservas.cancelar(reserva.id, motivoParaEnvio);
    if (_descartado) return;

    r.fold(
      (falha) {
        _envio.value = RequestFailure(falha);
        _tratarFalha(falha);
      },
      (atualizada) => batch(() {
        _envio.value = RequestSuccess(atualizada);
        _resultado.value = CancelamentoConcluido(atualizada);
      }),
    );
  }

  void _tratarFalha(Failure falha) {
    if (falha is ApiFailure) {
      final codigo = falha.subcodigo ?? falha.codigo;
      if (codigo == 'CANCELAMENTO_FORA_DO_PRAZO') {
        _resultado.value = CancelamentoRecusado(
          'reservas.cancelamento_dono.fora_do_prazo'.tr(),
        );
        return;
      }
      if (codigo == 'TRANSICAO_INVALIDA') {
        _resultado.value = CancelamentoRecusado(
          'reservas.cancelamento_dono.mudou_situacao'.tr(),
        );
        return;
      }
      if (falha.codigo == 'VALIDACAO' || falha.status == 400) {
        _erroMotivoApi.value = falha.campos['motivo'] ?? falha.message;
        return;
      }
    }
    _erroGeral.value = falha.message;
  }

  void consumirResultado() => _resultado.value = null;

  void dispose() {
    _descartado = true;
    podeConfirmar.dispose();
    erroMotivo.dispose();
    motivoValido.dispose();
    motivoLivre.dispose();
    mostrarAvisoEstorno.dispose();
    enviando.dispose();
    _reserva.dispose();
    _motivo.dispose();
    _textoLivre.dispose();
    _envio.dispose();
    _erroMotivoApi.dispose();
    _erroGeral.dispose();
    _resultado.dispose();
  }
}
