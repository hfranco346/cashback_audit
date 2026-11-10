import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_messages.dart';
import '../domain/credit_entities.dart';
import '../domain/credits_repository.dart';

/// App-wide credit balance, backed by `GET /credits/me`.
class CreditsController extends GetxController {
  CreditsController({
    required this._repository,
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

  final CreditsRepository _repository;

  /// Backoff between polls after a purchase (about 25 s in total): the
  /// RevenueCat webhook that grants the credits may lag.
  final List<Duration> pollDelays;
  final Future<void> Function(Duration) wait;

  static Future<void> _defaultWait(Duration d) => Future<void>.delayed(d);

  final balance = Rxn<CreditBalance>();
  final loading = false.obs;
  final errorMessage = RxnString();

  /// Known balance, `null` until the first successful fetch.
  int? get total => balance.value?.total;

  /// The account has unlimited credits (shown as "Unlimited").
  bool get isUnlimited => balance.value?.unlimited ?? false;

  /// Refreshes from the backend. Returns the balance, or `null` on failure
  /// (the previous balance is kept).
  Future<CreditBalance?> fetch() async {
    loading.value = true;
    errorMessage.value = null;
    try {
      final b = await _repository.getBalance();
      balance.value = b;
      return b;
    } on AppException catch (e) {
      errorMessage.value = userMessageFor(e);
      return null;
    } finally {
      loading.value = false;
    }
  }

  /// The `402 NO_CREDITS` error carries the current balance.
  void applyFromError(AppException e) {
    final b = CreditBalance.tryFromDetails(e.details);
    if (b != null) balance.value = b;
  }

  static bool _changed(CreditBalance? before, CreditBalance after) {
    if (before == null) return after.total > 0 || after.subscriptionActive;
    return before.unlimited != after.unlimited ||
        before.total != after.total ||
        before.free != after.free ||
        before.plan != after.plan ||
        before.purchased != after.purchased ||
        before.subscriptionActive != after.subscriptionActive;
  }

  /// After a purchase, polls with backoff until the balance differs from
  /// [before]. Returns whether it changed.
  Future<bool> waitForChange(CreditBalance? before) async {
    for (var i = 0; i <= pollDelays.length; i++) {
      final b = await fetch();
      if (b != null && _changed(before, b)) return true;
      if (i < pollDelays.length) await wait(pollDelays[i]);
    }
    return false;
  }

  void reset() {
    balance.value = null;
    errorMessage.value = null;
  }
}
