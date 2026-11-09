import 'dart:async';
import 'dart:convert';
import '../utils/utils.dart';
import '../config/app_config.dart';
import 'secure_storage_service.dart';
import 'package:dio/dio.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _tokenKey = 'auth_token';

  /// `UsuarioResponse` da sessão, para reabrir o app sem rede.
  static const _userKey = 'auth_user';

  /// Sign-up always creates CLIENTE accounts; DONO accounts are created directly in the database.
  static const _signUpProfile = 'CLIENTE';

  Dio get _dio => AppConfig.dio;

  /// `true` quando a última sessão terminou por token inválido (401). O Login
  /// lê uma vez com [consumirSessaoExpirada] para avisar o usuário.
  bool _sessaoExpirada = false;

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
      await _limparSessao();
      _authStateController.add(null);
    },
      operation: 'auth.logout',
      category: LogCategory.auth,
    );
  }

  /// Chamado pelo interceptor no 401 `TOKEN_INVALIDO`; encerra uma única vez.
  Future<void> encerrarPorSessaoExpirada() async {
    if (_dio.options.headers['Authorization'] == null) return;
    _sessaoExpirada = true;
    await _limparSessao();
    _authStateController.add(null);
  }

  /// Lê e zera o aviso de sessão expirada.
  bool consumirSessaoExpirada() {
    final valor = _sessaoExpirada;
    _sessaoExpirada = false;
    return valor;
  }

  /// Restores the session from the stored token; null when there is none.
  ///
  /// Sem rede, a sessão volta a partir do usuário salvo; com 401, o token é
  /// descartado.
  FutureEither<Map<String, dynamic>?> getCurrentUser() async {
    return runTask(() async {
      final stored = await SecureStorageService.instance.read(_tokenKey);
      final token = stored.fold((_) => null, (value) => value);
      if (token == null || token.isEmpty) return null;

      _setToken(token);
      try {
        final response = await _dio.get<Map<String, dynamic>>('/usuarios/me');
        await _salvarUsuario(response.data!);
        return response.data;
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          await _limparSessao();
          return null;
        }
        final salvo = await _usuarioSalvo();
        if (salvo != null) return salvo;
        rethrow;
      }
    },
      operation: 'auth.getCurrentUser',
      category: LogCategory.auth,
    );
  }

  /// Atualiza o usuário da sessão (por exemplo, depois do `PUT /usuarios/me`).
  Future<void> publicarUsuario(Map<String, dynamic> user) async {
    await _salvarUsuario(user);
    _authStateController.add(user);
  }

  /// Stores the token from the backend TokenResponse and returns its user.
  Future<Map<String, dynamic>> _startSession(Map<String, dynamic> data) async {
    final token = data['token'] as String;
    await SecureStorageService.instance.write(_tokenKey, token);
    _setToken(token);
    _sessaoExpirada = false;

    final user = data['usuario'] as Map<String, dynamic>;
    await _salvarUsuario(user);
    _authStateController.add(user);
    return user;
  }

  Future<void> _salvarUsuario(Map<String, dynamic> user) async {
    await SecureStorageService.instance.write(_userKey, jsonEncode(user));
  }

  Future<Map<String, dynamic>?> _usuarioSalvo() async {
    final stored = await SecureStorageService.instance.read(_userKey);
    final raw = stored.fold((_) => null, (value) => value);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException catch (e) {
      AppLogger.warning('auth.user cache invalid',
          category: LogCategory.auth, context: {'error': e.message});
      return null;
    }
  }

  Future<void> _limparSessao() async {
    await SecureStorageService.instance.delete(_tokenKey);
    await SecureStorageService.instance.delete(_userKey);
    _setToken(null);
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
