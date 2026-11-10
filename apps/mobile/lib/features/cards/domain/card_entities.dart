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

/// How the bank prints the reward figure: what was earned in the statement
/// month, the program's accumulated balance, or unknown (detected per check).
enum RewardReporting {
  auto('AUTO'),
  monthly('MONTHLY'),
  cumulative('CUMULATIVE');

  const RewardReporting(this.apiValue);
  final String apiValue;

  static RewardReporting fromApi(Object? value) => RewardReporting.values
      .firstWhere((m) => m.apiValue == value, orElse: () => auto);

  /// `monthly`/`cumulative` for an API mode, `null` for anything else.
  static RewardReporting? tryMode(Object? value) => value == 'MONTHLY'
      ? monthly
      : (value == 'CUMULATIVE' ? cumulative : null);
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
    this.rewardCurrency,
    this.rewardReporting = RewardReporting.auto,
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

  /// Currency the reward is paid in when it differs from [currency]; null
  /// lets the app detect it from the statement.
  final String? rewardCurrency;

  /// How this card's bank reports the reward (default: detect each time).
  final RewardReporting rewardReporting;
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
    rewardCurrency,
    rewardReporting,
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
    this.rewardCurrency,
    this.claimEmail,
    this.rewardReporting = RewardReporting.auto,
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
  final String? rewardCurrency;

  /// Where the claim email for this card's bank goes (optional).
  final String? claimEmail;

  /// What the bank's reward figure means (`AUTO` = decide per statement).
  final RewardReporting rewardReporting;
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
    rewardCurrency: rewardCurrency,
    rewardReporting: rewardReporting,
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
    rewardCurrency,
    claimEmail,
    rewardReporting,
    rules,
  ];
}
