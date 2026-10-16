import 'package:so_mais_uma/src/imports/core_imports.dart';
import 'package:so_mais_uma/src/imports/packages_imports.dart';

import 'package:so_mais_uma/src/features/auth/presentation/providers/session_store.dart';


class SessionListenerWrapper extends StatefulWidget {
  final Widget child;
  const SessionListenerWrapper({super.key, required this.child});

  @override
  State<SessionListenerWrapper> createState() => _SessionListenerWrapperState();
}

class _SessionListenerWrapperState extends State<SessionListenerWrapper> {
  late final EffectCleanup _disposeEffect;

  @override
  void initState() {
    super.initState();
    final sessionStore = injector.get<SessionStore>();
    // Runs immediately and again on every session change.
    _disposeEffect = effect(() {
      final next = sessionStore.state.value;
      // This widget sits above the Router (MaterialApp.builder), so its
      // context has no GoRouter — navigate through the global router.
      switch (next) {
        case SessionUnknown():
          break;
        case SessionAuthenticated():
          FlutterNativeSplash.remove();
          appRouter.go(AppRoutes.home);
        case SessionUnauthenticated():
          FlutterNativeSplash.remove();
          appRouter.go(AppRoutes.onboarding);
      }
    });
  }

  @override
  void dispose() {
    _disposeEffect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
