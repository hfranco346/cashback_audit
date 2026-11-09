import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/decimal_utils.dart';

/// Money with its ISO code, tabular figures, right aligned
/// (e.g. `HNL 1,526.84`). Formatting follows the active locale.
class AmountText extends StatelessWidget {
  AmountText({
    super.key,
    required Decimal amount,
    required String currency,
    this.style,
    this.color,
    this.signed = false,
    this.textAlign = TextAlign.end,
  }) : text = _format(amount, currency, signed);

  /// Already formatted text (keeps the tabular, right-aligned styling).
  const AmountText.text(
    this.text, {
    super.key,
    this.style,
    this.color,
    this.textAlign = TextAlign.end,
  }) : signed = false;

  final String text;
  final TextStyle? style;
  final Color? color;

  /// Prefix positive amounts with `+` (rewards).
  final bool signed;
  final TextAlign textAlign;

  static String _format(Decimal amount, String currency, bool signed) {
    final body = formatMoney(amount, currency: currency);
    return signed && amount > Decimal.zero ? '+$body' : body;
  }

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.titleSmall;
    return Text(
      text,
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: base?.copyWith(color: color, fontFeatures: appFigures),
    );
  }
}
