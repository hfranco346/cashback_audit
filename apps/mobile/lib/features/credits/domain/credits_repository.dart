import 'credit_entities.dart';

abstract class CreditsRepository {
  /// `GET /credits/me`.
  Future<CreditBalance> getBalance();

  /// `GET /credits/me/history` (newest first).
  Future<CreditHistoryPage> history({int page = 1, int pageSize = 20});
}
