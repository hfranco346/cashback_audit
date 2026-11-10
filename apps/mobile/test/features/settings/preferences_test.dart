import 'dart:ui';

import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/l10n/active_locale.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/network/dio_factory.dart';
import 'package:cashback_audit/core/network/session_events.dart';
import 'package:cashback_audit/core/storage/token_storage.dart';
import 'package:cashback_audit/features/auth/domain/auth_entities.dart';
import 'package:cashback_audit/features/auth/domain/auth_repository.dart';
import 'package:cashback_audit/features/auth/presentation/session_controller.dart';
import 'package:cashback_audit/features/settings/data/locale_preference_repository_impl.dart';
import 'package:cashback_audit/features/settings/data/user_preferences_repository_impl.dart';
import 'package:cashback_audit/features/settings/domain/locale_preference.dart';
import 'package:cashback_audit/features/settings/domain/user_preferences.dart';
import 'package:cashback_audit/features/settings/presentation/locale_controller.dart';
import 'package:cashback_audit/features/settings/presentation/preferences_controller.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/fake_adapter.dart';
import '../../support/fakes.dart';

class _NoopAuthRepo with EmailAuthStub implements AuthRepository {
  @override
  Future<AppUser> signInWithGoogle() => throw UnimplementedError();
  @override
  Future<AppUser> signInWithApple() => throw UnimplementedError();
  @override
  Future<AppUser?> cachedUser() async => null;
  @override
  Future<AppUser?> loadUser() async => null;
  @override
  Future<void> signOut() async {}
}

Map<String, dynamic> _prefsBody({
  String locale = 'auto',
  String? primary = 'HNL',
  List<Map<String, dynamic>> currencies = const [],
}) => {'locale': locale, 'primaryCurrency': primary, 'currencies': currencies};

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    await initializeDateFormatting('en_US');
  });
  tearDown(() {
    ActiveLocale.set(const Locale('es'));
    S.current = ActiveLocale.strings;
  });

  group('UserPreferencesRepositoryImpl', () {
    UserPreferencesRepositoryImpl repo(FakeAdapter adapter) =>
        UserPreferencesRepositoryImpl(
          buildDio(
            baseUrl: 'http://test/api/v1',
            tokens: InMemoryTokenStorage(),
            events: SessionEvents(),
            adapter: adapter,
          ),
        );

    test('PATCH payloads: locale, primary (nullable) and currencies', () async {
      final adapter = FakeAdapter(
        (_) => FakeResponse(
          200,
          _prefsBody(
            locale: 'en',
            currencies: [
              {'code': 'USD', 'lastRateToPrimary': '26.5'},
              {'code': 'EUR', 'lastRateToPrimary': null},
            ],
          ),
        ),
      );
      final r = repo(adapter);
      final saved = await r.setLocale(LocalePreference.en);
      expect(adapter.requests.last.method, 'PATCH');
      expect(adapter.requests.last.path, '/me/preferences');
      expect(adapter.requests.last.data, {'locale': 'en'});
      expect(saved.locale, LocalePreference.en);
      expect(saved.primaryCurrency, 'HNL');
      expect(saved.currencies, [
        CurrencyPref(code: 'USD', rate: Decimal.parse('26.5')),
        const CurrencyPref(code: 'EUR'),
      ]);

      await r.setPrimaryCurrency('usd');
      expect(adapter.requests.last.data, {'primaryCurrency': 'USD'});
      await r.setPrimaryCurrency(null);
      expect(adapter.requests.last.data, {'primaryCurrency': null});

      await r.setCurrencies([
        const CurrencyUpdate('USD'),
        CurrencyUpdate('EUR', rate: Decimal.parse('28.1')),
        const CurrencyUpdate('MXN', clearRate: true),
      ]);
      expect(adapter.requests.last.data, {
        'currencies': [
          {'code': 'USD'},
          {'code': 'EUR', 'lastRateToPrimary': '28.1'},
          {'code': 'MXN', 'lastRateToPrimary': null},
        ],
      });
    });

    test('400 INVALID_CURRENCIES surfaces as an AppException', () async {
      final adapter = FakeAdapter(
        (_) => const FakeResponse(400, {
          'statusCode': 400,
          'code': 'INVALID_CURRENCIES',
          'message': 'bad',
        }),
      );
      await expectLater(
        repo(adapter).setCurrencies([const CurrencyUpdate('HNL')]),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            'INVALID_CURRENCIES',
          ),
        ),
      );
    });
  });

  group('PreferencesController', () {
    late FakeAdapter adapter;
    late SessionController session;
    late LocaleController locale;
    late LocalePreferenceRepositoryImpl store;
    late PreferencesController controller;
    late List<Map<String, dynamic>> responses;

    Future<void> setUpController({
      AppUser? user,
      LocalePreference initial = LocalePreference.auto,
    }) async {
      responses = [];
      adapter = FakeAdapter(
        (o) => responses.isEmpty
            ? FakeResponse(200, _prefsBody())
            : FakeResponse(200, responses.removeAt(0)),
      );
      store = LocalePreferenceRepositoryImpl(freshPrefs());
      locale = LocaleController(
        repository: store,
        initial: initial,
        systemLocale: () => const Locale('es', 'MX'),
        applyLocale: (_) {},
      );
      session = SessionController(
        repository: _NoopAuthRepo(),
        events: SessionEvents(),
        clearLocalData: () async {},
        navigator: FakeNavigator(),
      );
      session.user.value =
          user ??
          AppUser(
            id: 'u1',
            primaryCurrency: 'HNL',
            currencies: const ['USD', 'EUR'],
            currencyRates: {'USD': Decimal.parse('26')},
          );
      controller = PreferencesController(
        repository: UserPreferencesRepositoryImpl(
          buildDio(
            baseUrl: 'http://test/api/v1',
            tokens: InMemoryTokenStorage(),
            events: SessionEvents(),
            adapter: adapter,
          ),
        ),
        session: session,
        locale: locale,
        localeStore: store,
      );
    }

    test('addCurrency sends the full list keeping the stored rates', () async {
      await setUpController();
      responses.add(
        _prefsBody(
          currencies: [
            {'code': 'EUR'},
            {'code': 'MXN', 'lastRateToPrimary': null},
            {'code': 'USD', 'lastRateToPrimary': '26'},
          ],
        ),
      );
      expect(await controller.addCurrency('mxn'), isTrue);
      expect(adapter.requests.last.data, {
        'currencies': [
          {'code': 'USD'},
          {'code': 'EUR'},
          {'code': 'MXN'},
        ],
      });
      expect(session.user.value!.currencies, ['EUR', 'MXN', 'USD']);
      expect(session.user.value!.currencyRates['USD'], Decimal.parse('26'));
    });

    test('setRate replaces only that rate; null clears it', () async {
      await setUpController();
      responses.add(
        _prefsBody(
          currencies: [
            {'code': 'EUR', 'lastRateToPrimary': '28.4'},
            {'code': 'USD', 'lastRateToPrimary': '26'},
          ],
        ),
      );
      await controller.setRate('EUR', Decimal.parse('28.4'));
      expect(adapter.requests.last.data, {
        'currencies': [
          {'code': 'USD'},
          {'code': 'EUR', 'lastRateToPrimary': '28.4'},
        ],
      });
      expect(session.user.value!.currencyRates['EUR'], Decimal.parse('28.4'));

      await controller.setRate('USD', null);
      expect(adapter.requests.last.data, {
        'currencies': [
          {'code': 'EUR'},
          {'code': 'USD', 'lastRateToPrimary': null},
        ],
      });
    });

    test('removeCurrency leaves the others out of the new list', () async {
      await setUpController();
      responses.add(
        _prefsBody(
          currencies: [
            {'code': 'EUR'},
          ],
        ),
      );
      await controller.removeCurrency('USD');
      expect(adapter.requests.last.data, {
        'currencies': [
          {'code': 'EUR'},
        ],
      });
      expect(session.user.value!.currencies, ['EUR']);
    });

    test('changing the primary currency adopts the cleared rates', () async {
      await setUpController();
      responses.add(
        _prefsBody(
          primary: 'USD',
          currencies: [
            {'code': 'EUR', 'lastRateToPrimary': null},
          ],
        ),
      );
      expect(await controller.setPrimaryCurrency('usd'), isTrue);
      expect(adapter.requests.last.data, {'primaryCurrency': 'USD'});
      expect(session.user.value!.primaryCurrency, 'USD');
      expect(session.user.value!.currencies, ['EUR']);
      expect(session.user.value!.currencyRates, isEmpty);
      // Same value again: nothing to send.
      final calls = adapter.requests.length;
      expect(await controller.setPrimaryCurrency('USD'), isTrue);
      expect(adapter.requests.length, calls);
    });

    test('400 INVALID_CURRENCIES keeps the list and explains', () async {
      await setUpController();
      adapter = FakeAdapter(
        (_) => const FakeResponse(400, {
          'statusCode': 400,
          'code': 'INVALID_CURRENCIES',
          'message': 'dup',
        }),
      );
      controller = PreferencesController(
        repository: UserPreferencesRepositoryImpl(
          buildDio(
            baseUrl: 'http://test/api/v1',
            tokens: InMemoryTokenStorage(),
            events: SessionEvents(),
            adapter: adapter,
          ),
        ),
        session: session,
        locale: locale,
        localeStore: store,
      );
      expect(await controller.addCurrency('XAF'), isFalse);
      expect(controller.errorMessage.value, S.errInvalidCurrencies);
      expect(session.user.value!.currencies, ['USD', 'EUR']);
      expect(controller.saving.value, isFalse);
    });

    test('selectLanguage applies locally then saves to the account', () async {
      await setUpController();
      responses.add(_prefsBody(locale: 'en'));
      await controller.selectLanguage(LocalePreference.en);
      expect(locale.preference.value, LocalePreference.en);
      expect(adapter.requests.last.data, {'locale': 'en'});
      expect(session.user.value!.locale, 'en');
      expect(controller.languageNotSynced.value, isFalse);
      expect(await store.read(), LocalePreference.en);
    });

    test('a failed save still applies the language on the phone', () async {
      await setUpController();
      adapter = FakeAdapter((_) => const FakeResponse(-1));
      controller = PreferencesController(
        repository: UserPreferencesRepositoryImpl(
          buildDio(
            baseUrl: 'http://test/api/v1',
            tokens: InMemoryTokenStorage(),
            events: SessionEvents(),
            adapter: adapter,
          ),
        ),
        session: session,
        locale: locale,
        localeStore: store,
      );
      await controller.selectLanguage(LocalePreference.en);
      expect(locale.preference.value, LocalePreference.en);
      expect(controller.languageNotSynced.value, isTrue);
    });

    test(
      'sign-in: the server language wins only while none is stored',
      () async {
        await setUpController();
        await controller.syncLocale(const AppUser(id: 'u1', locale: 'en'));
        expect(locale.preference.value, LocalePreference.en);
        expect(await store.isSet(), isTrue);
        expect(adapter.requests, isEmpty);
      },
    );

    test('sign-in: an automatic server value changes nothing', () async {
      await setUpController();
      await controller.syncLocale(const AppUser(id: 'u1', locale: 'auto'));
      expect(locale.preference.value, LocalePreference.auto);
      expect(await store.isSet(), isFalse);
    });

    test('sign-in: a stored local choice wins and is pushed', () async {
      await setUpController();
      await locale.select(LocalePreference.es);
      responses.add(_prefsBody(locale: 'es'));
      await controller.syncLocale(const AppUser(id: 'u1', locale: 'en'));
      expect(locale.preference.value, LocalePreference.es);
      expect(adapter.requests.last.data, {'locale': 'es'});
      // Equal values: no request.
      final calls = adapter.requests.length;
      await controller.syncLocale(const AppUser(id: 'u1', locale: 'es'));
      expect(adapter.requests.length, calls);
    });
  });
}
