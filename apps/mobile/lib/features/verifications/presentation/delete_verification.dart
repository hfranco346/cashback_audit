import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_messages.dart';
import '../../credits/presentation/credits_controller.dart';
import '../domain/verification_entities.dart';
import '../domain/verification_repository.dart';

/// Deletes verification [id]. Returns the message to show when it failed, or
/// `null` when it is gone. A `404 VERIFICATION_NOT_FOUND` counts as deleted:
/// the goal (it no longer exists) is already reached.
Future<String?> deleteVerificationById(
  VerificationRepository repository,
  String id,
) async {
  try {
    await repository.delete(id);
    return null;
  } on AppException catch (e) {
    if (e.code == 'VERIFICATION_NOT_FOUND') return null;
    return userMessageFor(e);
  }
}

/// Whether the confirmation must warn that the check used is not returned.
/// Not for unlimited accounts (nothing was consumed) nor for failed
/// analyses (their credit was already refunded). Unknown balance warns.
bool deleteLosesCredit({
  CreditsController? credits,
  VerificationStatus? status,
}) =>
    status != VerificationStatus.failed &&
    credits?.balance.value?.unlimited != true;
