import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:so_mais_uma/src/config/injector.dart';
import 'package:so_mais_uma/src/middleware/app_route_observer.dart';
import 'package:so_mais_uma/src/routing/app_routes.dart';
import 'package:so_mais_uma/src/routing/global_navigator.dart';
import 'package:so_mais_uma/src/routing/redirect.dart';
import 'package:so_mais_uma/src/routing/router_refresh.dart';
import 'package:so_mais_uma/src/routing/shell_scaffold.dart';
import 'package:so_mais_uma/src/shared/session/session_store.dart';
import 'package:so_mais_uma/src/shared/widgets/ui/ui_showcase_screen.dart';

import 'package:so_mais_uma/src/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:so_mais_uma/src/features/auth/presentation/screens/login_screen.dart';
import 'package:so_mais_uma/src/features/auth/presentation/screens/signup_screen.dart';
import 'package:so_mais_uma/src/features/auth/presentation/screens/splash_screen.dart';
import 'package:so_mais_uma/src/features/horarios/presentation/horarios_quadra/horarios_quadra_screen.dart';
import 'package:so_mais_uma/src/features/pagamento/presentation/pagamento/pagamento_screen.dart';
import 'package:so_mais_uma/src/features/perfil/presentation/perfil/perfil_screen.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/detalhe_quadra/detalhe_quadra_screen.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/form_quadra/form_quadra_screen.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/minhas_quadras/minhas_quadras_screen.dart';
import 'package:so_mais_uma/src/features/quadras/presentation/quadras/quadras_screen.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/cancelamento/cancelamento_cliente_sheet.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/confirmar_reserva/confirmar_reserva_screen.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/detalhe_reserva/detalhe_reserva_screen.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/grade/grade_slots_section.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/minhas_reservas/minhas_reservas_screen.dart';
import 'package:so_mais_uma/src/features/reservas/presentation/reservas_quadra/reservas_quadra_screen.dart';

final _shellClienteQuadras = GlobalKey<NavigatorState>(debugLabel: 'cliente-quadras');
final _shellClienteReservas = GlobalKey<NavigatorState>(debugLabel: 'cliente-reservas');
final _shellClientePerfil = GlobalKey<NavigatorState>(debugLabel: 'cliente-perfil');
final _shellDonoQuadras = GlobalKey<NavigatorState>(debugLabel: 'dono-quadras');
final _shellDonoReservas = GlobalKey<NavigatorState>(debugLabel: 'dono-reservas');
final _shellDonoPerfil = GlobalKey<NavigatorState>(debugLabel: 'dono-perfil');

int _id(GoRouterState state, [String nome = 'id']) =>
    int.tryParse(state.pathParameters[nome] ?? '') ?? 0;

/// Router único com dois `StatefulShellRoute.indexedStack` (CLIENTE e DONO).
/// As telas de detalhe abrem no navigator raiz, por cima da bottom-nav.
/// Acessado depois de `setupInjector()` (o `SessionStore` vem do injector).
final GoRouter appRouter = _criarRouter();

GoRouter _criarRouter() {
  final sessao = injector.get<SessionStore>();
  final splash = SplashGate.instance;

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    observers: <NavigatorObserver>[AppRouteObserver()],
    refreshListenable: RouterRefresh(sessao, splash),
    redirect: (context, state) => redirecionar(
      sessao: sessao.state.value,
      splashConcluida: splash.concluida.value,
      caminho: state.uri.path,
    ),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        // O redirect sempre leva à home do perfil.
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // ── Shell CLIENTE ───────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            ShellScaffold(navigationShell: shell, itens: itensCliente),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellClienteQuadras,
            routes: [
              GoRoute(
                path: AppRoutes.quadras,
                name: 'quadras',
                builder: (context, state) => const QuadrasScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'quadra',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => DetalheQuadraScreen(
                      quadraId: _id(state),
                      secaoReserva: (quadra, layout) =>
                          GradeSlotsSection(quadra: quadra, layout: layout),
                    ),
                    routes: [
                      GoRoute(
                        path: 'reservar',
                        name: 'confirmarReserva',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => ConfirmarReservaScreen(
                          quadraId: _id(state),
                          inicio: DateTime.tryParse(
                                state.uri.queryParameters['inicio'] ?? '',
                              ) ??
                              DateTime.now(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellClienteReservas,
            routes: [
              GoRoute(
                path: AppRoutes.reservas,
                name: 'reservas',
                builder: (context, state) => const MinhasReservasScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'reserva',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) =>
                        DetalheReservaScreen(reservaId: _id(state)),
                    routes: [
                      GoRoute(
                        path: 'pagamento',
                        name: 'pagamento',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => PagamentoScreen(
                          reservaId: _id(state),
                          cancelar: mostrarCancelamentoCliente,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellClientePerfil,
            routes: [
              GoRoute(
                path: AppRoutes.perfil,
                name: 'perfil',
                builder: (context, state) => const PerfilScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Shell DONO ──────────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            ShellScaffold(navigationShell: shell, itens: itensDono),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellDonoQuadras,
            routes: [
              GoRoute(
                path: AppRoutes.donoQuadras,
                name: 'donoQuadras',
                builder: (context, state) => const MinhasQuadrasScreen(),
                routes: [
                  // `nova` antes de `:id`, senão seria lida como id.
                  GoRoute(
                    path: 'nova',
                    name: 'donoNovaQuadra',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const FormQuadraScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    name: 'donoQuadra',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => DetalheQuadraScreen(
                      quadraId: _id(state),
                      modoDono: true,
                    ),
                    routes: [
                      GoRoute(
                        path: 'editar',
                        name: 'donoEditarQuadra',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) =>
                            FormQuadraScreen(quadraId: _id(state)),
                      ),
                      GoRoute(
                        path: 'horarios',
                        name: 'donoHorarios',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) =>
                            HorariosQuadraScreen(quadraId: _id(state)),
                      ),
                      GoRoute(
                        path: 'reservas',
                        name: 'donoReservasDaQuadra',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) =>
                            ReservasQuadraScreen(quadraId: _id(state)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellDonoReservas,
            routes: [
              GoRoute(
                path: AppRoutes.donoReservas,
                name: 'donoReservas',
                builder: (context, state) => const ReservasQuadraScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellDonoPerfil,
            routes: [
              GoRoute(
                path: AppRoutes.donoPerfil,
                name: 'donoPerfil',
                builder: (context, state) => const PerfilScreen(),
              ),
            ],
          ),
        ],
      ),

      if (kDebugMode)
        GoRoute(
          path: AppRoutes.uiShowcase,
          name: 'uiShowcase',
          builder: (context, state) => const UiShowcaseScreen(),
        ),
    ],
  );
}
