import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

import '../../cards/domain/card_entities.dart';

enum Verdict {
  match,
  underpaid,
  overpaid;

  static Verdict fromApi(String v) => switch (v) {
    'UNDERPAID' => Verdict.underpaid,
    'OVERPAID' => Verdict.overpaid,
    _ => Verdict.match,
  };
}

enum MatchSource {
  keyword,
  ai,
  none;

  static MatchSource fromApi(String? v) => switch (v) {
    'KEYWORD' => MatchSource.keyword,
    'AI' => MatchSource.ai,
    _ => MatchSource.none,
  };
}

class StatementInfo extends Equatable {
  const StatementInfo({
    this.bank,
    this.cardLast4,
    this.periodStart,
    this.periodEnd,
    this.currency,
    this.totalSpent,
    this.totalToPay,
  });

  final String? bank;
  final String? cardLast4;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String? currency;
  final Decimal? totalSpent;
  final Decimal? totalToPay;

  @override
  List<Object?> get props => [
    bank,
    cardLast4,
    periodStart,
    periodEnd,
    currency,
    totalSpent,
    totalToPay,
  ];
}

class ReportedReward extends Equatable {
  const ReportedReward({
    required this.amount,
    required this.unit,
    required this.fromOverride,
    this.label,
  });

  final Decimal amount;
  final RewardUnit unit;
  final bool fromOverride;
  final String? label;

  @override
  List<Object?> get props => [amount, unit, fromOverride, label];
}

class BreakdownLine extends Equatable {
  const BreakdownLine({
    required this.ratePercent,
    required this.transactionCount,
    required this.spend,
    required this.uncappedReward,
    required this.expectedReward,
    required this.capped,
    this.categoryId,
    this.categoryName,
    this.monthlyCap,
  });

  /// Null for the base-rate line.
  final String? categoryId;
  final String? categoryName;
  final Decimal ratePercent;
  final int transactionCount;
  final Decimal spend;
  final Decimal uncappedReward;
  final Decimal expectedReward;
  final Decimal? monthlyCap;
  final bool capped;

  bool get isBase => categoryId == null;

  @override
  List<Object?> get props => [
    categoryId,
    categoryName,
    ratePercent,
    transactionCount,
    spend,
    uncappedReward,
    expectedReward,
    monthlyCap,
    capped,
  ];
}

class VerificationTransaction extends Equatable {
  const VerificationTransaction({
    required this.index,
    required this.merchant,
    required this.amount,
    required this.isCredit,
    required this.matchSource,
    required this.appliedRatePercent,
    required this.ruleApplied,
    required this.expectedReward,
    this.date,
    this.matchedMerchantId,
    this.matchedMerchantName,
    this.categoryId,
    this.categoryName,
    this.matchConfidence,
  });

  final int index;
  final DateTime? date;

  /// Raw statement descriptor.
  final String merchant;

  /// Always positive; [isCredit] marks refunds.
  final Decimal amount;
  final bool isCredit;
  final String? matchedMerchantId;
  final String? matchedMerchantName;
  final String? categoryId;
  final String? categoryName;
  final MatchSource matchSource;
  final double? matchConfidence;
  final Decimal appliedRatePercent;
  final bool ruleApplied;
  final Decimal expectedReward;

  /// The merchant was matched to one of the user's categories.
  bool get inCategory => matchSource != MatchSource.none;

  /// Signed amount: negative for refunds/credits.
  Decimal get signedAmount => isCredit ? -amount : amount;

  @override
  List<Object?> get props => [
    index,
    date,
    merchant,
    amount,
    isCredit,
    matchedMerchantId,
    matchedMerchantName,
    categoryId,
    categoryName,
    matchSource,
    matchConfidence,
    appliedRatePercent,
    ruleApplied,
    expectedReward,
  ];
}

class VerificationWarning extends Equatable {
  const VerificationWarning({required this.code, required this.message});
  final String code;
  final String message;

  @override
  List<Object?> get props => [code, message];
}

class Verification extends Equatable {
  const Verification({
    required this.id,
    required this.cardId,
    required this.statement,
    required this.reported,
    required this.expectedAmount,
    required this.unit,
    required this.difference,
    required this.tolerance,
    required this.verdict,
    required this.breakdown,
    required this.transactions,
    required this.warnings,
    required this.createdAt,
  });

  final String id;
  final String cardId;
  final StatementInfo statement;
  final ReportedReward reported;
  final Decimal expectedAmount;
  final RewardUnit unit;

  /// `reported - expected`; negative means the bank paid less.
  final Decimal difference;
  final Decimal tolerance;
  final Verdict verdict;
  final List<BreakdownLine> breakdown;
  final List<VerificationTransaction> transactions;
  final List<VerificationWarning> warnings;
  final DateTime createdAt;

  int get countedTransactions => transactions.where((t) => t.inCategory).length;
  int get uncountedTransactions =>
      transactions.where((t) => !t.inCategory).length;

  @override
  List<Object?> get props => [
    id,
    cardId,
    statement,
    reported,
    expectedAmount,
    unit,
    difference,
    tolerance,
    verdict,
    breakdown,
    transactions,
    warnings,
    createdAt,
  ];
}

class VerificationSummary extends Equatable {
  const VerificationSummary({
    required this.id,
    required this.cardId,
    required this.statement,
    required this.unit,
    required this.reportedAmount,
    required this.expectedAmount,
    required this.difference,
    required this.verdict,
    required this.createdAt,
  });

  final String id;
  final String cardId;
  final StatementInfo statement;
  final RewardUnit unit;
  final Decimal reportedAmount;
  final Decimal expectedAmount;
  final Decimal difference;
  final Verdict verdict;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    cardId,
    statement,
    unit,
    reportedAmount,
    expectedAmount,
    difference,
    verdict,
    createdAt,
  ];
}

class VerificationPage extends Equatable {
  const VerificationPage({
    required this.items,
    required this.page,
    required this.total,
    required this.pageSize,
  });

  final List<VerificationSummary> items;
  final int page;
  final int pageSize;
  final int total;

  bool get hasMore => page * pageSize < total;

  @override
  List<Object?> get props => [items, page, pageSize, total];
}
