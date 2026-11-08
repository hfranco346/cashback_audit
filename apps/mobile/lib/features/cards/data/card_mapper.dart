import '../../../core/utils/decimal_utils.dart';
import '../domain/card_entities.dart';

abstract final class CardMapper {
  static CreditCard fromJson(Map<String, dynamic> json) => CreditCard(
    id: json['id'] as String,
    alias: json['alias'] as String,
    bank: json['bank'] as String,
    last4: json['last4'] as String,
    network: json['network'] as String?,
    rewardUnit: RewardUnit.fromApi(json['rewardUnit'] as String),
    pointsPerCurrencyUnit: parseDecimal(json['pointsPerCurrencyUnit'] ?? '1'),
    baseRatePercent: parseDecimal(json['baseRatePercent']),
    currency: json['currency'] as String,
    rules: [
      for (final r in (json['rules'] as List<dynamic>? ?? const []))
        RewardRule(
          categoryId: (r as Map<String, dynamic>)['categoryId'] as String,
          ratePercent: parseDecimal(r['ratePercent']),
          monthlyCap: tryParseDecimal(r['monthlyCap']),
        ),
    ],
  );

  /// Request body. Decimals go out as strings; unknown keys are rejected by
  /// the API so only documented fields are sent.
  static Map<String, dynamic> toRequest(
    CardDraft d, {
    required bool forUpdate,
  }) {
    final network = d.network?.trim();
    return {
      'alias': d.alias.trim(),
      'bank': d.bank.trim(),
      'last4': d.last4.trim(),
      if (network != null && network.isNotEmpty)
        'network': network
      else if (forUpdate)
        'network': null,
      'rewardUnit': d.rewardUnit.apiValue,
      if (d.rewardUnit == RewardUnit.points && d.pointsPerCurrencyUnit != null)
        'pointsPerCurrencyUnit': decimalToApi(d.pointsPerCurrencyUnit!),
      'baseRatePercent': decimalToApi(d.baseRatePercent),
      'currency': d.currency.trim().toUpperCase(),
      'rules': [
        for (final r in d.rules)
          {
            'categoryId': r.categoryId,
            'ratePercent': decimalToApi(r.ratePercent),
            'monthlyCap': r.monthlyCap == null
                ? null
                : decimalToApi(r.monthlyCap!),
          },
      ],
    };
  }
}
