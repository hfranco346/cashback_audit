import 'package:equatable/equatable.dart';

enum SubscriptionState {
  none,
  active,
  cancelled,
  billingIssue,
  expired;

  static SubscriptionState fromApi(String? v) => switch (v) {
    'ACTIVE' => SubscriptionState.active,
    'CANCELLED' => SubscriptionState.cancelled,
    'BILLING_ISSUE' => SubscriptionState.billingIssue,
    'EXPIRED' => SubscriptionState.expired,
    _ => SubscriptionState.none,
  };
}

/// Backend view of the user's subscription (source of truth).
class SubscriptionStatus extends Equatable {
  const SubscriptionStatus({
    required this.entitlementId,
    required this.active,
    required this.state,
    this.expiresAt,
    this.willRenew = false,
    this.store,
    this.productId,
  });

  final String entitlementId;

  /// Whether paid features (statement verification) are currently usable.
  final bool active;
  final SubscriptionState state;
  final DateTime? expiresAt;
  final bool willRenew;
  final String? store;
  final String? productId;

  static const none = SubscriptionStatus(
    entitlementId: 'pro',
    active: false,
    state: SubscriptionState.none,
  );

  @override
  List<Object?> get props => [
    entitlementId,
    active,
    state,
    expiresAt,
    willRenew,
    store,
    productId,
  ];
}

enum PaywallPackageKind { subscription, creditPack }

/// A purchasable package of the current offering, store-agnostic: the
/// monthly subscription or a consumable credit pack.
class PaywallPackage extends Equatable {
  const PaywallPackage({
    required this.id,
    required this.title,
    required this.priceString,
    this.description = '',
    this.period,
    this.kind = PaywallPackageKind.subscription,
    this.credits,
  });

  final String id;

  /// How many verifications a [PaywallPackageKind.creditPack] grants.
  final int? credits;
  final PaywallPackageKind kind;

  bool get isPack => kind == PaywallPackageKind.creditPack;
  final String title;
  final String priceString;
  final String description;

  /// ISO 8601 period such as `P1M`, when known.
  final String? period;

  @override
  List<Object?> get props => [
    id,
    title,
    priceString,
    description,
    period,
    kind,
    credits,
  ];
}

class PurchaseCancelled implements Exception {
  const PurchaseCancelled();
}

/// The store/RevenueCat operation failed (not a user cancellation).
class BillingException implements Exception {
  const BillingException([this.message]);
  final String? message;
}
