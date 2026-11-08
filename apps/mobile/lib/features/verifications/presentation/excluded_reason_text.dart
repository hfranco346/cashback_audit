import '../../../core/l10n/strings.dart';
import '../domain/verification_entities.dart';

/// Spanish explanation of why a line does not earn a reward, or `null` when
/// the line counts.
String? excludedReasonText(VerificationTransaction tx) {
  if (!tx.isExcluded) return null;
  if (tx.excludedReason == ExcludedReason.noExchangeRate) {
    return S.excludedNoRate(tx.currency);
  }
  return switch (tx.kind) {
    TransactionKind.payment => S.excludedPayment,
    TransactionKind.fee => S.excludedFee,
    TransactionKind.interest => S.excludedInterest,
    TransactionKind.insurance => S.excludedInsurance,
    _ => S.excludedOther,
  };
}

/// Spanish copy for a verification warning code (the server text is English
/// and meant for logs). Unknown codes fall back to the server message;
/// codes with no value for the user return `null`.
String? warningText(VerificationWarning w) => switch (w.code) {
  'CARD_LAST4_MISMATCH' => S.warnLast4,
  'CURRENCY_MISMATCH' => S.warnCurrencyMismatch,
  'TOTAL_SPENT_MISMATCH' => S.warnTotalMismatch,
  'NO_TRANSACTIONS' => S.warnNoTransactions,
  'AI_MATCHING_UNAVAILABLE' => S.warnAiUnavailable,
  'NO_EXCHANGE_RATE' => S.warnNoExchangeRate,
  'EXCHANGE_RATE_APPLIED_TO_MULTIPLE_CURRENCIES' => S.warnExchangeMultiple,
  'REPORTED_VALUE_MAY_BE_CUMULATIVE' => S.warnCumulative,
  'REPORTED_UNIT_DIFFERS_FROM_CARD' => S.warnUnitDiffers,
  'EXPLANATION_UNAVAILABLE' => null,
  _ => w.message.isEmpty ? null : w.message,
};
