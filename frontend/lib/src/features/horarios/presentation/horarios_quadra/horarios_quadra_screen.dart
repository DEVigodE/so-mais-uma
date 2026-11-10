import 'package:so_mais_uma/src/imports/imports.dart';

import 'horarios_quadra_store.dart';
import 'horarios_quadra_view.dart';

/// HorariosQuadra (`/dono/quadras/:id/horarios`): 7 cartões de segunda a
/// domingo, salvos em lote por operações individuais.
class HorariosQuadraScreen extends StatefulWidget {
  const HorariosQuadraScreen({
    super.key,
    required this.quadraId,
  });

  final int quadraId;

  @override
  State<HorariosQuadraScreen> createState() => _HorariosQuadraScreenState();
}

class _HorariosQuadraScreenState extends State<HorariosQuadraScreen> {
  late final HorariosQuadraStore _store;
  late final void Function() _limparEfeito;

  @override
  void initState() {
    super.initState();
    _store = injector.get<HorariosQuadraStore>();
    _limparEfeito = effect(() {
      final evento = _store.evento.value;
      if (evento == null) return;
      Future.microtask(() {
        if (!mounted) return;
        _store.consumirEvento();
        _tratarEvento(evento);
      });
    });
    _store.carregar(widget.quadraId);
  }

  @override
  void dispose() {
    _limparEfeito();
    _store.dispose();
    super.dispose();
  }

  void _tratarEvento(EventoHorarios evento) {
    switch (evento) {
      case HorarioCopiado():
        showAppSnack(context, 'horarios.copiado'.tr());
      case HorariosSalvos():
        showAppSnack(
          context,
          'horarios.salvos'.tr(),
          type: SnackBarType.success,
        );
      case SalvamentoIncompleto(:final conflitoComReservas, :final pendencias):
        if (pendencias) {
          showAppSnack(
            context,
            'horarios.pendentes'.tr(),
            type: SnackBarType.error,
          );
        }
        if (conflitoComReservas) _mostrarConflitoReservas();
    }
  }

  Future<void> _mostrarConflitoReservas() async {
    final verReservas = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.event_busy_outlined, color: context.colors.error),
        title: Text('horarios.conflito_titulo'.tr()),
        content: Text('horarios.conflito_mensagem'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('comum.fechar'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('horarios.ver_reservas'.tr()),
          ),
        ],
      ),
    );
    if ((verReservas ?? false) && mounted) {
      context.push(AppRoutes.donoReservasDaQuadra(widget.quadraId));
    }
  }

  Future<void> _salvar() async {
    if (!_store.validar()) return;
    final dias = _store.diasParaFechar.value;
    if (dias.isNotEmpty) {
      final confirmado = await showAppAlertDialog(
        context,
        title: 'horarios.fechar_titulo'
            .tr(namedArgs: {'dias': _diasComPreposicao(dias)}),
        message: 'horarios.fechar_mensagem'.tr(),
        confirmLabel: 'horarios.fechar_confirmar'.tr(),
        cancelLabel: 'comum.cancelar'.tr(),
        isDestructive: true,
      );
      if (confirmado != true || !mounted) return;
    }
    await _store.salvar();
  }

  /// "na segunda-feira e no domingo" / "na segunda-feira, na terça-feira e no
  /// domingo".
  String _diasComPreposicao(List<int> dias) {
    final nomes = [for (final d in dias) 'horarios.dia_prep.$d'.tr()];
    if (nomes.length == 1) return nomes.first;
    final e = 'horarios.e'.tr();
    return '${nomes.sublist(0, nomes.length - 1).join(', ')} $e ${nomes.last}';
  }

  /// Volta pelo `maybePop` para o `PopScope` interceptar alterações pendentes.
  void _voltar() => Navigator.of(context).maybePop(_store.salvouAlgo);

  Future<void> _confirmarDescarte() async {
    final descartar = await showAppAlertDialog(
      context,
      title: 'comum.descartar_alteracoes_titulo'.tr(),
      message: 'comum.descartar_alteracoes_mensagem'.tr(),
      confirmLabel: 'comum.descartar'.tr(),
      cancelLabel: 'horarios.continuar_editando'.tr(),
      isDestructive: true,
    );
    if ((descartar ?? false) && mounted) {
      Navigator.of(context).pop(_store.salvouAlgo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final alterado = _store.alterado.value;
        return PopScope<Object?>(
          canPop: !alterado && !_store.salvando.value,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || _store.salvando.value) return;
            _confirmarDescarte();
          },
          child: HorariosQuadraView(
            carga: _store.carga.value,
            quadra: _store.quadra.value,
            dias: _store.dias.value,
            errosDia: _store.errosDia.value,
            salvando: _store.salvando.value,
            podeSalvar: _store.podeSalvar.value,
            podeCopiar: _store.podeCopiar.value,
            semFaixas: _store.semFaixas.value,
            onVoltar: _voltar,
            onTentarNovamente: () => _store.carregar(widget.quadraId),
            onAlternarDia: (dia, aberto) =>
                _store.alternarDia(dia, aberto: aberto),
            onAbertura: _store.definirAbertura,
            onFechamento: _store.definirFechamento,
            onCopiar: _store.copiarSegunda,
            onSalvar: _salvar,
          ),
        );
      },
    );
  }
}
