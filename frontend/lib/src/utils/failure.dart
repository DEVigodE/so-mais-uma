import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';

import 'error_handler.dart';

/// Domain-level failure hierarchy. Prefer exhaustive `switch` over `is` checks.
sealed class Failure extends Equatable {
  const Failure(this.message, {this.error});

  final String message;
  final Object? error;

  /// Maps thrown objects into a typed [Failure] for railway-style APIs.
  ///
  /// `DioException` segue a tabela do design D6: erro de conexão ou timeout
  /// vira [NetworkFailure]; resposta HTTP com erro vira [ApiFailure] lido do
  /// `ProblemDetail`; o resto vira [UnknownFailure].
  factory Failure.fromException(Object error, [StackTrace? stackTrace]) {
    if (error is Failure) return error;

    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return NetworkFailure(
            'erros.sem_conexao'.tr(),
            error: error,
          );
        case DioExceptionType.badResponse:
          return ApiFailure.fromResponse(
            error.response?.statusCode ?? 0,
            error.response?.data,
            error: error,
          );
        default:
          break;
      }
    }

    final message = AppErrorHandler.format(error);
    return switch (error) {
      final Exception e when e.toString().contains('SocketException') ||
              e.toString().contains('Network') =>
        NetworkFailure('erros.sem_conexao'.tr(), error: error),
      _ => UnknownFailure(message, error: error),
    };
  }

  @override
  List<Object?> get props => [message, error];

  @override
  String toString() => message;
}

final class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.error});
}

final class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.error});
}

/// Sem conexão com o backend (erro de conexão ou timeout).
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.error});
}

final class UnknownFailure extends Failure {
  const UnknownFailure(super.message, {super.error});
}

/// Resposta de erro da API (RFC 9457 `ProblemDetail` do backend).
///
/// `codigo` e `subcodigo` vêm dos catálogos `CodigoErro` e `SubcodigoErro` do
/// backend; `campos` traz as mensagens de validação por campo (400
/// `VALIDACAO`); `reservaId` vem no 422 `RESERVA_PENDENTE_EXISTENTE`.
final class ApiFailure extends Failure {
  const ApiFailure({
    required this.status,
    this.codigo,
    this.subcodigo,
    this.detail,
    this.campos = const {},
    this.reservaId,
    String message = '',
    Object? error,
  }) : super(message, error: error);

  factory ApiFailure.fromResponse(int status, Object? data, {Object? error}) {
    if (data is! Map) {
      return ApiFailure(
        status: status,
        message: _mensagemPadrao(null, null, null),
        error: error,
      );
    }

    final codigo = data['codigo']?.toString();
    final subcodigo = data['subcodigo']?.toString();
    final detail = data['detail']?.toString();
    final campos = <String, String>{};
    final lista = data['campos'];
    if (lista is List) {
      for (final item in lista) {
        if (item is Map && item['campo'] != null) {
          campos[item['campo'].toString()] = item['mensagem']?.toString() ?? '';
        }
      }
    }
    final reservaId = switch (data['reservaId']) {
      final int v => v,
      final num v => v.toInt(),
      final String v => int.tryParse(v),
      _ => null,
    };

    return ApiFailure(
      status: status,
      codigo: codigo,
      subcodigo: subcodigo,
      detail: detail,
      campos: campos,
      reservaId: reservaId,
      message: _mensagemPadrao(codigo, subcodigo, detail),
      error: error,
    );
  }

  final int status;
  final String? codigo;
  final String? subcodigo;
  final String? detail;
  final Map<String, String> campos;
  final int? reservaId;

  bool get naoEncontrado => status == 404;
  bool get conflito => status == 409;

  /// Ordem de D6: `erros.<SUBCODIGO>`, `erros.<CODIGO>`, `detail`, genérico.
  static String _mensagemPadrao(
    String? codigo,
    String? subcodigo,
    String? detail,
  ) {
    for (final chave in [subcodigo, codigo]) {
      if (chave == null) continue;
      final key = 'erros.$chave';
      final traduzido = key.tr();
      if (traduzido != key) return traduzido;
    }
    if (detail != null && detail.isNotEmpty) return detail;
    return 'erros.generico'.tr();
  }

  @override
  List<Object?> get props =>
      [status, codigo, subcodigo, detail, campos, reservaId, message];
}
