import 'package:so_mais_uma/src/imports/imports.dart';

import 'minhas_quadras_store.dart';
import 'minhas_quadras_view.dart';

/// MinhasQuadras (`/dono/quadras`): aba 0 do shell DONO.
class MinhasQuadrasScreen extends StatefulWidget {
  const MinhasQuadrasScreen({super.key});

  @override
  State<MinhasQuadrasScreen> createState() => _MinhasQuadrasScreenState();
}

class _MinhasQuadrasScreenState extends State<MinhasQuadrasScreen> {
  late final MinhasQuadrasStore _store;
  late final void Function() _limparEfeito;

  @override
  void initState() {
    super.initState();
    _store = injector.get<MinhasQuadrasStore>();
    _limparEfeito = effect(() {
      final evento = _store.evento.value;
      if (evento == null) return;
      Future.microtask(() {
        if (!mounted) return;
        _store.consumirEvento();
        _tratarEvento(evento);
      });
    });
    _store.carregar();
  }

  @override
  void dispose() {
    _limparEfeito();
    _store.dispose();
    super.dispose();
  }

  void _tratarEvento(EventoMinhasQuadras evento) {
    switch (evento) {
      case QuadraDesativada(:final nome):
        showAppSnack(
          context,
          'quadras.minhas.desativada'.tr(namedArgs: {'nome': nome}),
          type: SnackBarType.success,
        );
      case DesativacaoBloqueada(:final quadraId):
        _mostrarReservasFuturas(quadraId);
      case SemPermissao():
        showAppSnack(
          context,
          'quadras.minhas.sem_permissao'.tr(),
          type: SnackBarType.error,
        );
      case FalhaMinhasQuadras(:final mensagem):
        showAppSnack(context, mensagem, type: SnackBarType.error);
    }
  }

  /// Abre uma rota empilhada e sincroniza ao voltar ([sempre] = mesmo sem
  /// resultado `true`, para Horários, Reservas e o detalhe).
  Future<void> _abrir(String rota, {bool sempre = true}) async {
    final resultado = await context.push<Object?>(rota);
    if (!mounted) return;
    if (sempre || resultado == true) _store.carregar();
  }

  Future<void> _confirmarDesativacao(Quadra quadra) async {
    final confirmado = await showAppAlertDialog(
      context,
      title: 'quadras.minhas.desativar_titulo'
          .tr(namedArgs: {'nome': quadra.nome}),
      message: 'quadras.minhas.desativar_mensagem'.tr(),
      confirmLabel: 'quadras.minhas.desativar_confirmar'.tr(),
      cancelLabel: 'comum.cancelar'.tr(),
      isDestructive: true,
    );
    if ((confirmado ?? false) && mounted) _store.desativar(quadra);
  }

  Future<void> _mostrarReservasFuturas(int quadraId) async {
    final verReservas = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.event_busy_outlined, color: context.colors.error),
        title: Text('quadras.minhas.bloqueada_titulo'.tr()),
        content: Text('quadras.minhas.bloqueada_mensagem'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('comum.fechar'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('quadras.minhas.ver_reservas'.tr()),
          ),
        ],
      ),
    );
    if ((verReservas ?? false) && mounted) {
      _abrir(AppRoutes.donoReservasDaQuadra(quadraId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) => MinhasQuadrasView(
        estado: _store.estado.value,
        cards: _store.cards.value,
        resumo: _store.resumo.value,
        desativando: _store.desativando.value,
        onAtualizar: _store.carregar,
        onTentarNovamente: _store.carregar,
        onNovaQuadra: () => _abrir(AppRoutes.donoNovaQuadra, sempre: false),
        onAbrir: (q) => _abrir(AppRoutes.donoQuadra(q.id)),
        onEditar: (q) =>
            _abrir(AppRoutes.donoEditarQuadra(q.id), sempre: false),
        onHorarios: (q) => _abrir(AppRoutes.donoHorarios(q.id)),
        onReservas: (q) => _abrir(AppRoutes.donoReservasDaQuadra(q.id)),
        onDesativar: _confirmarDesativacao,
        onPerfil: () => context.go(AppRoutes.donoPerfil),
      ),
    );
  }
}
