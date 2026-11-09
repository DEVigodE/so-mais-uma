import 'package:so_mais_uma/src/imports/imports.dart';

import 'cancelamento_cliente_store.dart';
import 'cancelamento_cliente_view.dart';

/// Abre o sheet de cancelamento do cliente (`cancelar_reserva_confirma_o`).
/// Devolve `true` quando a reserva foi cancelada.
///
/// Também devolve `true` no 422 `TRANSICAO_INVALIDA` ("A reserva mudou de
/// situação"): nos dois casos quem abriu o sheet precisa recarregar a reserva
/// (a DetalheReserva recarrega; o Pagamento leva ao detalhe). O snackbar do
/// desfecho é mostrado aqui.
Future<bool> mostrarCancelamentoCliente(
  BuildContext context,
  Reserva reserva,
) async {
  final resultado = await showModalBottomSheet<ResultadoCancelamento>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: context.colors.onSurface.withValues(alpha: 0.6),
    builder: (_) => CancelamentoClienteSheet(reserva: reserva),
  );
  if (resultado == null) return false;
  if (context.mounted) {
    switch (resultado) {
      case ResultadoCancelamento.cancelada:
        showAppSnack(
          context,
          'reservas.cancelamento_cliente.sucesso'.tr(),
          type: SnackBarType.success,
        );
      case ResultadoCancelamento.mudouSituacao:
        showAppSnack(
          context,
          'reservas.cancelamento_cliente.erro_mudou_situacao'.tr(),
          type: SnackBarType.error,
        );
    }
  }
  return true;
}

/// Contêiner do sheet: resolve o store, guarda o campo e os focos e fecha o
/// sheet com o desfecho.
class CancelamentoClienteSheet extends StatefulWidget {
  const CancelamentoClienteSheet({super.key, required this.reserva});

  final Reserva reserva;

  @override
  State<CancelamentoClienteSheet> createState() =>
      _CancelamentoClienteSheetState();
}

class _CancelamentoClienteSheetState extends State<CancelamentoClienteSheet> {
  late final CancelamentoClienteStore _store;
  late final EffectCleanup _limparResultado;
  final _motivo = TextEditingController();
  final _motivoFocus = FocusNode(debugLabel: 'motivo-cancelamento');
  final _manterFocus = FocusNode(debugLabel: 'manter-reserva');
  bool _fechando = false;

  @override
  void initState() {
    super.initState();
    _store = injector.get<CancelamentoClienteStore>()..iniciar(widget.reserva);
    _limparResultado = effect(() {
      final resultado = _store.resultado.value;
      if (resultado == null || _fechando) return;
      _fechando = true;
      Future.microtask(() {
        if (mounted) Navigator.of(context).pop(resultado);
      });
    });
  }

  void _usarChip(String texto) {
    _motivo.value = TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
    _store.alterarMotivo(texto);
    _motivoFocus.requestFocus();
  }

  @override
  void dispose() {
    _limparResultado();
    _store.dispose();
    _motivo.dispose();
    _motivoFocus.dispose();
    _manterFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) => CancelamentoClienteView(
        reserva: widget.reserva,
        prazo: _store.prazo.value,
        tamanho: _store.tamanho.value,
        motivoCurto: _store.motivoCurto.value,
        podeConfirmar: _store.podeConfirmar.value,
        enviando: _store.envio.value.isLoading,
        erro: _store.erro.value,
        motivoController: _motivo,
        motivoFocus: _motivoFocus,
        manterFocus: _manterFocus,
        onMotivo: _store.alterarMotivo,
        onChip: _usarChip,
        onManter: () => Navigator.of(context).pop(),
        onConfirmar: _store.confirmar,
      ),
    );
  }
}
