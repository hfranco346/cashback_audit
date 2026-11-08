import '../../../core/db/app_database.dart';
import '../../../core/utils/decimal_utils.dart';
import '../../cards/domain/card_entities.dart';
import '../domain/verification_entities.dart';

abstract final class VerificationMapper {
  static DateTime? _date(Object? v) =>
      v == null ? null : DateTime.tryParse(v as String);

  static StatementInfo statement(JsonMap? j) => j == null
      ? const StatementInfo()
      : StatementInfo(
          bank: j['bank'] as String?,
          cardLast4: j['cardLast4'] as String?,
          periodStart: _date(j['periodStart']),
          periodEnd: _date(j['periodEnd']),
          currency: j['currency'] as String?,
          totalSpent: tryParseDecimal(j['totalSpent']),
          totalToPay: tryParseDecimal(j['totalToPay']),
        );

  static Verification detail(JsonMap j) {
    final reported = j['reported'] as JsonMap;
    final expected = j['expected'] as JsonMap;
    return Verification(
      id: j['id'] as String,
      cardId: j['cardId'] as String,
      statement: statement(j['statement'] as JsonMap?),
      reported: ReportedReward(
        amount: parseDecimal(reported['amount']),
        unit: RewardUnit.fromApi(reported['unit'] as String),
        fromOverride: reported['source'] == 'OVERRIDE',
        label: reported['label'] as String?,
      ),
      expectedAmount: parseDecimal(expected['amount']),
      unit: RewardUnit.fromApi(expected['unit'] as String),
      difference: parseDecimal(j['difference']),
      tolerance: parseDecimal(j['tolerance']),
      verdict: Verdict.fromApi(j['verdict'] as String),
      breakdown: [
        for (final b in (j['breakdown'] as List<dynamic>? ?? const []))
          _line(b as JsonMap),
      ],
      transactions: [
        for (final t in (j['transactions'] as List<dynamic>? ?? const []))
          _transaction(t as JsonMap),
      ],
      warnings: [
        for (final w in (j['warnings'] as List<dynamic>? ?? const []))
          VerificationWarning(
            code: (w as JsonMap)['code'] as String,
            message: w['message'] as String? ?? '',
          ),
      ],
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }

  static BreakdownLine _line(JsonMap b) => BreakdownLine(
    categoryId: b['categoryId'] as String?,
    categoryName: b['categoryName'] as String?,
    ratePercent: parseDecimal(b['ratePercent']),
    transactionCount: (b['transactionCount'] as num).toInt(),
    spend: parseDecimal(b['spend']),
    uncappedReward: parseDecimal(b['uncappedReward']),
    expectedReward: parseDecimal(b['expectedReward']),
    monthlyCap: tryParseDecimal(b['monthlyCap']),
    capped: b['capped'] as bool? ?? false,
  );

  static VerificationTransaction _transaction(JsonMap t) =>
      VerificationTransaction(
        index: (t['index'] as num).toInt(),
        date: _date(t['date']),
        merchant: t['merchant'] as String? ?? '',
        amount: parseDecimal(t['amount']),
        isCredit: t['isCredit'] as bool? ?? false,
        matchedMerchantId: t['matchedMerchantId'] as String?,
        matchedMerchantName: t['matchedMerchantName'] as String?,
        categoryId: t['categoryId'] as String?,
        categoryName: t['categoryName'] as String?,
        matchSource: MatchSource.fromApi(t['matchSource'] as String?),
        matchConfidence: (t['matchConfidence'] as num?)?.toDouble(),
        appliedRatePercent: parseDecimal(t['appliedRatePercent']),
        ruleApplied: t['ruleApplied'] as bool? ?? false,
        expectedReward: parseDecimal(t['expectedReward']),
      );

  static VerificationSummary summary(JsonMap j) => VerificationSummary(
    id: j['id'] as String,
    cardId: j['cardId'] as String,
    statement: statement(j['statement'] as JsonMap?),
    unit: RewardUnit.fromApi(j['rewardUnit'] as String),
    reportedAmount: parseDecimal(j['reportedAmount']),
    expectedAmount: parseDecimal(j['expectedAmount']),
    difference: parseDecimal(j['difference']),
    verdict: Verdict.fromApi(j['verdict'] as String),
    createdAt: DateTime.parse(j['createdAt'] as String),
  );

  /// Derives the list-summary JSON from a full verification JSON so a fresh
  /// upload can be cached in the history without another request.
  static JsonMap summaryJsonFromDetail(JsonMap d) => {
    'id': d['id'],
    'cardId': d['cardId'],
    'statement': d['statement'],
    'rewardUnit': (d['expected'] as JsonMap)['unit'],
    'reportedAmount': (d['reported'] as JsonMap)['amount'],
    'expectedAmount': (d['expected'] as JsonMap)['amount'],
    'difference': d['difference'],
    'verdict': d['verdict'],
    'createdAt': d['createdAt'],
  };
}
