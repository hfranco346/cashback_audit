import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_utils.dart';
import '../../cards/domain/card_entities.dart';

/// Formats a reward as money (cashback) or points depending on [unit].
String formatReward(
  Decimal value,
  RewardUnit unit, {
  required String currency,
  String? locale,
}) => unit == RewardUnit.points
    ? formatPoints(value, locale: locale)
    : formatMoney(value, currency: currency, locale: locale);
