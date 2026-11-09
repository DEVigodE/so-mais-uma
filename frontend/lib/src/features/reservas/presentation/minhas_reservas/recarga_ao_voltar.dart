import 'package:so_mais_uma/src/imports/imports.dart';

/// Chama [aoVoltarParaTela] quando a rota do topo volta a ser [caminhoDaTela]
/// depois de ter sido outra (pop de um detalhe, `go` vindo do Pagamento ou
/// troca de aba). Serve para recarregar dados que outra tela pode ter mudado.
///
/// Usa `GoRouter.state.matchedLocation`, que considera também as rotas
/// abertas com `push` (a `uri` da configuração não muda no `push`).
mixin RecargaAoVoltar<T extends StatefulWidget> on State<T> {
  GoRouter? _router;
  String? _localAnterior;

  /// Local da tela, como `AppRoutes.reservas` ou `AppRoutes.reserva(id)`.
  String get caminhoDaTela;

  /// Chamado ao voltar para a tela.
  void aoVoltarParaTela();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (identical(router, _router)) return;
    _router?.routerDelegate.removeListener(_aoMudarRota);
    _router = router;
    _localAnterior = _localAtual();
    router?.routerDelegate.addListener(_aoMudarRota);
  }

  String? _localAtual() {
    final router = _router;
    if (router == null) return null;
    if (router.routerDelegate.currentConfiguration.isEmpty) return null;
    return router.state.matchedLocation;
  }

  void _aoMudarRota() {
    final atual = _localAtual();
    final voltou = atual == caminhoDaTela && _localAnterior != caminhoDaTela;
    _localAnterior = atual;
    if (voltou && mounted) aoVoltarParaTela();
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_aoMudarRota);
    _router = null;
    super.dispose();
  }
}
