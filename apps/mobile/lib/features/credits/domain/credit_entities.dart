import 'package:equatable/equatable.dart';

/// Backend view of the user's verification credits (source of truth).
class CreditBalance extends Equatable {
  const CreditBalance({
    required this.free,
    required this.plan,
    required this.purchased,
    required this.total,
    required this.subscriptionActive,
    this.planPeriodEnd,
  });

  final int free;
  final int plan;
  final DateTime? planPeriodEnd;
  final int purchased;

  /// `free + plan + purchased`: analyses the user can still run.
  final int total;
  final bool subscriptionActive;

  bool get hasCredits => total > 0;

  factory CreditBalance.fromJson(Map<String, dynamic> j) {
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    final free = n(j['free']);
    final plan = n(j['plan']);
    final purchased = n(j['purchased']);
    return CreditBalance(
      free: free,
      plan: plan,
      purchased: purchased,
      total: j['total'] == null ? free + plan + purchased : n(j['total']),
      subscriptionActive: j['subscriptionActive'] as bool? ?? false,
      planPeriodEnd: j['planPeriodEnd'] is String
          ? DateTime.tryParse(j['planPeriodEnd'] as String)
          : null,
    );
  }

  /// The balance the `402 NO_CREDITS` error carries in `details`, if any.
  static CreditBalance? tryFromDetails(Object? details) =>
      details is Map ? CreditBalance.fromJson(Map.from(details)) : null;

  @override
  List<Object?> get props => [
    free,
    plan,
    planPeriodEnd,
    purchased,
    total,
    subscriptionActive,
  ];
}

enum CreditBucket {
  free,
  plan,
  purchased;

  static CreditBucket fromApi(String? v) => switch (v) {
    'PLAN' => CreditBucket.plan,
    'PURCHASED' => CreditBucket.purchased,
    _ => CreditBucket.free,
  };
}

enum CreditReason {
  grantFree,
  grantPlan,
  grantPack,
  consume,
  refund,
  expirePlan,
  other;

  static CreditReason fromApi(String? v) => switch (v) {
    'GRANT_FREE' => CreditReason.grantFree,
    'GRANT_PLAN' => CreditReason.grantPlan,
    'GRANT_PACK' => CreditReason.grantPack,
    'CONSUME' => CreditReason.consume,
    'REFUND' => CreditReason.refund,
    'EXPIRE_PLAN' => CreditReason.expirePlan,
    _ => CreditReason.other,
  };
}

/// One line of the append-only credit ledger.
class CreditHistoryEntry extends Equatable {
  const CreditHistoryEntry({
    required this.id,
    required this.delta,
    required this.bucket,
    required this.reason,
    required this.createdAt,
    this.verificationId,
    this.periodEnd,
  });

  final String id;
  final int delta;
  final CreditBucket bucket;
  final CreditReason reason;
  final String? verificationId;
  final DateTime? periodEnd;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    delta,
    bucket,
    reason,
    verificationId,
    periodEnd,
    createdAt,
  ];
}

class CreditHistoryPage extends Equatable {
  const CreditHistoryPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<CreditHistoryEntry> items;
  final int page;
  final int pageSize;
  final int total;

  bool get hasMore => page * pageSize < total;

  @override
  List<Object?> get props => [items, page, pageSize, total];
}
