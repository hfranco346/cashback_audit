import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../domain/theme_preference.dart';

/// Permanent holder of the user's theme choice. Registered before the first
/// frame (see `main.dart`) so the app starts in the right brightness.
class ThemeController extends GetxController {
  ThemeController({
    required this._repository,
    ThemePreference initial = ThemePreference.system,
    void Function(ThemeMode mode)? applyMode,
  }) : _applyMode = applyMode ?? Get.changeThemeMode,
       preference = initial.obs;

  final ThemePreferenceRepository _repository;
  final void Function(ThemeMode mode) _applyMode;
  final Rx<ThemePreference> preference;

  ThemeMode get themeMode => toThemeMode(preference.value);

  static ThemeMode toThemeMode(ThemePreference p) => switch (p) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };

  /// Reads the stored preference; falls back to system on any failure.
  static Future<ThemePreference> loadInitial(
    ThemePreferenceRepository repository,
  ) async {
    try {
      return await repository.read();
    } on Object {
      return ThemePreference.system;
    }
  }

  Future<void> select(ThemePreference value) async {
    if (value == preference.value) return;
    preference.value = value;
    _applyMode(toThemeMode(value));
    try {
      await _repository.save(value);
    } on Object {
      // Not persisting is acceptable: the choice still applies this session.
    }
  }
}
