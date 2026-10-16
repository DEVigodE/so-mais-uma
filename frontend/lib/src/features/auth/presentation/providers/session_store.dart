import 'dart:async';
import 'package:so_mais_uma/src/imports/imports.dart';
import 'package:so_mais_uma/src/features/auth/domain/entities/user.dart';
import 'package:so_mais_uma/src/features/auth/domain/repositories/auth_repository.dart';

/// Exhaustive session variants — prefer `switch (state)` over status enums.
sealed class SessionState {
  const SessionState();

  AppUser? get userOrNull => switch (this) {
        SessionAuthenticated(:final user) => user,
        _ => null,
      };

  bool get isUnknown => this is SessionUnknown;
  bool get isAuthenticated => this is SessionAuthenticated;
  bool get isUnauthenticated => this is SessionUnauthenticated;
}

final class SessionUnknown extends SessionState {
  const SessionUnknown();
}

final class SessionAuthenticated extends SessionState {
  const SessionAuthenticated(this.user);
  final AppUser user;
}

final class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated();
}

SessionState sessionFromUser(AppUser? user) => switch (user) {
      final AppUser u => SessionAuthenticated(u),
      null => const SessionUnauthenticated(),
    };

class SessionStore with StreamSubscriptionsMixin {
  SessionStore({required AuthRepository repository})
      : _repository = repository {
    _init();
  }

  final AuthRepository _repository;

  final _state = signal<SessionState>(const SessionUnknown());

  ReadonlySignal<SessionState> get state => _state;

  late final ReadonlySignal<AppUser?> user =
      computed(() => _state.value.userOrNull);

  late final ReadonlySignal<bool> isAuthenticated =
      computed(() => _state.value.isAuthenticated);

  Future<void> _init() async {
    final result = await _repository.checkAuthState();
    _state.value = result.fold(
      (_) => const SessionUnauthenticated(),
      sessionFromUser,
    );

    addSubscription(
      _repository.onAuthStateChanged.listen((user) {
        _state.value = sessionFromUser(user);
      }),
    );
  }

  Future<void> logout() async {
    await _repository.logout();
    _state.value = const SessionUnauthenticated();
  }

  void dispose() {
    cancelSubscriptions();
    user.dispose();
    isAuthenticated.dispose();
    _state.dispose();
  }
}
