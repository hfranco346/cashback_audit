import 'dart:async';

/// Broadcasts that a verification changed on the backend through this
/// device (uploaded, confirmed, marked as seen, deleted, or finished), so
/// every list that shows verifications (Home, History) can refresh without
/// the user pulling to refresh.
class VerificationEvents {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get changes => _controller.stream;

  void notify() {
    if (!_controller.isClosed) _controller.add(null);
  }

  void dispose() => _controller.close();
}
