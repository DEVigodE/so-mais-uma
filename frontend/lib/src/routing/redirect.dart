import '../shared/domain/enums.dart';
import '../shared/session/session_store.dart';
import 'app_routes.dart';

/// Regra pura do `redirect` do GoRouter (design D9), testável sem Flutter.
///
/// - Sessão desconhecida: tudo vai para a Splash.
/// - Splash ainda no mínimo de 1 s: fica na Splash.
/// - Sem sessão: só rotas públicas; o resto vai para o Login.
/// - Com sessão: Splash, Login, Cadastro e `/` vão para a home do perfil;
///   rota do outro perfil também vai para a home do perfil.
String? redirecionar({
  required SessionState sessao,
  required bool splashConcluida,
  required String caminho,
}) {
  final naSplash = caminho == AppRoutes.splash;

  switch (sessao) {
    case SessionUnknown():
      return naSplash ? null : AppRoutes.splash;

    case SessionUnauthenticated():
      if (naSplash) return splashConcluida ? AppRoutes.login : null;
      if (AppRoutes.publicas.contains(caminho)) return null;
      return AppRoutes.login;

    case SessionAuthenticated(:final user):
      final home = AppRoutes.homeDoPerfil(user.perfil);
      if (naSplash) return splashConcluida ? home : null;
      if (caminho == AppRoutes.home ||
          caminho == AppRoutes.login ||
          caminho == AppRoutes.signup ||
          caminho == AppRoutes.forgotPassword) {
        return home;
      }
      if (caminho == AppRoutes.uiShowcase) return null;
      final rotaDono = caminho == '/dono' || caminho.startsWith('/dono/');
      if (user.perfil == PerfilUsuario.dono && !rotaDono) return home;
      if (user.perfil == PerfilUsuario.cliente && rotaDono) return home;
      return null;
  }
}
