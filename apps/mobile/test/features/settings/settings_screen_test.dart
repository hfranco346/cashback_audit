import 'package:cashback_audit/features/auth/domain/auth_entities.dart';
import 'package:cashback_audit/features/credits/domain/credit_entities.dart';
import 'package:cashback_audit/features/settings/domain/locale_preference.dart';
import 'package:cashback_audit/features/settings/domain/theme_preference.dart';
import 'package:cashback_audit/features/settings/domain/user_preferences.dart';
import 'package:cashback_audit/features/settings/presentation/widgets/currency_sheets.dart';
import 'package:cashback_audit/features/settings/presentation/widgets/language_currencies_view.dart';
import 'package:cashback_audit/features/settings/presentation/widgets/settings_view.dart';
import 'package:cashback_audit/features/subscription/domain/subscription_entities.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../core/ui/ui_harness.dart';
import '../../support/fake_credits_repository.dart';

const _user = AppUser(
  id: 'u1',
  email: 'ana@correo.com',
  name: 'Ana Martínez',
  provider: 'GOOGLE',
);

SettingsView _settings({
  AppUser? user = _user,
  CreditBalance? credits,
  SubscriptionStatus? sub,
  LocalePreference language = LocalePreference.auto,
  ThemePreference theme = ThemePreference.system,
  List<String> currencies = const ['HNL', 'USD'],
  Map<String, int>? taps,
  ValueChanged<ThemePreference>? onTheme,
}) {
  void tap(String k) => taps?.update(k, (v) => v + 1, ifAbsent: () => 1);
  return SettingsView(
    user: user,
    balance: credits ?? balance(free: 1),
    subscription: sub,
    language: language,
    currencies: currencies,
    theme: theme,
    onGetMore: () => tap('more'),
    onCreditHistory: () => tap('history'),
    onRestore: () => tap('restore'),
    onLanguageCurrencies: () => tap('lang'),
    onTheme: onTheme ?? (_) {},
    onSignOut: () => tap('logout'),
  );
}

LanguageCurrenciesView _lang({
  LocalePreference language = LocalePreference.auto,
  String? primary = 'HNL',
  List<CurrencyPref>? currencies,
  String? error,
  bool notSynced = false,
  ValueChanged<LocalePreference>? onLanguage,
  ValueChanged<String>? onPrimary,
  VoidCallback? onOtherPrimary,
  VoidCallback? onAdd,
  ValueChanged<String>? onRemove,
  ValueChanged<CurrencyPref>? onEditRate,
}) => LanguageCurrenciesView(
  language: language,
  primary: primary,
  currencies:
      currencies ??
      [
        CurrencyPref(code: 'USD', rate: Decimal.parse('26')),
        const CurrencyPref(code: 'EUR'),
      ],
  saving: false,
  errorMessage: error,
  languageNotSynced: notSynced,
  onLanguage: onLanguage ?? (_) {},
  onPrimary: onPrimary ?? (_) {},
  onOtherPrimary: onOtherPrimary ?? () {},
  onAddCurrency: onAdd ?? () {},
  onRemoveCurrency: onRemove ?? (_) {},
  onEditRate: onEditRate ?? (_) {},
  onBack: () {},
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    await initializeDateFormatting('en_US');
  });

  group('profile', () {
    testWidgets('shows account, balance by bucket and shortcuts', (
      tester,
    ) async {
      final taps = <String, int>{};
      await pumpUi(
        tester,
        _settings(credits: balance(free: 1, plan: 2, purchased: 3), taps: taps),
      );
      await tester.pumpAndSettle();
      expect(find.text('AM'), findsOneWidget);
      expect(find.text('Ana Martínez'), findsOneWidget);
      expect(find.text('ana@correo.com · Google'), findsOneWidget);
      expect(find.text('Sin plan activo'), findsOneWidget);
      expect(find.text('Automático · Español'), findsOneWidget);
      expect(find.text('HNL · USD'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('profile-credits-total')))
            .data,
        '6',
      );
      expect(tester.widget<Text>(find.byKey(const Key('bag-plan'))).data, '2');
      for (final k in [
        'profile-get-more',
        'row-credit-history',
        'restore-purchases',
        'row-language',
        'row-currencies',
        'logout',
      ]) {
        await tester.ensureVisible(find.byKey(Key(k)));
        await tester.tap(find.byKey(Key(k)));
      }
      expect(taps, {
        'more': 1,
        'history': 1,
        'restore': 1,
        'lang': 2,
        'logout': 1,
      });
    });

    testWidgets('subscription row follows the state', (tester) async {
      await pumpUi(
        tester,
        _settings(
          sub: const SubscriptionStatus(
            entitlementId: 'pro',
            active: true,
            state: SubscriptionState.active,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pro activa'), findsOneWidget);
    });

    testWidgets('appearance selector reports the choice', (tester) async {
      ThemePreference? picked;
      await pumpUi(tester, _settings(onTheme: (t) => picked = t));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Oscuro'));
      await tester.tap(find.text('Oscuro'));
      expect(picked, ThemePreference.dark);
    });

    for (final dark in [false, true]) {
      for (final lang in ['es', 'en']) {
        testWidgets('renders (dark=$dark, $lang)', (tester) async {
          await pumpUi(
            tester,
            _settings(user: _user),
            dark: dark,
            lang: lang,
          );
          await tester.pumpAndSettle();
          expect(
            find.text(lang == 'es' ? 'Sin plan activo' : 'No active plan'),
            findsOneWidget,
          );
          expect(
            find.text(
              lang == 'es' ? 'Automático · Español' : 'Automatic · English',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('language and currencies', () {
    testWidgets('language options map to the preference', (tester) async {
      final picked = <LocalePreference>[];
      await pumpUi(tester, _lang(onLanguage: picked.add));
      await tester.pumpAndSettle();
      expect(find.text('Igual que tu teléfono · ahora Español'), findsOne);
      await tester.tap(find.byKey(const Key('lang-en')));
      await tester.tap(find.byKey(const Key('lang-es')));
      await tester.tap(find.byKey(const Key('lang-auto')));
      expect(picked, [
        LocalePreference.en,
        LocalePreference.es,
        LocalePreference.auto,
      ]);
    });

    testWidgets('currencies: primary, rates, add, remove, edit', (
      tester,
    ) async {
      final calls = <String>[];
      await pumpUi(
        tester,
        _lang(
          onPrimary: (c) => calls.add('primary:$c'),
          onOtherPrimary: () => calls.add('other'),
          onAdd: () => calls.add('add'),
          onRemove: (c) => calls.add('remove:$c'),
          onEditRate: (c) => calls.add('edit:${c.code}'),
        ),
        size: const Size(390, 1400),
      );
      await tester.pumpAndSettle();
      expect(find.text('HNL · Lempira'), findsOneWidget);
      expect(find.text('Principal'), findsOneWidget);
      expect(find.text('USD · Dólar estadounidense'), findsOneWidget);
      expect(find.text('Último tipo de cambio: 1 USD = 26.00 HNL'), findsOne);
      expect(find.text('Sin tipo de cambio guardado'), findsOneWidget);
      await tester.tap(find.byKey(const Key('primary-USD')));
      await tester.tap(find.byKey(const Key('primary-other')));
      await tester.ensureVisible(find.byKey(const Key('add-currency')));
      await tester.tap(find.byKey(const Key('add-currency')));
      await tester.tap(find.byKey(const Key('remove-EUR')));
      await tester.tap(find.byKey(const Key('currency-USD')));
      expect(calls, ['primary:USD', 'other', 'add', 'remove:EUR', 'edit:USD']);
    });

    testWidgets('shows server errors and the not-synced note', (tester) async {
      await pumpUi(tester, _lang(error: 'Lista inválida', notSynced: true));
      await tester.pumpAndSettle();
      expect(find.text('Lista inválida'), findsOneWidget);
      expect(find.byKey(const Key('prefs-not-synced')), findsOneWidget);
    });

    for (final dark in [false, true]) {
      for (final lang in ['es', 'en']) {
        testWidgets('renders (dark=$dark, $lang)', (tester) async {
          await pumpUi(
            tester,
            _lang(language: LocalePreference.en),
            dark: dark,
            lang: lang,
          );
          await tester.pumpAndSettle();
          expect(
            find.text(
              lang == 'es' ? 'Idioma y monedas' : 'Language & currencies',
            ),
            findsOneWidget,
          );
          expect(
            find.text(
              lang == 'es' ? 'HNL · Lempira' : 'HNL · Honduran lempira',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('currency sheets', () {
    testWidgets('rate sheet validates and returns the rate or clear', (
      tester,
    ) async {
      RateSheetResult? result;
      await pumpUi(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showRateSheet(
              context,
              code: 'USD',
              primary: 'HNL',
              current: Decimal.parse('26'),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('1 USD = ¿cuántos HNL?'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('rate-field')), '0');
      await tester.tap(find.byKey(const Key('rate-sheet-save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('mayor que 0'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('rate-field')), '26,4');
      await tester.tap(find.byKey(const Key('rate-sheet-save')));
      await tester.pumpAndSettle();
      expect(result?.rate, Decimal.parse('26.4'));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rate-sheet-clear')));
      await tester.pumpAndSettle();
      expect(result?.clear, isTrue);
    });

    testWidgets('code sheet only accepts 3 letters', (tester) async {
      String? code;
      await pumpUi(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                code = await showCurrencyCodeSheet(context, title: 'Agregar'),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('currency-code-field')),
        'us',
      );
      await tester.tap(find.byKey(const Key('currency-sheet-save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('3 letras'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('currency-code-field')),
        'cad',
      );
      await tester.tap(find.byKey(const Key('currency-sheet-save')));
      await tester.pumpAndSettle();
      expect(code, 'CAD');
    });

    test('parseRateInput bounds', () {
      expect(parseRateInput('26.123456'), Decimal.parse('26.123456'));
      expect(parseRateInput('26.1234567'), isNull);
      expect(parseRateInput('-1'), isNull);
      expect(parseRateInput('abc'), isNull);
    });
  });
}
