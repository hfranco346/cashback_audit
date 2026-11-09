import 'package:decimal/decimal.dart';
import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_messages.dart';
import '../../auth/domain/auth_entities.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/locale_preference.dart';
import '../domain/user_preferences.dart';
import 'locale_controller.dart';

/// Account preferences behind "Language & currencies": the language choice
/// (also applied locally right away) and the primary currency plus the list
/// of currencies with their last rate. Every change is one
/// `PATCH /me/preferences`; the server answer replaces the signed-in user.
class PreferencesController extends GetxController {
  PreferencesController({
    required this._repository,
    required this._session,
    required this._locale,
    required this._localeStore,
  });

  final UserPreferencesRepository _repository;
  final SessionController _session;
  final LocaleController _locale;
  final LocalePreferenceRepository _localeStore;

  final saving = false.obs;

  /// Last failure, already localized. Cleared by the next change.
  final errorMessage = RxnString();

  /// The language was applied on this phone but the account could not be
  /// updated (the UI shows a neutral note, not an error).
  final languageNotSynced = false.obs;

  AppUser? get _user => _session.user.value;
  LocalePreference get languagePreference => _locale.preference.value;
  String? get primaryCurrency => _user?.primaryCurrency;

  List<CurrencyPref> get currencies {
    final u = _user;
    if (u == null) return const [];
    return [
      for (final c in u.currencies)
        CurrencyPref(code: c, rate: u.currencyRates[c]),
    ];
  }

  /// Sign-in / start-up rule (kept simple): the server's language wins only
  /// while this phone has never stored a choice; once the phone has one, it
  /// wins and is pushed to the account when they differ.
  Future<void> syncLocale(AppUser user) async {
    final server = LocalePreference.tryFromApi(user.locale);
    if (!await _localeStore.isSet()) {
      if (server != null && server != LocalePreference.auto) {
        await _locale.select(server);
      }
      return;
    }
    final local = _locale.preference.value;
    if (server != local) {
      try {
        await _repository.setLocale(local);
      } on AppException {
        // Retried the next time the app signs in.
      }
    }
  }

  /// Applies [value] on this phone immediately, then saves it to the account.
  Future<void> selectLanguage(LocalePreference value) async {
    errorMessage.value = null;
    languageNotSynced.value = false;
    await _locale.select(value);
    try {
      final saved = await _repository.setLocale(value);
      _apply(saved);
    } on AppException {
      languageNotSynced.value = true;
    }
  }

  Future<bool> setPrimaryCurrency(String? code) => _run(
    () => _repository.setPrimaryCurrency(code),
    skipIf: code?.toUpperCase() == primaryCurrency,
  );

  Future<bool> addCurrency(String code, {Decimal? rate}) {
    final upper = code.trim().toUpperCase();
    if (currencies.any((c) => c.code == upper)) return Future.value(true);
    return _run(
      () => _repository.setCurrencies([
        for (final c in currencies) CurrencyUpdate(c.code),
        CurrencyUpdate(upper, rate: rate),
      ]),
    );
  }

  Future<bool> removeCurrency(String code) => _run(
    () => _repository.setCurrencies([
      for (final c in currencies)
        if (c.code != code) CurrencyUpdate(c.code),
    ]),
  );

  /// Stores [rate] for [code]; `null` clears the stored one.
  Future<bool> setRate(String code, Decimal? rate) => _run(
    () => _repository.setCurrencies([
      for (final c in currencies)
        if (c.code != code)
          CurrencyUpdate(c.code)
        else
          CurrencyUpdate(c.code, rate: rate, clearRate: rate == null),
    ]),
  );

  Future<bool> _run(
    Future<UserPreferences> Function() call, {
    bool skipIf = false,
  }) async {
    if (skipIf || saving.value) return true;
    saving.value = true;
    errorMessage.value = null;
    try {
      _apply(await call());
      return true;
    } on AppException catch (e) {
      errorMessage.value = userMessageFor(e);
      return false;
    } finally {
      saving.value = false;
    }
  }

  void _apply(UserPreferences p) {
    final u = _user;
    if (u == null) return;
    _session.updateUser(
      u.withPreferences(
        locale: p.locale.apiValue,
        primaryCurrency: p.primaryCurrency,
        currencies: [for (final c in p.currencies) c.code],
        currencyRates: {
          for (final c in p.currencies)
            if (c.rate != null) c.code: c.rate!,
        },
      ),
    );
  }
}
