import 'dart:async';

import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/l10n/active_locale.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/core/utils/cached.dart';
import 'package:cashback_audit/features/cards/data/card_mapper.dart';
import 'package:cashback_audit/features/cards/domain/card_entities.dart';
import 'package:cashback_audit/features/cards/domain/card_repository.dart';
import 'package:cashback_audit/features/cards/presentation/card_form_controller.dart';
import 'package:cashback_audit/features/cards/presentation/card_form_page.dart';
import 'package:cashback_audit/features/cards/presentation/cards_controller.dart';
import 'package:cashback_audit/features/cards/presentation/widgets/currency_picker.dart';
import 'package:cashback_audit/features/cards/presentation/widgets/rule_editor.dart';
import 'package:cashback_audit/features/categories/domain/catalog_entities.dart';
import 'package:cashback_audit/features/categories/presentation/catalog_controller.dart';
import 'package:cashback_audit/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/fixtures.dart';
import '../categories/fake_catalog.dart';

class _CardRepo implements CardRepository {
  final saved = <CardDraft>[];
  final deleted = <String>[];
  Object? error;

  @override
  Future<Cached<List<CreditCard>>> getCards() async => const Cached([]);
  @override
  Future<CreditCard> createCard(CardDraft draft) async {
    if (error != null) throw error!;
    saved.add(draft);
    return CardMapper.fromJson(cardJson());
  }

  @override
  Future<CreditCard> updateCard(String id, CardDraft draft) async {
    saved.add(draft);
    return CardMapper.fromJson(cardJson());
  }

  @override
  Future<void> deleteCard(String id) async {
    if (error != null) throw error!;
    deleted.add(id);
  }
}

const _cats = [
  Category(id: 'cat1', name: 'Super'),
  Category(id: 'cat2', name: 'Gasolina'),
];

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    await initializeDateFormatting('en_US');
  });
  tearDown(Get.reset);

  late _CardRepo repo;
  late CardFormController controller;

  /// Mounts the real container page (so the whole form is exercised).
  Future<void> pumpPage(
    WidgetTester tester, {
    CreditCard? editing,
    bool dark = false,
    String lang = 'es',
    List<String> userCurrencies = const [],
    String? defaultCurrency,
  }) async {
    tester.view.physicalSize = const Size(390, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ActiveLocale.set(Locale(lang));
    S.current = ActiveLocale.strings;
    repo = _CardRepo();
    final catalog = CatalogController(
      categories: FakeCategoryRepository(_cats),
      merchants: FakeMerchantRepository(),
    );
    await catalog.load();
    controller = Get.put(
      CardFormController(
        repository: repo,
        cards: CardsController(repo),
        catalog: catalog,
        editing: editing,
        userCurrencies: userCurrencies,
        defaultCurrency: defaultCurrency,
      ),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: Locale(lang),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const Scaffold(),
      ),
    );
    unawaited(Get.to<void>(() => const CardFormPage()));
    await tester.pumpAndSettle();
  }

  Future<void> fillBasics(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('field-alias')), 'Daily');
    await tester.enterText(find.byKey(const Key('field-bank')), 'BBVA');
    await tester.enterText(find.byKey(const Key('field-last4')), '4321');
    await tester.enterText(find.byKey(const Key('field-base-rate')), '1,5');
  }

  Future<void> openAdvanced(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('advanced-toggle')));
    await tester.pumpAndSettle();
  }

  group('RuleEditor', () {
    Widget host(Widget child) => MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

    testWidgets('adds, edits and removes rules; cap is opt-in', (tester) async {
      final rules = <RuleDraft>[RuleDraft(categoryId: 'cat1')];
      var added = 0;
      int? removed;
      await tester.pumpWidget(
        host(
          RuleEditor(
            rules: rules,
            categories: _cats,
            capSuffix: 'MXN',
            onAdd: () => added++,
            onRemove: (i) => removed = i,
            onCategoryChanged: (_, _) {},
            errors: const {0: 'Tasa inválida'},
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('rule-rate-0')), '5');
      expect(rules.first.rate.text, '5');
      expect(find.text('Tasa inválida'), findsOneWidget);
      expect(find.byKey(const Key('rule-cap-0')), findsNothing);
      await tester.tap(find.byKey(const Key('add-cap-0')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('rule-cap-0')), '500');
      expect(rules.first.cap.text, '500');
      await tester.tap(find.byKey(const Key('add-rule')));
      expect(added, 1);
      await tester.tap(find.byKey(const Key('remove-rule-0')));
      expect(removed, 0);
    });

    testWidgets('a rule with a cap shows it right away', (tester) async {
      await tester.pumpWidget(
        host(
          RuleEditor(
            rules: [RuleDraft(categoryId: 'cat1', cap: '200')],
            categories: _cats,
            capSuffix: 'MXN',
            onAdd: () {},
            onRemove: (_) {},
            onCategoryChanged: (_, _) {},
          ),
        ),
      );
      expect(find.byKey(const Key('rule-cap-0')), findsOneWidget);
    });

    testWidgets('explains when there are no categories', (tester) async {
      await tester.pumpWidget(
        host(
          RuleEditor(
            rules: const [],
            categories: const [],
            capSuffix: 'MXN',
            onAdd: () {},
            onRemove: (_) {},
            onCategoryChanged: (_, _) {},
          ),
        ),
      );
      expect(find.byKey(const Key('rules-need-categories')), findsOneWidget);
      final add = tester.widget<TextButton>(find.byKey(const Key('add-rule')));
      expect(add.onPressed, isNull);
    });
  });

  test('suggestedCurrencies puts the user currencies first, deduped', () {
    expect(suggestedCurrencies(['hnl', 'USD']).take(3), ['HNL', 'USD', 'EUR']);
    expect(suggestedCurrencies(const [], max: 2), ['USD', 'EUR']);
  });

  group('basic form', () {
    testWidgets('shows basics and keeps advanced options collapsed', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(find.text(S.newCard), findsOneWidget);
      expect(find.byKey(const Key('field-alias')), findsOneWidget);
      expect(find.byKey(const Key('unit-selector')), findsOneWidget);
      expect(find.byKey(const Key('add-rule')), findsOneWidget);
      expect(find.byKey(const Key('field-currency')), findsNothing);
      expect(find.byKey(const Key('delete-card')), findsNothing);
      await openAdvanced(tester);
      expect(find.byKey(const Key('field-currency')), findsOneWidget);
      expect(find.byKey(const Key('network-Visa')), findsOneWidget);
      // Creating: nothing to delete.
      expect(find.byKey(const Key('delete-card')), findsNothing);
    });

    testWidgets('the preview band follows alias and last 4', (tester) async {
      await pumpPage(tester);
      await tester.enterText(find.byKey(const Key('field-alias')), 'BAC Cash');
      await tester.enterText(find.byKey(const Key('field-last4')), '4821');
      await tester.pump();
      expect(find.text('BAC Cash'), findsWidgets);
      expect(find.text('•••• 4821'), findsOneWidget);
    });

    testWidgets('blocks invalid input and never builds a draft', (
      tester,
    ) async {
      await pumpPage(tester);
      await tester.enterText(find.byKey(const Key('field-last4')), '12');
      await tester.tap(find.byKey(const Key('submit-card')));
      await tester.pumpAndSettle();
      expect(find.text(S.fieldRequired), findsWidgets);
      expect(find.text(S.last4Invalid), findsOneWidget);
      expect(repo.saved, isEmpty);
    });

    testWidgets('saves a valid card with a rule through the UI', (
      tester,
    ) async {
      await pumpPage(tester);
      await fillBasics(tester);
      await tester.tap(find.byKey(const Key('add-rule')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('rule-rate-0')), '5');
      await tester.tap(find.byKey(const Key('add-cap-0')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('rule-cap-0')), '500');
      await tester.tap(find.byKey(const Key('submit-card')));
      await tester.pumpAndSettle();
      final d = repo.saved.single;
      expect(d.alias, 'Daily');
      expect(d.baseRatePercent.toString(), '1.5');
      expect(d.rules.single.categoryId, 'cat1');
      expect(d.rules.single.ratePercent.toString(), '5');
      expect(d.rules.single.monthlyCap.toString(), '500');
    });

    testWidgets('points unit asks for the points factor', (tester) async {
      await pumpPage(tester);
      expect(find.byKey(const Key('field-points-factor')), findsNothing);
      await tester.tap(find.text(S.current.cardUnitPoints));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('field-points-factor')), findsOneWidget);
      await openAdvanced(tester);
      // Points are not paid in a currency.
      expect(find.byKey(const Key('field-reward-currency')), findsNothing);
    });

    testWidgets('rejects duplicate categories and missing rates', (
      tester,
    ) async {
      await pumpPage(tester);
      await fillBasics(tester);
      controller.rules.addAll([
        RuleDraft(categoryId: 'cat1', rate: '5'),
        RuleDraft(categoryId: 'cat1', rate: '3'),
        RuleDraft(categoryId: 'cat2'),
      ]);
      expect(controller.buildDraft(), isNull);
      expect(controller.ruleErrors[1], S.ruleDuplicateCategory);
      expect(controller.ruleErrors[2], S.numberInvalid);
      expect(controller.ruleErrors.containsKey(0), isFalse);
      await tester.pumpAndSettle();
      expect(find.text(S.ruleDuplicateCategory), findsOneWidget);
    });

    testWidgets('API failure shows a mapped message', (tester) async {
      await pumpPage(tester);
      await fillBasics(tester);
      repo.error = const AppException(kind: AppErrorKind.network);
      await tester.tap(find.byKey(const Key('submit-card')));
      await tester.pumpAndSettle();
      expect(find.text(S.errNetwork), findsOneWidget);
    });
  });

  group('advanced options', () {
    testWidgets('network chips pick, switch and clear the network', (
      tester,
    ) async {
      await pumpPage(tester);
      await fillBasics(tester);
      await openAdvanced(tester);
      await tester.tap(find.byKey(const Key('network-Visa')));
      await tester.pump();
      expect(controller.network.text, 'Visa');
      await tester.tap(find.byKey(const Key('network-Visa')));
      await tester.pump();
      expect(controller.network.text, isEmpty);
      await tester.tap(find.byKey(const Key('network-other')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('field-network')),
        'Discover',
      );
      await tester.tap(find.byKey(const Key('submit-card')));
      await tester.pumpAndSettle();
      expect(repo.saved.single.network, 'Discover');
    });

    testWidgets('reward program is optional and trimmed', (tester) async {
      await pumpPage(tester);
      await fillBasics(tester);
      await openAdvanced(tester);
      await tester.enterText(
        find.byKey(const Key('field-reward-program')),
        '  CASH BAC CREDOMATIC ',
      );
      await tester.tap(find.byKey(const Key('submit-card')));
      await tester.pumpAndSettle();
      expect(repo.saved.single.rewardProgramName, 'CASH BAC CREDOMATIC');
    });

    for (final dark in [false, true]) {
      for (final lang in ['es', 'en']) {
        testWidgets('how the bank reports the cashback: default and choice '
            '(${dark ? 'dark' : 'light'} $lang)', (tester) async {
          await pumpPage(tester, dark: dark, lang: lang);
          await fillBasics(tester);
          await openAdvanced(tester);
          final l10n = AppLocalizations.of(
            tester.element(find.byType(CardFormPage)),
          );
          await tester.ensureVisible(
            find.byKey(const Key('reward-reporting-field')),
          );
          expect(
            find.textContaining(l10n.cardReportingLabel, findRichText: true),
            findsOneWidget,
          );
          expect(find.text(l10n.cardReportingAuto), findsOneWidget);
          expect(find.text(l10n.cardReportingMonthly), findsOneWidget);
          expect(find.text(l10n.cardReportingCumulative), findsOneWidget);
          expect(controller.rewardReporting.value, RewardReporting.auto);

          await tester.tap(find.byKey(const Key('reporting-cumulative')));
          await tester.pumpAndSettle();
          expect(controller.rewardReporting.value, RewardReporting.cumulative);
          await tester.tap(find.byKey(const Key('submit-card')));
          await tester.pumpAndSettle();
          expect(repo.saved.single.rewardReporting, RewardReporting.cumulative);
        });
      }
    }

    testWidgets('editing a card loads its reporting setting', (tester) async {
      await pumpPage(
        tester,
        editing: CardMapper.fromJson({
          ...cardJson(),
          'rewardReporting': 'MONTHLY',
        }),
      );
      expect(controller.rewardReporting.value, RewardReporting.monthly);
    });

    testWidgets('reward currency: detect, chips and validated free entry', (
      tester,
    ) async {
      await pumpPage(tester);
      await fillBasics(tester);
      await openAdvanced(tester);
      expect(find.text(S.current.cardRewardCurrencyNote), findsOneWidget);
      // Invalid free entry blocks the form.
      await tester.enterText(
        find.byKey(const Key('field-reward-currency')),
        'US',
      );
      await tester.tap(find.byKey(const Key('submit-card')));
      await tester.pumpAndSettle();
      expect(find.text(S.currencyInvalid), findsOneWidget);
      expect(repo.saved, isEmpty);
      // A common code is one tap away; tapping it again goes back to detect.
      await tester.tap(find.byKey(const Key('reward-currency-USD')));
      await tester.pump();
      expect(controller.rewardCurrency.text, 'USD');
      await tester.tap(find.byKey(const Key('reward-currency-detect')));
      await tester.pump();
      expect(controller.rewardCurrency.text, isEmpty);
      await tester.tap(find.byKey(const Key('reward-currency-USD')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('submit-card')));
      await tester.pumpAndSettle();
      expect(repo.saved.last.rewardCurrency, 'USD');
    });

    testWidgets('the user currencies are suggested first', (tester) async {
      await pumpPage(
        tester,
        userCurrencies: const ['HNL', 'GBP'],
        defaultCurrency: 'HNL',
      );
      expect(controller.currency.text, 'HNL');
      await openAdvanced(tester);
      expect(find.byKey(const Key('currency-GBP')), findsOneWidget);
      expect(find.byKey(const Key('reward-currency-GBP')), findsOneWidget);
      final gbp = tester.getTopLeft(
        find.byKey(const Key('reward-currency-GBP')),
      );
      final usd = tester.getTopLeft(
        find.byKey(const Key('reward-currency-USD')),
      );
      expect(
        gbp.dx < usd.dx || gbp.dy < usd.dy,
        isTrue,
        reason: 'GBP (user) must come before USD (common)',
      );
      await tester.tap(find.byKey(const Key('currency-GBP')));
      await tester.pump();
      expect(controller.currency.text, 'GBP');
    });

    testWidgets('an invalid hidden field opens the section on save', (
      tester,
    ) async {
      await pumpPage(tester);
      await fillBasics(tester);
      controller.currency.text = 'XX';
      expect(controller.advancedOpen.value, isFalse);
      await tester.tap(find.byKey(const Key('submit-card')));
      await tester.pumpAndSettle();
      expect(controller.advancedOpen.value, isTrue);
      expect(find.text(S.currencyInvalid), findsOneWidget);
      expect(repo.saved, isEmpty);
    });
  });

  group('delete', () {
    final card = CardMapper.fromJson(cardJson());

    testWidgets('confirms, then deletes the card being edited', (tester) async {
      await pumpPage(tester, editing: card);
      expect(find.text(S.editCard), findsOneWidget);
      await openAdvanced(tester);
      await tester.tap(find.byKey(const Key('delete-card')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete-card-confirm')));
      await tester.pumpAndSettle();
      expect(repo.deleted, ['c1']);
    });

    testWidgets('cancelling keeps the card', (tester) async {
      await pumpPage(tester, editing: card);
      await openAdvanced(tester);
      await tester.tap(find.byKey(const Key('delete-card')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-card-cancel')));
      await tester.pumpAndSettle();
      expect(repo.deleted, isEmpty);
      expect(find.byKey(const Key('delete-card')), findsOneWidget);
    });

    testWidgets('a failed delete shows the mapped error', (tester) async {
      await pumpPage(tester, editing: card);
      repo.error = const AppException(kind: AppErrorKind.network);
      await openAdvanced(tester);
      await tester.tap(find.byKey(const Key('delete-card')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-card-confirm')));
      await tester.pumpAndSettle();
      expect(find.text(S.errNetwork), findsOneWidget);
    });
  });

  group('theme and language smoke', () {
    for (final dark in [false, true]) {
      for (final lang in ['es', 'en']) {
        testWidgets('renders both sections (dark=$dark, $lang)', (
          tester,
        ) async {
          await pumpPage(
            tester,
            editing: CardMapper.fromJson(cardJson()),
            dark: dark,
            lang: lang,
          );
          expect(tester.takeException(), isNull);
          await openAdvanced(tester);
          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('delete-card')), findsOneWidget);
          expect(
            find.text(lang == 'es' ? 'Opciones avanzadas' : 'Advanced options'),
            findsOneWidget,
          );
        });
      }
    }

    testWidgets('fits a 320 px wide phone', (tester) async {
      await pumpPage(tester, editing: CardMapper.fromJson(cardJson()));
      tester.view.physicalSize = const Size(320, 2000);
      await tester.pumpAndSettle();
      await openAdvanced(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
