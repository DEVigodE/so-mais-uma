import 'package:so_mais_uma/src/imports/imports.dart';

import 'cancelamento_dono_store.dart';
import 'cancelamento_dono_view.dart';

export 'cancelamento_dono_store.dart'
    show CancelamentoConcluido, CancelamentoRecusado, ResultadoCancelamentoDono;

/// Abre o sheet de cancelamento pelo dono por cima do shell e devolve o
/// resultado (`null` quando o dono volta sem cancelar).
Future<ResultadoCancelamentoDono?> abrirCancelamentoDono(
  BuildContext context,
  Reserva reserva,
) {
  return showModalBottomSheet<ResultadoCancelamentoDono>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.colors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(borderRadius: AppBorders.bottomSheet),
    builder: (_) => CancelamentoDonoSheet(reserva: reserva),
  );
}

/// Contêiner do sheet (design D4): resolve o store, guarda o controller do
/// motivo livre e fecha o sheet com o resultado.
class CancelamentoDonoSheet extends StatefulWidget {
  const CancelamentoDonoSheet({super.key, required this.reserva});

  final Reserva reserva;

  @override
  State<CancelamentoDonoSheet> createState() => _CancelamentoDonoSheetState();
}

class _CancelamentoDonoSheetState extends State<CancelamentoDonoSheet> {
  late final CancelamentoDonoStore _store;
  final _textoLivre = TextEditingController();
  EffectCleanup? _efeitoResultado;

  @override
  void initState() {
    super.initState();
    _store = injector.get<CancelamentoDonoStore>();
    _store.iniciar(widget.reserva);
    _efeitoResultado = effect(() {
      final resultado = _store.resultado.value;
      if (resultado == null) return;
      Future.microtask(() {
        if (!mounted) return;
        _store.consumirResultado();
        Navigator.of(context).pop(resultado);
      });
    });
  }

  @override
  void dispose() {
    _efeitoResultado?.call();
    _textoLivre.dispose();
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final enviando = _store.enviando.value;
        return PopScope(
          canPop: !enviando,
          child: CancelamentoDonoView(
            reserva: widget.reserva,
            motivo: _store.motivo.value,
            mostrarAvisoEstorno: _store.mostrarAvisoEstorno.value,
            motivoLivre: _store.motivoLivre.value,
            textoLivreController: _textoLivre,
            comprimentoTextoLivre: _store.textoLivre.value.length,
            enviando: enviando,
            podeConfirmar: _store.podeConfirmar.value,
            erroMotivo: _store.erroMotivo.value,
            erroGeral: _store.erroGeral.value,
            onMotivo: _store.selecionarMotivo,
            onTextoLivre: _store.alterarTextoLivre,
            onVoltar: () => Navigator.of(context).maybePop(),
            onConfirmar: _store.confirmar,
          ),
        );
      },
    );
  }
}
