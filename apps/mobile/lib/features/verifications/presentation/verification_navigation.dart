import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/app_routes.dart';
import '../domain/verification_entities.dart';
import 'confirm_rates_controller.dart';

/// Opens a history entry by status: finished audits show the result,
/// statements waiting for the rates resume the confirmation, running and
/// failed analyses open the progress page.
void openVerificationSummary(AppNavigator navigator, VerificationSummary s) {
  switch (s.status) {
    case VerificationStatus.processing:
    case VerificationStatus.failed:
      // The progress page shows the running analysis or why it failed (and
      // offers to retry).
      navigator.push(Routes.verificationProgress, arguments: s.id);
    case VerificationStatus.awaitingRates:
      navigator.push(
        Routes.confirmRates,
        arguments: ConfirmRatesArgs.byId(s.id),
      );
    case VerificationStatus.completed:
      navigator.push(Routes.result, arguments: s.id);
  }
}
