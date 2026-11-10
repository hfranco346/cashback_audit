import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    this.email,
    this.name,
    this.provider,
    this.locale,
    this.primaryCurrency,
    this.currencies = const [],
    this.currencyRates = const {},
    this.unlimitedCredits = false,
  });

  /// Also the RevenueCat app user id.
  final String id;
  final String? email;
  final String? name;

  /// Sign-in provider (`GOOGLE` | `APPLE` | `EMAIL`).
  final String? provider;

  /// Language preference stored in the account (`auto` | `es` | `en`).
  final String? locale;

  /// ISO code the user compares amounts in (`GET /me`), when set.
  final String? primaryCurrency;

  /// ISO codes of the currencies the user works with, most relevant first.
  /// Suggested before the common ones when creating cards.
  final List<String> currencies;

  /// Last exchange rate used per currency code: primary-currency units per
  /// 1 unit of the code (`lastRateToPrimary`). Only codes with a known rate.
  final Map<String, Decimal> currencyRates;

  /// Operator-granted accounts have no credit limit (`GET /me`).
  final bool unlimitedCredits;

  /// The same user with new preferences (the server answer to a PATCH).
  AppUser withPreferences({
    String? locale,
    required String? primaryCurrency,
    required List<String> currencies,
    required Map<String, Decimal> currencyRates,
  }) => AppUser(
    id: id,
    email: email,
    name: name,
    provider: provider,
    locale: locale ?? this.locale,
    primaryCurrency: primaryCurrency,
    currencies: currencies,
    currencyRates: currencyRates,
    unlimitedCredits: unlimitedCredits,
  );

  /// First name for greetings; falls back to the e-mail local part.
  String? get firstName {
    final n = name?.trim();
    if (n != null && n.isNotEmpty) return n.split(' ').first;
    final mail = email;
    if (mail != null && mail.contains('@')) return mail.split('@').first;
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'provider': provider,
    'locale': locale,
    'primaryCurrency': primaryCurrency,
    'unlimitedCredits': unlimitedCredits,
    'currencies': [
      for (final c in currencies)
        {
          'code': c,
          if (currencyRates[c] != null)
            'lastRateToPrimary': currencyRates[c].toString(),
        },
    ],
  };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    email: json['email'] as String?,
    name: json['name'] as String?,
    provider: json['provider'] as String?,
    locale: json['locale'] as String?,
    primaryCurrency: json['primaryCurrency'] as String?,
    currencies: _currencyCodes(json['currencies']),
    currencyRates: _currencyRates(json['currencies']),
    unlimitedCredits: json['unlimitedCredits'] as bool? ?? false,
  );

  /// Accepts `[{code: 'USD', ...}]` (API) or `['USD']` (local cache).
  static List<String> _currencyCodes(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is String)
          e
        else if (e is Map && e['code'] is String)
          e['code'] as String,
    ];
  }

  static Map<String, Decimal> _currencyRates(Object? raw) {
    if (raw is! List) return const {};
    final rates = <String, Decimal>{};
    for (final e in raw) {
      if (e is! Map || e['code'] is! String) continue;
      final rate = Decimal.tryParse('${e['lastRateToPrimary']}');
      if (rate != null && rate > Decimal.zero) {
        rates[e['code'] as String] = rate;
      }
    }
    return rates;
  }

  @override
  List<Object?> get props => [
    id,
    email,
    name,
    provider,
    locale,
    primaryCurrency,
    currencies,
    currencyRates,
    unlimitedCredits,
  ];
}

/// Credential obtained from Apple on the device.
class AppleCredential extends Equatable {
  const AppleCredential({required this.identityToken, this.fullName});

  final String identityToken;

  /// Only provided by Apple on the first authorization.
  final String? fullName;

  @override
  List<Object?> get props => [identityToken, fullName];
}

/// The user dismissed the native sign-in sheet. Not an error to display.
class SignInCancelled implements Exception {
  const SignInCancelled();
}

/// Answer of `POST /auth/email/start`: when the emailed code stops working and
/// when another one may be requested.
class EmailChallenge extends Equatable {
  const EmailChallenge({
    required this.expiresInSeconds,
    required this.resendAfterSeconds,
  });

  final int expiresInSeconds;
  final int resendAfterSeconds;

  @override
  List<Object?> get props => [expiresInSeconds, resendAfterSeconds];
}

/// Sign-in methods the backend has configured (`GET /auth/providers`).
class AuthProviders extends Equatable {
  const AuthProviders({
    this.email = true,
    this.google = false,
    this.apple = false,
  });

  /// Used until the backend answers (or when it cannot be reached): the email
  /// code works without any third-party setup.
  static const emailOnly = AuthProviders();

  factory AuthProviders.fromJson(Map<String, dynamic> json) => AuthProviders(
    email: json['email'] != false,
    google: json['google'] == true,
    apple: json['apple'] == true,
  );

  final bool email;
  final bool google;
  final bool apple;

  @override
  List<Object?> get props => [email, google, apple];
}
