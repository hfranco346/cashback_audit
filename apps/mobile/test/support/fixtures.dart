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

Map<String, dynamic> verificationJson({
  String id = 'v1',
  String verdict = 'UNDERPAID',
  List<Map<String, dynamic>>? transactions,
}) => {
  'id': id,
  'cardId': 'c1',
  'statement': {
    'bank': 'BBVA',
    'cardLast4': '4321',
    'periodStart': '2026-01-01',
    'periodEnd': '2026-01-31',
    'currency': 'MXN',
    'totalSpent': '1400',
    'totalToPay': '1400',
  },
  'reported': {
    'amount': '40',
    'unit': 'CASHBACK_CURRENCY',
    'label': 'Bonificacion',
    'source': 'STATEMENT',
  },
  'expected': {'amount': '58', 'unit': 'CASHBACK_CURRENCY'},
  'difference': '-18',
  'tolerance': '1',
  'verdict': verdict,
  'breakdown': [
    {
      'categoryId': 'cat1',
      'categoryName': 'Super',
      'ratePercent': '5',
      'transactionCount': 3,
      'spend': '1100',
      'uncappedReward': '55',
      'expectedReward': '55',
      'monthlyCap': null,
      'capped': false,
    },
    {
      'categoryId': null,
      'categoryName': null,
      'ratePercent': '1',
      'transactionCount': 1,
      'spend': '300',
      'uncappedReward': '3',
      'expectedReward': '3',
      'monthlyCap': null,
      'capped': false,
    },
  ],
  'transactions':
      transactions ??
      [
        txJson(0, 'WAL MART SUC 123', '1000', source: 'KEYWORD'),
        txJson(1, 'OXXO REFORMA', '300', source: 'NONE', rate: '1'),
      ],
  'warnings': [
    {'code': 'AI_MATCHING_UNAVAILABLE', 'message': 'AI matching failed'},
  ],
  'model': 'claude-sonnet-5-5',
  'createdAt': '2026-02-01T10:00:00.000Z',
};

Map<String, dynamic> txJson(
  int index,
  String merchant,
  String amount, {
  String source = 'KEYWORD',
  String rate = '5',
  bool credit = false,
}) => {
  'index': index,
  'date': '2026-01-02',
  'merchant': merchant,
  'amount': amount,
  'isCredit': credit,
  'matchedMerchantId': source == 'NONE' ? null : 'm1',
  'matchedMerchantName': source == 'NONE' ? null : 'Walmart',
  'categoryId': source == 'NONE' ? null : 'cat1',
  'categoryName': source == 'NONE' ? null : 'Super',
  'matchSource': source,
  'matchConfidence': source == 'AI' ? 0.8 : null,
  'appliedRatePercent': rate,
  'ruleApplied': source != 'NONE',
  'expectedReward': '50',
};

Map<String, dynamic> summaryJson(String id, {String cardId = 'c1'}) => {
  'id': id,
  'cardId': cardId,
  'statement': {
    'bank': 'BBVA',
    'cardLast4': '4321',
    'periodStart': '2026-01-01',
    'periodEnd': '2026-01-31',
    'currency': 'MXN',
  },
  'rewardUnit': 'CASHBACK_CURRENCY',
  'reportedAmount': '40',
  'expectedAmount': '58',
  'difference': '-18',
  'verdict': 'UNDERPAID',
  'createdAt': '2026-02-01T10:00:00.000Z',
};
