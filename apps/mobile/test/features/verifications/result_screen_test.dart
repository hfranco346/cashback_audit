import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/l10n/active_locale.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/routing/app_routes.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/core/ui/ui.dart';
import 'package:cashback_audit/features/categories/domain/catalog_entities.dart';
import 'package:cashback_audit/features/categories/presentation/catalog_controller.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';
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

Map<String, dynamic> _bacJson() {
  final json = verificationJson(
    transactions: [
      txJson(
        0,
        'SUPER LA COLONIA',
        '1000',
        source: 'AI_CATEGORY',
        currency: 'HNL',
        reason: 'Supermercado',
      ),
      txJson(
        1,
        'COMIDAS ESPECIALES EBERSO',
        '300',
        source: 'NONE',
        currency: 'HNL',
      ),
      txJson(
        2,
        'PAGO RECIBIDO',
        '500',
        source: 'NONE',
        currency: 'HNL',
        kind: 'PAYMENT',
      ),
      txJson(
        3,
        'AMAZON',
        '20',
        source: 'NONE',
        currency: 'USD',
        excludedReason: 'NO_EXCHANGE_RATE',
      ),
    ],
  );
  json['primaryCurrency'] = 'HNL';
  json['statement'] = {
    ...json['statement'] as Map<String, dynamic>,
    'currency': 'HNL',
  };
  json['warnings'] = [
    {'code': 'NO_EXCHANGE_RATE', 'message': 'no rate'},
    {'code': 'CARD_LAST4_MISMATCH', 'message': 'mismatch'},
    {'code': 'REPORTED_VALUE_MAY_BE_CUMULATIVE', 'message': 'cumulative'},
    {'code': 'EXPLANATION_UNAVAILABLE', 'message': 'no explanation'},
    {'code': 'SOMETHING_NEW', 'message': 'Texto del servidor'},
  ];
  json['currencies'] = [
    {
      'currency': 'HNL',
      'isPrimary': true,
      'spent': '1300',
      'eligibleSpent': '1300',
      'convertedEligibleSpent': '1300',
      'exchangeRate': null,
      'exchangeRateSource': null,
      'expectedReward': '91',
      'excludedCount': 0,
    },
    {
      'currency': 'USD',
      'isPrimary': false,
      'spent': '20',
      'eligibleSpent': '0',
      'convertedEligibleSpent': null,
      'exchangeRate': null,
      'exchangeRateSource': null,
      'expectedReward': '0',
      'excludedCount': 1,
    },
  ];
  json['loyalty'] = {
    'selectedBy': 'CARD',
    'requestedProgramName': null,
    'selectedProgram': programJson('CASH BAC', '6534'),
    'programs': [
      {
        ...programJson('PUNTOS BAC', '1200'),
        'unit': 'POINTS',
        'available': '900',
      },
      programJson('CASH BAC', '6534'),
    ],
  };
  return json;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    await initializeDateFormatting('en_US');
  });
  tearDown(Get.reset);

  late FakeVerificationRepository repo;
  late FakeNavigator nav;
  late FakeMerchantRepository merchants;
  late CatalogController catalog;

  setUp(() {
    repo = FakeVerificationRepository();
    nav = FakeNavigator();
    merchants = FakeMerchantRepository();
  });

  Future<ResultController> pumpResult(
    WidgetTester tester,
    Map<String, dynamic> json, {
    bool dark = false,
    String lang = 'es',
    ResultTab tab = ResultTab.summary,
    List<Category> categories = const [
      Category(id: 'cat1', name: 'Super'),
      Category(id: 'cat2', name: 'Farmacia'),
    ],
  }) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ActiveLocale.set(Locale(lang));
    S.current = ActiveLocale.strings;
    repo.detailJson = json;
    catalog = CatalogController(
      categories: FakeCategoryRepository(categories),
      merchants: merchants,
    );
    await catalog.load();
    final c = ResultController(
      repository: repo,
      catalog: catalog,
      navigator: nav,
      initial: VerificationMapper.detail(json),
    )..onInit();
    c.setTab(tab);
    Get.put<ResultController>(c);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: Locale(lang),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const ResultPage(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    return c;
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(ResultPage)));

  group('claim entry', () {
    testWidgets('underpaid offers the claim and opens the claim route', (
      tester,
    ) async {
      await pumpResult(tester, verificationJson());
      expect(find.byKey(const Key('result-claim')), findsOneWidget);
      expect(find.text('Reclamar al banco'), findsOneWidget);
      await tester.tap(find.byKey(const Key('result-claim')));
      expect(nav.pushed, [Routes.claim]);
      expect((nav.pushedArgs.single as Verification).id, 'v1');
    });

    testWidgets('the English label', (tester) async {
      await pumpResult(tester, verificationJson(), lang: 'en');
      expect(find.text('Claim from your bank'), findsOneWidget);
    });

    testWidgets('overpaid and match do not offer it', (tester) async {
      await pumpResult(tester, ficohsaCompletedJson());
      expect(find.byKey(const Key('result-claim')), findsNothing);
      await pumpResult(
        tester,
        verificationJson(verdict: 'MATCH')..['difference'] = '0',
      );
      expect(find.byKey(const Key('result-claim')), findsNothing);
    });
  });

  group('verdict variants (light/dark, ES/EN)', () {
    final variants = <String, Map<String, dynamic>>{
      'underpaid': verificationJson(),
      'overpaid': ficohsaCompletedJson(),
      'match': verificationJson(verdict: 'MATCH')..['difference'] = '0',
    };
    for (final dark in [false, true]) {
      for (final lang in ['es', 'en']) {
        for (final e in variants.entries) {
          testWidgets('${e.key} (${dark ? 'dark' : 'light'} $lang)', (
            tester,
          ) async {
            await pumpResult(tester, e.value, dark: dark, lang: lang);
            final l10n = l10nOf(tester);
            final (pill, title) = switch (e.key) {
              'underpaid' => (
                l10n.verdictPillUnderpaid,
                l10n.resultTitleUnderpaid,
              ),
              'overpaid' => (
                l10n.verdictPillOverpaid,
                l10n.resultTitleOverpaid,
              ),
              _ => (l10n.verdictPillMatch, l10n.resultTitleMatch),
            };
            expect(find.text(pill), findsOneWidget);
            expect(find.text(title), findsOneWidget);
            expect(find.text(l10n.expectedLabel), findsOneWidget);
            expect(find.text(l10n.reportedByBank), findsOneWidget);
            expect(find.byKey(const Key('verdict-card')), findsOneWidget);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    testWidgets('underpaid shows the missing amount and expected/reported', (
      tester,
    ) async {
      await pumpResult(tester, verificationJson());
      final l10n = l10nOf(tester);
      expect(find.text('MXN 58.00'), findsWidgets); // expected
      expect(find.text('MXN 40.00'), findsWidgets); // reported
      expect(find.text(l10n.resultNoteUnderpaid), findsOneWidget);
      expect(
        find.text('BBVA 4321'.replaceAll('BBVA', 'Daily •••• ')),
        findsNothing,
      );
    });

    testWidgets('overpaid is in the reward currency with the equivalence', (
      tester,
    ) async {
      await pumpResult(tester, ficohsaCompletedJson());
      expect(find.text('USD 22.68'), findsOneWidget);
      expect(find.text('USD 42.00'), findsWidgets);
      expect(find.text('+USD 19.32'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('verdict-card')),
          matching: find.textContaining('HNL 589.61'),
        ),
        findsOneWidget,
      );
      // Breakdown stays in the card currency.
      expect(find.textContaining('HNL 1,100.00'), findsOneWidget);
    });

    testWidgets('same currency: no equivalence line', (tester) async {
      await pumpResult(tester, verificationJson());
      expect(find.textContaining('Equivale'), findsNothing);
      expect(find.textContaining('1 USD ='), findsNothing);
    });

    testWidgets('match states the tolerance', (tester) async {
      await pumpResult(
        tester,
        verificationJson(verdict: 'MATCH')..['difference'] = '-0.5',
      );
      final l10n = l10nOf(tester);
      expect(
        find.text(l10n.resultNoteMatch('MXN 0.50', 'MXN 1.00')),
        findsOneWidget,
      );
    });
  });

  group('summary tab', () {
    testWidgets('one collapsible notice with Spanish texts', (tester) async {
      final c = await pumpResult(tester, _bacJson());
      final l10n = l10nOf(tester);
      expect(find.byType(CollapsibleWarning), findsOneWidget);
      expect(find.text(l10n.noticeCount(4)), findsOneWidget);
      expect(find.text(l10n.warnNoExchangeRate), findsOneWidget);
      expect(find.text(l10n.warnLast4), findsOneWidget);
      expect(find.text(l10n.warnCumulative), findsOneWidget);
      expect(find.text('Texto del servidor'), findsOneWidget);
      // Hidden codes and the server's English text never show.
      expect(find.text('no explanation'), findsNothing);
      expect(find.text('mismatch'), findsNothing);
      // The action for the missing rate reopens the confirmation.
      await tester.tap(find.text(l10n.warnActionAddRate));
      await tester.pump();
      expect(nav.pushedForResult, ['/confirm-rates']);
      expect(c.tab.value, ResultTab.summary);
    });

    testWidgets('explanation, breakdown, program and recalculate', (
      tester,
    ) async {
      await pumpResult(tester, verificationJson());
      final l10n = l10nOf(tester);
      expect(find.byKey(const Key('explanation-card')), findsOneWidget);
      expect(find.text(l10n.explanationTitle.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.resultByCategory.toUpperCase()), findsOneWidget);
      expect(find.byKey(const Key('loyalty-table')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('recalculate-button')));
      await tester.tap(find.byKey(const Key('recalculate-button')));
      await tester.pump();
      expect(nav.pushedForResult, ['/confirm-rates']);
    });

    testWidgets('header names the card and the period', (tester) async {
      await pumpResult(tester, verificationJson());
      expect(find.textContaining('BBVA •••• 4321'), findsOneWidget);
      expect(find.textContaining('2 movimientos'), findsOneWidget);
    });

    testWidgets('stale banner offers a retry', (tester) async {
      final c = await pumpResult(tester, verificationJson());
      repo.confirmErrors.add(const AppException(kind: AppErrorKind.network));
      await c.changeCategory(c.verification.value!.transactions[1], 'cat1');
      await tester.pump();
      expect(find.byKey(const Key('stale-banner')), findsOneWidget);
      await tester.tap(find.text(l10nOf(tester).recalcAction));
      await tester.pump();
      expect(c.stale.value, isFalse);
      expect(find.byKey(const Key('stale-banner')), findsNothing);
    });

    testWidgets('a result not computed yet asks to confirm the rates', (
      tester,
    ) async {
      await pumpResult(tester, awaitingVerificationJson());
      final l10n = l10nOf(tester);
      expect(find.text(l10n.resultNotConfirmed), findsOneWidget);
      await tester.tap(find.byKey(const Key('result-confirm')));
      await tester.pump();
      expect(nav.pushedForResult, ['/confirm-rates']);
    });
  });

  group('categories tab', () {
    testWidgets('applied rates, currency subtotals and the programs', (
      tester,
    ) async {
      await pumpResult(tester, _bacJson(), tab: ResultTab.categories);
      final l10n = l10nOf(tester);
      expect(find.byKey(const Key('applied-rates-card')), findsOneWidget);
      expect(find.text(l10n.rateBaseTitle), findsOneWidget);
      expect(find.byKey(const Key('currency-HNL')), findsOneWidget);
      expect(find.byKey(const Key('currency-USD')), findsOneWidget);
      expect(find.text(l10n.currencyExcluded(1)), findsOneWidget);
      expect(find.text('PUNTOS BAC'), findsOneWidget);
      expect(find.text('CASH BAC'), findsOneWidget);
      expect(find.byKey(const Key('audited-label')), findsOneWidget);
      expect(find.byKey(const Key('cumulative-chip')), findsOneWidget);
      expect(find.text('900 pts'), findsOneWidget);
    });

    testWidgets('shows the applied reward exchange rate', (tester) async {
      await pumpResult(
        tester,
        ficohsaCompletedJson(),
        tab: ResultTab.categories,
      );
      final l10n = l10nOf(tester);
      expect(
        find.descendant(
          of: find.byKey(const Key('reward-rate-detail')),
          matching: find.text('1 USD = 25.9969 HNL'),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.rewardRateUserEntered), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('loyalty-table')),
          matching: find.text('USD 42.00'),
        ),
        findsOneWidget,
      );
    });
  });

  group('movements tab', () {
    testWidgets('filter with 4 options and counters', (tester) async {
      await pumpResult(tester, _bacJson(), tab: ResultTab.movements);
      final l10n = l10nOf(tester);
      for (final label in [
        l10n.filterAll,
        l10n.filterCounted,
        l10n.filterUncounted,
        l10n.filterExcluded,
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      Finder count(String key) => find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(Text),
      );
      expect(tester.widgetList<Text>(count('filter-all')).map((t) => t.data), [
        l10n.filterAll,
        '4',
      ]);
      expect(
        tester.widgetList<Text>(count('filter-counted')).map((t) => t.data),
        [l10n.filterCounted, '1'],
      );
      expect(
        tester.widgetList<Text>(count('filter-uncounted')).map((t) => t.data),
        [l10n.filterUncounted, '1'],
      );
      expect(
        tester.widgetList<Text>(count('filter-excluded')).map((t) => t.data),
        [l10n.filterExcluded, '2'],
      );
      expect(find.byType(MovementRow), findsNWidgets(4));

      await tester.tap(find.byKey(const Key('filter-excluded')));
      await tester.pump();
      expect(find.byType(MovementRow), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('filter-uncounted')));
      await tester.pump();
      expect(find.byType(MovementRow), findsOneWidget);
      expect(find.text('Comidas Especiales Eberso'), findsOneWidget);
      // Bank's original text below the clean name.
      expect(find.text('COMIDAS ESPECIALES EBERSO'), findsOneWidget);
    });

    testWidgets('green, red and grey rows carry icon and text', (tester) async {
      await pumpResult(tester, _bacJson(), tab: ResultTab.movements);
      final l10n = l10nOf(tester);
      expect(
        find.textContaining('${l10n.movInCategory('Super', '5%')} · IA'),
        findsOneWidget,
      );
      expect(find.text(l10n.movUncounted('5%')), findsOneWidget);
      expect(
        find.text(l10n.movExcluded(l10n.movReasonPayment)),
        findsOneWidget,
      );
      expect(
        find.text(l10n.movExcluded(l10n.movReasonNoRate('USD'))),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_rounded), findsWidgets);
      expect(find.byIcon(Icons.priority_high_rounded), findsWidgets);
      expect(find.byIcon(Icons.remove_rounded), findsWidgets);
      // "Assign category" only on the red row.
      expect(find.byKey(const Key('assign-1')), findsOneWidget);
      expect(find.byKey(const Key('assign-0')), findsNothing);
      expect(find.byKey(const Key('assign-2')), findsNothing);
      expect(find.text(l10n.noTransactionsMatch), findsNothing);
      expect(find.text('Supermercado'), findsOneWidget); // AI reason
    });

    testWidgets('credit lines are labelled and the bank hint shows', (
      tester,
    ) async {
      await pumpResult(
        tester,
        ficohsaCompletedJson(),
        tab: ResultTab.movements,
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.creditPayment), findsOneWidget);
      expect(find.text(l10n.creditRefund), findsOneWidget);
      expect(find.text(l10n.creditOther), findsOneWidget);
      expect(
        find.text(l10n.bankConsiders('Restaurantes y Comida rápida')),
        findsOneWidget,
      );
    });

    testWidgets('empty filter says there is nothing to show', (tester) async {
      final c = await pumpResult(
        tester,
        verificationJson(),
        tab: ResultTab.movements,
      );
      await tester.tap(find.byKey(const Key('filter-excluded')));
      await tester.pump();
      expect(c.filter.value, TransactionFilter.excluded);
      expect(find.text(l10nOf(tester).noTransactionsMatch), findsOneWidget);
    });
  });

  group('change category sheet', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('assign-1')));
      await tester.pumpAndSettle();
    }

    testWidgets('lists the categories with the card rate and a switch', (
      tester,
    ) async {
      await pumpResult(tester, _bacJson(), tab: ResultTab.movements);
      await openSheet(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.changeSheetQuestion), findsOneWidget);
      expect(find.byKey(const Key('pick-cat1')), findsOneWidget);
      expect(find.text('5%'), findsOneWidget); // Super has a rule
      expect(find.text(l10n.changeSheetNoRate), findsOneWidget); // Farmacia
      expect(find.text(l10n.changeSheetBase('1%')), findsOneWidget);
      expect(find.text(l10n.rememberTitle), findsOneWidget);
      expect(find.text(l10n.rememberOff), findsOneWidget);
      // Nothing chosen yet: cannot apply.
      expect(
        tester
            .widget<AppButton>(find.byKey(const Key('change-apply')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('without remember only this verification changes', (
      tester,
    ) async {
      final c = await pumpResult(tester, _bacJson(), tab: ResultTab.movements);
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('pick-cat2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('change-apply')));
      await tester.pumpAndSettle();
      expect(repo.corrections.single.categoryId, 'cat2');
      expect(repo.corrections.single.index, 1);
      expect(repo.confirmRequests, hasLength(1));
      expect(merchants.calls, isEmpty);
      expect(c.notice.value?.message, S.categoryChanged);
      expect(find.byKey(const Key('result-notice')), findsOneWidget);
    });

    testWidgets('with remember the merchant is created too', (tester) async {
      final c = await pumpResult(tester, _bacJson(), tab: ResultTab.movements);
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('pick-cat2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('remember-switch')));
      await tester.pump();
      expect(find.text(l10nOf(tester).rememberOn), findsOneWidget);
      await tester.tap(find.byKey(const Key('change-apply')));
      await tester.pumpAndSettle();
      expect(repo.corrections.single.categoryId, 'cat2');
      expect(
        merchants.calls.single,
        'create:Comidas Especiales Eberso:cat2:COMIDAS ESPECIALES EBERSO',
      );
      expect(c.notice.value?.message, S.current.categoryChangedRemembered);
    });

    testWidgets('"no category" cannot be remembered', (tester) async {
      await pumpResult(tester, _bacJson(), tab: ResultTab.movements);
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('pick-none')));
      await tester.pump();
      final sw = tester.widget<Switch>(
        find.byKey(const Key('remember-switch')),
      );
      expect(sw.onChanged, isNull);
      expect(find.text(l10nOf(tester).rememberNeedsCategory), findsOneWidget);
    });

    testWidgets('a green row can be moved too', (tester) async {
      await pumpResult(tester, _bacJson(), tab: ResultTab.movements);
      await tester.tap(find.byKey(const Key('tx-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pick-cat1')), findsOneWidget);
    });

    testWidgets('without categories it sends the user to create one', (
      tester,
    ) async {
      await pumpResult(
        tester,
        _bacJson(),
        tab: ResultTab.movements,
        categories: const [],
      );
      await openSheet(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.noCategoriesToAssign), findsOneWidget);
      expect(find.byKey(const Key('change-apply')), findsOneWidget);
    });
  });
}
