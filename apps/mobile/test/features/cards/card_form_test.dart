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
import 'package:cashback_audit/core/ui/ui.dart';
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
    tester.view.physicalSize = const Size(390, 1800);
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

    testWidgets('the category row shows the full name and opens the picker', (
      tester,
    ) async {
      const long =
          'Restaurantes, cafeterías y servicios de comida rápida a domicilio';
      String? changed;
      final cats = [
        const Category(id: 'a', name: long),
        const Category(id: 'b', name: 'Super'),
      ];
      await tester.pumpWidget(
        host(
          RuleEditor(
            rules: [RuleDraft(categoryId: 'a', rate: '3')],
            categories: cats,
            capSuffix: 'MXN',
            onAdd: () {},
            onRemove: (_) {},
            onCategoryChanged: (_, id) => changed = id,
          ),
        ),
      );
      final name = tester.widget<Text>(find.text(long));
      expect(name.overflow, isNull);
      await tester.tap(find.byKey(const Key('rule-category-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('category-picker')), findsOneWidget);
      await tester.tap(find.byKey(const Key('category-option-b')));
      await tester.pumpAndSettle();
      expect(changed, 'b');
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

  Future<void> fillCard(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('field-alias')), 'Daily');
    await tester.enterText(find.byKey(const Key('field-bank')), 'BBVA');
    await tester.enterText(find.byKey(const Key('field-last4')), '4321');
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('step-next')));
    await tester.pumpAndSettle();
  }

  Future<void> fillRules(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('field-base-rate')), '1,5');
  }

  /// Walks a new card to the review step with valid data.
  Future<void> reachReview(WidgetTester tester) async {
    await fillCard(tester);
    await next(tester);
    await next(tester);
    await fillRules(tester);
    await next(tester);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('submit-card')));
    await tester.pumpAndSettle();
  }

  bool onStep(WidgetTester tester, int step) =>
      tester
          .widget<StepProgress>(find.byKey(const Key('step-progress')))
          .step ==
      step + 1;

  test('suggestedCurrencies puts the user currencies first, deduped', () {
    expect(suggestedCurrencies(['hnl', 'USD']).take(3), ['HNL', 'USD', 'EUR']);
    expect(suggestedCurrencies(const [], max: 2), ['USD', 'EUR']);
  });

  group('stepper navigation', () {
    testWidgets('starts on the card step with progress and a live preview', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(find.text(S.newCard), findsOneWidget);
      expect(find.text(S.current.stepOf(1, 4)), findsOneWidget);
      expect(onStep(tester, 0), isTrue);
      expect(find.byKey(const Key('field-alias')), findsOneWidget);
      expect(find.byKey(const Key('field-currency')), findsOneWidget);
      // Back is visible but disabled on the first step.
      final back = tester.widget<OutlinedButton>(
        find.descendant(
          of: find.byKey(const Key('step-back')),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(back.onPressed, isNull);
      expect(find.byKey(const Key('step-next')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('field-alias')), 'BAC Cash');
      await tester.enterText(find.byKey(const Key('field-last4')), '4821');
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const Key('card-preview')),
          matching: find.text('BAC Cash'),
        ),
        findsOneWidget,
      );
      expect(find.text('•••• 4821'), findsOneWidget);
    });

    testWidgets('Next is blocked by an invalid step and shows its errors', (
      tester,
    ) async {
      await pumpPage(tester);
      await tester.enterText(find.byKey(const Key('field-last4')), '12');
      await next(tester);
      expect(onStep(tester, 0), isTrue);
      expect(find.text(S.fieldRequired), findsWidgets);
      expect(find.text(S.last4Invalid), findsOneWidget);
      await fillCard(tester);
      await next(tester);
      expect(onStep(tester, 1), isTrue);
      expect(find.byKey(const Key('unit-selector')), findsOneWidget);
    });

    testWidgets('Back returns and keeps what was typed', (tester) async {
      await pumpPage(tester);
      await fillCard(tester);
      await next(tester);
      await tester.tap(find.byKey(const Key('step-back')));
      await tester.pumpAndSettle();
      expect(onStep(tester, 0), isTrue);
      expect(find.text('Daily'), findsWidgets);
    });

    testWidgets('creating: header tabs only reach visited steps', (
      tester,
    ) async {
      await pumpPage(tester);
      await fillCard(tester);
      await next(tester);
      // Step 3 not reached yet: its tab does nothing.
      await tester.tap(find.byKey(const Key('step-tab-2')));
      await tester.pumpAndSettle();
      expect(onStep(tester, 1), isTrue);
      await tester.tap(find.byKey(const Key('step-tab-0')));
      await tester.pumpAndSettle();
      expect(onStep(tester, 0), isTrue);
      // Going forward again through a visited tab needs no re-validation.
      await tester.tap(find.byKey(const Key('step-tab-1')));
      await tester.pumpAndSettle();
      expect(onStep(tester, 1), isTrue);
    });

    testWidgets('reward step: unit, cap helper and validation', (tester) async {
      await pumpPage(tester, defaultCurrency: 'HNL');
      await fillCard(tester);
      await next(tester);
      expect(
        find.textContaining(S.current.cardRewardCapLabel, findRichText: true),
        findsOneWidget,
      );
      expect(
        find.text(S.current.cardRewardCapHelp('HNL 1,000')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('field-reward-currency')), findsOneWidget);
      expect(find.byKey(const Key('field-points-factor')), findsNothing);
      // A bad cap blocks Next.
      await tester.enterText(find.byKey(const Key('field-reward-cap')), '0');
      await next(tester);
      expect(onStep(tester, 1), isTrue);
      expect(find.text(S.capInvalid), findsOneWidget);
      // Points swap the currency for the factor and the cap unit.
      await tester.tap(find.text(S.current.cardUnitPoints));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('field-points-factor')), findsOneWidget);
      expect(find.byKey(const Key('field-reward-currency')), findsNothing);
      expect(
        find.text(S.current.cardRewardCapHelp('1,000 pts')),
        findsOneWidget,
      );
    });

    testWidgets('the cap stays in the card currency, not the reward one', (
      tester,
    ) async {
      await pumpPage(tester, defaultCurrency: 'HNL');
      await fillCard(tester);
      await next(tester);
      await tester.tap(find.byKey(const Key('reward-currency-USD')));
      await tester.pumpAndSettle();
      expect(
        find.text(S.current.cardRewardCapHelp('HNL 1,000')),
        findsOneWidget,
      );
    });

    testWidgets('categories step needs a base rate and valid rules', (
      tester,
    ) async {
      await pumpPage(tester);
      await fillCard(tester);
      await next(tester);
      await next(tester);
      expect(onStep(tester, 2), isTrue);
      await next(tester);
      expect(onStep(tester, 2), isTrue);
      expect(find.text(S.numberInvalid), findsOneWidget);
      await fillRules(tester);
      await tester.tap(find.byKey(const Key('add-rule')));
      await tester.pumpAndSettle();
      await next(tester);
      // The new rule has no rate yet.
      expect(onStep(tester, 2), isTrue);
      expect(controller.ruleErrors[0], S.numberInvalid);
      await tester.enterText(find.byKey(const Key('rule-rate-0')), '5');
      await next(tester);
      expect(onStep(tester, 3), isTrue);
    });

    testWidgets('rejects duplicate categories and missing rates', (
      tester,
    ) async {
      await pumpPage(tester);
      await reachReview(tester);
      controller.rules.addAll([
        RuleDraft(categoryId: 'cat1', rate: '5'),
        RuleDraft(categoryId: 'cat1', rate: '3'),
        RuleDraft(categoryId: 'cat2'),
      ]);
      expect(controller.buildDraft(), isNull);
      // buildDraft jumps to the step with the problem.
      expect(controller.step.value, 2);
      expect(controller.ruleErrors[1], S.ruleDuplicateCategory);
      expect(controller.ruleErrors[2], S.numberInvalid);
      expect(controller.ruleErrors.containsKey(0), isFalse);
      await tester.pumpAndSettle();
      expect(find.text(S.ruleDuplicateCategory), findsOneWidget);
    });
  });

  group('category picker in the rules step', () {
    testWidgets('chooses another category and creates a new one inline', (
      tester,
    ) async {
      await pumpPage(tester);
      await fillCard(tester);
      await next(tester);
      await next(tester);
      await tester.tap(find.byKey(const Key('add-rule')));
      await tester.pumpAndSettle();
      expect(controller.rules.single.categoryId, 'cat1');
      await tester.tap(find.byKey(const Key('rule-category-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('category-option-cat2')));
      await tester.pumpAndSettle();
      expect(controller.rules.single.categoryId, 'cat2');
      // "Create category" at the end selects the new rubro.
      await tester.tap(find.byKey(const Key('rule-category-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('category-create')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('category-new-name')),
        'Mascotas',
      );
      await tester.tap(find.byKey(const Key('category-create-confirm')));
      await tester.pumpAndSettle();
      expect(controller.rules.single.categoryId, 'new-Mascotas');
      expect(find.text('Mascotas'), findsOneWidget);
    });

    testWidgets('a category already used by another rule is not offered', (
      tester,
    ) async {
      await pumpPage(tester);
      await fillCard(tester);
      await next(tester);
      await next(tester);
      await tester.tap(find.byKey(const Key('add-rule')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-rule')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rule-category-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('category-option-cat1')), findsNothing);
      expect(find.byKey(const Key('category-option-cat2')), findsOneWidget);
    });
  });

  group('review and save', () {
    testWidgets('summarizes everything with edit links', (tester) async {
      await pumpPage(tester);
      await fillCard(tester);
      await next(tester);
      await tester.enterText(find.byKey(const Key('field-reward-cap')), '1000');
      await next(tester);
      await fillRules(tester);
      await tester.tap(find.byKey(const Key('add-rule')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('rule-rate-0')), '5');
      await next(tester);
      expect(onStep(tester, 3), isTrue);
      expect(find.text('BBVA'), findsWidgets);
      expect(find.text('1000 MXN'), findsOneWidget);
      expect(find.text('Super'), findsOneWidget);
      expect(find.text('5%'), findsOneWidget);
      // Edit link jumps back; Next from there walks on again.
      await tester.tap(find.byKey(const Key('review-edit-1')));
      await tester.pumpAndSettle();
      expect(onStep(tester, 1), isTrue);
      expect(find.byKey(const Key('delete-card')), findsNothing);
    });

    testWidgets('saves the card with the cap and no program field', (
      tester,
    ) async {
      await pumpPage(tester);
      await fillCard(tester);
      await next(tester);
      await tester.tap(find.byKey(const Key('reporting-cumulative')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('field-reward-cap')), '1000');
      await next(tester);
      await fillRules(tester);
      await tester.tap(find.byKey(const Key('add-rule')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('rule-rate-0')), '5');
      await tester.tap(find.byKey(const Key('add-cap-0')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('rule-cap-0')), '500');
      await next(tester);
      await save(tester);
      final d = repo.saved.single;
      expect(d.alias, 'Daily');
      expect(d.baseRatePercent.toString(), '1.5');
      expect(d.rewardCap.toString(), '1000');
      expect(d.rewardReporting, RewardReporting.cumulative);
      expect(d.rules.single.categoryId, 'cat1');
      expect(d.rules.single.monthlyCap.toString(), '500');
      final body = CardMapper.toRequest(d, forUpdate: false);
      expect(body['rewardCap'], '1000');
      expect(body.containsKey('rewardProgramName'), isFalse);
    });

    testWidgets('no cap means the key is not sent on create', (tester) async {
      await pumpPage(tester);
      await reachReview(tester);
      await save(tester);
      final d = repo.saved.single;
      expect(d.rewardCap, isNull);
      expect(
        CardMapper.toRequest(d, forUpdate: false),
        isNot(contains('rewardCap')),
      );
    });

    testWidgets('network and reward currency choices reach the payload', (
      tester,
    ) async {
      await pumpPage(tester);
      await fillCard(tester);
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
      await next(tester);
      await tester.tap(find.byKey(const Key('reward-currency-USD')));
      await tester.pump();
      expect(controller.rewardCurrency.text, 'USD');
      await tester.tap(find.byKey(const Key('reward-currency-detect')));
      await tester.pump();
      expect(controller.rewardCurrency.text, isEmpty);
      await tester.tap(find.byKey(const Key('reward-currency-USD')));
      await tester.pump();
      await next(tester);
      await fillRules(tester);
      await next(tester);
      await save(tester);
      expect(repo.saved.single.network, 'Discover');
      expect(repo.saved.single.rewardCurrency, 'USD');
    });

    testWidgets('an invalid reward currency blocks the reward step', (
      tester,
    ) async {
      await pumpPage(tester);
      await fillCard(tester);
      await next(tester);
      await tester.enterText(
        find.byKey(const Key('field-reward-currency')),
        'US',
      );
      await next(tester);
      expect(onStep(tester, 1), isTrue);
      expect(find.text(S.currencyInvalid), findsOneWidget);
    });

    testWidgets('points card sends the factor and no reward currency', (
      tester,
    ) async {
      await pumpPage(tester);
      await fillCard(tester);
      await next(tester);
      await tester.tap(find.text(S.current.cardUnitPoints));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('field-points-factor')), '2');
      await next(tester);
      await fillRules(tester);
      await next(tester);
      await save(tester);
      final d = repo.saved.single;
      expect(d.rewardUnit, RewardUnit.points);
      expect(d.pointsPerCurrencyUnit.toString(), '2');
      expect(d.rewardCurrency, isNull);
    });

    testWidgets('API failure shows a mapped message on the review', (
      tester,
    ) async {
      await pumpPage(tester);
      await reachReview(tester);
      repo.error = const AppException(kind: AppErrorKind.network);
      await save(tester);
      expect(find.text(S.errNetwork), findsOneWidget);
      expect(onStep(tester, 3), isTrue);
    });

    testWidgets('the user currencies are suggested first', (tester) async {
      await pumpPage(
        tester,
        userCurrencies: const ['HNL', 'GBP'],
        defaultCurrency: 'HNL',
      );
      expect(controller.currency.text, 'HNL');
      expect(find.byKey(const Key('currency-GBP')), findsOneWidget);
      await tester.tap(find.byKey(const Key('currency-GBP')));
      await tester.pump();
      expect(controller.currency.text, 'GBP');
      await fillCard(tester);
      await next(tester);
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
    });
  });

  group('editing', () {
    final card = CardMapper.fromJson({
      ...cardJson(rewardProgramName: 'CASH BAC'),
      'rewardCap': '800',
      'rewardReporting': 'MONTHLY',
    });

    testWidgets('loads the card and lets the tabs jump anywhere', (
      tester,
    ) async {
      await pumpPage(tester, editing: card);
      expect(find.text(S.editCard), findsOneWidget);
      expect(controller.rewardReporting.value, RewardReporting.monthly);
      expect(controller.rewardCap.text, '800');
      await tester.tap(find.byKey(const Key('step-tab-2')));
      await tester.pumpAndSettle();
      expect(onStep(tester, 2), isTrue);
      expect(find.byKey(const Key('rule-rate-0')), findsOneWidget);
      await tester.tap(find.byKey(const Key('step-tab-3')));
      await tester.pumpAndSettle();
      expect(onStep(tester, 3), isTrue);
      await tester.tap(find.byKey(const Key('step-tab-1')));
      await tester.pumpAndSettle();
      expect(onStep(tester, 1), isTrue);
      expect(find.byKey(const Key('reporting-monthly')), findsOneWidget);
    });

    testWidgets('saves keeping the program the card already has', (
      tester,
    ) async {
      await pumpPage(tester, editing: card);
      await tester.tap(find.byKey(const Key('step-tab-3')));
      await tester.pumpAndSettle();
      await save(tester);
      final d = repo.saved.single;
      expect(d.rewardProgramName, 'CASH BAC');
      expect(d.rewardCap.toString(), '800');
      final body = CardMapper.toRequest(d, forUpdate: true);
      expect(body['rewardCap'], '800');
    });

    testWidgets('clearing the cap sends null on update', (tester) async {
      await pumpPage(tester, editing: card);
      await tester.tap(find.byKey(const Key('step-tab-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('field-reward-cap')), '');
      await tester.tap(find.byKey(const Key('step-tab-3')));
      await tester.pumpAndSettle();
      await save(tester);
      final body = CardMapper.toRequest(repo.saved.single, forUpdate: true);
      expect(body.containsKey('rewardCap'), isTrue);
      expect(body['rewardCap'], isNull);
    });

    testWidgets('saving with an invalid earlier step jumps back to it', (
      tester,
    ) async {
      await pumpPage(tester, editing: card);
      controller.alias.text = '';
      await tester.tap(find.byKey(const Key('step-tab-3')));
      await tester.pumpAndSettle();
      await save(tester);
      expect(repo.saved, isEmpty);
      expect(onStep(tester, 0), isTrue);
      expect(find.text(S.fieldRequired), findsOneWidget);
    });

    testWidgets('delete lives in the review: confirms, then deletes', (
      tester,
    ) async {
      await pumpPage(tester, editing: card);
      expect(find.byKey(const Key('delete-card')), findsNothing);
      await tester.tap(find.byKey(const Key('step-tab-3')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('delete-card')));
      await tester.tap(find.byKey(const Key('delete-card')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete-card-confirm')));
      await tester.pumpAndSettle();
      expect(repo.deleted, ['c1']);
    });

    testWidgets('cancelling keeps the card', (tester) async {
      await pumpPage(tester, editing: card);
      await tester.tap(find.byKey(const Key('step-tab-3')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('delete-card')));
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
      await tester.tap(find.byKey(const Key('step-tab-3')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('delete-card')));
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
        testWidgets('walks the four steps (dark=$dark, $lang)', (tester) async {
          await pumpPage(
            tester,
            editing: CardMapper.fromJson(cardJson()),
            dark: dark,
            lang: lang,
          );
          final l10n = AppLocalizations.of(
            tester.element(find.byType(CardFormPage)),
          );
          for (var i = 0; i < 4; i++) {
            await tester.tap(find.byKey(Key('step-tab-$i')));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.text(l10n.stepOf(i + 1, 4)), findsOneWidget);
          }
          expect(find.byKey(const Key('delete-card')), findsOneWidget);
          expect(find.text(l10n.cardStepTitleReview), findsOneWidget);
        });
      }
    }

    testWidgets('fits a 320 px wide phone on every step', (tester) async {
      await pumpPage(tester, editing: CardMapper.fromJson(cardJson()));
      tester.view.physicalSize = const Size(320, 700);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(Key('step-tab-$i')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });
}
