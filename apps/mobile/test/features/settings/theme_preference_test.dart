import 'package:cashback_audit/features/settings/data/theme_preference_repository_impl.dart';
import 'package:cashback_audit/features/settings/domain/theme_preference.dart';
import 'package:cashback_audit/features/settings/presentation/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fakes.dart';

class _FailingRepo implements ThemePreferenceRepository {
  @override
  Future<ThemePreference> read() async => throw StateError('boom');
  @override
  Future<void> save(ThemePreference preference) async =>
      throw StateError('boom');
}

void main() {
  group('ThemePreferenceRepositoryImpl', () {
    test('defaults to system when nothing is stored', () async {
      final repo = ThemePreferenceRepositoryImpl(freshPrefs());
      expect(await repo.read(), ThemePreference.system);
    });

    test('persists and reloads each preference', () async {
      final prefs = freshPrefs();
      for (final p in ThemePreference.values) {
        await ThemePreferenceRepositoryImpl(prefs).save(p);
        expect(await ThemePreferenceRepositoryImpl(prefs).read(), p);
      }
    });

    test('unknown stored value falls back to system', () async {
      final prefs = freshPrefs();
      await prefs.setString('theme_preference', 'sepia');
      expect(
        await ThemePreferenceRepositoryImpl(prefs).read(),
        ThemePreference.system,
      );
    });
  });

  group('ThemeController', () {
    test('starts on system and maps to ThemeMode', () {
      final c = ThemeController(
        repository: ThemePreferenceRepositoryImpl(freshPrefs()),
        applyMode: (_) {},
      );
      expect(c.preference.value, ThemePreference.system);
      expect(c.themeMode, ThemeMode.system);
    });

    test('select applies the mode, persists it and reloads', () async {
      final prefs = freshPrefs();
      final repo = ThemePreferenceRepositoryImpl(prefs);
      final applied = <ThemeMode>[];
      final c = ThemeController(repository: repo, applyMode: applied.add);
      await c.select(ThemePreference.dark);
      await c.select(ThemePreference.light);
      expect(applied, [ThemeMode.dark, ThemeMode.light]);
      expect(c.themeMode, ThemeMode.light);
      expect(
        await ThemeController.loadInitial(
          ThemePreferenceRepositoryImpl(SharedPreferencesAsync()),
        ),
        ThemePreference.light,
      );
    });

    test('storage failures never break the session', () async {
      final applied = <ThemeMode>[];
      final c = ThemeController(
        repository: _FailingRepo(),
        applyMode: applied.add,
      );
      expect(
        await ThemeController.loadInitial(_FailingRepo()),
        ThemePreference.system,
      );
      await c.select(ThemePreference.dark);
      expect(applied, [ThemeMode.dark]);
    });
  });
}
