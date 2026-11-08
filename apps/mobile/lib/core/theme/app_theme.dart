import 'package:flutter/material.dart';

/// Colors with a fixed meaning across the app: the audit verdicts.
@immutable
class VerdictColors extends ThemeExtension<VerdictColors> {
  const VerdictColors({
    required this.match,
    required this.matchContainer,
    required this.underpaid,
    required this.underpaidContainer,
    required this.overpaid,
    required this.overpaidContainer,
    required this.warning,
    required this.warningContainer,
  });

  final Color match;
  final Color matchContainer;
  final Color underpaid;
  final Color underpaidContainer;
  final Color overpaid;
  final Color overpaidContainer;
  final Color warning;
  final Color warningContainer;

  static const light = VerdictColors(
    match: Color(0xFF0B7A5B),
    matchContainer: Color(0xFFD7F2E8),
    underpaid: Color(0xFFC4351F),
    underpaidContainer: Color(0xFFFFE1DA),
    overpaid: Color(0xFF4A4FC4),
    overpaidContainer: Color(0xFFE3E4FF),
    warning: Color(0xFF8A5A00),
    warningContainer: Color(0xFFFFEDC2),
  );

  static const dark = VerdictColors(
    match: Color(0xFF58D3A8),
    matchContainer: Color(0xFF0E3A2E),
    underpaid: Color(0xFFFF8C77),
    underpaidContainer: Color(0xFF4A1A12),
    overpaid: Color(0xFFA9ADFF),
    overpaidContainer: Color(0xFF23265E),
    warning: Color(0xFFF3C15B),
    warningContainer: Color(0xFF45310A),
  );

  @override
  VerdictColors copyWith({
    Color? match,
    Color? matchContainer,
    Color? underpaid,
    Color? underpaidContainer,
    Color? overpaid,
    Color? overpaidContainer,
    Color? warning,
    Color? warningContainer,
  }) => VerdictColors(
    match: match ?? this.match,
    matchContainer: matchContainer ?? this.matchContainer,
    underpaid: underpaid ?? this.underpaid,
    underpaidContainer: underpaidContainer ?? this.underpaidContainer,
    overpaid: overpaid ?? this.overpaid,
    overpaidContainer: overpaidContainer ?? this.overpaidContainer,
    warning: warning ?? this.warning,
    warningContainer: warningContainer ?? this.warningContainer,
  );

  @override
  VerdictColors lerp(ThemeExtension<VerdictColors>? other, double t) {
    if (other is! VerdictColors) return this;
    return VerdictColors(
      match: Color.lerp(match, other.match, t)!,
      matchContainer: Color.lerp(matchContainer, other.matchContainer, t)!,
      underpaid: Color.lerp(underpaid, other.underpaid, t)!,
      underpaidContainer: Color.lerp(
        underpaidContainer,
        other.underpaidContainer,
        t,
      )!,
      overpaid: Color.lerp(overpaid, other.overpaid, t)!,
      overpaidContainer: Color.lerp(
        overpaidContainer,
        other.overpaidContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
    );
  }
}

/// Semantic success/danger colors (e.g. transaction counted / not counted).
/// Always pair them with an icon and label; never rely on color alone.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.success,
    required this.successContainer,
    required this.danger,
    required this.dangerContainer,
  });

  final Color success;
  final Color successContainer;
  final Color danger;
  final Color dangerContainer;

  static const light = StatusColors(
    success: Color(0xFF0B7A5B),
    successContainer: Color(0xFFD7F2E8),
    danger: Color(0xFFC4351F),
    dangerContainer: Color(0xFFFFE1DA),
  );

  static const dark = StatusColors(
    success: Color(0xFF58D3A8),
    successContainer: Color(0xFF0E3A2E),
    danger: Color(0xFFFF8C77),
    dangerContainer: Color(0xFF4A1A12),
  );

  @override
  StatusColors copyWith({
    Color? success,
    Color? successContainer,
    Color? danger,
    Color? dangerContainer,
  }) => StatusColors(
    success: success ?? this.success,
    successContainer: successContainer ?? this.successContainer,
    danger: danger ?? this.danger,
    dangerContainer: dangerContainer ?? this.dangerContainer,
  );

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) return this;
    return StatusColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
    );
  }
}

extension StatusColorsContext on BuildContext {
  StatusColors get statusColors =>
      Theme.of(this).extension<StatusColors>() ?? StatusColors.light;
}

extension VerdictColorsContext on BuildContext {
  VerdictColors get verdictColors =>
      Theme.of(this).extension<VerdictColors>() ?? VerdictColors.light;
}

/// "Ledger" look: deep verdigris ink on a cool paper surface, with numerals
/// set tabular so amounts line up like a statement.
abstract final class AppTheme {
  static const _seed = Color(0xFF0B5C54);

  static ThemeData get light => _build(
    ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    ).copyWith(
      surface: const Color(0xFFF3F6F5),
      primary: const Color(0xFF0B5C54),
      secondary: const Color(0xFF3F6B66),
    ),
    VerdictColors.light,
    StatusColors.light,
  );

  static ThemeData get dark => _build(
    ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF0C1514),
      primary: const Color(0xFF7FD6C8),
    ),
    VerdictColors.dark,
    StatusColors.dark,
  );

  static ThemeData _build(
    ColorScheme scheme,
    VerdictColors verdicts,
    StatusColors status,
  ) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
    );
    const figures = [FontFeature.tabularFigures()];
    final text = base.textTheme
        .copyWith(
          displaySmall: base.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            fontFeatures: figures,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: figures,
          ),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [verdicts, status],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF142120),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF142120),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
