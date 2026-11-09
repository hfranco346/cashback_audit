import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

import 'locale_preference.dart';

/// A currency the user works with and the last rate used for it
/// (primary-currency units per 1 unit of [code]).
class CurrencyPref extends Equatable {
  const CurrencyPref({required this.code, this.rate});

  final String code;
  final Decimal? rate;

  @override
  List<Object?> get props => [code, rate];
}

/// What `PATCH /me/preferences` answers.
class UserPreferences extends Equatable {
  const UserPreferences({
    required this.locale,
    required this.primaryCurrency,
    required this.currencies,
  });

  final LocalePreference locale;
  final String? primaryCurrency;
  final List<CurrencyPref> currencies;

  @override
  List<Object?> get props => [locale, primaryCurrency, currencies];
}

/// One entry of the full currency list sent by the client. By default the
/// stored rate is kept; [clearRate] erases it and [rate] replaces it.
class CurrencyUpdate extends Equatable {
  const CurrencyUpdate(this.code, {this.rate, this.clearRate = false});

  final String code;
  final Decimal? rate;
  final bool clearRate;

  Map<String, dynamic> toJson() => {
    'code': code,
    if (clearRate)
      'lastRateToPrimary': null
    else if (rate != null)
      'lastRateToPrimary': rate.toString(),
  };

  @override
  List<Object?> get props => [code, rate, clearRate];
}

abstract class UserPreferencesRepository {
  Future<UserPreferences> setLocale(LocalePreference locale);

  /// `null` clears the primary currency. The server drops every stored rate.
  Future<UserPreferences> setPrimaryCurrency(String? code);

  /// Replaces the whole list (codes not listed are removed).
  Future<UserPreferences> setCurrencies(List<CurrencyUpdate> currencies);
}
