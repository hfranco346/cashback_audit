import 'package:get/get.dart';

import '../../../core/errors/error_messages.dart';
import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/l10n/strings.dart';
import '../../cards/presentation/cards_controller.dart';
import '../../credits/presentation/credits_controller.dart';
import '../domain/verification_entities.dart';
import '../domain/verification_repository.dart';
import 'attention_controller.dart';
import 'confirm_rates_controller.dart';
import 'delete_verification.dart';
import 'verification_poller.dart';

/// Route arguments of the progress page. The bare id (from Home or History)
/// is also accepted; the file name is only known right after an upload.
class VerificationProgressArgs {
  const VerificationProgressArgs(this.verificationId, {this.fileName});

  factory VerificationProgressArgs.from(Object? raw) => switch (raw) {
    final VerificationProgressArgs a => a,
    final String id => VerificationProgressArgs(id),
    _ => throw ArgumentError('Unsupported progress arguments: $raw'),
  };

  final String verificationId;
  final String? fileName;
}

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
    this.cards,
    this.credits,
    this.fileName,
  }) : poller = poller ?? VerificationPoller(repository: _repository);

  final String verificationId;
  final VerificationRepository _repository;
  final AppNavigator _navigator;
  final VerificationPoller poller;
  final AttentionController? attention;
  final CardsController? cards;
  final CreditsController? credits;

  /// Name of the PDF just uploaded (unknown when reopened from Home).
  final String? fileName;

  final verification = Rxn<Verification>();

  /// `BAC Cash •••• 4821` once the card is known.
  String? get cardLabel {
    final id = verification.value?.cardId;
    final card = id == null ? null : cards?.byId(id);
    return card == null ? null : '${card.alias} •••• ${card.last4}';
  }

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

  /// "Try again" / "Choose another PDF": the failure is acknowledged and the
  /// verify screen opens on the same card.
  Future<void> retryUpload() async {
    final v = verification.value;
    await attention?.markSeen(verificationId);
    _navigator.replace(Routes.upload, arguments: v?.cardId);
  }

  /// Acknowledge a failure: the credit was refunded.
  Future<void> dismissFailure() async {
    await attention?.markSeen(verificationId);
    _navigator.pop();
  }

  bool get deleteLosesCreditNote =>
      deleteLosesCredit(credits: credits, status: verification.value?.status);

  bool _deleting = false;

  /// Discards this verification (already confirmed by the user), whether it
  /// is still analyzing or failed. Goes back with a snackbar on success;
  /// returns the error message otherwise.
  Future<String?> deleteVerification() async {
    if (_deleting) return null;
    _deleting = true;
    poller.stop();
    try {
      final error = await deleteVerificationById(_repository, verificationId);
      if (error != null) {
        if (verification.value?.isProcessing ?? true) _startPolling();
        return error;
      }
      attention?.reload();
      _navigator.pop();
      _navigator.showNotice(S.current.deleteVerificationDone, '');
      return null;
    } finally {
      _deleting = false;
    }
  }

  @override
  void onClose() {
    poller.stop();
    super.onClose();
  }
}
