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

/// ISO 4217 minor units for the currencies that do not use 2 decimals. Every
/// other code (including unknown ones) defaults to 2.
const _minorUnits = <String, int>{
  'BIF': 0,
  'CLP': 0,
  'DJF': 0,
  'GNF': 0,
  'ISK': 0,
  'JPY': 0,
  'KMF': 0,
  'KRW': 0,
  'PYG': 0,
  'RWF': 0,
  'UGX': 0,
  'UYI': 0,
  'VND': 0,
  'VUV': 0,
  'XAF': 0,
  'XOF': 0,
  'XPF': 0,
  'BHD': 3,
  'IQD': 3,
  'JOD': 3,
  'KWD': 3,
  'LYD': 3,
  'OMR': 3,
  'TND': 3,
  'CLF': 4,
  'UYW': 4,
};

/// Decimal digits of [currency] per ISO 4217 (JPY 0, KWD 3, default 2).
int minorUnitsOf(String currency) =>
    _minorUnits[currency.trim().toUpperCase()] ?? 2;

/// Formats a monetary amount with its ISO code and the currency's minor
/// units, e.g. `USD 22.68`, `HNL 589.61`, `JPY 1,500`, `KWD 1.250`. No
/// symbols: `$` would be ambiguous between USD, MXN, HNL...
String formatMoney(Decimal value, {required String currency}) {
  final code = currency.trim().toUpperCase();
  final fmt = NumberFormat.decimalPatternDigits(
    locale: _locale,
    decimalDigits: minorUnitsOf(code),
  );
  final body = DecimalFormatter(fmt).format(value.abs());
  final negative = value < Decimal.zero;
  return '${negative ? '-' : ''}$code $body';
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
