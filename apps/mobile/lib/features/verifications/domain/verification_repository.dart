import '../../../core/utils/cached.dart';
import 'verification_entities.dart';

typedef UploadProgress = void Function(int sent, int total);

abstract class VerificationRepository {
  /// Step 1: uploads a statement PDF; the result is `AWAITING_RATES` and
  /// carries the rate proposal. Costs one credit and is not idempotent:
  /// callers must not auto-retry on timeout.
  Future<Verification> verify({
    required String cardId,
    required String filePath,
    String? exchangeRate,
    String? rewardProgramName,
    UploadProgress? onProgress,
  });

  /// Step 2 (and free recalculation): computes the audit with the rates the
  /// user confirmed. Never costs a credit.
  Future<Verification> confirm(String id, ConfirmRequest request);

  /// Changes the category of one line (`null` clears it). Does NOT recompute
  /// the result: call [confirm] again for that.
  Future<Verification> correctTransaction(
    String id,
    int index,
    String? categoryId,
  );

  /// Page 1 is cached for offline use.
  Future<Cached<VerificationPage>> history({
    String? cardId,
    int page = 1,
    int pageSize = 20,
  });

  Future<Cached<Verification>> detail(String id);
  Future<void> delete(String id);
}
