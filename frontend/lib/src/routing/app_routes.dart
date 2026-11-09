import '../shared/domain/enums.dart';

/// Caminhos centralizados do GoRouter (design D9, docs/04 §4.2).
///
/// Use as constantes e os construtores de caminho em vez de strings soltas.
/// Exemplo: `context.push(AppRoutes.quadra(id))`.
abstract final class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';

  /// Alias da home: o redirect leva à home do perfil da sessão.
  static const String home = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';

  // ── CLIENTE ───────────────────────────────────────────────────────────────
  /// Aba 0 do shell CLIENTE.
  static const String quadras = '/quadras';

  /// DetalheQuadra do cliente, com a grade de horários.
  static String quadra(int id) => '/quadras/$id';

  /// ConfirmarReserva. `inicio` é o instante do slot (ISO-8601 em UTC na URL).
  static String confirmarReserva(int quadraId, DateTime inicio) =>
      '/quadras/$quadraId/reservar?inicio='
      '${Uri.encodeQueryComponent(inicio.toUtc().toIso8601String())}';

  /// Aba 1 do shell CLIENTE.
  static const String reservas = '/reservas';
  static String reserva(int id) => '/reservas/$id';
  static String pagamento(int reservaId) => '/reservas/$reservaId/pagamento';

  /// Aba 2 do shell CLIENTE.
  static const String perfil = '/perfil';

  // ── DONO ──────────────────────────────────────────────────────────────────
  /// Aba 0 do shell DONO.
  static const String donoQuadras = '/dono/quadras';
  static const String donoNovaQuadra = '/dono/quadras/nova';

  /// DetalheQuadra do dono (só a parte estática, sem grade).
  static String donoQuadra(int id) => '/dono/quadras/$id';
  static String donoEditarQuadra(int id) => '/dono/quadras/$id/editar';
  static String donoHorarios(int id) => '/dono/quadras/$id/horarios';

  /// ReservasQuadra filtrada por uma quadra.
  static String donoReservasDaQuadra(int id) => '/dono/quadras/$id/reservas';

  /// Aba 1 do shell DONO: ReservasQuadra de todas as quadras.
  static const String donoReservas = '/dono/reservas';

  /// Aba 2 do shell DONO.
  static const String donoPerfil = '/dono/perfil';

  /// Debug-only component gallery.
  static const String uiShowcase = '/debug/ui-showcase';

  /// Home do perfil: Quadras (CLIENTE) ou MinhasQuadras (DONO).
  static String homeDoPerfil(PerfilUsuario perfil) =>
      perfil == PerfilUsuario.dono ? donoQuadras : quadras;

  /// Rotas acessíveis sem sessão.
  static const Set<String> publicas = {
    login,
    signup,
    forgotPassword,
    uiShowcase,
  };
}
