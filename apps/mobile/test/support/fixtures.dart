Map<String, dynamic> cardJson({
  String id = 'c1',
  String alias = 'Daily',
  List<Map<String, dynamic>>? rules,
  String unit = 'CASHBACK_CURRENCY',
  String? rewardProgramName,
  String? rewardCurrency,
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
  'rewardProgramName': rewardProgramName,
  'rewardCurrency': rewardCurrency,
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
  'status': 'COMPLETED',
  'statement': {
    'bank': 'BBVA',
    'cardLast4': '4321',
    'periodStart': '2026-01-01',
    'periodEnd': '2026-01-31',
    'currency': 'MXN',
    'totalSpent': '1400',
    'totalToPay': '1400',
  },
  'primaryCurrency': 'MXN',
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
  'explanation': 'El banco te pago 18 menos de lo esperado.',
  'detectedRates': <Map<String, dynamic>>[],
  'rateProposal': [
    proposalJson(null, null, '1', 'CARD_RULE'),
    proposalJson('cat1', 'Super', '5', 'STATEMENT', evidence: '5% en super'),
  ],
  'appliedRates': {
    'baseRatePercent': '1',
    'baseSource': 'CARD_RULE_CONFIRMED',
    'savedToCard': false,
    'categoryRates': [
      {
        'categoryId': 'cat1',
        'categoryName': 'Super',
        'ratePercent': '5',
        'monthlyCap': null,
        'source': 'STATEMENT_CONFIRMED',
      },
    ],
  },
  'conversion': {
    'primaryCurrency': 'MXN',
    'requestedRate': null,
    'statementRate': null,
  },
  'currencies': [
    {
      'currency': 'MXN',
      'isPrimary': true,
      'spent': '1400',
      'eligibleSpent': '1400',
      'convertedEligibleSpent': '1400',
      'exchangeRate': null,
      'exchangeRateSource': null,
      'expectedReward': '58',
      'excludedCount': 0,
    },
  ],
  'loyalty': {
    'selectedBy': 'ONLY_PROGRAM',
    'requestedProgramName': null,
    'selectedProgram': programJson('Bonificacion', '40'),
    'programs': [programJson('Bonificacion', '40')],
  },
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
  'models': {
    'extraction': 'claude-sonnet-5-5',
    'classification': 'claude-haiku-5-5',
    'explanation': 'claude-haiku-5-5',
  },
  'createdAt': '2026-02-01T10:00:00.000Z',
};

Map<String, dynamic> programJson(String name, String accumulated) => {
  'name': name,
  'unit': 'CURRENCY',
  'accumulated': accumulated,
  'available': null,
  'redeemedInPeriod': null,
  'expiring': null,
  'forfeited': null,
};

Map<String, dynamic> proposalJson(
  String? categoryId,
  String? name,
  String? rate,
  String source, {
  String? evidence,
  String? cap,
}) => {
  'categoryId': categoryId,
  'categoryName': name,
  'ratePercent': rate,
  'monthlyCap': cap,
  'source': source,
  'evidence': evidence,
  'unitNote': null,
  'required': source == 'NONE',
};

/// Step-1 result: nothing computed yet, the user must confirm the rates.
Map<String, dynamic> awaitingVerificationJson({
  String id = 'v1',
  List<Map<String, dynamic>>? rateProposal,
  List<Map<String, dynamic>>? transactions,
  List<Map<String, dynamic>>? programs,
  Map<String, dynamic>? selectedProgram,
}) => {
  'id': id,
  'cardId': 'c1',
  'status': 'AWAITING_RATES',
  'statement': {
    'bank': 'BAC',
    'cardLast4': '4321',
    'periodStart': '2026-01-01',
    'periodEnd': '2026-01-31',
    'currency': 'HNL',
    'totalSpent': '1400',
    'totalToPay': '1400',
  },
  'primaryCurrency': 'HNL',
  'reported': null,
  'expected': null,
  'difference': null,
  'tolerance': null,
  'verdict': null,
  'explanation': null,
  'detectedRates': <Map<String, dynamic>>[],
  'rateProposal':
      rateProposal ??
      [
        proposalJson(null, null, null, 'NONE'),
        proposalJson('cat1', 'Supermercados', null, 'NONE'),
      ],
  'appliedRates': null,
  'conversion': {
    'primaryCurrency': 'HNL',
    'requestedRate': null,
    'statementRate': null,
  },
  'currencies': <Map<String, dynamic>>[],
  'loyalty': {
    'selectedBy': null,
    'requestedProgramName': null,
    'selectedProgram': selectedProgram,
    'programs': programs ?? <Map<String, dynamic>>[],
  },
  'breakdown': <Map<String, dynamic>>[],
  'transactions':
      transactions ??
      [
        txJson(
          0,
          'SUPER LA COLONIA',
          '1000',
          source: 'AI_CATEGORY',
          currency: 'HNL',
          awaiting: true,
        ),
      ],
  'warnings': <Map<String, dynamic>>[],
  'models': {'extraction': 'claude-sonnet-5-5', 'classification': null},
  'createdAt': '2026-02-01T10:00:00.000Z',
};

/// A verification as stored before the two-step / multi-currency contract.
Map<String, dynamic> legacyVerificationJson({String id = 'old'}) => {
  'id': id,
  'cardId': 'c1',
  'statement': {'bank': 'BBVA', 'currency': 'MXN', 'totalSpent': '1400'},
  'reported': {
    'amount': '40',
    'unit': 'CASHBACK_CURRENCY',
    'source': 'STATEMENT',
  },
  'expected': {'amount': '58', 'unit': 'CASHBACK_CURRENCY'},
  'difference': '-18',
  'tolerance': '1',
  'verdict': 'UNDERPAID',
  'breakdown': <Map<String, dynamic>>[],
  'transactions': [
    {
      'index': 0,
      'date': '2026-01-02',
      'merchant': 'WAL MART',
      'amount': '1000',
      'isCredit': false,
      'matchedMerchantId': 'm1',
      'matchedMerchantName': 'Walmart',
      'categoryId': 'cat1',
      'categoryName': 'Super',
      'matchSource': 'AI',
      'matchConfidence': 0.8,
      'appliedRatePercent': '5',
      'ruleApplied': true,
      'expectedReward': '50',
    },
  ],
  'warnings': <Map<String, dynamic>>[],
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
  String currency = 'MXN',
  String kind = 'PURCHASE',
  String? excludedReason,
  String? reason,
  bool awaiting = false,
  String? creditType,
  String? suggestedHint,
}) => {
  'index': index,
  'date': '2026-01-02',
  'reference': null,
  'merchant': merchant,
  'amount': amount,
  'currency': currency,
  'isCredit': credit,
  'kind': kind,
  'convertedAmount': awaiting || excludedReason != null ? null : amount,
  'exchangeRate': null,
  'exchangeRateSource': null,
  'excludedReason':
      excludedReason ??
      (kind == 'PURCHASE' || kind == 'REFUND' ? null : 'NON_PURCHASE_KIND'),
  'matchedMerchantId': source == 'NONE' || source == 'AI_CATEGORY'
      ? null
      : 'm1',
  'matchedMerchantName': source == 'NONE' || source == 'AI_CATEGORY'
      ? null
      : 'Walmart',
  'categoryId': source == 'NONE' ? null : 'cat1',
  'categoryName': source == 'NONE' ? null : 'Super',
  'matchSource': source,
  'matchConfidence': source.startsWith('AI') ? 0.8 : null,
  'matchReason': reason,
  'creditType': creditType,
  'suggestedHint': suggestedHint,
  'appliedRatePercent': awaiting ? null : rate,
  'ruleApplied': !awaiting && source != 'NONE',
  'expectedReward': awaiting ? null : '50',
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
  'status': 'COMPLETED',
  'primaryCurrency': 'MXN',
  'rewardUnit': 'CASHBACK_CURRENCY',
  'reportedAmount': '40',
  'expectedAmount': '58',
  'difference': '-18',
  'verdict': 'UNDERPAID',
  'createdAt': '2026-02-01T10:00:00.000Z',
};

/// Step-1 result of a live Ficohsa (Honduras) run: spend in HNL, the
/// "Cash Back del mes: \$42" reward in USD, statement categories the user
/// lacks and a foreign (EUR) spend currency without a rate.
Map<String, dynamic> ficohsaAwaitingJson({String id = 'fico'}) =>
    awaitingVerificationJson(
      id: id,
      rateProposal: [
        proposalJson(null, null, '1', 'CARD_RULE'),
        proposalJson(
          'cat1',
          'Supermercados',
          '7',
          'STATEMENT',
          evidence: '7% en supermercados',
        ),
      ],
      transactions: [
        txJson(
          0,
          'SUPER LA COLONIA',
          '1000',
          source: 'AI_CATEGORY',
          currency: 'HNL',
          awaiting: true,
        ),
        txJson(
          1,
          'PIZZA HUT TGU',
          '300',
          source: 'NONE',
          currency: 'HNL',
          awaiting: true,
          suggestedHint: 'Restaurantes y Comida rápida',
        ),
        txJson(
          2,
          'HOTEL MADRID',
          '100',
          source: 'NONE',
          currency: 'EUR',
          awaiting: true,
        ),
      ],
    )..addAll({
      'rewardCurrency': null,
      'rewardConversion': {
        'fromCurrency': 'HNL',
        'toCurrency': 'USD',
        'rate': null,
        'source': 'NONE',
        'required': true,
        'note': null,
      },
      'exchangeRateProposal': [
        {'currency': 'EUR', 'rate': null, 'source': 'NONE', 'required': false},
      ],
      'suggestedCategories': [
        {
          'name': 'Tiendas por Departamento',
          'ratePercent': '7',
          'evidence': '7% Tiendas por Departamento',
          'matchingTransactionCount': 0,
        },
        {
          'name': 'Restaurantes y Comida rápida',
          'ratePercent': '7',
          'evidence': '7% Restaurantes y Comida rápida',
          'matchingTransactionCount': 7,
        },
        {
          'name': 'Débitos automáticos en educación',
          'ratePercent': '7',
          'evidence': null,
          'matchingTransactionCount': 0,
        },
      ],
      'conversion': {
        'primaryCurrency': 'HNL',
        'requestedRate': null,
        'requestedRates': <String, dynamic>{},
        'requestedRewardRate': null,
        'statementRates': <Map<String, dynamic>>[],
        'statementRate': null,
      },
    });

/// The same statement after confirm: reward USD, expected USD 22.68
/// (HNL 589.61), reported USD 42, applied reward rate, creditType lines and a
/// still-uncategorized line carrying the bank's hint.
Map<String, dynamic> ficohsaCompletedJson({String id = 'fico'}) =>
    verificationJson(
      id: id,
      verdict: 'OVERPAID',
      transactions: [
        txJson(
          0,
          'SUPER LA COLONIA',
          '1000',
          currency: 'HNL',
          source: 'AI_CATEGORY',
          reason: 'Supermercado de la zona',
        ),
        txJson(
          1,
          'PIZZA HUT TGU',
          '300',
          currency: 'HNL',
          source: 'NONE',
          rate: '1',
          suggestedHint: 'Restaurantes y Comida rápida',
        ),
        txJson(
          2,
          'PAGO RECIBIDO GRACIAS',
          '5000',
          currency: 'HNL',
          credit: true,
          kind: 'PAYMENT',
          creditType: 'PAYMENT',
        ),
        txJson(
          3,
          'DEVOLUCION AMAZON',
          '200',
          currency: 'HNL',
          credit: true,
          kind: 'REFUND',
          creditType: 'REFUND',
        ),
        txJson(
          4,
          'BONO POR MEMBRESIA',
          '50',
          currency: 'HNL',
          credit: true,
          kind: 'OTHER',
          creditType: 'OTHER_CREDIT',
        ),
      ],
    )..addAll({
      'primaryCurrency': 'HNL',
      'rewardCurrency': 'USD',
      'statement': {
        'bank': 'Ficohsa',
        'cardLast4': '4321',
        'periodStart': '2026-01-01',
        'periodEnd': '2026-01-31',
        'currency': 'HNL',
        'totalSpent': '22242.56',
        'totalToPay': '22967.72',
        'summaries': [
          {
            'currency': 'HNL',
            'previousBalance': '0',
            'purchasesAndCharges': '22967.72',
            'purchases': '22242.56',
            'chargesAndInterest': '725.16',
            'totalBalance': '22967.72',
          },
        ],
      },
      'reported': {
        'amount': '42',
        'unit': 'CASHBACK_CURRENCY',
        'currency': 'USD',
        'label': 'Cash Back',
        'source': 'STATEMENT',
      },
      'expected': {
        'amount': '22.68',
        'unit': 'CASHBACK_CURRENCY',
        'currency': 'USD',
      },
      'expectedInPrimaryCurrency': '589.61',
      'difference': '19.32',
      'tolerance': '1',
      'rewardConversion': {
        'fromCurrency': 'HNL',
        'toCurrency': 'USD',
        'rate': '25.9969',
        'source': 'NONE',
        'required': false,
        'note': null,
      },
      'exchangeRateProposal': <Map<String, dynamic>>[],
      'suggestedCategories': <Map<String, dynamic>>[],
      'appliedRates': {
        'baseRatePercent': '1',
        'baseSource': 'CARD_RULE_CONFIRMED',
        'savedToCard': false,
        'rewardExchangeRate': {
          'fromCurrency': 'HNL',
          'toCurrency': 'USD',
          'rate': '25.9969',
          'source': 'USER_ENTERED',
        },
        'categoryRates': [
          {
            'categoryId': 'cat1',
            'categoryName': 'Super',
            'ratePercent': '7',
            'monthlyCap': null,
            'source': 'STATEMENT_CONFIRMED',
          },
        ],
      },
      'conversion': {
        'primaryCurrency': 'HNL',
        'requestedRate': null,
        'requestedRates': <String, dynamic>{},
        'requestedRewardRate': '25.9969',
        'statementRates': [
          {'from': 'HNL', 'to': 'USD', 'rate': '26.1', 'source': 'STATEMENT'},
        ],
        'statementRate': {'from': 'HNL', 'to': 'USD', 'rate': '26.1'},
      },
      'loyalty': {
        'selectedBy': 'ONLY_PROGRAM',
        'requestedProgramName': null,
        'selectedProgram': {
          ...programJson('Cash Back', '42'),
          'currency': 'USD',
        },
        'programs': [
          {...programJson('Cash Back', '42'), 'currency': 'USD'},
        ],
      },
    });
