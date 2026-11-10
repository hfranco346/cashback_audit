import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../domain/verification_events.dart';

/// Keeps a list of verifications fresh without pull-to-refresh:
///
/// * polls every [interval] while [hasPending] (something is `PROCESSING`),
///   only while the screen is visible and the app is in the foreground;
/// * refreshes when the app resumes, when its tab becomes visible, and when
///   a [VerificationEvents] change arrives (upload, confirm, seen, finish,
///   or the user returning to Home from another route).
///
/// Requests never overlap: a refresh asked for while one is running is
/// repeated once when it ends, a poll tick is simply skipped.
class AutoRefresh {
  AutoRefresh({
    required this.refresh,
    required this.hasPending,
    this.poll,
    this.events,
    this.tab,
    this.tabIndex = 0,
    this.isRouteOnTop,
    this.interval = const Duration(seconds: 5),
  });

  /// Full refresh (event, resume, tab shown).
  final Future<void> Function() refresh;

  /// Lighter refresh run by the poll; defaults to [refresh].
  final Future<void> Function()? poll;
  final bool Function() hasPending;
  final VerificationEvents? events;

  /// Selected tab of the navigation shell, when the screen is a tab.
  final RxInt? tab;
  final int tabIndex;

  /// Whether the screen's route is the one on top (no pushed route over it).
  final bool Function()? isRouteOnTop;
  final Duration interval;

  Timer? _timer;
  StreamSubscription<void>? _events;
  Worker? _tabWorker;
  AppLifecycleListener? _lifecycle;
  bool _foreground = true;
  bool _running = false;
  bool _again = false;
  bool _disposed = false;

  bool get polling => _timer != null;

  bool get _tabVisible => tab == null || tab!.value == tabIndex;

  bool get visible =>
      _foreground && _tabVisible && (isRouteOnTop?.call() ?? true);

  void start() {
    _events = events?.changes.listen((_) => refreshNow());
    final shellTab = tab;
    if (shellTab != null) {
      _tabWorker = ever<int>(shellTab, (i) {
        if (i == tabIndex) {
          refreshNow();
        } else {
          sync();
        }
      });
    }
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _foreground = true;
        refreshNow();
      },
      onInactive: () {
        _foreground = false;
        sync();
      },
    );
  }

  /// Starts or stops the timer to match the current state. Call it after
  /// anything that can change [hasPending] or the visibility.
  void sync() {
    if (_disposed) return;
    if (visible && hasPending()) {
      _timer ??= Timer.periodic(interval, (_) => _tick());
    } else {
      _stop();
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick() {
    if (!visible || !hasPending()) {
      _stop();
      return;
    }
    if (_running) return;
    _run(poll ?? refresh);
  }

  /// Refreshes now (asked again once if one is already running).
  Future<void> refreshNow() async {
    if (_disposed) return;
    if (_running) {
      _again = true;
      return;
    }
    await _run(refresh);
  }

  Future<void> _run(Future<void> Function() action) async {
    _running = true;
    try {
      await action();
    } catch (_) {
      // Failures keep what is shown; the next poll or event retries.
    } finally {
      _running = false;
    }
    if (_disposed) return;
    if (_again) {
      _again = false;
      await _run(refresh);
      return;
    }
    sync();
  }

  void dispose() {
    _disposed = true;
    _stop();
    _events?.cancel();
    _tabWorker?.dispose();
    _lifecycle?.dispose();
  }
}
