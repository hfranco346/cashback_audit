import 'package:dio/dio.dart';

/// Coarse classification used by the UI to pick messages and behaviour.
enum AppErrorKind {
  network,
  timeout,
  unauthorized,
  noCredits,
  validation,
  notFound,
  conflict,
  payloadTooLarge,
  unsupportedMedia,
  unprocessable,
  rateLimited,
  server,
  cancelled,
  unknown,
}

/// Error raised by repositories. Carries the API error body fields
/// (`statusCode`, `code`, `message`, `details`) when available.
class AppException implements Exception {
  const AppException({
    required this.kind,
    this.statusCode,
    this.code,
    this.serverMessage,
    this.details,
    this.body,
  });

  final AppErrorKind kind;
  final int? statusCode;
  final String? code;
  final String? serverMessage;
  final Object? details;

  /// The raw error body, for endpoints that add fields (`attemptsLeft`,
  /// `retryAfterSeconds`).
  final Map<String, dynamic>? body;

  /// Integer field of the error body, also looked up under `details`.
  int? intField(String name) {
    final value =
        body?[name] ?? (details is Map ? (details as Map)[name] : null);
    return value is num ? value.toInt() : null;
  }

  /// The user has no verification credits left (`402 NO_CREDITS`).
  bool get isNoCredits => kind == AppErrorKind.noCredits;

  /// Maps a [DioException] using the API error body
  /// `{statusCode, code, message, details?}`.
  factory AppException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const AppException(kind: AppErrorKind.timeout);
      case DioExceptionType.connectionError:
        return const AppException(kind: AppErrorKind.network);
      case DioExceptionType.cancel:
        return const AppException(kind: AppErrorKind.cancelled);
      case DioExceptionType.badResponse:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        break;
    }
    final response = e.response;
    if (response == null) {
      return const AppException(kind: AppErrorKind.network);
    }
    final status = response.statusCode ?? 0;
    final body = response.data;
    String? code;
    String? message;
    Object? details;
    if (body is Map) {
      code = body['code'] as String?;
      message = body['message'] is String ? body['message'] as String : null;
      details = body['details'];
    }
    return AppException(
      kind: _kindFor(status, code),
      statusCode: status,
      code: code,
      serverMessage: message,
      details: details,
      body: body is Map ? Map<String, dynamic>.from(body) : null,
    );
  }

  static AppErrorKind _kindFor(int status, String? code) {
    if (code == 'NO_CREDITS' || status == 402) {
      return AppErrorKind.noCredits;
    }
    return switch (status) {
      400 => AppErrorKind.validation,
      401 => AppErrorKind.unauthorized,
      404 => AppErrorKind.notFound,
      409 => AppErrorKind.conflict,
      413 => AppErrorKind.payloadTooLarge,
      415 => AppErrorKind.unsupportedMedia,
      422 => AppErrorKind.unprocessable,
      429 => AppErrorKind.rateLimited,
      >= 500 => AppErrorKind.server,
      _ => AppErrorKind.unknown,
    };
  }

  @override
  String toString() =>
      'AppException($kind, $statusCode, $code, $serverMessage)';
}

/// Runs [body] and converts Dio failures into [AppException].
Future<T> guardApi<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on DioException catch (e) {
    throw AppException.fromDio(e);
  }
}
