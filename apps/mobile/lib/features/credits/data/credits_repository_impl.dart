import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/credit_entities.dart';
import '../domain/credits_repository.dart';

class CreditsRepositoryImpl implements CreditsRepository {
  CreditsRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<CreditBalance> getBalance() => guardApi(() async {
    final res = await _dio.get<Map<String, dynamic>>('/credits/me');
    return CreditBalance.fromJson(res.data!);
  });

  @override
  Future<CreditHistoryPage> history({int page = 1, int pageSize = 20}) =>
      guardApi(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/credits/me/history',
          queryParameters: {'page': page, 'pageSize': pageSize},
        );
        final body = res.data!;
        return CreditHistoryPage(
          items: [
            for (final e in (body['items'] as List<dynamic>? ?? const []))
              _entry(e as Map<String, dynamic>),
          ],
          page: (body['page'] as num?)?.toInt() ?? page,
          pageSize: (body['pageSize'] as num?)?.toInt() ?? pageSize,
          total: (body['total'] as num?)?.toInt() ?? 0,
        );
      });

  CreditHistoryEntry _entry(Map<String, dynamic> j) => CreditHistoryEntry(
    id: j['id'] as String,
    delta: (j['delta'] as num).toInt(),
    bucket: CreditBucket.fromApi(j['bucket'] as String?),
    reason: CreditReason.fromApi(j['reason'] as String?),
    verificationId: j['verificationId'] as String?,
    periodEnd: j['periodEnd'] is String
        ? DateTime.tryParse(j['periodEnd'] as String)
        : null,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}
