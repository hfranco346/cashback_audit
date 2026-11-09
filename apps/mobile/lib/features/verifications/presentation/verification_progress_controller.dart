import 'package:get/get.dart';

import '../../../core/errors/error_messages.dart';
import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/app_routes.dart';
import '../domain/verification_entities.dart';
import '../domain/verification_repository.dart';
import 'attention_controller.dart';
import 'confirm_rates_controller.dart';
import 'verification_poller.dart';

/// Watches one `PROCESSING` verification: polls it every few seconds while
/// the screen is open, sends the user to the rates when it is ready and shows
/// the reason when it failed. The user may leave at any time: the backend
/// keeps analyzing and Home shows it as pending.
class VerificationProgressController extends GetxController {
  VerificationProgressController({
    required this.verificationId,
    required this._repository,
    required this._navigator,
    VerificationPoller? poller,
    this.attention,
  }) : poller = poller ?? VerificationPoller(repository: _repository);

  final String verificationId;
  final VerificationRepository _repository;
  final AppNavigator _navigator;
  final VerificationPoller poller;
  final AttentionController? attention;

  final verification = Rxn<Verification>();

  /// Non-fatal connectivity problem shown as a hint while polling continues.
  final errorMessage = RxnString();

  @override
  void onReady() {
    super.onReady();
    _begin();
  }

  Future<void> _begin() async {
    // One immediate read: the user may come back to an already finished one.
    try {
      _handle(await _repository.get(verificationId));
    } catch (e) {
      errorMessage.value = userMessageFor(e);
    }
    if (verification.value?.isProcessing ?? true) _startPolling();
  }

  void _startPolling() {
    poller.start(
      verificationId,
      onUpdate: _handle,
      onError: (e, {required fatal}) => errorMessage.value = userMessageFor(e),
    );
  }

  void _handle(Verification v) {
    verification.value = v;
    errorMessage.value = null;
    if (v.isAwaitingRates) {
      poller.stop();
      _navigator.replace(
        Routes.confirmRates,
        arguments: ConfirmRatesArgs.verification(v),
      );
    } else if (v.isCompleted) {
      poller.stop();
      attention?.markSeen(v.id);
      _navigator.replace(Routes.result, arguments: v);
    } else if (v.isFailed) {
      poller.stop();
    }
  }

  /// "Go to my home": the analysis continues in the backend.
  void leave() {
    poller.stop();
    attention?.reload();
    _navigator.pop();
  }

  /// Acknowledge a failure: the credit was refunded.
  Future<void> dismissFailure() async {
    await attention?.markSeen(verificationId);
    _navigator.pop();
  }

  @override
  void onClose() {
    poller.stop();
    super.onClose();
  }
}
