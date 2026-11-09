import '../../../core/utils/cached.dart';
import 'verification_entities.dart';

typedef UploadProgress = void Function(int sent, int total);

abstract class VerificationRepository {
  /// Step 1: uploads a statement PDF. The backend answers `202` right away
  /// with a `PROCESSING` verification (the analysis runs in the background,
  /// the PDF is never stored). Consumes one credit on acceptance, refunded if
  /// the verification ends `FAILED`. Not idempotent: callers must not
  /// auto-retry on timeout. Follow it with [get] (see `VerificationPoller`)
  /// until the status leaves `PROCESSING`.
  Future<Verification> upload({
    required String cardId,
    required String filePath,
    String? exchangeRate,
    String? rewardProgramName,
    UploadProgress? onProgress,
  });

  /// Fresh `GET /verifications/:id`, network only (works for every status;
  /// a `PROCESSING` one has no lines yet). Refreshes the offline cache.
  Future<Verification> get(String id);

  /// `GET /verifications/attention`: verifications that need the user —
  /// `PROCESSING`, `AWAITING_RATES`, and `COMPLETED` / `FAILED` not seen yet.
  Future<List<VerificationSummary>> attention();

  /// `POST /verifications/:id/seen`: the user opened a finished result, so it
  /// leaves [attention]. Idempotent.
  Future<void> markSeen(String id);

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

  /// Creates (or reuses) the categories the statement mentions and moves the
  /// matching lines into them. Free: no Claude call, no credit. Returns the
  /// refreshed verification (new categories appear in `rateProposal`
  /// prefilled with the statement rate).
  Future<Verification> createCategoriesFromSuggestions(
    String id,
    List<String> names,
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
