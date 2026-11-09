import 'dart:ui';

/// Which language the app uses. Pure Dart; the presentation layer applies it.
enum LocalePreference {
  auto,
  es,
  en;

  /// Value of `locale` in `GET /me` and `PATCH /me/preferences`.
  String get apiValue => name;

  static LocalePreference? tryFromApi(String? v) {
    for (final p in values) {
      if (p.name == v?.toLowerCase()) return p;
    }
    return null;
  }
}

abstract class LocalePreferenceRepository {
  /// Stored preference, or [LocalePreference.auto] when none/invalid.
  Future<LocalePreference> read();

  /// Whether the user (or a previous sync) ever stored a choice on this
  /// device. Distinguishes "never chosen" from an explicit Automatic.
  Future<bool> isSet();
  Future<void> save(LocalePreference preference);
}

/// The locale the app actually uses: an explicit choice wins; with
/// [LocalePreference.auto] any `en-*` phone locale gives English and every
/// other language gives Spanish.
Locale resolveLocale(LocalePreference preference, Locale system) =>
    switch (preference) {
      LocalePreference.es => const Locale('es'),
      LocalePreference.en => const Locale('en'),
      LocalePreference.auto =>
        system.languageCode.toLowerCase() == 'en'
            ? const Locale('en')
            : const Locale('es'),
    };
