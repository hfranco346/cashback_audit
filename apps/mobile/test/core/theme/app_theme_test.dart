import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light scheme follows the HANDOFF tokens', () {
    final s = AppTheme.light.colorScheme;
    expect(s.surface, const Color(0xFFF6F4EF));
    expect(s.surfaceContainerLowest, const Color(0xFFFFFFFF));
    expect(s.surfaceContainerHigh, const Color(0xFFEFECE5));
    expect(s.onSurface, const Color(0xFF16201E));
    expect(s.onSurfaceVariant, const Color(0xFF5C6664));
    expect(s.outlineVariant, const Color(0xFFE2DED5));
    expect(s.primary, const Color(0xFF0F3D36));
    expect(s.primaryContainer, const Color(0xFFD8E8E3));
    expect(s.tertiary, const Color(0xFF8A6D33));
    expect(s.error, const Color(0xFFB42318));
    expect(s.errorContainer, const Color(0xFFFBE3DF));
  });

  test('dark scheme follows the HANDOFF tokens', () {
    final s = AppTheme.dark.colorScheme;
    expect(s.surface, const Color(0xFF0C1211));
    expect(s.surfaceContainerLowest, const Color(0xFF141C1B));
    expect(s.primary, const Color(0xFF8FD3C3));
    expect(s.onPrimary, const Color(0xFF08201B));
    expect(s.tertiary, const Color(0xFFCDAE6E));
    expect(s.error, const Color(0xFFFF907F));
  });

  test('status extension carries tones, card and brass in both themes', () {
    final l = AppTheme.light.extension<AppStatusColors>()!;
    final d = AppTheme.dark.extension<AppStatusColors>()!;
    expect(l.success.fg, const Color(0xFF17734F));
    expect(l.overpaid.bg, const Color(0xFFE6E4F7));
    expect(l.warning.fg, const Color(0xFF7A5300));
    expect(l.neutral.bg, const Color(0xFFE9E8E3));
    expect(l.creditCard, const Color(0xFF0F3D36));
    expect(d.creditCard, const Color(0xFF183F38));
    expect(d.brass, const Color(0xFFCDAE6E));
    expect(d.success.fg, const Color(0xFF62D2A2));
  });

  test('Bodoni only for roles >= 22 px; Manrope elsewhere', () {
    final t = AppTheme.light.textTheme;
    for (final style in [
      t.displayLarge,
      t.displayMedium,
      t.displaySmall,
      t.headlineLarge,
      t.headlineMedium,
      t.headlineSmall,
    ]) {
      expect(style!.fontFamily, AppFonts.display);
      expect(style.fontSize, greaterThanOrEqualTo(22));
    }
    for (final style in [
      t.titleLarge,
      t.titleMedium,
      t.titleSmall,
      t.bodyLarge,
      t.bodyMedium,
      t.bodySmall,
      t.labelLarge,
      t.labelMedium,
      t.labelSmall,
    ]) {
      expect(style!.fontFamily, AppFonts.text);
    }
    expect(
      t.labelLarge!.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  test('component shapes and sizes', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      expect(
        theme.filledButtonTheme.style!.minimumSize!.resolve({}),
        const Size(64, 52),
      );
      expect(
        theme.filledButtonTheme.style!.shape!.resolve({}),
        isA<StadiumBorder>(),
      );
      expect(theme.chipTheme.shape, isA<RoundedRectangleBorder>());
      expect(theme.cardTheme.elevation, 0);
      expect(theme.navigationBarTheme.height, greaterThanOrEqualTo(64));
    }
  });
}
