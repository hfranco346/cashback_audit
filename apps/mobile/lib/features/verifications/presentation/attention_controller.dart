import 'package:get/get.dart';

import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/app_routes.dart';
import '../domain/verification_entities.dart';
import '../domain/verification_repository.dart';
import 'confirm_rates_controller.dart';

/// Verifications that need the user (`GET /verifications/attention`):
/// still processing, waiting for the rates, or finished but not seen yet.
/// Home refreshes it on load and when the app is resumed.
class AttentionController extends GetxController {
  AttentionController({required this._repository, required this._navigator});

  final VerificationRepository _repository;
  final AppNavigator _navigator;

  final items = <VerificationSummary>[].obs;
  final loading = false.obs;

  /// True when the last refresh failed (the previous list is kept).
  final failed = false.obs;

  bool _refreshing = false;

  /// Reloads the list. Failures keep what is shown (offline-safe).
  Future<void> reload() async {
    if (_refreshing) return;
    _refreshing = true;
    loading.value = true;
    try {
      items.assignAll(await _repository.attention());
      failed.value = false;
    } catch (_) {
      failed.value = true;
    } finally {
      loading.value = false;
      _refreshing = false;
    }
  }

  /// Marks a finished result as seen so it leaves the list. The row is
  /// removed right away; a failed request is retried on the next refresh.
  Future<void> markSeen(String id) async {
    items.removeWhere((e) => e.id == id);
    try {
      await _repository.markSeen(id);
    } catch (_) {
      // The next refresh brings it back and the user can open it again.
    }
  }

  /// Opens the right screen for [item]. A `FAILED` one is explained by
  /// [showFailure] (a dialog / sheet) and then marked as seen.
  Future<void> open(
    VerificationSummary item, {
    Future<void> Function(VerificationSummary item)? showFailure,
  }) async {
    switch (item.status) {
      case VerificationStatus.processing:
        _navigator.push(Routes.verificationProgress, arguments: item.id);
      case VerificationStatus.awaitingRates:
        _navigator.push(
          Routes.confirmRates,
          arguments: ConfirmRatesArgs.byId(item.id),
        );
      case VerificationStatus.completed:
        if (item.seenAt == null) await markSeen(item.id);
        _navigator.push(Routes.result, arguments: item.id);
      case VerificationStatus.failed:
        await showFailure?.call(item);
        if (item.seenAt == null) await markSeen(item.id);
    }
  }

  void reset() {
    items.clear();
    failed.value = false;
  }
}
