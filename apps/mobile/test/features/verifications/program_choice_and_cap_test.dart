import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/l10n/active_locale.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/core/utils/cached.dart';
import 'package:cashback_audit/features/cards/data/card_mapper.dart';
import 'package:cashback_audit/features/cards/domain/card_entities.dart';
import 'package:cashback_audit/features/cards/domain/card_repository.dart';
import 'package:cashback_audit/features/cards/presentation/cards_controller.dart';
import 'package:cashback_audit/features/categories/presentation/catalog_controller.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/presentation/confirm_rates_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/confirm_rates_page.dart';
import 'package:cashback_audit/features/verifications/presentation/result_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/result_page.dart';
import 'package:cashback_audit/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/fake_verification_repository.dart';
import '../../support/fakes.dart';
import '../../support/fixtures.dart';
import '../categories/fake_catalog.dart';

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

Map<String, dynamic> _choiceJson({bool required = true}) =>
    awaitingVerificationJson()
      ..['rewardProgramChoice'] = {
        'required': required,
        'options': [
          {
            'name': 'PUNTOS BAC',
            'unit': 'POINTS',
            'currency': null,
            'reportedLabel': 'Puntos acumulados',
          },
          {
            'name': 'CASH BAC',
            'unit': 'CURRENCY',
            'currency': 'HNL',
            'reportedLabel': 'Cashback del mes',
          },
        ],
      };

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    await initializeDateFormatting('en_US');
  });
  tearDown(Get.reset);

  late FakeVerificationRepository repo;
  late FakeNavigator nav;
  setUp(() {
    repo = FakeVerificationRepository();
    nav = FakeNavigator();
  });

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  Widget app(Widget home, {required bool dark, required String lang}) =>
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: Locale(lang),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: home,
      );

  group('program choice on the confirm screen', () {
    Future<ConfirmRatesController> pumpConfirm(
      WidgetTester tester,
      Map<String, dynamic> json, {
      bool dark = false,
      String lang = 'es',
    }) async {
      tester.view.physicalSize = const Size(390, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      ActiveLocale.set(Locale(lang));
      S.current = ActiveLocale.strings;
      final c = ConfirmRatesController(
        repository: repo,
        cards: CardsController(_CardRepo()),
        navigator: nav,
        args: ConfirmRatesArgs.verification(VerificationMapper.detail(json)),
      )..onInit();
      addTearDown(c.onClose);
      Get.put<ConfirmRatesController>(c);
      await tester.pumpWidget(
        app(const ConfirmRatesPage(), dark: dark, lang: lang),
      );
      await tester.pump(const Duration(seconds: 2));
      for (final e in c.entries) {
        if (!e.hasRate) e.rate.text = '1';
      }
      await tester.pump();
      return c;
    }

    testWidgets('lists each program with unit, currency and label', (
      tester,
    ) async {
      await pumpConfirm(tester, _choiceJson());
      final l10n = l10nOf(tester);
      expect(find.byKey(const Key('program-chooser')), findsOneWidget);
      expect(find.byKey(const Key('program-PUNTOS BAC')), findsOneWidget);
      expect(find.text(l10n.programUnitPoints), findsOneWidget);
      expect(find.text('${l10n.programUnitCurrency} · HNL'), findsOneWidget);
      expect(
        find.text(l10n.programPrintedAs('Cashback del mes')),
        findsOneWidget,
      );
      // The footer says what is missing until a program is chosen.
      expect(
        find.text(l10n.confirmMissingOne(l10n.programChooserTitle)),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('confirm-button')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('choosing and remembering sends both fields', (tester) async {
      final c = await pumpConfirm(tester, _choiceJson());
      await tester.tap(find.byKey(const Key('program-CASH BAC')));
      await tester.pump();
      expect(find.byKey(const Key('confirm-missing')), findsNothing);
      await tester.tap(find.byKey(const Key('program-remember')));
      await tester.pump();
      expect(c.rememberProgram.value, isTrue);
      await tester.tap(find.byKey(const Key('confirm-button')));
      await tester.pump();
      final req = repo.confirmRequests.single;
      expect(req.rewardProgramName, 'CASH BAC');
      expect(req.rememberProgramForCard, isTrue);
      final body = VerificationMapper.confirmBody(req);
      expect(body['rewardProgramName'], 'CASH BAC');
      expect(body['rememberProgramForCard'], isTrue);
    });

    testWidgets('without remembering the flag is not sent', (tester) async {
      final c = await pumpConfirm(tester, _choiceJson());
      c.selectProgram('PUNTOS BAC');
      final body = VerificationMapper.confirmBody(c.buildRequest());
      expect(body['rewardProgramName'], 'PUNTOS BAC');
      expect(body.containsKey('rememberProgramForCard'), isFalse);
    });

    testWidgets('no choice required: no chooser, nothing extra sent', (
      tester,
    ) async {
      final c = await pumpConfirm(tester, _choiceJson(required: false));
      expect(find.byKey(const Key('program-chooser')), findsNothing);
      final body = VerificationMapper.confirmBody(c.buildRequest());
      expect(body.containsKey('rewardProgramName'), isFalse);
      expect(body.containsKey('rememberProgramForCard'), isFalse);
    });

    testWidgets('INVALID_REWARD_PROGRAM reopens the chooser', (tester) async {
      final c = await pumpConfirm(tester, awaitingVerificationJson());
      expect(c.programChoices, isEmpty);
      repo.confirmErrors.add(
        const AppException(
          kind: AppErrorKind.validation,
          statusCode: 400,
          code: 'INVALID_REWARD_PROGRAM',
          details: {
            'programs': ['PUNTOS BAC', 'CASH BAC'],
          },
        ),
      );
      await c.confirm();
      expect(c.programChoices, ['PUNTOS BAC', 'CASH BAC']);
      expect(c.errorMessage.value, S.errInvalidRewardProgram);
    });

    for (final dark in [false, true]) {
      for (final lang in ['es', 'en']) {
        testWidgets('renders (dark=$dark, $lang)', (tester) async {
          await pumpConfirm(tester, _choiceJson(), dark: dark, lang: lang);
          expect(tester.takeException(), isNull);
          expect(
            find.text(
              lang == 'es'
                  ? 'Recordar para esta tarjeta'
                  : 'Remember for this card',
            ),
            findsOneWidget,
          );
        });
      }
    }
  });

  group('card cap on the result', () {
    Map<String, dynamic> capped() => verificationJson()
      ..['rewardCapApplied'] = {
        'cap': '1000',
        'uncapped': '1400.50',
        'capped': '1000',
      };

    Future<void> pumpResult(
      WidgetTester tester,
      Map<String, dynamic> json, {
      ResultTab tab = ResultTab.summary,
      bool dark = false,
      String lang = 'es',
    }) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      ActiveLocale.set(Locale(lang));
      S.current = ActiveLocale.strings;
      repo.detailJson = json;
      final catalog = CatalogController(
        categories: FakeCategoryRepository(const []),
        merchants: FakeMerchantRepository(),
      );
      final c = ResultController(
        repository: repo,
        catalog: catalog,
        navigator: nav,
        initial: VerificationMapper.detail(json),
      )..onInit();
      c.setTab(tab);
      Get.put<ResultController>(c);
      await tester.pumpWidget(app(const ResultPage(), dark: dark, lang: lang));
      await tester.pump(const Duration(seconds: 2));
    }

    testWidgets('summary shows the cap reached with uncapped to capped', (
      tester,
    ) async {
      await pumpResult(tester, capped());
      final l10n = l10nOf(tester);
      expect(find.text(l10n.resultCapTitle), findsOneWidget);
      final change = tester.widget<Text>(
        find.byKey(const Key('cap-applied-change')),
      );
      expect(change.data, contains('→'));
      expect(change.data, contains('1,400.50'));
    });

    testWidgets('no cap applied: nothing shown, tolerates absent field', (
      tester,
    ) async {
      await pumpResult(tester, verificationJson());
      expect(find.byKey(const Key('cap-applied')), findsNothing);
    });

    testWidgets('the categories tab shows the cap too', (tester) async {
      await pumpResult(tester, capped(), tab: ResultTab.categories);
      expect(find.byKey(const Key('applied-cap-row')), findsOneWidget);
      expect(find.text(l10nOf(tester).resultCapRow), findsOneWidget);
    });

    for (final dark in [false, true]) {
      for (final lang in ['es', 'en']) {
        testWidgets('renders (dark=$dark, $lang)', (tester) async {
          await pumpResult(tester, capped(), dark: dark, lang: lang);
          expect(tester.takeException(), isNull);
          expect(
            find.text(
              lang == 'es'
                  ? 'Tope de la tarjeta alcanzado'
                  : 'Card cap reached',
            ),
            findsOneWidget,
          );
        });
      }
    }
  });

  test('mapper tolerates absent and malformed cap and choice', () {
    final v = VerificationMapper.detail(verificationJson());
    expect(v.rewardCapApplied, isNull);
    expect(v.rewardProgramChoice, isNull);
    final bad = VerificationMapper.detail(
      verificationJson()
        ..['rewardCapApplied'] = {'cap': 'x'}
        ..['rewardProgramChoice'] = {'required': true},
    );
    expect(bad.rewardCapApplied, isNull);
    expect(bad.rewardProgramChoice?.options, isEmpty);
  });
}
