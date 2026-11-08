import 'package:shared_preferences/shared_preferences.dart';

import '../domain/theme_preference.dart';

class ThemePreferenceRepositoryImpl implements ThemePreferenceRepository {
  ThemePreferenceRepositoryImpl(this._prefs);

  static const _key = 'theme_preference';
  final SharedPreferencesAsync _prefs;

  @override
  Future<ThemePreference> read() async {
    final stored = await _prefs.getString(_key);
    return ThemePreference.values.firstWhere(
      (p) => p.name == stored,
      orElse: () => ThemePreference.system,
    );
  }

  @override
  Future<void> save(ThemePreference preference) =>
      _prefs.setString(_key, preference.name);
}
