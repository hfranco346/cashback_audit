import 'dart:async';

import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/network/session_events.dart';
import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/app_routes.dart';
import '../domain/auth_entities.dart';
import '../domain/auth_repository.dart';

typedef UserHook = Future<void> Function(AppUser user);

/// Owns the signed-in user for the whole app. Other features plug in via
/// [addSignedInHook] / [addSignedOutHook] (e.g. RevenueCat identification).
class SessionController extends GetxController {
  SessionController({
    required this._repository,
    required this._events,
    required this._clearLocalData,
    required this._navigator,
  });

  final AuthRepository _repository;
  final SessionEvents _events;
  final Future<void> Function() _clearLocalData;
  final AppNavigator _navigator;

  final user = Rxn<AppUser>();
  final _signedInHooks = <UserHook>[];
  final _signedOutHooks = <Future<void> Function()>[];
  StreamSubscription<void>? _expiredSub;

  void addSignedInHook(UserHook hook) => _signedInHooks.add(hook);
  void addSignedOutHook(Future<void> Function() hook) =>
      _signedOutHooks.add(hook);

  @override
  void onInit() {
    super.onInit();
    _expiredSub = _events.onExpired.listen((_) => _handleExpired());
  }

  /// Called after a successful interactive sign-in.
  Future<void> onSignedIn(AppUser signedIn) async {
    user.value = signedIn;
    await _runHooks(signedIn);
  }

  /// Restores the user at start-up (home calls this). Offline-safe.
  Future<void> restore() async {
    try {
      final restored = await _repository.loadUser();
      if (restored == null) return;
      user.value = restored;
      await _runHooks(restored);
    } on AppException {
      // Unauthorized is handled through SessionEvents.
    }
  }

  Future<void> _runHooks(AppUser u) async {
    for (final hook in _signedInHooks) {
      try {
        await hook(u);
      } catch (_) {
        // A failing integration (e.g. store billing) must not block the app.
      }
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    await _endSession();
    _navigator.offAll(Routes.login);
  }

  Future<void> _handleExpired() async {
    await _endSession();
    _navigator.offAll(Routes.login);
    _navigator.showNotice(S.sessionExpiredTitle, S.errUnauthorized);
  }

  Future<void> _endSession() async {
    user.value = null;
    await _clearLocalData();
    for (final hook in _signedOutHooks) {
      try {
        await hook();
      } catch (_) {}
    }
  }

  @override
  void onClose() {
    _expiredSub?.cancel();
    super.onClose();
  }
}
