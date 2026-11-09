import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/locale_preference.dart';
import '../domain/user_preferences.dart';

/// `PATCH /me/preferences`.
class UserPreferencesRepositoryImpl implements UserPreferencesRepository {
  UserPreferencesRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<UserPreferences> setLocale(LocalePreference locale) =>
      _patch({'locale': locale.apiValue});

  @override
  Future<UserPreferences> setPrimaryCurrency(String? code) =>
      _patch({'primaryCurrency': code?.toUpperCase()});

  @override
  Future<UserPreferences> setCurrencies(List<CurrencyUpdate> currencies) =>
      _patch({
        'currencies': [for (final c in currencies) c.toJson()],
      });

  Future<UserPreferences> _patch(Map<String, dynamic> body) =>
      guardApi(() async {
        final res = await _dio.patch<Map<String, dynamic>>(
          '/me/preferences',
          data: body,
        );
        return _parse(res.data!);
      });

  static UserPreferences _parse(Map<String, dynamic> j) => UserPreferences(
    locale:
        LocalePreference.tryFromApi(j['locale'] as String?) ??
        LocalePreference.auto,
    primaryCurrency: j['primaryCurrency'] as String?,
    currencies: [
      for (final e in (j['currencies'] as List<dynamic>? ?? const []))
        if (e is Map && e['code'] is String)
          CurrencyPref(
            code: e['code'] as String,
            rate: _rate(e['lastRateToPrimary']),
          ),
    ],
  );

  static Decimal? _rate(Object? v) {
    if (v == null) return null;
    final d = Decimal.tryParse('$v');
    return d != null && d > Decimal.zero ? d : null;
  }
}
