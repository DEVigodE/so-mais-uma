import '../middleware/dio_logging_interceptor.dart';
import '../services/auth_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();
  static late final Dio dio;

  static String get baseUrl => _getBaseUrl();

  /// Chave do `POST /dev/pagamentos/{txid}/confirmar` (só debug, profile
  /// `simulado` do backend).
  static String get devKey => dotenv.maybeGet('DEV_KEY') ?? '';

  static Future<void> init() async {
    dio = Dio(
      BaseOptions(
        baseUrl: _getBaseUrl(),
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors
      ..add(_SessaoExpiradaInterceptor())
      ..add(DioLoggingInterceptor());
  }

  static String _getBaseUrl() {
    return dotenv.get('API_BASE_URL', fallback: 'https://localhost.com.br');
  }
}

/// Encerra a sessão uma única vez quando a API responde 401 `TOKEN_INVALIDO`
/// fora de `/auth/*` (token expirado ou segredo trocado). O erro segue íntegro
/// para quem chamou; o redirect do router leva ao Login.
class _SessaoExpiradaInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final resposta = err.response;
    final dados = resposta?.data;
    if (resposta?.statusCode == 401 &&
        !err.requestOptions.path.startsWith('/auth/') &&
        dados is Map &&
        dados['codigo'] == 'TOKEN_INVALIDO') {
      AuthService.instance.encerrarPorSessaoExpirada();
    }
    handler.next(err);
  }
}
