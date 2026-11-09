import 'package:cashback_audit/core/utils/cached.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';
import 'package:cashback_audit/features/verifications/domain/verification_repository.dart';

import 'fixtures.dart';

/// In-memory [VerificationRepository] recording calls and scripted failures.
class FakeVerificationRepository implements VerificationRepository {
  /// What `upload` returns (the `202` PROCESSING summary by default).
  Map<String, dynamic> verifyJson = processingVerificationJson();

  /// Scripted `get` answers (consumed in order; the last one repeats).
  final getResults = <Object>[];
  int getCalls = 0;
  List<VerificationSummary> attentionItems = [];
  Object? attentionError;
  int attentionCalls = 0;
  final seen = <String>[];

  /// What `detail`/`confirm`/`correctTransaction` return unless scripted.
  Map<String, dynamic> detailJson = verificationJson();

  Object? verifyError;
  final confirmErrors = <Object>[];
  Object? correctError;
  Object? detailError;

  String? lastExchangeRate;
  String? lastProgram;
  final confirmRequests = <ConfirmRequest>[];
  final confirmedIds = <String>[];
  final corrections = <({String id, int index, String? categoryId})>[];
  final deleted = <String>[];
  final suggestionRequests = <({String id, List<String> names})>[];

  /// What `createCategoriesFromSuggestions` returns.
  Map<String, dynamic>? suggestionsResultJson;
  Object? suggestionsError;
  List<VerificationSummary> items = [];
  int pageSizeSeen = 0;

  @override
  Future<Verification> upload({
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
  Future<Verification> get(String id) async {
    getCalls++;
    if (getResults.isEmpty) return VerificationMapper.detail(detailJson);
    final next = getResults.length > 1 ? getResults.removeAt(0) : getResults[0];
    if (next is Map<String, dynamic>) return VerificationMapper.detail(next);
    throw next;
  }

  @override
  Future<List<VerificationSummary>> attention() async {
    attentionCalls++;
    if (attentionError != null) throw attentionError!;
    return attentionItems;
  }

  @override
  Future<void> markSeen(String id) async => seen.add(id);

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
  Future<Verification> createCategoriesFromSuggestions(
    String id,
    List<String> names,
  ) async {
    suggestionRequests.add((id: id, names: names));
    if (suggestionsError != null) throw suggestionsError!;
    return VerificationMapper.detail(suggestionsResultJson ?? detailJson);
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
    if (detailError != null) throw detailError!;
    final json = Map<String, dynamic>.from(detailJson)..['id'] = id;
    return Cached(VerificationMapper.detail(json));
  }

  @override
  Future<void> delete(String id) async => deleted.add(id);
}
