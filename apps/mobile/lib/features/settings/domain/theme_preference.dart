/// How the app picks its brightness. Pure Dart; mapped to `ThemeMode` by the
/// presentation layer.
enum ThemePreference { system, light, dark }

abstract class ThemePreferenceRepository {
  /// Stored preference, or [ThemePreference.system] when none/invalid.
  Future<ThemePreference> read();
  Future<void> save(ThemePreference preference);
}
