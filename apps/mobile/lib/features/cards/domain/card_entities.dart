import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

enum RewardUnit {
  cashbackCurrency('CASHBACK_CURRENCY'),
  points('POINTS');

  const RewardUnit(this.apiValue);
  final String apiValue;

  static RewardUnit fromApi(String value) => RewardUnit.values.firstWhere(
    (u) => u.apiValue == value,
    orElse: () => RewardUnit.cashbackCurrency,
  );
}

class RewardRule extends Equatable {
  const RewardRule({
    required this.categoryId,
    required this.ratePercent,
    this.monthlyCap,
  });

  final String categoryId;
  final Decimal ratePercent;

  /// Maximum reward per statement period in the card's reward unit.
  final Decimal? monthlyCap;

  @override
  List<Object?> get props => [categoryId, ratePercent, monthlyCap];
}

/// Writable part of a card (create / update payload).
class CardDraft extends Equatable {
  const CardDraft({
    required this.alias,
    required this.bank,
    required this.last4,
    required this.rewardUnit,
    required this.baseRatePercent,
    required this.currency,
    this.network,
    this.pointsPerCurrencyUnit,
    this.rewardProgramName,
    this.rules = const [],
  });

  final String alias;
  final String bank;
  final String last4;
  final String? network;
  final RewardUnit rewardUnit;
  final Decimal? pointsPerCurrencyUnit;
  final Decimal baseRatePercent;
  final String currency;

  /// Loyalty program to audit when the statement lists several.
  final String? rewardProgramName;
  final List<RewardRule> rules;

  @override
  List<Object?> get props => [
    alias,
    bank,
    last4,
    network,
    rewardUnit,
    pointsPerCurrencyUnit,
    baseRatePercent,
    currency,
    rewardProgramName,
    rules,
  ];
}

class CreditCard extends Equatable {
  const CreditCard({
    required this.id,
    required this.alias,
    required this.bank,
    required this.last4,
    required this.rewardUnit,
    required this.pointsPerCurrencyUnit,
    required this.baseRatePercent,
    required this.currency,
    this.network,
    this.rewardProgramName,
    this.rules = const [],
  });

  final String id;
  final String alias;
  final String bank;
  final String last4;
  final String? network;
  final RewardUnit rewardUnit;
  final Decimal pointsPerCurrencyUnit;
  final Decimal baseRatePercent;
  final String currency;
  final String? rewardProgramName;
  final List<RewardRule> rules;

  bool get isPoints => rewardUnit == RewardUnit.points;

  CardDraft toDraft() => CardDraft(
    alias: alias,
    bank: bank,
    last4: last4,
    network: network,
    rewardUnit: rewardUnit,
    pointsPerCurrencyUnit: pointsPerCurrencyUnit,
    baseRatePercent: baseRatePercent,
    currency: currency,
    rewardProgramName: rewardProgramName,
    rules: rules,
  );

  @override
  List<Object?> get props => [
    id,
    alias,
    bank,
    last4,
    network,
    rewardUnit,
    pointsPerCurrencyUnit,
    baseRatePercent,
    currency,
    rewardProgramName,
    rules,
  ];
}
