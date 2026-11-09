import 'package:flutter/material.dart';

import 'app_colors.dart';

export 'app_colors.dart';

/// Typeface families bundled in `assets/fonts`.
abstract final class AppFonts {
  /// High-contrast serif, only for roles >= 22 px (screen titles, verdicts,
  /// hero amounts).
  static const display = 'BodoniModa';

  /// Geometric sans for UI and body text; has tabular figures for amounts.
  static const text = 'Manrope';
}

/// Spacing scale (base 4) and layout constants.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20; // screen margin
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double screen = 20;
}

/// Corner radii from the design system.
abstract final class AppRadii {
  static const double chip = 10;
  static const double field = 14;
  static const double card = 20;
  static const double creditCard = 18;
  static const double sheet = 28;
  static const double pill = 999;
}

/// Tabular, lining figures so amounts line up in columns.
const appFigures = [FontFeature.tabularFigures()];

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF0F3D36),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFD8E8E3),
  onPrimaryContainer: Color(0xFF0F3D36),
  secondary: Color(0xFF3F6B66),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFEFECE5),
  onSecondaryContainer: Color(0xFF16201E),
  tertiary: Color(0xFF8A6D33),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFF8ECCB),
  onTertiaryContainer: Color(0xFF7A5300),
  error: Color(0xFFB42318),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFBE3DF),
  onErrorContainer: Color(0xFFB42318),
  surface: Color(0xFFF6F4EF),
  onSurface: Color(0xFF16201E),
  onSurfaceVariant: Color(0xFF5C6664),
  outline: Color(0xFF8B9490),
  outlineVariant: Color(0xFFE2DED5),
  shadow: Color(0xFF16201E),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFF16201E),
  onInverseSurface: Color(0xFFF6F4EF),
  inversePrimary: Color(0xFF8FD3C3),
  surfaceTint: Colors.transparent,
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFFBFAF7),
  surfaceContainer: Color(0xFFF3F1EB),
  surfaceContainerHigh: Color(0xFFEFECE5),
  surfaceContainerHighest: Color(0xFFE8E4DB),
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF8FD3C3),
  onPrimary: Color(0xFF08201B),
  primaryContainer: Color(0xFF1F3A35),
  onPrimaryContainer: Color(0xFFBFE7DD),
  secondary: Color(0xFF9CC4BB),
  onSecondary: Color(0xFF08201B),
  secondaryContainer: Color(0xFF1B2523),
  onSecondaryContainer: Color(0xFFEDF0EC),
  tertiary: Color(0xFFCDAE6E),
  onTertiary: Color(0xFF2A1F08),
  tertiaryContainer: Color(0xFF3D2C07),
  onTertiaryContainer: Color(0xFFF0C462),
  error: Color(0xFFFF907F),
  onError: Color(0xFF2B0A05),
  errorContainer: Color(0xFF45150E),
  onErrorContainer: Color(0xFFFF907F),
  surface: Color(0xFF0C1211),
  onSurface: Color(0xFFEDF0EC),
  onSurfaceVariant: Color(0xFFA2ACA9),
  outline: Color(0xFF6E7977),
  outlineVariant: Color(0xFF2A3533),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFFEDF0EC),
  onInverseSurface: Color(0xFF0C1211),
  inversePrimary: Color(0xFF0F3D36),
  surfaceTint: Colors.transparent,
  // Dark elevation = lighter surfaces, never shadows.
  surfaceContainerLowest: Color(0xFF141C1B),
  surfaceContainerLow: Color(0xFF172120),
  surfaceContainer: Color(0xFF192321),
  surfaceContainerHigh: Color(0xFF1B2523),
  surfaceContainerHighest: Color(0xFF222E2C),
);

/// Ledger look: ivory paper, banking green and a brass hairline. Built from
/// the tokens in `docs/cashback-audit-design/HANDOFF.md`.
abstract final class AppTheme {
  static ThemeData get light => _build(_lightScheme, AppStatusColors.light);
  static ThemeData get dark => _build(_darkScheme, AppStatusColors.dark);

  static TextTheme _textTheme(ColorScheme scheme) {
    final base = ThemeData(
      brightness: scheme.brightness,
      fontFamily: AppFonts.text,
    ).textTheme;
    TextStyle serif(
      TextStyle? s,
      double size,
      FontWeight w,
      double ls,
      double h,
    ) => (s ?? const TextStyle()).copyWith(
      fontFamily: AppFonts.display,
      fontSize: size,
      fontWeight: w,
      letterSpacing: ls,
      height: h,
      fontFeatures: appFigures,
    );
    TextStyle sans(
      TextStyle? s,
      FontWeight w, {
      double? ls,
      bool figs = false,
    }) => (s ?? const TextStyle()).copyWith(
      fontFamily: AppFonts.text,
      fontWeight: w,
      letterSpacing: ls,
      fontFeatures: figs ? appFigures : null,
    );
    return base
        .copyWith(
          // Bodoni Moda only for >= 22 px roles.
          displayLarge: serif(base.displayLarge, 57, FontWeight.w500, -1, 1.05),
          displayMedium: serif(
            base.displayMedium,
            45,
            FontWeight.w500,
            -0.8,
            1.08,
          ),
          displaySmall: serif(
            base.displaySmall,
            36,
            FontWeight.w500,
            -0.6,
            1.1,
          ),
          headlineLarge: serif(
            base.headlineLarge,
            32,
            FontWeight.w500,
            -0.5,
            1.12,
          ),
          headlineMedium: serif(
            base.headlineMedium,
            28,
            FontWeight.w500,
            -0.4,
            1.15,
          ),
          headlineSmall: serif(
            base.headlineSmall,
            24,
            FontWeight.w600,
            -0.2,
            1.2,
          ),
          // Manrope for everything else.
          titleLarge: sans(base.titleLarge, FontWeight.w700, ls: -0.2),
          titleMedium: sans(base.titleMedium, FontWeight.w700),
          titleSmall: sans(base.titleSmall, FontWeight.w700),
          bodyLarge: sans(base.bodyLarge, FontWeight.w500),
          bodyMedium: sans(base.bodyMedium, FontWeight.w500),
          bodySmall: sans(base.bodySmall, FontWeight.w500),
          labelLarge: sans(base.labelLarge, FontWeight.w700, figs: true),
          labelMedium: sans(base.labelMedium, FontWeight.w700, figs: true),
          labelSmall: sans(base.labelSmall, FontWeight.w700, ls: 1.1),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }

  static ThemeData _build(ColorScheme scheme, AppStatusColors status) {
    final text = _textTheme(scheme);
    final dark = scheme.brightness == Brightness.dark;
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      side: BorderSide(color: scheme.outlineVariant),
    );
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.field),
      borderSide: BorderSide(color: c, width: w),
    );
    const pill = StadiumBorder();

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
      fontFamily: AppFonts.text,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      dividerColor: scheme.outlineVariant,
      splashFactory: InkSparkle.splashFactory,
      extensions: [status],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: cardShape,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: border(scheme.outlineVariant),
        enabledBorder: border(scheme.outlineVariant),
        focusedBorder: border(scheme.primary, 2),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error, 2),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        helperStyle: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        errorStyle: text.bodySmall?.copyWith(
          color: scheme.error,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: pill,
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outlineVariant),
          shape: pill,
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: scheme.primary,
          shape: pill,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: Colors.transparent,
        selectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.onPrimaryContainer,
        labelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        secondaryLabelStyle: text.labelLarge?.copyWith(
          color: scheme.onPrimaryContainer,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        showCheckmark: false,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surfaceContainerLowest,
        elevation: dark ? 0 : 8,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sheet),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: scheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: pill,
          side: BorderSide(color: scheme.outlineVariant),
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          foregroundColor: scheme.onSurface,
          textStyle: text.labelMedium,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStatePropertyAll(scheme.outlineVariant),
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 8),
    );
  }
}
