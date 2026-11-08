import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_utils.dart';
import '../../cards/domain/card_entities.dart';

/// Formats a reward as money (cashback) or points depending on [unit].
String formatReward(Decimal value, RewardUnit unit, {String? currency}) =>
    unit == RewardUnit.points
    ? formatPoints(value)
    : formatMoney(value, currency: currency ?? 'MXN');
