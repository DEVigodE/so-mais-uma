import 'package:so_mais_uma/src/imports/core_imports.dart';
import 'package:so_mais_uma/src/imports/packages_imports.dart';

import 'package:so_mais_uma/src/features/auth/domain/entities/user.dart';
import 'package:so_mais_uma/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:so_mais_uma/src/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:so_mais_uma/src/features/auth/data/datasources/auth_remote_data_source_impl.dart';
import 'package:so_mais_uma/src/features/auth/data/models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({AuthRemoteDataSource? remoteDataSource})
      : _remoteDataSource =
            remoteDataSource ?? AuthRemoteDataSourceImpl();

  final AuthRemoteDataSource _remoteDataSource;

  AppUser _toUser(Map<String, dynamic> userData, {String? fallbackEmail, String? fallbackName}) {
    final model = UserModel.fromJson(userData);
    final entity = model.toEntity();
    if (fallbackEmail == null && fallbackName == null) return entity;
    return AppUser(
      id: entity.id,
      email: entity.email.isEmpty ? (fallbackEmail ?? '') : entity.email,
      name: entity.name ?? fallbackName,
      photoUrl: entity.photoUrl,
    );
  }

  @override
  Stream<AppUser?> get onAuthStateChanged {
    return _remoteDataSource.authStateChanges.map((userData) {
      if (userData == null) return null;
      return _toUser(userData);
    });
  }

  @override
  FutureEither<AppUser> login({
    required String email,
    required String password,
  }) async {
    final result = await _remoteDataSource.login(email: email, password: password);

    return result.flatMap((userData) {
      if (userData == null) {
        return left(const ServerFailure('Login failed: User record not found'));
      }
      return right(_toUser(userData, fallbackEmail: email));
    });
  }

  @override
  FutureEither<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final result = await _remoteDataSource.signUp(
      name: name,
      email: email,
      password: password,
    );

    return result.flatMap((userData) {
      if (userData == null) {
        return left(
            const ServerFailure('Sign up failed: User record corrupted'));
      }
      return right(_toUser(userData, fallbackEmail: email, fallbackName: name));
    });
  }

  @override
  FutureEither<void> forgotPassword({required String email}) {
    return _remoteDataSource.forgotPassword(email: email);
  }

  @override
  FutureEither<void> logout() {
    return _remoteDataSource.logout();
  }

  @override
  FutureEither<AppUser?> checkAuthState() async {
    final result = await _remoteDataSource.getCurrentUser();

    return result.map((userData) {
      if (userData == null) return null;
      return _toUser(userData);
    });
  }
}
