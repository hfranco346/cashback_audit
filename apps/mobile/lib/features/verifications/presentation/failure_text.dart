import '../../../l10n/app_localizations.dart';
import '../domain/verification_entities.dart';

/// User-facing reason of a failed verification. Always says the credit was
/// refunded.
String failureMessage(AppLocalizations l10n, FailureCode? code) =>
    switch (code) {
      FailureCode.notAStatement => l10n.failureNotAStatement,
      FailureCode.interrupted => l10n.failureInterrupted,
      FailureCode.extractionFailed || null => l10n.failureExtraction,
    };

/// Short headline of a failed verification.
String failureTitle(AppLocalizations l10n, FailureCode? code) => switch (code) {
  FailureCode.notAStatement => l10n.failureTitleNotAStatement,
  FailureCode.interrupted => l10n.failureTitleInterrupted,
  FailureCode.extractionFailed || null => l10n.failureTitleExtraction,
};
