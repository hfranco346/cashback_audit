Map<String, dynamic> cardJson({
  String id = 'c1',
  String alias = 'Daily',
  List<Map<String, dynamic>>? rules,
  String unit = 'CASHBACK_CURRENCY',
}) => {
  'id': id,
  'alias': alias,
  'bank': 'BBVA',
  'last4': '4321',
  'network': 'VISA',
  'rewardUnit': unit,
  'pointsPerCurrencyUnit': '1',
  'baseRatePercent': '1.5',
  'currency': 'MXN',
  'rules':
      rules ??
      [
        {'categoryId': 'cat1', 'ratePercent': '5', 'monthlyCap': '500'},
      ],
  'createdAt': '2026-01-01T00:00:00.000Z',
  'updatedAt': '2026-01-01T00:00:00.000Z',
};

Map<String, dynamic> categoryJson(
  String id,
  String name, {
  int merchants = 0,
}) => {
  'id': id,
  'name': name,
  'description': null,
  'merchantCount': merchants,
  'createdAt': '2026-01-01T00:00:00.000Z',
  'updatedAt': '2026-01-01T00:00:00.000Z',
};

Map<String, dynamic> merchantJson(
  String id,
  String name,
  String categoryId, {
  List<String> keywords = const [],
}) => {
  'id': id,
  'name': name,
  'keywords': keywords,
  'categoryId': categoryId,
  'createdAt': '2026-01-01T00:00:00.000Z',
  'updatedAt': '2026-01-01T00:00:00.000Z',
};
