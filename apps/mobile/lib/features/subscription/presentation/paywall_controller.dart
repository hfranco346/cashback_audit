import 'package:get/get.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/routing/app_navigator.dart';
import '../domain/subscription_entities.dart';
import '../domain/subscription_repository.dart';
import 'subscription_controller.dart';

enum PaywallBusy { none, loadingPackages, purchasing, restoring, confirming }

class PaywallController extends GetxController {
  PaywallController({
    required this._billing,
    required this._subscription,
    required this._navigator,
  });

  final BillingService _billing;
  final SubscriptionController _subscription;
  final AppNavigator _navigator;

  final packages = <PaywallPackage>[].obs;
  final selectedId = RxnString();
  final busy = PaywallBusy.none.obs;
  final errorMessage = RxnString();

  /// Purchase went through in the store but the backend is not active yet.
  final pending = false.obs;

  bool get configured => _billing.isConfigured;
  bool get isBusy => busy.value != PaywallBusy.none;

  PaywallPackage? get selected =>
      packages.firstWhereOrNull((p) => p.id == selectedId.value);

  @override
  void onReady() {
    super.onReady();
    loadPackages();
  }

  Future<void> loadPackages() async {
    if (!configured) return;
    busy.value = PaywallBusy.loadingPackages;
    errorMessage.value = null;
    try {
      final list = await _billing.packages();
      packages.assignAll(list);
      selectedId.value = list.isEmpty ? null : list.first.id;
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
    await _confirm();
  }

  /// Re-checks the backend (also used by the "check again" button).
  Future<void> _confirm() async {
    busy.value = PaywallBusy.confirming;
    final active = await _subscription.waitUntilActive();
    busy.value = PaywallBusy.none;
    if (active) {
      pending.value = false;
      _navigator.pop();
      _navigator.showNotice(S.paywallSuccessTitle, S.paywallSuccessBody);
    } else {
      pending.value = true;
    }
  }

  Future<void> checkAgain() async {
    if (isBusy) return;
    await _confirm();
  }
}
