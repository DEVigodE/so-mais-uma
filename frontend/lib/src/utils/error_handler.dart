import 'package:dio/dio.dart';

class AppErrorHandler {
  static String format(Object? error) {
    if (error == null) return 'An unexpected error occurred';
    if (error is String) return error;
    if (error is DioException) {
      final problem = _problemDetailMessage(error.response?.data);
      if (problem != null) return problem;
    }

    try {
      final dynamic dynamicError = error;
      if (dynamicError.message is String) {
        return dynamicError.message as String;
      }
    } catch (_) {}

    return error.toString();
  }

  /// Backend errors are RFC 9457 ProblemDetails: `detail` plus `campos[]` on validation errors.
  static String? _problemDetailMessage(Object? data) {
    if (data is! Map) return null;

    final fields = data['campos'];
    if (fields is List && fields.isNotEmpty) {
      return fields
          .map((field) => field is Map ? '${field['campo']}: ${field['mensagem']}' : '$field')
          .join('\n');
    }

    final detail = data['detail'];
    return detail is String && detail.isNotEmpty ? detail : null;
  }
}
