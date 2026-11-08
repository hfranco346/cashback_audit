import 'package:get/get.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/routing/app_navigator.dart';
import '../../credits/domain/credit_entities.dart';
import '../../credits/presentation/credits_controller.dart';
import '../domain/subscription_entities.dart';
import '../domain/subscription_repository.dart';
import 'subscription_controller.dart';

enum PaywallBusy { none, loadingPackages, purchasing, restoring, confirming }

/// Sells the monthly subscription and the consumable credit packs. After a
/// purchase the credits arrive through a webhook, so the backend balance is
/// polled until it changes.
class PaywallController extends GetxController {
  PaywallController({
    required this._billing,
    required this._credits,
    required this._subscription,
    required this._navigator,
  });

  final BillingService _billing;
  final CreditsController _credits;
  final SubscriptionController _subscription;
  final AppNavigator _navigator;

  final packages = <PaywallPackage>[].obs;
  final selectedId = RxnString();
  final busy = PaywallBusy.none.obs;
  final errorMessage = RxnString();

  /// Purchase went through in the store but the backend balance has not
  /// changed yet.
  final pending = false.obs;

  /// Balance before the purchase in flight, to detect the change.
  CreditBalance? _before;
  PaywallPackage? _purchased;

  bool get configured => _billing.isConfigured;
  bool get isBusy => busy.value != PaywallBusy.none;
  CreditsController get credits => _credits;

  PaywallPackage? get selected =>
      packages.firstWhereOrNull((p) => p.id == selectedId.value);

  PaywallPackage? get subscriptionPackage =>
      packages.firstWhereOrNull((p) => !p.isPack);

  List<PaywallPackage> get packs => [
    for (final p in packages)
      if (p.isPack) p,
  ]..sort((a, b) => (a.credits ?? 0).compareTo(b.credits ?? 0));

  @override
  void onReady() {
    super.onReady();
    loadPackages();
    if (_credits.balance.value == null) _credits.fetch();
  }

  Future<void> loadPackages() async {
    if (!configured) return;
    busy.value = PaywallBusy.loadingPackages;
    errorMessage.value = null;
    try {
      final list = await _billing.packages();
      packages.assignAll(list);
      selectedId.value = (subscriptionPackage ?? list.firstOrNull)?.id;
      if (list.isEmpty) errorMessage.value = S.paywallNoPackages;
    } on BillingException {
      errorMessage.value = S.paywallLoadFailed;
    } finally {
      busy.value = PaywallBusy.none;
    }
  }

  void select(String id) => selectedId.value = id;

  Future<void> purchase() async {
    final pkg = selected;
    if (pkg == null || isBusy) return;
    busy.value = PaywallBusy.purchasing;
    errorMessage.value = null;
    // The balance to compare against once the webhook lands.
    _before = _credits.balance.value ?? await _credits.fetch();
    _purchased = pkg;
    try {
      await _billing.purchase(pkg);
    } on PurchaseCancelled {
      busy.value = PaywallBusy.none;
      return;
    } on BillingException {
      errorMessage.value = S.paywallPurchaseFailed;
      busy.value = PaywallBusy.none;
      return;
    }
    await _confirm();
  }

  Future<void> restore() async {
    if (isBusy) return;
    busy.value = PaywallBusy.restoring;
    errorMessage.value = null;
    try {
      await _billing.restore();
    } on BillingException {
      errorMessage.value = S.paywallRestoreFailed;
      busy.value = PaywallBusy.none;
      return;
    }
    // A restore re-links existing purchases: nothing new to wait for, just
    // refresh what the backend already knows.
    await _credits.fetch();
    final status = await _subscription.fetchStatus();
    busy.value = PaywallBusy.none;
    if (status?.active ?? false) {
      _navigator.pop();
      _navigator.showNotice(S.paywallSuccessTitle, S.restoreDone);
    } else {
      errorMessage.value = S.restoreNothing;
    }
  }

  /// Polls the backend balance until the purchase shows up.
  Future<void> _confirm() async {
    busy.value = PaywallBusy.confirming;
    final changed = await _credits.waitForChange(_before);
    busy.value = PaywallBusy.none;
    if (changed) {
      pending.value = false;
      _subscription.fetchStatus();
      _navigator.pop();
      _navigator.showNotice(
        S.paywallSuccessTitle,
        (_purchased?.isPack ?? false)
            ? S.paywallSuccessPack
            : S.paywallSuccessBody,
      );
    } else {
      pending.value = true;
    }
  }

  Future<void> checkAgain() async {
    if (isBusy) return;
    await _confirm();
  }
}
