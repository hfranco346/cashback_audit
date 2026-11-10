import '../domain/card_entities.dart';

/// One rule line of the review step.
class ReviewRule {
  const ReviewRule({required this.name, required this.rate, this.cap});

  final String name;
  final String rate;
  final String? cap;
}

/// Plain snapshot of everything the user entered, shown in the last step.
class CardReviewData {
  const CardReviewData({
    required this.alias,
    required this.bank,
    required this.last4,
    required this.currency,
    required this.unit,
    required this.reporting,
    required this.baseRate,
    required this.capUnit,
    this.network,
    this.pointsFactor,
    this.rewardCurrency,
    this.cap,
    this.rules = const [],
  });

  final String alias;
  final String bank;
  final String last4;
  final String? network;
  final String currency;
  final RewardUnit unit;

  /// Only for points cards.
  final String? pointsFactor;

  /// Null = detected from the statement.
  final String? rewardCurrency;
  final RewardReporting reporting;

  /// Card-wide cap per statement, null = none.
  final String? cap;

  /// Currency code or `pts` the [cap] is expressed in.
  final String capUnit;
  final String baseRate;
  final List<ReviewRule> rules;
}
