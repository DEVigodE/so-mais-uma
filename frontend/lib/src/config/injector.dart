import 'package:auto_injector/auto_injector.dart';

import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/providers/auth_store.dart';
import '../features/auth/presentation/providers/session_store.dart';

/// Composition root. Resolve dependencies with `injector.get<T>()`.
final injector = AutoInjector();

void setupInjector() {
  injector
    ..addLazySingleton<AuthRepository>(AuthRepositoryImpl.new)
    ..addLazySingleton<SessionStore>(
      SessionStore.new,
      config: BindConfig(onDispose: (store) => store.dispose()),
    )
    ..add<AuthStore>(AuthStore.new)
    ..commit();
}
