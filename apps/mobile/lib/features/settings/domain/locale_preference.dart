import 'dart:ui';

/// Which language the app uses. Pure Dart; the presentation layer applies it.
enum LocalePreference { auto, es, en }

abstract class LocalePreferenceRepository {
  /// Stored preference, or [LocalePreference.auto] when none/invalid.
  Future<LocalePreference> read();
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
