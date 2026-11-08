import 'package:decimal/decimal.dart';

import '../../../core/l10n/strings.dart';

/// Client-side checks mirroring the API contract so users get instant
/// feedback. Each returns a Spanish message or `null` when valid.
abstract final class CardValidator {
  static String? required(String? v, {int max = 60}) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return S.fieldRequired;
    if (t.length > max) return S.fieldTooLong(max);
    return null;
  }

  static String? last4(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return S.fieldRequired;
    if (!RegExp(r'^\d{4}$').hasMatch(t)) return S.last4Invalid;
    return null;
  }

  static String? currency(String? v) {
    final t = v?.trim() ?? '';
    if (!RegExp(r'^[A-Za-z]{3}$').hasMatch(t)) return S.currencyInvalid;
    return null;
  }

  /// Optional ISO 4217 code: empty is valid (detect automatically).
  static String? optionalCurrency(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    return currency(t);
  }

  /// Parses user input (accepts `,` as decimal separator).
  static Decimal? parse(String? v) {
    final t = v?.trim().replaceAll(',', '.') ?? '';
    if (t.isEmpty) return null;
    return Decimal.tryParse(t);
  }

  static String? percent(String? v) {
    final d = parse(v);
    if (d == null) return S.numberInvalid;
    if (d < Decimal.zero || d > Decimal.fromInt(100)) return S.percentRange;
    if (d.scale > 4) return S.numberInvalid;
    return null;
  }

  static String? positiveCap(String? v) {
    if ((v?.trim() ?? '').isEmpty) return null; // no cap
    final d = parse(v);
    if (d == null || d <= Decimal.zero || d.scale > 2) return S.capInvalid;
    return null;
  }

  static String? pointsFactor(String? v) {
    final d = parse(v);
    if (d == null) return S.numberInvalid;
    if (d <= Decimal.zero || d > Decimal.fromInt(1000) || d.scale > 4) {
      return S.pointsFactorInvalid;
    }
    return null;
  }
}
