import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/db/app_database.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/cached.dart';
import '../domain/verification_entities.dart';
import '../domain/verification_events.dart';
import '../domain/verification_repository.dart';
import 'verification_mapper.dart';

class VerificationRepositoryImpl implements VerificationRepository {
  VerificationRepositoryImpl(this._dio, this._db, {this._events});

  final Dio _dio;
  final AppDatabase _db;
  final VerificationEvents? _events;

  @override
  Future<Verification> upload({
    required String cardId,
    required String filePath,
    String? exchangeRate,
    String? rewardProgramName,
    UploadProgress? onProgress,
  }) => guardApi(() async {
    final rate = exchangeRate?.trim().replaceAll(',', '.');
    final program = rewardProgramName?.trim();
    final form = FormData.fromMap({
      'cardId': cardId,
      if (rate != null && rate.isNotEmpty) 'exchangeRate': rate,
      if (program != null && program.isNotEmpty) 'rewardProgramName': program,
      'file': await MultipartFile.fromFile(
        filePath,
        filename: 'statement.pdf',
        contentType: MediaType('application', 'pdf'),
      ),
    });
    final res = await _dio.post<JsonMap>(
      '/verifications',
      data: form,
      onSendProgress: onProgress,
      // The backend accepts the file and answers 202 immediately; the
      // request is not idempotent so there is no automatic retry.
      options: Options(
        receiveTimeout: const Duration(minutes: 1),
        sendTimeout: const Duration(minutes: 2),
      ),
    );
    final stored = await _store(res.data!);
    _events?.notify();
    return stored;
  });

  @override
  Future<Verification> get(String id) => guardApi(() async {
    final res = await _dio.get<JsonMap>('/verifications/$id');
    final stored = await _store(res.data!);
    // The analysis ended (rates to confirm, result or failure): lists that
    // still show it as running must refresh.
    if (!stored.isProcessing) _events?.notify();
    return stored;
  });

  @override
  Future<List<VerificationSummary>> attention() => guardApi(() async {
    final res = await _dio.get<JsonMap>('/verifications/attention');
    final items = res.data?['items'];
    return [
      if (items is List)
        for (final e in items)
          if (e is Map)
            VerificationMapper.summary(Map<String, dynamic>.from(e)),
    ];
  });

  @override
  Future<void> markSeen(String id) => guardApi(() async {
    await _dio.post<void>('/verifications/$id/seen');
    _events?.notify();
  });

  @override
  Future<Verification> confirm(String id, ConfirmRequest request) =>
      guardApi(() async {
        final res = await _dio.post<JsonMap>(
          '/verifications/$id/confirm',
          data: VerificationMapper.confirmBody(request),
        );
        final stored = await _store(res.data!);
        _events?.notify();
        return stored;
      });

  @override
  Future<Verification> correctTransaction(
    String id,
    int index,
    String? categoryId,
  ) => guardApi(() async {
    final res = await _dio.patch<JsonMap>(
      '/verifications/$id/transactions/$index',
      data: {'categoryId': categoryId},
    );
    return _store(res.data!);
  });

  @override
  Future<Verification> createCategoriesFromSuggestions(
    String id,
    List<String> names,
  ) => guardApi(() async {
    final res = await _dio.post<JsonMap>(
      '/verifications/$id/categories-from-suggestions',
      data: {'names': names},
    );
    return _store(res.data!);
  });

  /// Writes a fresh verification through to the offline cache. The `202`
  /// upload answer is a summary (no `breakdown`): it only feeds the history.
  Future<Verification> _store(JsonMap json) async {
    final isSummary = !json.containsKey('breakdown');
    if (!isSummary) await _db.saveVerificationDetail(json);
    await _db.saveVerificationSummaries([
      isSummary ? json : VerificationMapper.summaryJsonFromDetail(json),
    ]);
    return VerificationMapper.detail(json);
  }

  @override
  Future<Cached<VerificationPage>> history({
    String? cardId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final res = await guardApi(
        () => _dio.get<JsonMap>(
          '/verifications',
          queryParameters: {
            'cardId': ?cardId,
            'page': page,
            'pageSize': pageSize,
          },
        ),
      );
      final body = res.data!;
      final items = (body['items'] as List<dynamic>).cast<JsonMap>();
      // Only the first page refreshes the cache (replacing its scope).
      if (page == 1) {
        await _db.saveVerificationSummaries(
          items,
          replaceAll: cardId == null,
          replaceScopeCardId: cardId,
        );
      } else {
        await _db.saveVerificationSummaries(items);
      }
      return Cached(_page(body, items));
    } on AppException catch (e) {
      final offlineCapable =
          e.kind == AppErrorKind.network ||
          e.kind == AppErrorKind.timeout ||
          e.kind == AppErrorKind.server;
      if (!offlineCapable) rethrow;
      final rows = await _db.readVerificationSummaries(cardId: cardId);
      if (rows.isEmpty) rethrow;
      final cachedAt = await _db.verificationsCachedAt(cardId: cardId);
      final start = (page - 1) * pageSize;
      final slice = rows.skip(start).take(pageSize).toList();
      return Cached(
        VerificationPage(
          items: slice.map(VerificationMapper.summary).toList(),
          page: page,
          pageSize: pageSize,
          total: rows.length,
        ),
        fromCache: true,
        cachedAt: cachedAt,
      );
    }
  }

  VerificationPage _page(JsonMap body, List<JsonMap> items) => VerificationPage(
    items: items.map(VerificationMapper.summary).toList(),
    page: (body['page'] as num).toInt(),
    pageSize: (body['pageSize'] as num).toInt(),
    total: (body['total'] as num).toInt(),
  );

  @override
  Future<Cached<Verification>> detail(String id) =>
      networkFirst<JsonMap, Verification>(
        fetch: () => guardApi(() async {
          final res = await _dio.get<JsonMap>('/verifications/$id');
          return res.data!;
        }),
        readCache: () => _db.readVerificationDetail(id),
        writeCache: _db.saveVerificationDetail,
        map: VerificationMapper.detail,
      );

  @override
  Future<void> delete(String id) => guardApi(() async {
    await _dio.delete<void>('/verifications/$id');
    await _db.removeVerification(id);
    _events?.notify();
  });
}
