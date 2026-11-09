import '../../../core/l10n/strings.dart';
import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/app_routes.dart';
import '../domain/verification_entities.dart';
import 'confirm_rates_controller.dart';
import 'failure_text.dart';

/// Opens a history entry by status: finished audits show the result,
/// statements waiting for the rates resume the confirmation, running
/// analyses show their progress and failed ones explain why.
void openVerificationSummary(AppNavigator navigator, VerificationSummary s) {
  switch (s.status) {
    case VerificationStatus.processing:
      navigator.push(Routes.verificationProgress, arguments: s.id);
    case VerificationStatus.awaitingRates:
      navigator.push(
        Routes.confirmRates,
        arguments: ConfirmRatesArgs.byId(s.id),
      );
    case VerificationStatus.failed:
      navigator.showNotice(
        S.current.pendingFailedTitle,
        failureMessage(S.current, s.failureCode),
      );
    case VerificationStatus.completed:
      navigator.push(Routes.result, arguments: s.id);
  }
}
