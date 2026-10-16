import 'dart:async';
import '../utils/utils.dart';
import '../config/app_config.dart';
import 'secure_storage_service.dart';
import 'package:dio/dio.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _tokenKey = 'auth_token';

  /// Sign-up always creates CLIENTE accounts; DONO accounts are created directly in the database.
  static const _signUpProfile = 'CLIENTE';

  Dio get _dio => AppConfig.dio;

  // Custom Backend doesn't have a built-in auth state stream, so we manage our own
  final StreamController<Map<String, dynamic>?> _authStateController =
      StreamController<Map<String, dynamic>?>.broadcast();

  /// Stream of auth state changes. Emits the current user map or null.
  Stream<Map<String, dynamic>?> get authStateChanges {
    return logAuthStateChanges(
      _authStateController.stream,
      userIdOf: (user) => user['id']?.toString() ?? '',
    );
  }

  FutureEither<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    return runTask(() async {
      final response = await _dio.post<Map<String, dynamic>>('/auth/login', data: {
        'email': email,
        'senha': password,
      });
      return _startSession(response.data!);
    },
      operation: 'auth.login',
      category: LogCategory.auth,
      context: {'method': 'email'},
      requiresNetwork: true,
    );
  }

  FutureEither<Map<String, dynamic>?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    return runTask(() async {
      final response = await _dio.post<Map<String, dynamic>>('/auth/registrar', data: {
        'nome': name,
        'email': email,
        'senha': password,
        'perfil': _signUpProfile,
      });
      return _startSession(response.data!);
    },
      operation: 'auth.signUp',
      category: LogCategory.auth,
      context: {'method': 'email'},
      requiresNetwork: true,
    );
  }

  FutureEither<void> forgotPassword({required String email}) async {
    return runTask(() async {
      await _dio.post<void>('/auth/forgot-password', data: {'email': email});
    },
      operation: 'auth.forgotPassword',
      category: LogCategory.auth,
      requiresNetwork: true,
    );
  }

  /// The backend is stateless (JWT), so logging out only discards the local token.
  FutureEither<void> logout() async {
    return runTask(() async {
      await SecureStorageService.instance.delete(_tokenKey);
      _setToken(null);
      _authStateController.add(null);
    },
      operation: 'auth.logout',
      category: LogCategory.auth,
    );
  }

  /// Restores the session from the stored token; null when there is none.
  FutureEither<Map<String, dynamic>?> getCurrentUser() async {
    return runTask(() async {
      final stored = await SecureStorageService.instance.read(_tokenKey);
      final token = stored.fold((_) => null, (value) => value);
      if (token == null || token.isEmpty) return null;

      _setToken(token);
      final response = await _dio.get<Map<String, dynamic>>('/usuarios/me');
      return response.data;
    },
      operation: 'auth.getCurrentUser',
      category: LogCategory.auth,
    );
  }

  /// Stores the token from the backend TokenResponse and returns its user.
  Future<Map<String, dynamic>> _startSession(Map<String, dynamic> data) async {
    final token = data['token'] as String;
    await SecureStorageService.instance.write(_tokenKey, token);
    _setToken(token);

    final user = data['usuario'] as Map<String, dynamic>;
    _authStateController.add(user);
    return user;
  }

  void _setToken(String? token) {
    if (token == null) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  void dispose() {
    _authStateController.close();
  }
}
