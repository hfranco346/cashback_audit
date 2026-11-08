import '../../../core/utils/cached.dart';
import 'verification_entities.dart';

typedef UploadProgress = void Function(int sent, int total);

abstract class VerificationRepository {
  /// Uploads a statement PDF and returns the audit. Not idempotent: callers
  /// must not auto-retry on timeout.
  Future<Verification> verify({
    required String cardId,
    required String filePath,
    String? reportedRewardOverride,
    UploadProgress? onProgress,
  });

  /// Page 1 is cached for offline use.
  Future<Cached<VerificationPage>> history({
    String? cardId,
    int page = 1,
    int pageSize = 20,
  });

  Future<Cached<Verification>> detail(String id);
  Future<void> delete(String id);
}
