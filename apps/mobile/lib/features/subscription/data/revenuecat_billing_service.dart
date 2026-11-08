import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/config/app_config.dart';
import '../domain/subscription_entities.dart';
import '../domain/subscription_repository.dart';

/// RevenueCat implementation. When no API key is provided for the current
/// platform the service reports `isConfigured == false` and every call is a
/// no-op so development builds do not crash.
class RevenueCatBillingService implements BillingService {
  RevenueCatBillingService({String? apiKey})
    : _apiKey = apiKey ?? _platformKey();

  final String _apiKey;
  bool _ready = false;
  final _packages = <String, Package>{};

  static String _platformKey() => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => AppConfig.revenueCatIosKey,
    TargetPlatform.android => AppConfig.revenueCatAndroidKey,
    _ => '',
  };

  @override
  bool get isConfigured => _apiKey.isNotEmpty;

  @override
  Future<void> configure() async {
    if (!isConfigured || _ready) return;
    await Purchases.configure(PurchasesConfiguration(_apiKey));
    _ready = true;
  }

  @override
  Future<void> logIn(String userId) async {
    if (!isConfigured) return;
    await configure();
    await Purchases.logIn(userId);
  }

  @override
  Future<void> logOut() async {
    if (!isConfigured || !_ready) return;
    try {
      await Purchases.logOut();
    } on PlatformException {
      // Already anonymous: nothing to do.
    }
  }

  @override
  Future<List<PaywallPackage>> packages() async {
    if (!isConfigured) return const [];
    await configure();
    try {
      final offerings = await Purchases.getOfferings();
      final list = offerings.current?.availablePackages ?? const <Package>[];
      _packages
        ..clear()
        ..addEntries(list.map((p) => MapEntry(p.identifier, p)));
      return [
        for (final p in list)
          PaywallPackage(
            id: p.identifier,
            title: p.storeProduct.title,
            priceString: p.storeProduct.priceString,
            description: p.storeProduct.description,
            period: p.storeProduct.subscriptionPeriod,
          ),
      ];
    } on PlatformException catch (e) {
      throw BillingException(e.message);
    }
  }

  @override
  Future<void> purchase(PaywallPackage package) async {
    final native = _packages[package.id];
    if (native == null) throw const BillingException('Unknown package');
    try {
      await Purchases.purchase(PurchaseParams.package(native));
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        throw const PurchaseCancelled();
      }
      throw BillingException(e.message);
    }
  }

  @override
  Future<void> restore() async {
    if (!isConfigured) return;
    await configure();
    try {
      await Purchases.restorePurchases();
    } on PlatformException catch (e) {
      throw BillingException(e.message);
    }
  }
}
