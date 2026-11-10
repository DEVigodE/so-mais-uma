import 'package:so_mais_uma/src/imports/imports.dart';

import 'grade_slots_store.dart';
import 'grade_slots_view.dart';

/// Seção de reserva da DetalheQuadra do cliente: faixa de datas, grade de
/// slots e a barra fixa "Horário selecionado".
///
/// A seção é dona do store da grade e da barra, mas não do layout da tela:
/// ela chama [layout] com a seção (que entra no fim da rolagem da
/// DetalheQuadra) e a barra (fixa no rodapé). A composição fica no router, e
/// nenhuma feature importa a outra.
class GradeSlotsSection extends StatefulWidget {
  const GradeSlotsSection({
    super.key,
    required this.quadra,
    required this.layout,
  });

  final Quadra quadra;

  /// Monta o corpo da tela com `secao` e `barra`.
  final Widget Function(Widget secao, Widget barra) layout;

  @override
  State<GradeSlotsSection> createState() => _GradeSlotsSectionState();
}

class _GradeSlotsSectionState extends State<GradeSlotsSection> {
  late final GradeSlotsStore _store;
  late final EffectCleanup _limparEfeitoAviso;
  late final AppLifecycleListener _ciclo;
  bool _abrindoConfirmacao = false;

  @override
  void initState() {
    super.initState();
    _store = injector.get<GradeSlotsStore>();
    _limparEfeitoAviso = effect(() {
      final aviso = _store.aviso.value;
      if (aviso == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showAppSnack(context, aviso.mensagem, type: SnackBarType.warning);
        _store.consumirAviso();
      });
      // Garante um quadro para o callback rodar mesmo sem rebuild.
      WidgetsBinding.instance.ensureVisualUpdate();
    });
    // Volta ao primeiro plano: recarrega mantendo a seleção ainda livre.
    _ciclo = AppLifecycleListener(
      onResume: () => _store.recarregar(limparSelecao: false),
    );
    _store.iniciar(widget.quadra.id);
  }

  @override
  void didUpdateWidget(covariant GradeSlotsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quadra.id != widget.quadra.id) {
      _store.iniciar(widget.quadra.id);
    }
  }

  @override
  void dispose() {
    _ciclo.dispose();
    _limparEfeitoAviso();
    _store.dispose();
    super.dispose();
  }

  Future<void> _continuar() async {
    final slot = _store.selecionado.value;
    if (slot == null || _abrindoConfirmacao) return;
    _abrindoConfirmacao = true;
    final recarregar = await context.push<bool>(
      AppRoutes.confirmarReserva(widget.quadra.id, slot.inicio),
    );
    _abrindoConfirmacao = false;
    if (!mounted) return;
    if (recarregar ?? false) _store.recarregar();
  }

  @override
  Widget build(BuildContext context) {
    return widget.layout(
      SignalBuilder(
        builder: (context) => GradeSlotsView(
          datas: _store.datas.value,
          dataSelecionada: _store.dataSelecionada.value,
          grade: _store.grade.value,
          visiveis: _store.visiveis.value,
          selecionado: _store.selecionado.value,
          semLivre: _store.semLivre.value,
          proxima: _store.proxima.value,
          onData: _store.selecionarData,
          onSlot: _store.tocarSlot,
          onTentarNovamente: _store.tentarNovamente,
        ),
      ),
      SignalBuilder(
        builder: (context) => BarraHorarioSelecionado(
          slot: _store.selecionado.value,
          data: _store.dataSelecionada.value,
          onContinuar: _continuar,
        ),
      ),
    );
  }
}
