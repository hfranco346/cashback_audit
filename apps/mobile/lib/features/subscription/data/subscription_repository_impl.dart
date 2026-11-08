import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/subscription_entities.dart';
import '../domain/subscription_repository.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<SubscriptionStatus> getStatus() => guardApi(() async {
    final res = await _dio.get<Map<String, dynamic>>('/subscriptions/me');
    final j = res.data!;
    return SubscriptionStatus(
      entitlementId: j['entitlementId'] as String? ?? 'pro',
      active: j['active'] as bool? ?? false,
      state: SubscriptionState.fromApi(j['status'] as String?),
      expiresAt: j['expiresAt'] == null
          ? null
          : DateTime.parse(j['expiresAt'] as String),
      willRenew: j['willRenew'] as bool? ?? false,
      store: j['store'] as String?,
      productId: j['productId'] as String?,
    );
  });
}
