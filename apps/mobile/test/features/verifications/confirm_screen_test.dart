import 'package:cashback_audit/core/l10n/active_locale.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/core/ui/ui.dart';
import 'package:cashback_audit/core/utils/cached.dart';
import 'package:cashback_audit/features/cards/data/card_mapper.dart';
import 'package:cashback_audit/features/cards/domain/card_entities.dart';
import 'package:cashback_audit/features/cards/domain/card_repository.dart';
import 'package:cashback_audit/features/cards/presentation/cards_controller.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/presentation/confirm_rates_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/confirm_rates_page.dart';
import 'package:cashback_audit/l10n/app_localizations.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/fake_verification_repository.dart';
import '../../support/fakes.dart';
import '../../support/fixtures.dart';

class _CardRepo implements CardRepository {
  @override
  Future<Cached<List<CreditCard>>> getCards() async =>
      Cached([CardMapper.fromJson(cardJson())]);
  @override
  Future<CreditCard> createCard(CardDraft draft) => throw UnimplementedError();
  @override
  Future<CreditCard> updateCard(String id, CardDraft draft) =>
      throw UnimplementedError();
  @override
  Future<void> deleteCard(String id) async {}
}

Map<String, dynamic> _fico({String? rate, String source = 'NONE'}) =>
    ficohsaAwaitingJson()
      ..['rewardConversion'] = {
        'fromCurrency': 'HNL',
        'toCurrency': 'USD',
        'rate': rate,
        'source': source,
        'required': rate == null,
        'note': null,
      };

Decimal _d(String s) => Decimal.parse(s);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    await initializeDateFormatting('en_US');
  });
  tearDown(Get.reset);

  late FakeVerificationRepository repo;
  late FakeNavigator nav;
  setUp(() {
    repo = FakeVerificationRepository()..detailJson = ficohsaCompletedJson();
    nav = FakeNavigator();
  });

  ConfirmRatesController make(
    Map<String, dynamic> json, {
    Map<String, Decimal> saved = const {},
    String? savedPrimary,
  }) {
    final c = ConfirmRatesController(
      repository: repo,
      cards: CardsController(_CardRepo()),
      navigator: nav,
      savedRates: saved,
      savedRatesPrimary: savedPrimary,
      args: ConfirmRatesArgs.verification(VerificationMapper.detail(json)),
    )..onInit();
    addTearDown(c.onClose);
    return c;
  }

  void fillRates(ConfirmRatesController c) {
    for (final e in c.entries) {
      if (!e.hasRate) e.rate.text = '1';
    }
  }

  Future<ConfirmRatesController> pumpPage(
    WidgetTester tester,
    Map<String, dynamic> json, {
    bool dark = false,
    String lang = 'es',
    Map<String, Decimal> saved = const {},
    String? savedPrimary,
  }) async {
    tester.view.physicalSize = const Size(390, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ActiveLocale.set(Locale(lang));
    S.current = ActiveLocale.strings;
    final c = make(json, saved: saved, savedPrimary: savedPrimary);
    Get.put<ConfirmRatesController>(c);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: Locale(lang),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const ConfirmRatesPage(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    return c;
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(ConfirmRatesPage)));

  AppButton confirmButton(WidgetTester tester) =>
      tester.widget<AppButton>(find.byKey(const Key('confirm-button')));

  group('controller: saved currency rates and footer hints', () {
    test('foreign and reward rates fall back to the user\'s saved rate', () {
      final c = make(
        _fico(),
        saved: {'EUR': _d('28.1'), 'USD': _d('26.5')},
        savedPrimary: 'HNL',
      );
      expect(c.foreignRates.single.rate.text, '28.1');
      expect(c.foreignRates.single.origin, RateOrigin.lastRate);
      expect(c.rewardRate.text, '26.5');
      expect(c.rewardRateOrigin, RateOrigin.lastRate);
    });

    test('a saved rate expressed in another primary currency is ignored', () {
      final c = make(
        _fico(),
        saved: {'EUR': _d('28.1'), 'USD': _d('26.5')},
        savedPrimary: 'MXN',
      );
      expect(c.foreignRates.single.rate.text, isEmpty);
      expect(c.rewardRate.text, isEmpty);
      expect(c.rewardRateOrigin, RateOrigin.none);
    });

    test('the statement rate wins over the saved one', () {
      final c = make(
        _fico(rate: '26.35', source: 'STATEMENT'),
        saved: {'USD': _d('26.5')},
        savedPrimary: 'HNL',
      );
      expect(c.rewardRate.text, '26.35');
      expect(c.rewardRateOrigin, RateOrigin.statement);
    });

    test('missing and invalid fields are listed', () {
      final c = make(_fico());
      expect(c.missingFields, contains(S.current.exchangeRewardTitle));
      c.rewardRate.text = '0';
      expect(c.missingFields, isNot(contains(S.current.exchangeRewardTitle)));
      expect(c.invalidFields, contains(S.current.exchangeRewardTitle));
    });

    test('programName follows the chosen or single program', () {
      final c = make(_fico());
      c.programChoices.assignAll(['A', 'B']);
      c.selectProgram('B');
      expect(c.programName, 'B');
    });
  });

  for (final dark in [false, true]) {
    for (final lang in ['es', 'en']) {
      final tag = '${dark ? 'dark' : 'light'} $lang';

      testWidgets('prefilled + suggested categories ($tag)', (tester) async {
        final c = await pumpPage(tester, _fico(), dark: dark, lang: lang);
        final l10n = l10nOf(tester);
        expect(find.text(l10n.confirmRatesTitle), findsOneWidget);
        expect(find.text(l10n.confirmRatesIntro), findsOneWidget);
        expect(find.text(l10n.suggestionsTitleN(3)), findsOneWidget);
        // Only suggestions with matching lines are preselected.
        expect(find.text(l10n.createNSuggestions(1)), findsOneWidget);
        expect(find.text(l10n.suggestionTxns(7)), findsOneWidget);
        // Header: card alias and the statement period.
        expect(find.textContaining('Daily · '), findsOneWidget);
        // Base rate from the card rules, category detected with its quote.
        expect(find.text(l10n.rateBaseTitle), findsOneWidget);
        expect(find.text(l10n.badgeCardRule), findsOneWidget);
        expect(find.text(l10n.badgeStatement), findsOneWidget);
        expect(find.text(l10n.evidenceQuote('7% en supermercados')), findsOne);
        fillRates(c);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('required exchange rate blocks and says what is missing '
          '($tag)', (tester) async {
        final c = await pumpPage(tester, _fico(), dark: dark, lang: lang);
        final l10n = l10nOf(tester);
        fillRates(c);
        c.touchRewardRate();
        await tester.pump();

        expect(find.text(l10n.exchangeRewardTitle), findsOneWidget);
        expect(find.text(l10n.exchangeQuestion('USD', 'HNL')), findsOneWidget);
        expect(find.text(l10n.exchangeEnterHint('USD', 'HNL')), findsOneWidget);
        expect(find.text(l10n.exchangeFindHint), findsOneWidget);
        expect(find.text(l10n.badgeRequired), findsWidgets);
        expect(confirmButton(tester).onPressed, isNull);
        expect(
          find.text(l10n.confirmMissingOne(l10n.exchangeRewardTitle)),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const Key('reward-rate-field')),
          '26',
        );
        await tester.pump();
        expect(find.text(l10n.exchangeEnterHint('USD', 'HNL')), findsNothing);
        expect(find.byKey(const Key('confirm-missing')), findsNothing);
        expect(confirmButton(tester).onPressed, isNotNull);

        await tester.enterText(find.byKey(const Key('reward-rate-field')), '0');
        await tester.pump();
        expect(find.text(l10n.exchangeRateInvalid), findsOneWidget);
        expect(confirmButton(tester).onPressed, isNull);
        expect(
          find.text(l10n.confirmCheckOne(l10n.exchangeRewardTitle)),
          findsOneWidget,
        );
      });
    }
  }

  testWidgets('a required rate field shows the inline error once emptied', (
    tester,
  ) async {
    await pumpPage(tester, awaitingVerificationJson(), saved: const {});
    final l10n = l10nOf(tester);
    expect(find.text(l10n.badgeRequired), findsNWidgets(2));
    expect(confirmButton(tester).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('rate-field-base')), '1');
    await tester.enterText(find.byKey(const Key('rate-field-cat1')), '5');
    await tester.enterText(find.byKey(const Key('rate-field-cat1')), '');
    await tester.pump();
    expect(find.text(l10n.rateRequiredError), findsOneWidget);
    expect(confirmButton(tester).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('rate-field-cat1')), '7');
    await tester.pump();
    expect(find.text(l10n.rateRequiredError), findsNothing);
    expect(confirmButton(tester).onPressed, isNotNull);
  });

  testWidgets('the monthly cap opens on demand and is sent', (tester) async {
    final c = await pumpPage(
      tester,
      awaitingVerificationJson(
        rateProposal: [
          proposalJson(null, null, '1', 'CARD_RULE'),
          proposalJson('cat1', 'Supermercados', '7', 'STATEMENT'),
        ],
      ),
    );
    final l10n = l10nOf(tester);
    expect(find.byKey(const Key('rate-cap-cat1')), findsNothing);
    await tester.tap(find.text(l10n.rateCapAdd));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('rate-cap-cat1')), '500');
    await tester.pump();
    expect(c.buildRequest().categoryRates.single.monthlyCap, _d('500'));
  });

  testWidgets('saved rate shows the "your last exchange rate" label', (
    tester,
  ) async {
    await pumpPage(
      tester,
      _fico(),
      saved: {'EUR': _d('28.1'), 'USD': _d('26.5')},
      savedPrimary: 'HNL',
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.rateSourceLast), findsNWidgets(2));
    final field = tester.widget<TextField>(
      find.byKey(const Key('reward-rate-field')),
    );
    expect(field.controller?.text, '26.5');
  });

  testWidgets(
    'one optional field per foreign currency with the left-out note',
    (tester) async {
      await pumpPage(tester, _fico());
      final l10n = l10nOf(tester);
      expect(find.byKey(const Key('foreign-rate-EUR')), findsOneWidget);
      expect(find.text(l10n.exchangeQuestion('EUR', 'HNL')), findsOneWidget);
      expect(find.byKey(const Key('foreign-excluded-EUR')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('foreign-rate-EUR')), '28.1');
      await tester.pump();
      expect(find.byKey(const Key('foreign-excluded-EUR')), findsNothing);
    },
  );

  testWidgets('legacy single exchange rate field and warning', (tester) async {
    await pumpPage(
      tester,
      awaitingVerificationJson(
        transactions: [
          txJson(0, 'AMAZON', '20', currency: 'USD', awaiting: true),
        ],
      ),
    );
    expect(find.byKey(const Key('exchange-rate-field')), findsOneWidget);
    expect(find.byKey(const Key('exchange-rate-warning')), findsOneWidget);
  });

  testWidgets('tapping create refreshes the proposal in place', (tester) async {
    final c = await pumpPage(tester, _fico());
    final l10n = l10nOf(tester);
    repo.suggestionsResultJson = ficohsaAwaitingJson()
      ..['rateProposal'] = [
        proposalJson(null, null, '1', 'CARD_RULE'),
        proposalJson('cat1', 'Supermercados', '7', 'STATEMENT'),
        proposalJson(
          'cat-rest',
          'Restaurantes y Comida rápida',
          '7',
          'STATEMENT',
        ),
      ]
      ..['suggestedCategories'] = <Map<String, dynamic>>[];
    await tester.tap(find.byKey(const Key('create-suggestions')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(repo.suggestionRequests, hasLength(1));
    expect(find.byKey(const Key('rate-field-cat-rest')), findsOneWidget);
    expect(find.byKey(const Key('suggested-categories-card')), findsNothing);
    expect(find.text(l10n.suggestionsCreated), findsOneWidget);
    expect(c.entries.length, 3);
  });

  testWidgets('untick a suggestion changes the create count', (tester) async {
    await pumpPage(tester, _fico());
    final l10n = l10nOf(tester);
    await tester.tap(
      find.byKey(const Key('suggestion-Tiendas por Departamento')),
    );
    await tester.pump();
    expect(find.text(l10n.createNSuggestions(2)), findsOneWidget);
  });

  testWidgets('save-to-card switch and the audited program', (tester) async {
    final c = await pumpPage(tester, _fico());
    final l10n = l10nOf(tester);
    await tester.tap(find.byKey(const Key('save-to-card')));
    await tester.pump();
    expect(c.saveToCard.value, isTrue);
    expect(find.text(l10n.saveToCardSubtitle), findsOneWidget);
    c.programChoices.assignAll(['A', 'B']);
    c.selectProgram('B');
    await tester.pump();
    expect(find.text(l10n.confirmProgramBody('B')), findsOneWidget);
  });
}
