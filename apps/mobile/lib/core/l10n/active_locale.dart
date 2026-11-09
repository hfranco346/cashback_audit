import 'dart:ui';

import '../../l10n/app_localizations.dart';

/// Locale currently in effect, readable without a `BuildContext` (money and
/// date formatters, the legacy `S` layer). Kept in sync by `LocaleController`.
abstract final class ActiveLocale {
  static Locale _locale = const Locale('es');

  static Locale get locale => _locale;

  /// Name for `intl` formatters: `es_MX` or `en_US`.
  static String get intlName =>
      _locale.languageCode == 'en' ? 'en_US' : 'es_MX';

  static void set(Locale locale) {
    _locale = locale;
  }

  /// Localizations for [locale] without a widget tree.
  static AppLocalizations get strings => lookupAppLocalizations(_locale);
}
