import 'package:shared_preferences/shared_preferences.dart';

import '../domain/locale_preference.dart';

class LocalePreferenceRepositoryImpl implements LocalePreferenceRepository {
  LocalePreferenceRepositoryImpl(this._prefs);

  static const _key = 'locale_preference';
  final SharedPreferencesAsync _prefs;

  @override
  Future<LocalePreference> read() async {
    final stored = await _prefs.getString(_key);
    return LocalePreference.values.firstWhere(
      (p) => p.name == stored,
      orElse: () => LocalePreference.auto,
    );
  }

  @override
  Future<bool> isSet() async {
    final stored = await _prefs.getString(_key);
    return LocalePreference.values.any((p) => p.name == stored);
  }

  @override
  Future<void> save(LocalePreference preference) =>
      _prefs.setString(_key, preference.name);
}
