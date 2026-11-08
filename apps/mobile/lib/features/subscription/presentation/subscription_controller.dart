import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/l10n/strings.dart';
import '../domain/subscription_entities.dart';
import '../domain/subscription_repository.dart';

/// App-wide subscription state, backed by `GET /subscriptions/me`.
class SubscriptionController extends GetxController {
  SubscriptionController({
    required this._repository,
    required this._billing,
    this.pollDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 2),
      Duration(seconds: 3),
      Duration(seconds: 3),
      Duration(seconds: 4),
      Duration(seconds: 5),
      Duration(seconds: 5),
    ],
    this.wait = _defaultWait,
  });

  final SubscriptionRepository _repository;
  final BillingService _billing;

  /// Backoff between polls after a purchase (about 25 s in total).
  final List<Duration> pollDelays;
  final Future<void> Function(Duration) wait;

  static Future<void> _defaultWait(Duration d) => Future<void>.delayed(d);

  final status = Rxn<SubscriptionStatus>();
  final loading = false.obs;
  final errorMessage = RxnString();

  bool get isActive => status.value?.active ?? false;
  BillingService get billing => _billing;

  /// Refreshes from the backend. Returns the status, or `null` on failure.
  Future<SubscriptionStatus?> fetchStatus() async {
    loading.value = true;
    errorMessage.value = null;
    try {
      final s = await _repository.getStatus();
      status.value = s;
      return s;
    } on AppException catch (e) {
      errorMessage.value = userMessageFor(e);
      return null;
    } finally {
      loading.value = false;
    }
  }

  /// After a purchase the RevenueCat webhook may lag: poll with backoff until
  /// the backend reports an active entitlement. Returns whether it did.
  Future<bool> waitUntilActive() async {
    for (var i = 0; i <= pollDelays.length; i++) {
      final s = await fetchStatus();
      if (s?.active ?? false) return true;
      if (i < pollDelays.length) await wait(pollDelays[i]);
    }
    return false;
  }

  /// Restores store purchases and refreshes the backend status. Returns an
  /// error message or `null`.
  Future<String?> restorePurchases() async {
    if (!_billing.isConfigured) return S.paywallDevNotice;
    try {
      await _billing.restore();
    } on BillingException {
      return S.paywallRestoreFailed;
    }
    await waitUntilActive();
    return null;
  }

  void reset() {
    status.value = null;
    errorMessage.value = null;
  }
}
