import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

import '../../cards/domain/card_entities.dart';

/// `AWAITING_RATES` after the upload (nothing computed yet); `COMPLETED`
/// after the user confirmed the rates.
enum VerificationStatus {
  awaitingRates,
  completed;

  /// Rows cached before the two-step flow have no status: they are results.
  static VerificationStatus fromApi(String? v) => v == 'AWAITING_RATES'
      ? VerificationStatus.awaitingRates
      : VerificationStatus.completed;
}

enum Verdict {
  match,
  underpaid,
  overpaid;

  static Verdict fromApi(String v) => switch (v) {
    'UNDERPAID' => Verdict.underpaid,
    'OVERPAID' => Verdict.overpaid,
    _ => Verdict.match,
  };

  static Verdict? tryFromApi(String? v) => v == null ? null : fromApi(v);
}

/// How a line got its category. `AI` is the legacy value (split by the API
/// into the two AI_* sources); it is read as [aiMerchant].
enum MatchSource {
  keyword,
  aiMerchant,
  aiCategory,
  user,
  none;

  static MatchSource fromApi(String? v) => switch (v) {
    'KEYWORD' => MatchSource.keyword,
    'AI_MERCHANT' || 'AI' => MatchSource.aiMerchant,
    'AI_CATEGORY' => MatchSource.aiCategory,
    'USER' => MatchSource.user,
    _ => MatchSource.none,
  };

  bool get isAi => this == aiMerchant || this == aiCategory;
}

enum TransactionKind {
  purchase,
  refund,
  fee,
  interest,
  insurance,
  payment,
  other;

  static TransactionKind fromApi(String? v) => switch (v) {
    'REFUND' => TransactionKind.refund,
    'FEE' => TransactionKind.fee,
    'INTEREST' => TransactionKind.interest,
    'INSURANCE' => TransactionKind.insurance,
    'PAYMENT' => TransactionKind.payment,
    'OTHER' => TransactionKind.other,
    _ => TransactionKind.purchase,
  };

  /// Only purchases and refunds can earn a reward.
  bool get earnsReward => this == purchase || this == refund;
}

enum ExcludedReason {
  noExchangeRate,
  nonPurchaseKind,
  other;

  static ExcludedReason? fromApi(String? v) => switch (v) {
    null => null,
    'NO_EXCHANGE_RATE' => ExcludedReason.noExchangeRate,
    'NON_PURCHASE_KIND' => ExcludedReason.nonPurchaseKind,
    _ => ExcludedReason.other,
  };
}

enum RateSource {
  statement,
  cardRule,
  none;

  static RateSource fromApi(String? v) => switch (v) {
    'STATEMENT' => RateSource.statement,
    'CARD_RULE' => RateSource.cardRule,
    _ => RateSource.none,
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

  /// Name of the audited loyalty program, when one was chosen.
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
    required this.currency,
    required this.isCredit,
    required this.kind,
    required this.matchSource,
    required this.ruleApplied,
    this.date,
    this.reference,
    this.convertedAmount,
    this.exchangeRate,
    this.excludedReason,
    this.matchedMerchantId,
    this.matchedMerchantName,
    this.categoryId,
    this.categoryName,
    this.matchConfidence,
    this.matchReason,
    this.appliedRatePercent,
    this.expectedReward,
  });

  final int index;
  final DateTime? date;
  final String? reference;

  /// Raw statement descriptor.
  final String merchant;

  /// Always positive, in the line's own [currency]; [isCredit] marks refunds.
  final Decimal amount;
  final String currency;
  final bool isCredit;
  final TransactionKind kind;

  /// Signed amount in the primary currency (after confirm, when convertible).
  final Decimal? convertedAmount;
  final Decimal? exchangeRate;
  final ExcludedReason? excludedReason;
  final String? matchedMerchantId;
  final String? matchedMerchantName;
  final String? categoryId;
  final String? categoryName;
  final MatchSource matchSource;
  final double? matchConfidence;
  final String? matchReason;

  /// Null until the rates are confirmed.
  final Decimal? appliedRatePercent;
  final bool ruleApplied;
  final Decimal? expectedReward;

  /// Payments, fees, interest, insurance, or foreign lines without a rate:
  /// they never earn a reward, so they are neither counted nor missed.
  bool get isExcluded => excludedReason != null || !kind.earnsReward;

  /// The purchase was matched to one of the user's categories.
  bool get inCategory => !isExcluded && matchSource != MatchSource.none;

  /// A purchase that is not part of any category (earns the base rate).
  bool get outOfCategory => !isExcluded && matchSource == MatchSource.none;

  /// Signed amount in its own currency: negative for refunds/credits.
  Decimal get signedAmount => isCredit ? -amount : amount;

  @override
  List<Object?> get props => [
    index,
    date,
    reference,
    merchant,
    amount,
    currency,
    isCredit,
    kind,
    convertedAmount,
    exchangeRate,
    excludedReason,
    matchedMerchantId,
    matchedMerchantName,
    categoryId,
    categoryName,
    matchSource,
    matchConfidence,
    matchReason,
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

/// A reward rate the statement itself states (informational).
class DetectedRate extends Equatable {
  const DetectedRate({
    required this.isBase,
    this.categoryHint,
    this.suggestedCategoryId,
    this.ratePercent,
    this.unitNote,
    this.evidence,
    this.confidence,
  });

  final bool isBase;
  final String? categoryHint;
  final String? suggestedCategoryId;
  final Decimal? ratePercent;
  final String? unitNote;
  final String? evidence;
  final double? confidence;

  @override
  List<Object?> get props => [
    isBase,
    categoryHint,
    suggestedCategoryId,
    ratePercent,
    unitNote,
    evidence,
    confidence,
  ];
}

/// One rate the user has to confirm: the base (`categoryId == null`) or a
/// category. [required] means there is no value to prefill (source NONE).
class RateProposalEntry extends Equatable {
  const RateProposalEntry({
    required this.source,
    required this.required,
    this.categoryId,
    this.categoryName,
    this.ratePercent,
    this.monthlyCap,
    this.evidence,
    this.unitNote,
  });

  final String? categoryId;
  final String? categoryName;
  final Decimal? ratePercent;
  final Decimal? monthlyCap;
  final RateSource source;
  final String? evidence;
  final String? unitNote;
  final bool required;

  bool get isBase => categoryId == null;

  @override
  List<Object?> get props => [
    categoryId,
    categoryName,
    ratePercent,
    monthlyCap,
    source,
    evidence,
    unitNote,
    required,
  ];
}

class AppliedCategoryRate extends Equatable {
  const AppliedCategoryRate({
    required this.categoryId,
    required this.ratePercent,
    this.categoryName,
    this.monthlyCap,
    this.source,
  });

  final String categoryId;
  final String? categoryName;
  final Decimal ratePercent;
  final Decimal? monthlyCap;
  final String? source;

  @override
  List<Object?> get props => [
    categoryId,
    categoryName,
    ratePercent,
    monthlyCap,
    source,
  ];
}

/// Exactly the rates a completed verification was audited with.
class AppliedRates extends Equatable {
  const AppliedRates({
    required this.baseRatePercent,
    required this.categoryRates,
    this.baseSource,
    this.savedToCard = false,
  });

  final Decimal baseRatePercent;
  final String? baseSource;
  final bool savedToCard;
  final List<AppliedCategoryRate> categoryRates;

  @override
  List<Object?> get props => [
    baseRatePercent,
    baseSource,
    savedToCard,
    categoryRates,
  ];
}

class StatementRate extends Equatable {
  const StatementRate({
    required this.from,
    required this.to,
    required this.rate,
  });

  final String from;
  final String to;
  final Decimal rate;

  @override
  List<Object?> get props => [from, to, rate];
}

class ConversionInfo extends Equatable {
  const ConversionInfo({
    this.primaryCurrency,
    this.requestedRate,
    this.statementRate,
  });

  final String? primaryCurrency;
  final Decimal? requestedRate;
  final StatementRate? statementRate;

  @override
  List<Object?> get props => [primaryCurrency, requestedRate, statementRate];
}

/// Per-currency subtotal of a completed verification.
class CurrencySubtotal extends Equatable {
  const CurrencySubtotal({
    required this.currency,
    required this.isPrimary,
    required this.spent,
    required this.eligibleSpent,
    required this.excludedCount,
    this.convertedEligibleSpent,
    this.exchangeRate,
    this.exchangeRateSource,
    this.expectedReward,
  });

  final String currency;
  final bool isPrimary;
  final Decimal spent;
  final Decimal eligibleSpent;
  final Decimal? convertedEligibleSpent;
  final Decimal? exchangeRate;
  final String? exchangeRateSource;
  final Decimal? expectedReward;
  final int excludedCount;

  @override
  List<Object?> get props => [
    currency,
    isPrimary,
    spent,
    eligibleSpent,
    convertedEligibleSpent,
    exchangeRate,
    exchangeRateSource,
    expectedReward,
    excludedCount,
  ];
}

class LoyaltyProgram extends Equatable {
  const LoyaltyProgram({
    required this.name,
    this.unit,
    this.accumulated,
    this.available,
    this.redeemedInPeriod,
    this.expiring,
    this.forfeited,
  });

  final String name;

  /// `POINTS`, `CURRENCY`, `MILES` or `UNKNOWN`.
  final String? unit;
  final Decimal? accumulated;
  final Decimal? available;
  final Decimal? redeemedInPeriod;
  final Decimal? expiring;
  final Decimal? forfeited;

  @override
  List<Object?> get props => [
    name,
    unit,
    accumulated,
    available,
    redeemedInPeriod,
    expiring,
    forfeited,
  ];
}

class LoyaltyInfo extends Equatable {
  const LoyaltyInfo({
    this.selectedProgram,
    this.programs = const [],
    this.selectedBy,
    this.requestedProgramName,
  });

  final LoyaltyProgram? selectedProgram;
  final List<LoyaltyProgram> programs;

  /// `REQUEST`, `CARD`, `ONLY_PROGRAM` or `null`.
  final String? selectedBy;
  final String? requestedProgramName;

  static const empty = LoyaltyInfo();

  /// The statement lists several programs and none was chosen yet.
  bool get needsChoice => selectedProgram == null && programs.length > 1;

  @override
  List<Object?> get props => [
    selectedProgram,
    programs,
    selectedBy,
    requestedProgramName,
  ];
}

class Verification extends Equatable {
  const Verification({
    required this.id,
    required this.cardId,
    required this.status,
    required this.statement,
    required this.unit,
    required this.breakdown,
    required this.transactions,
    required this.warnings,
    required this.createdAt,
    this.primaryCurrency,
    this.reported,
    this.expectedAmount,
    this.difference,
    this.tolerance,
    this.verdict,
    this.explanation,
    this.detectedRates = const [],
    this.rateProposal = const [],
    this.appliedRates,
    this.conversion = const ConversionInfo(),
    this.currencies = const [],
    this.loyalty = LoyaltyInfo.empty,
    this.models = const {},
  });

  final String id;
  final String cardId;
  final VerificationStatus status;
  final StatementInfo statement;

  /// Card currency: every reward figure is expressed in it.
  final String? primaryCurrency;

  /// Reward unit of the card (falls back to cashback when unknown).
  final RewardUnit unit;
  final ReportedReward? reported;
  final Decimal? expectedAmount;

  /// `reported - expected`; negative means the bank paid less.
  final Decimal? difference;
  final Decimal? tolerance;
  final Verdict? verdict;

  /// Short Spanish narrative of the verdict (may be missing).
  final String? explanation;
  final List<DetectedRate> detectedRates;
  final List<RateProposalEntry> rateProposal;
  final AppliedRates? appliedRates;
  final ConversionInfo conversion;
  final List<CurrencySubtotal> currencies;
  final LoyaltyInfo loyalty;
  final List<BreakdownLine> breakdown;
  final List<VerificationTransaction> transactions;
  final List<VerificationWarning> warnings;
  final Map<String, String?> models;
  final DateTime createdAt;

  bool get isCompleted => status == VerificationStatus.completed;
  bool get isAwaitingRates => status == VerificationStatus.awaitingRates;

  /// Currency used to format rewards and totals.
  String get currency => primaryCurrency ?? statement.currency ?? 'MXN';

  int get countedTransactions => transactions.where((t) => t.inCategory).length;
  int get uncountedTransactions =>
      transactions.where((t) => t.outOfCategory).length;
  int get excludedTransactions =>
      transactions.where((t) => t.isExcluded).length;

  /// True when at least one purchase/refund is in a currency other than the
  /// primary one (an exchange rate may be needed).
  bool get hasForeignPurchases =>
      transactions.any((t) => t.kind.earnsReward && t.currency != currency);

  bool hasWarning(String code) => warnings.any((w) => w.code == code);

  @override
  List<Object?> get props => [
    id,
    cardId,
    status,
    statement,
    primaryCurrency,
    unit,
    reported,
    expectedAmount,
    difference,
    tolerance,
    verdict,
    explanation,
    detectedRates,
    rateProposal,
    appliedRates,
    conversion,
    currencies,
    loyalty,
    breakdown,
    transactions,
    warnings,
    models,
    createdAt,
  ];
}

class VerificationSummary extends Equatable {
  const VerificationSummary({
    required this.id,
    required this.cardId,
    required this.status,
    required this.statement,
    required this.unit,
    required this.createdAt,
    this.primaryCurrency,
    this.reportedAmount,
    this.expectedAmount,
    this.difference,
    this.verdict,
  });

  final String id;
  final String cardId;
  final VerificationStatus status;
  final StatementInfo statement;
  final String? primaryCurrency;
  final RewardUnit unit;

  /// Null while the rates are not confirmed.
  final Decimal? reportedAmount;
  final Decimal? expectedAmount;
  final Decimal? difference;
  final Verdict? verdict;
  final DateTime createdAt;

  bool get isAwaitingRates => status == VerificationStatus.awaitingRates;
  String get currency => primaryCurrency ?? statement.currency ?? 'MXN';

  @override
  List<Object?> get props => [
    id,
    cardId,
    status,
    statement,
    primaryCurrency,
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

/// One confirmed rate for a category (confirm request body).
class CategoryRateInput extends Equatable {
  const CategoryRateInput({
    required this.categoryId,
    required this.ratePercent,
    this.monthlyCap,
  });

  final String categoryId;
  final Decimal ratePercent;
  final Decimal? monthlyCap;

  @override
  List<Object?> get props => [categoryId, ratePercent, monthlyCap];
}

/// Body of `POST /verifications/:id/confirm`.
class ConfirmRequest extends Equatable {
  const ConfirmRequest({
    required this.baseRatePercent,
    required this.categoryRates,
    this.saveToCard = false,
    this.reportedRewardOverride,
    this.exchangeRate,
    this.rewardProgramName,
  });

  final Decimal baseRatePercent;
  final List<CategoryRateInput> categoryRates;
  final bool saveToCard;
  final Decimal? reportedRewardOverride;
  final Decimal? exchangeRate;
  final String? rewardProgramName;

  /// The same rates a completed verification was audited with, for a free
  /// recalculation after a line correction.
  factory ConfirmRequest.fromApplied(AppliedRates applied) => ConfirmRequest(
    baseRatePercent: applied.baseRatePercent,
    categoryRates: [
      for (final r in applied.categoryRates)
        CategoryRateInput(
          categoryId: r.categoryId,
          ratePercent: r.ratePercent,
          monthlyCap: r.monthlyCap,
        ),
    ],
  );

  @override
  List<Object?> get props => [
    baseRatePercent,
    categoryRates,
    saveToCard,
    reportedRewardOverride,
    exchangeRate,
    rewardProgramName,
  ];
}
