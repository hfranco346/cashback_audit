import 'dart:async';

import '../../../core/errors/app_exception.dart';
import '../domain/verification_entities.dart';
import '../domain/verification_repository.dart';

/// Polls `GET /verifications/:id` while a verification is `PROCESSING`.
///
/// Reusable by every screen that watches an upload (onboarding, progress
/// page, verify). Requests never overlap: the next one is scheduled
/// [interval] after the previous answer. It stops by itself as soon as the
/// status leaves `PROCESSING` (after delivering that last value) and on
/// fatal errors; transient ones (network, timeout, server) keep it going.
/// Call [stop] when the screen goes away.
class VerificationPoller {
  VerificationPoller({
    required this._repository,
    this.interval = const Duration(seconds: 4),
  });

  final VerificationRepository _repository;
  final Duration interval;

  Timer? _timer;
  int _generation = 0;

  bool get isRunning => _timer != null || _inFlight;
  bool _inFlight = false;

  /// Starts (or restarts) polling [id]. [onUpdate] gets every fresh value,
  /// including the final one. [onError] gets every failure; [fatal] tells
  /// whether polling stopped because of it.
  void start(
    String id, {
    required void Function(Verification verification) onUpdate,
    void Function(Object error, {required bool fatal})? onError,
  }) {
    stop();
    final generation = _generation;
    void schedule() {
      _timer = Timer(interval, () async {
        _timer = null;
        _inFlight = true;
        try {
          final v = await _repository.get(id);
          if (generation != _generation) return;
          _inFlight = false;
          onUpdate(v);
          if (v.isProcessing && generation == _generation) schedule();
        } catch (e) {
          if (generation != _generation) return;
          _inFlight = false;
          final fatal = _isFatal(e);
          onError?.call(e, fatal: fatal);
          if (!fatal && generation == _generation) schedule();
        } finally {
          if (generation == _generation) _inFlight = false;
        }
      });
    }

    schedule();
  }

  void stop() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _inFlight = false;
  }

  static bool _isFatal(Object e) =>
      e is AppException &&
      (e.kind == AppErrorKind.unauthorized ||
          e.kind == AppErrorKind.notFound ||
          e.kind == AppErrorKind.cancelled);
}
