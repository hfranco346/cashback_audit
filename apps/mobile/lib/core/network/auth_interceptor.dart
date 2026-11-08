import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'session_events.dart';

/// Adds the Bearer token and transparently refreshes it on
/// `401 INVALID_ACCESS_TOKEN`.
///
/// * Refresh calls are single-flight: concurrent 401s await the same refresh,
///   because refresh tokens are single use (reuse revokes the session).
/// * A request that failed with an outdated token while another refresh already
///   completed is simply retried with the stored token.
/// * If the refresh endpoint rejects the token (4xx), tokens are cleared and
///   [SessionEvents.notifyExpired] fires. Network/5xx failures keep the
///   session so being offline never logs the user out.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.refreshDio,
    required this.tokens,
    required this.events,
  });

  /// Client used to replay the original request.
  final Dio dio;

  /// Interceptor-free client used for `/auth/refresh`.
  final Dio refreshDio;
  final TokenStorage tokens;
  final SessionEvents events;

  static const _retriedKey = 'auth_retried';
  Future<AuthTokens?>? _inFlight;

  bool _isPublic(String path) => path.startsWith('/auth/');

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublic(options.path)) {
      final stored = await tokens.read();
      if (stored != null) {
        options.headers['Authorization'] = 'Bearer ${stored.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final response = err.response;
    if (response?.statusCode != 401 ||
        _isPublic(request.path) ||
        request.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    final code = response?.data is Map ? (response!.data as Map)['code'] : null;
    if (code == 'UNAUTHORIZED') {
      // The account no longer exists: refreshing cannot help.
      await tokens.clear();
      events.notifyExpired();
      return handler.next(err);
    }
    if (code != 'INVALID_ACCESS_TOKEN') return handler.next(err);

    final usedHeader = request.headers['Authorization'] as String?;
    final usedToken = usedHeader?.replaceFirst('Bearer ', '');
    final AuthTokens? fresh;
    try {
      fresh = await _refresh(usedToken);
    } on DioException {
      // Transient failure (offline, 5xx): keep the session, surface the
      // original 401 to the caller.
      return handler.next(err);
    }
    if (fresh == null) return handler.next(err);

    try {
      final retry = await dio.fetch<dynamic>(
        _clone(request, fresh.accessToken),
      );
      handler.resolve(retry);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  RequestOptions _clone(RequestOptions r, String accessToken) {
    final data = r.data;
    return r.copyWith(
      headers: {...r.headers, 'Authorization': 'Bearer $accessToken'},
      extra: {...r.extra, _retriedKey: true},
      data: data is FormData ? data.clone() : data,
    );
  }

  /// Returns fresh tokens, `null` when the session ended (tokens cleared).
  /// Throws [DioException] for transient failures.
  Future<AuthTokens?> _refresh(String? usedAccessToken) {
    final running = _inFlight;
    if (running != null) return running;
    final future = _doRefresh(usedAccessToken);
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<AuthTokens?> _doRefresh(String? usedAccessToken) async {
    final stored = await tokens.read();
    if (stored == null) return null;
    if (usedAccessToken != null && stored.accessToken != usedAccessToken) {
      // Another request already refreshed after this one was sent.
      return stored;
    }
    try {
      final res = await refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': stored.refreshToken},
      );
      final body = res.data!;
      final next = AuthTokens(
        accessToken: body['accessToken'] as String,
        refreshToken: body['refreshToken'] as String,
      );
      await tokens.save(next);
      return next;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != null && status >= 400 && status < 500) {
        await tokens.clear();
        events.notifyExpired();
        return null;
      }
      rethrow;
    }
  }
}
