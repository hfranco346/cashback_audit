import 'package:cashback_audit/features/credits/domain/credit_entities.dart';
import 'package:cashback_audit/features/credits/domain/credits_repository.dart';

CreditBalance balance({
  int free = 0,
  int plan = 0,
  int purchased = 0,
  bool subscriptionActive = false,
  bool unlimited = false,
}) => CreditBalance(
  free: free,
  plan: plan,
  purchased: purchased,
  total: free + plan + purchased,
  subscriptionActive: subscriptionActive,
  unlimited: unlimited,
);

/// Scripted balances: each `getBalance` pops the next one (the last repeats).
class FakeCreditsRepository implements CreditsRepository {
  FakeCreditsRepository(List<CreditBalance> balances, {this.error})
    : _balances = [...balances];

  final List<CreditBalance> _balances;
  final Object? error;
  int calls = 0;
  List<CreditHistoryPage> pages = [];

  @override
  Future<CreditBalance> getBalance() async {
    calls++;
    if (error != null) throw error!;
    return _balances.length > 1 ? _balances.removeAt(0) : _balances.first;
  }

  @override
  Future<CreditHistoryPage> history({int page = 1, int pageSize = 20}) async =>
      pages[page - 1];
}
