import 'subscription_entities.dart';

abstract class SubscriptionRepository {
  /// `GET /subscriptions/me`.
  Future<SubscriptionStatus> getStatus();
}

/// Port to the store billing SDK (RevenueCat).
abstract class BillingService {
  /// False when no API key was provided (development builds).
  bool get isConfigured;

  Future<void> configure();

  /// Identifies the RevenueCat customer with our user id. Required so the
  /// backend webhook can attribute purchases.
  Future<void> logIn(String userId);
  Future<void> logOut();

  /// Packages of the current offering.
  Future<List<PaywallPackage>> packages();

  /// Throws [PurchaseCancelled] when the user dismisses the store sheet.
  Future<void> purchase(PaywallPackage package);
  Future<void> restore();
}
