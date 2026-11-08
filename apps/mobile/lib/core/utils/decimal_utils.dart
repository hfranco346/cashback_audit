import 'package:decimal/decimal.dart';
import 'package:decimal/intl.dart';
import 'package:intl/intl.dart';

/// The API serializes money, rates and rewards as decimal strings.
Decimal parseDecimal(Object? value) {
  if (value == null) return Decimal.zero;
  return Decimal.parse(value.toString());
}

Decimal? tryParseDecimal(Object? value) {
  if (value == null) return null;
  return Decimal.tryParse(value.toString());
}

/// Serializes for requests (plain string, no exponent).
String decimalToApi(Decimal value) => value.toString();

/// Rounds half up to [scale] decimals without going through `double`.
Decimal roundDecimal(Decimal value, {int scale = 2}) =>
    value.round(scale: scale);

const _locale = 'es_MX';

/// Formats a monetary amount, e.g. `$1,234.50`.
String formatMoney(Decimal value, {String currency = 'MXN'}) {
  final symbol = switch (currency) {
    'MXN' || 'USD' || 'ARS' || 'COP' || 'CLP' => r'$',
    'EUR' => '€',
    _ => '$currency ',
  };
  final fmt = NumberFormat.currency(
    locale: _locale,
    symbol: symbol,
    decimalDigits: 2,
  );
  return DecimalFormatter(fmt).format(value);
}

/// Formats a points amount, e.g. `12,500 pts`.
String formatPoints(Decimal value) {
  final fmt = NumberFormat.decimalPatternDigits(
    locale: _locale,
    decimalDigits: value.scale > 0 ? 2 : 0,
  );
  return '${DecimalFormatter(fmt).format(value)} pts';
}

/// Formats a percent rate, e.g. `5%` or `1.5%`.
String formatRate(Decimal value) {
  final fmt = NumberFormat.decimalPattern(_locale)
    ..maximumFractionDigits = 4
    ..minimumFractionDigits = 0;
  return '${DecimalFormatter(fmt).format(value)}%';
}
