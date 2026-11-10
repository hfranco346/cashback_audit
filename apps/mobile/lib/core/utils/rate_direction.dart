import 'package:decimal/decimal.dart';

/// Rough value of one unit in USD. Only used to decide which currency is the
/// "stronger" one (the unit of the question, so the typed number is >= 1);
/// never for money. Pairs with a saved or printed rate ignore it.
const _approxUsd = <String, double>{
  'USD': 1,
  'PAB': 1,
  'EUR': 1.08,
  'GBP': 1.27,
  'CAD': 0.73,
  'CHF': 1.12,
  'HNL': 0.038,
  'GTQ': 0.13,
  'CRC': 0.0019,
  'NIO': 0.027,
  'MXN': 0.055,
  'COP': 0.00025,
  'DOP': 0.017,
  'SVC': 0.114,
  'BZD': 0.5,
  'JMD': 0.0064,
  'PEN': 0.27,
  'CLP': 0.00105,
  'ARS': 0.001,
  'BRL': 0.18,
  'UYU': 0.025,
  'PYG': 0.00013,
  'BOB': 0.145,
  'VES': 0.027,
  'CUP': 0.0416,
  'HTG': 0.0076,
  'TTD': 0.147,
};

/// When a pair is not in the table, these are the reference currencies.
const _anchors = ['USD', 'EUR'];

/// Which currency is "1 unit" when asking for an exchange rate, and how to
/// convert what the user types to what the API expects.
///
/// API convention (docs/api-contract.md): a rate is *units of the
/// verification's primary currency per 1 unit of the other currency*
/// (`stored`). The question shown to the user always has the stronger
/// currency as its unit ("1 USD = how many HNL?") so the typed number
/// (`shown`) is >= 1. When the stronger one is the primary currency, `shown`
/// is the inverse of `stored`.
class RateDirection {
  const RateDirection._({
    required this.primary,
    required this.other,
    required this.flipped,
  });

  /// Picks the unit currency for the pair.
  ///
  /// [knownStored] (a saved, printed or previously sent rate, in the API
  /// direction) wins: `>= 1` means [other] is the stronger one. Without it a
  /// small table of common currencies decides, then USD/EUR, then [other].
  factory RateDirection.choose({
    required String primary,
    required String other,
    Decimal? knownStored,
  }) {
    final p = primary.trim().toUpperCase();
    final o = other.trim().toUpperCase();
    final bool otherIsStronger;
    if (knownStored != null && knownStored > Decimal.zero) {
      otherIsStronger = knownStored >= Decimal.one;
    } else if (_approxUsd[p] != null && _approxUsd[o] != null) {
      otherIsStronger = _approxUsd[o]! >= _approxUsd[p]!;
    } else if (_anchors.contains(o)) {
      otherIsStronger = true;
    } else if (_anchors.contains(p)) {
      otherIsStronger = false;
    } else {
      otherIsStronger = true;
    }
    return RateDirection._(primary: p, other: o, flipped: !otherIsStronger);
  }

  /// Currency the rate is expressed in the API (the verification's own).
  final String primary;

  /// The foreign / reward currency the rate refers to.
  final String other;

  /// The unit of the question is [primary] (so `shown = 1 / stored`).
  final bool flipped;

  /// The "1 X" currency of the question.
  String get unit => flipped ? primary : other;

  /// The currency the answer is expressed in.
  String get quote => flipped ? other : primary;

  static Decimal _invert(Decimal v) =>
      (Decimal.one / v).toDecimal(scaleOnInfinitePrecision: 12);

  /// What the API expects for the typed [shown] value: positive, at most 6
  /// decimals. `null` when it cannot be represented (<= 0, or so large that
  /// the inverse rounds to 0).
  Decimal? toStored(Decimal shown) {
    if (shown <= Decimal.zero) return null;
    final value = flipped ? _invert(shown) : shown;
    final rounded = value.round(scale: 6);
    if (rounded <= Decimal.zero) return null;
    return rounded;
  }

  /// The human-facing number for an API [stored] rate. When flipped it is the
  /// shortest (2 to 6 decimals) number that converts back to exactly
  /// [stored], so re-editing shows what the user typed (26.30, not
  /// 26.299854).
  Decimal toShown(Decimal stored) {
    if (!flipped || stored <= Decimal.zero) return stored;
    final exact = _invert(stored);
    for (var scale = 2; scale <= 6; scale++) {
      final candidate = exact.round(scale: scale);
      if (candidate > Decimal.zero && toStored(candidate) == stored) {
        return candidate;
      }
    }
    return exact.round(scale: 6);
  }

  /// A plausible reading of a value typed upside down, or `null`.
  Decimal? invertedSuggestion(Decimal shown) {
    if (shown <= Decimal.zero || shown >= Decimal.one) return null;
    final s = _invert(shown).round(scale: 4);
    return s > Decimal.zero ? s : null;
  }

  /// Example `shown` value for the pair from the built-in table, or `null`.
  Decimal? get exampleShown {
    final u = _approxUsd[unit];
    final q = _approxUsd[quote];
    if (u == null || q == null || q == 0) return null;
    final ratio = u / q;
    if (ratio < 1) return null;
    return Decimal.parse(ratio.toStringAsFixed(ratio >= 100 ? 0 : 2));
  }
}
