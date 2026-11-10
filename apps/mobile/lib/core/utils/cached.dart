import '../errors/app_exception.dart';

/// A value plus whether it came from the local cache because the network
/// was unavailable.
class Cached<T> {
  const Cached(this.data, {this.fromCache = false, this.cachedAt});

  final T data;
  final bool fromCache;

  /// When the cached data was saved, when known (only set with [fromCache]).
  final DateTime? cachedAt;
}

bool _isConnectivityProblem(AppException e) =>
    e.kind == AppErrorKind.network ||
    e.kind == AppErrorKind.timeout ||
    e.kind == AppErrorKind.server;

/// Network-first read with cache fallback. [fetch] returns the raw payload
/// `R` (API JSON), which is written through to the cache and mapped with
/// [map]. When the network is unavailable the cached payload is served if
/// there is one, otherwise the error is rethrown.
Future<Cached<T>> networkFirst<R, T>({
  required Future<R> Function() fetch,
  required Future<R?> Function() readCache,
  required Future<void> Function(R raw) writeCache,
  required T Function(R raw) map,
}) async {
  try {
    final fresh = await fetch();
    await writeCache(fresh);
    return Cached(map(fresh));
  } on AppException catch (e) {
    if (!_isConnectivityProblem(e)) rethrow;
    final cached = await readCache();
    if (cached == null) rethrow;
    return Cached(map(cached), fromCache: true);
  }
}
