import 'dart:async';

/// Broadcasts session-level events from the network layer (for example a
/// failed token refresh) to whoever owns the session (the auth controller).
class SessionEvents {
  final _expired = StreamController<void>.broadcast();

  Stream<void> get onExpired => _expired.stream;

  void notifyExpired() {
    if (!_expired.isClosed) _expired.add(null);
  }

  Future<void> dispose() => _expired.close();
}
