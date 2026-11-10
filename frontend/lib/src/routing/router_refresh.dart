import 'package:flutter/foundation.dart';
import 'package:signals/signals_flutter.dart';

import '../shared/session/session_store.dart';

/// Marca quando a Splash do protótipo já ficou 1 s na tela (design D9).
class SplashGate {
  SplashGate._();
  static final SplashGate instance = SplashGate._();

  final _concluida = signal(false);

  ReadonlySignal<bool> get concluida => _concluida;

  void concluir() => _concluida.value = true;
}

/// `refreshListenable` do GoRouter: notifica quando a sessão ou a Splash mudam.
class RouterRefresh extends ChangeNotifier {
  RouterRefresh(SessionStore sessao, SplashGate splash) {
    var primeiro = true;
    _cleanup = effect(() {
      sessao.state.value;
      splash.concluida.value;
      if (primeiro) {
        primeiro = false;
        return;
      }
      notifyListeners();
    });
  }

  late final void Function() _cleanup;

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
