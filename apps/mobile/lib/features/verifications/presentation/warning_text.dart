import '../../../core/l10n/l10n_context.dart';
import '../domain/verification_entities.dart';

/// Localized copy for a verification warning code (the server text is English
/// and meant for logs). Unknown codes fall back to the server message;
/// codes with no value for the user return `null`.
String? warningText(AppLocalizations l10n, VerificationWarning w) =>
    switch (w.code) {
      'CARD_LAST4_MISMATCH' => l10n.warnLast4,
      'CURRENCY_MISMATCH' => l10n.warnCurrencyMismatch,
      'TOTAL_SPENT_MISMATCH' => l10n.warnTotalMismatch,
      'NO_TRANSACTIONS' => l10n.warnNoTransactions,
      'AI_MATCHING_UNAVAILABLE' => l10n.warnAiUnavailable,
      'NO_EXCHANGE_RATE' => l10n.warnNoExchangeRate,
      'EXCHANGE_RATE_APPLIED_TO_MULTIPLE_CURRENCIES' =>
        l10n.warnExchangeMultiple,
      'REPORTED_VALUE_MAY_BE_CUMULATIVE' => l10n.warnCumulative,
      'REPORTED_UNIT_DIFFERS_FROM_CARD' => l10n.warnUnitDiffers,
      'EXPLANATION_UNAVAILABLE' => null,
      _ => w.message.isEmpty ? null : w.message,
    };
