import 'package:cashback_audit/core/utils/cached.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';
import 'package:cashback_audit/features/verifications/domain/verification_repository.dart';

import 'fixtures.dart';

/// In-memory [VerificationRepository] recording calls and scripted failures.
class FakeVerificationRepository implements VerificationRepository {
  /// What `verify` returns (step 1 result by default).
  Map<String, dynamic> verifyJson = awaitingVerificationJson();

  /// What `detail`/`confirm`/`correctTransaction` return unless scripted.
  Map<String, dynamic> detailJson = verificationJson();

  Object? verifyError;
  final confirmErrors = <Object>[];
  Object? correctError;

  String? lastExchangeRate;
  String? lastProgram;
  final confirmRequests = <ConfirmRequest>[];
  final confirmedIds = <String>[];
  final corrections = <({String id, int index, String? categoryId})>[];
  final deleted = <String>[];
  List<VerificationSummary> items = [];
  int pageSizeSeen = 0;

  @override
  Future<Verification> verify({
    required String cardId,
    required String filePath,
    String? exchangeRate,
    String? rewardProgramName,
    UploadProgress? onProgress,
  }) async {
    lastExchangeRate = exchangeRate;
    lastProgram = rewardProgramName;
    onProgress?.call(5, 10);
    onProgress?.call(10, 10);
    if (verifyError != null) throw verifyError!;
    return VerificationMapper.detail(verifyJson);
  }

  @override
  Future<Verification> confirm(String id, ConfirmRequest request) async {
    confirmRequests.add(request);
    confirmedIds.add(id);
    if (confirmErrors.isNotEmpty) throw confirmErrors.removeAt(0);
    return VerificationMapper.detail(detailJson);
  }

  @override
  Future<Verification> correctTransaction(
    String id,
    int index,
    String? categoryId,
  ) async {
    corrections.add((id: id, index: index, categoryId: categoryId));
    if (correctError != null) throw correctError!;
    return VerificationMapper.detail(detailJson);
  }

  @override
  Future<Cached<VerificationPage>> history({
    String? cardId,
    int page = 1,
    int pageSize = 20,
  }) async {
    pageSizeSeen = pageSize;
    final start = (page - 1) * pageSize;
    final slice = items.skip(start).take(pageSize).toList();
    return Cached(
      VerificationPage(
        items: slice,
        page: page,
        pageSize: pageSize,
        total: items.length,
      ),
    );
  }

  @override
  Future<Cached<Verification>> detail(String id) async {
    final json = Map<String, dynamic>.from(detailJson)..['id'] = id;
    return Cached(VerificationMapper.detail(json));
  }

  @override
  Future<void> delete(String id) async => deleted.add(id);
}
