import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/app_routes.dart';
import '../domain/verification_entities.dart';
import 'confirm_rates_controller.dart';

/// Opens a history entry: finished audits show the result, statements still
/// waiting for the rates resume in the confirmation screen.
void openVerificationSummary(AppNavigator navigator, VerificationSummary s) {
  if (s.isAwaitingRates) {
    navigator.push(Routes.confirmRates, arguments: ConfirmRatesArgs.byId(s.id));
  } else {
    navigator.push(Routes.result, arguments: s.id);
  }
}
