import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/db/app_database.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/cached.dart';
import '../domain/verification_entities.dart';
import '../domain/verification_repository.dart';
import 'verification_mapper.dart';

class VerificationRepositoryImpl implements VerificationRepository {
  VerificationRepositoryImpl(this._dio, this._db);

  final Dio _dio;
  final AppDatabase _db;

  @override
  Future<Verification> verify({
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
      // Analysis can take minutes; the request is not idempotent so there is
      // no automatic retry.
      options: Options(
        receiveTimeout: const Duration(minutes: 3),
        sendTimeout: const Duration(minutes: 2),
      ),
    );
    return _store(res.data!);
  });

  @override
  Future<Verification> confirm(String id, ConfirmRequest request) =>
      guardApi(() async {
        final res = await _dio.post<JsonMap>(
          '/verifications/$id/confirm',
          data: VerificationMapper.confirmBody(request),
        );
        return _store(res.data!);
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

  /// Writes a fresh verification through to the offline cache.
  Future<Verification> _store(JsonMap json) async {
    await _db.saveVerificationDetail(json);
    await _db.saveVerificationSummaries([
      VerificationMapper.summaryJsonFromDetail(json),
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
  });
}
