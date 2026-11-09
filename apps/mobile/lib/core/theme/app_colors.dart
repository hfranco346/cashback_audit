import 'package:flutter/material.dart';

/// A foreground/background pair for one status meaning. Always pair it with
/// an icon and a text label; never rely on color alone.
@immutable
class StatusTone {
  const StatusTone({required this.fg, required this.bg});

  final Color fg;
  final Color bg;

  static StatusTone lerp(StatusTone a, StatusTone b, double t) => StatusTone(
    fg: Color.lerp(a.fg, b.fg, t)!,
    bg: Color.lerp(a.bg, b.bg, t)!,
  );
}

/// Design tokens that M3's [ColorScheme] has no slot for: the status tones
/// (ok / error / overpaid / warning / excluded), the credit-card surface and
/// the brass ornament. Values come from `docs/cashback-audit-design/HANDOFF.md`.
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.success,
    required this.error,
    required this.overpaid,
    required this.warning,
    required this.neutral,
    required this.creditCard,
    required this.onCreditCard,
    required this.brass,
  });

  /// Paid right / counted in a category (green).
  final StatusTone success;

  /// Underpaid / no category (red).
  final StatusTone error;

  /// Overpaid (indigo).
  final StatusTone overpaid;

  /// Notices (amber).
  final StatusTone warning;

  /// Excluded lines (grey).
  final StatusTone neutral;

  final Color creditCard;
  final Color onCreditCard;

  /// Brass hairline ornament.
  final Color brass;

  static const light = AppStatusColors(
    success: StatusTone(fg: Color(0xFF17734F), bg: Color(0xFFDDF0E5)),
    error: StatusTone(fg: Color(0xFFB42318), bg: Color(0xFFFBE3DF)),
    overpaid: StatusTone(fg: Color(0xFF4338A8), bg: Color(0xFFE6E4F7)),
    warning: StatusTone(fg: Color(0xFF7A5300), bg: Color(0xFFF8ECCB)),
    neutral: StatusTone(fg: Color(0xFF545D5B), bg: Color(0xFFE9E8E3)),
    creditCard: Color(0xFF0F3D36),
    onCreditCard: Color(0xFFF3EBDA),
    brass: Color(0xFF8A6D33),
  );

  static const dark = AppStatusColors(
    success: StatusTone(fg: Color(0xFF62D2A2), bg: Color(0xFF0F3427)),
    error: StatusTone(fg: Color(0xFFFF907F), bg: Color(0xFF45150E)),
    overpaid: StatusTone(fg: Color(0xFFB4AEFF), bg: Color(0xFF262159)),
    warning: StatusTone(fg: Color(0xFFF0C462), bg: Color(0xFF3D2C07)),
    neutral: StatusTone(fg: Color(0xFFA9B2AF), bg: Color(0xFF232C2B)),
    creditCard: Color(0xFF183F38),
    onCreditCard: Color(0xFFF3EBDA),
    brass: Color(0xFFCDAE6E),
  );

  @override
  AppStatusColors copyWith({
    StatusTone? success,
    StatusTone? error,
    StatusTone? overpaid,
    StatusTone? warning,
    StatusTone? neutral,
    Color? creditCard,
    Color? onCreditCard,
    Color? brass,
  }) => AppStatusColors(
    success: success ?? this.success,
    error: error ?? this.error,
    overpaid: overpaid ?? this.overpaid,
    warning: warning ?? this.warning,
    neutral: neutral ?? this.neutral,
    creditCard: creditCard ?? this.creditCard,
    onCreditCard: onCreditCard ?? this.onCreditCard,
    brass: brass ?? this.brass,
  );

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      success: StatusTone.lerp(success, other.success, t),
      error: StatusTone.lerp(error, other.error, t),
      overpaid: StatusTone.lerp(overpaid, other.overpaid, t),
      warning: StatusTone.lerp(warning, other.warning, t),
      neutral: StatusTone.lerp(neutral, other.neutral, t),
      creditCard: Color.lerp(creditCard, other.creditCard, t)!,
      onCreditCard: Color.lerp(onCreditCard, other.onCreditCard, t)!,
      brass: Color.lerp(brass, other.brass, t)!,
    );
  }
}

extension AppStatusColorsContext on BuildContext {
  /// Status tones, credit-card colors and brass for the current theme.
  AppStatusColors get appColors =>
      Theme.of(this).extension<AppStatusColors>() ?? AppStatusColors.light;
}

// ---------------------------------------------------------------------------
// Backward-compatible views over the new tokens. Existing screens keep using
// `context.statusColors` / `context.verdictColors` until they are rebuilt.
// ---------------------------------------------------------------------------

/// Legacy success/danger/neutral accessor, derived from [AppStatusColors].
@immutable
class StatusColors {
  const StatusColors._(this._t);

  final AppStatusColors _t;

  static const light = StatusColors._(AppStatusColors.light);
  static const dark = StatusColors._(AppStatusColors.dark);

  Color get success => _t.success.fg;
  Color get successContainer => _t.success.bg;
  Color get danger => _t.error.fg;
  Color get dangerContainer => _t.error.bg;
  Color get neutral => _t.neutral.fg;
  Color get neutralContainer => _t.neutral.bg;
}

/// Legacy verdict accessor, derived from [AppStatusColors].
@immutable
class VerdictColors {
  const VerdictColors._(this._t);

  final AppStatusColors _t;

  static const light = VerdictColors._(AppStatusColors.light);
  static const dark = VerdictColors._(AppStatusColors.dark);

  Color get match => _t.success.fg;
  Color get matchContainer => _t.success.bg;
  Color get underpaid => _t.error.fg;
  Color get underpaidContainer => _t.error.bg;
  Color get overpaid => _t.overpaid.fg;
  Color get overpaidContainer => _t.overpaid.bg;
  Color get warning => _t.warning.fg;
  Color get warningContainer => _t.warning.bg;
}

extension StatusColorsContext on BuildContext {
  StatusColors get statusColors => Theme.of(this).brightness == Brightness.dark
      ? StatusColors.dark
      : StatusColors.light;
}

extension VerdictColorsContext on BuildContext {
  VerdictColors get verdictColors =>
      Theme.of(this).brightness == Brightness.dark
      ? VerdictColors.dark
      : VerdictColors.light;
}
