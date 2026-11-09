import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:cashback_audit/core/l10n/active_locale.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/utils/decimal_utils.dart';
import 'package:cashback_audit/features/settings/data/locale_preference_repository_impl.dart';
import 'package:cashback_audit/features/settings/domain/locale_preference.dart';
import 'package:cashback_audit/features/settings/presentation/locale_controller.dart';
import 'package:cashback_audit/l10n/app_localizations.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/fakes.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    await initializeDateFormatting('en_US');
  });
  tearDown(() {
    ActiveLocale.set(const Locale('es'));
    S.current = ActiveLocale.strings;
  });

  group('resolveLocale', () {
    test('auto maps en-* to English and everything else to Spanish', () {
      Locale r(Locale l) => resolveLocale(LocalePreference.auto, l);
      expect(r(const Locale('en', 'US')), const Locale('en'));
      expect(r(const Locale('en', 'GB')), const Locale('en'));
      expect(r(const Locale('es', 'MX')), const Locale('es'));
      expect(r(const Locale('fr', 'FR')), const Locale('es'));
      expect(r(const Locale('pt', 'BR')), const Locale('es'));
    });

    test('an explicit choice ignores the phone locale', () {
      expect(
        resolveLocale(LocalePreference.es, const Locale('en', 'US')),
        const Locale('es'),
      );
      expect(
        resolveLocale(LocalePreference.en, const Locale('es', 'MX')),
        const Locale('en'),
      );
    });
  });

  group('LocaleController', () {
    test('auto follows the phone locale and switches S + formatters', () {
      var system = const Locale('es', 'MX');
      final applied = <Locale>[];
      final controller = LocaleController(
        repository: LocalePreferenceRepositoryImpl(freshPrefs()),
        systemLocale: () => system,
        applyLocale: applied.add,
      );
      expect(controller.locale, const Locale('es'));
      expect(S.retry, 'Reintentar');

      system = const Locale('en', 'US');
      controller.didChangeLocales(null);
      expect(applied, [const Locale('en')]);
      expect(S.retry, 'Retry');
      expect(ActiveLocale.intlName, 'en_US');
      expect(
        formatMoney(Decimal.parse('1526.84'), currency: 'hnl'),
        'HNL 1,526.84',
      );

      system = const Locale('de');
      controller.didChangeLocales(null);
      expect(applied.last, const Locale('es'));
      expect(S.retry, 'Reintentar');
    });

    test(
      'explicit choice is persisted, applied and ignores phone changes',
      () async {
        final prefs = freshPrefs();
        final repo = LocalePreferenceRepositoryImpl(prefs);
        var system = const Locale('es');
        final applied = <Locale>[];
        final controller = LocaleController(
          repository: repo,
          systemLocale: () => system,
          applyLocale: applied.add,
        );
        await controller.select(LocalePreference.en);
        expect(applied, [const Locale('en')]);
        expect(await repo.read(), LocalePreference.en);

        system = const Locale('es');
        controller.didChangeLocales(null);
        expect(applied, hasLength(1));
        expect(S.retry, 'Retry');

        await controller.select(LocalePreference.auto);
        expect(applied.last, const Locale('es'));
        expect(await repo.read(), LocalePreference.auto);
      },
    );

    test('loadInitial falls back to auto on junk or failure', () async {
      final prefs = freshPrefs();
      await prefs.setString('locale_preference', 'klingon');
      expect(
        await LocaleController.loadInitial(
          LocalePreferenceRepositoryImpl(prefs),
        ),
        LocalePreference.auto,
      );
    });
  });

  group('ARB catalogs', () {
    Map<String, dynamic> load(String lang) =>
        jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
            as Map<String, dynamic>;

    test('Spanish and English define exactly the same messages', () {
      final es = load('es').keys.where((k) => !k.startsWith('@')).toSet();
      final en = load('en').keys.where((k) => !k.startsWith('@')).toSet();
      expect(en.difference(es), isEmpty);
      expect(es.difference(en), isEmpty);
      expect(es.length, greaterThan(350));
    });

    test('plurals and placeholders resolve per language', () {
      final es = lookupAppLocalizations(const Locale('es'));
      final en = lookupAppLocalizations(const Locale('en'));
      expect(es.merchantCount(1), '1 comercio');
      expect(es.merchantCount(3), '3 comercios');
      expect(en.merchantCount(1), '1 merchant');
      expect(en.merchantCount(3), '3 merchants');
      expect(en.ruleCount(0), 'No rules');
      expect(es.greeting('none'), 'Hola');
      expect(en.greeting('Ana'), 'Hello, Ana');
      expect(es.creditsAvailable(2), '2 verificaciones disponibles');
      expect(en.creditsAvailable(1), '1 check available');
      expect(en.breakdownDetail('HNL 10.00', 2), 'HNL 10.00 in 2 transactions');
    });
  });
}
