import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'auth_interceptor.dart';
import 'session_events.dart';

/// Builds the app HTTP client. [adapter] lets tests inject a fake transport.
Dio buildDio({
  required String baseUrl,
  required TokenStorage tokens,
  required SessionEvents events,
  HttpClientAdapter? adapter,
}) {
  BaseOptions options() => BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 60),
    headers: {'Accept': 'application/json'},
  );
  final dio = Dio(options());
  final refreshDio = Dio(options());
  if (adapter != null) {
    dio.httpClientAdapter = adapter;
    refreshDio.httpClientAdapter = adapter;
  }
  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      refreshDio: refreshDio,
      tokens: tokens,
      events: events,
    ),
  );
  return dio;
}
