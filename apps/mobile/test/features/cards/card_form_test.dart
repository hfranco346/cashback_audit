import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/core/utils/cached.dart';
import 'package:cashback_audit/features/cards/data/card_mapper.dart';
import 'package:cashback_audit/features/cards/domain/card_entities.dart';
import 'package:cashback_audit/features/cards/domain/card_repository.dart';
import 'package:cashback_audit/features/cards/presentation/card_form_controller.dart';
import 'package:cashback_audit/features/cards/presentation/cards_controller.dart';
import 'package:cashback_audit/features/cards/presentation/widgets/card_form_view.dart';
import 'package:cashback_audit/features/cards/presentation/widgets/card_tile.dart';
import 'package:cashback_audit/features/cards/presentation/widgets/rule_editor.dart';
import 'package:cashback_audit/features/categories/domain/catalog_entities.dart';
import 'package:cashback_audit/features/categories/presentation/catalog_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/fixtures.dart';
import '../categories/fake_catalog.dart';

class _CardRepo implements CardRepository {
  final saved = <CardDraft>[];
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
  Future<void> deleteCard(String id) async {}
}

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));

  const cats = [
    Category(id: 'cat1', name: 'Super'),
    Category(id: 'cat2', name: 'Gasolina'),
  ];

  group('RuleEditor', () {
    testWidgets('adds, edits and removes rules', (tester) async {
      final rules = <RuleDraft>[RuleDraft(categoryId: 'cat1')];
      var added = 0;
      int? removed;
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: SingleChildScrollView(
              child: RuleEditor(
                rules: rules,
                categories: cats,
                capSuffix: 'MXN',
                onAdd: () => added++,
                onRemove: (i) => removed = i,
                onCategoryChanged: (_, _) {},
                errors: const {0: 'Tasa inválida'},
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('rule-rate-0')), '5');
      expect(rules.first.rate.text, '5');
      expect(find.text('Tasa inválida'), findsOneWidget);
      await tester.tap(find.byKey(const Key('add-rule')));
      expect(added, 1);
      await tester.tap(find.byKey(const Key('remove-rule-0')));
      expect(removed, 0);
    });

    testWidgets('explains when there are no categories', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: RuleEditor(
              rules: const [],
              categories: const [],
              capSuffix: 'MXN',
              onAdd: () {},
              onRemove: (_) {},
              onCategoryChanged: (_, _) {},
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('rules-need-categories')), findsOneWidget);
      final add = tester.widget<OutlinedButton>(
        find.byKey(const Key('add-rule')),
      );
      expect(add.onPressed, isNull);
    });
  });

  group('CardFormController', () {
    late _CardRepo repo;
    late CardFormController controller;

    Future<void> pumpForm(WidgetTester tester) async {
      repo = _CardRepo();
      final catalog = CatalogController(
        categories: FakeCategoryRepository(cats),
        merchants: FakeMerchantRepository(),
      );
      await catalog.load();
      controller = CardFormController(
        repository: repo,
        cards: CardsController(repo),
        catalog: catalog,
      )..onInit();
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: CardFormView(
              formKey: controller.formKey,
              alias: controller.alias,
              bank: controller.bank,
              last4: controller.last4,
              network: controller.network,
              rewardProgram: controller.rewardProgram,
              rewardCurrency: controller.rewardCurrency,
              currency: controller.currency,
              pointsFactor: controller.pointsFactor,
              baseRate: controller.baseRate,
              rewardUnit: RewardUnit.cashbackCurrency,
              onUnitChanged: (_) {},
              rules: controller.rules.toList(),
              categories: cats,
              ruleErrors: const {},
              onAddRule: () {},
              onRemoveRule: (_) {},
              onRuleCategoryChanged: (_, _) {},
              onSubmit: () {},
              submitting: false,
              isEditing: false,
            ),
          ),
        ),
      );
    }

    testWidgets('blocks invalid input and never builds a draft', (
      tester,
    ) async {
      await pumpForm(tester);
      controller.last4.text = '12345';
      expect(controller.buildDraft(), isNull);
      await tester.pump();
      expect(find.text(S.fieldRequired), findsWidgets);
      expect(await controller.save(), isFalse);
      expect(repo.saved, isEmpty);
    });

    testWidgets('saves a valid draft with rules', (tester) async {
      await pumpForm(tester);
      controller.alias.text = 'Daily';
      controller.bank.text = 'BBVA';
      controller.last4.text = '4321';
      controller.baseRate.text = '1,5';
      expect(controller.addRule(), isTrue);
      controller.rules.first.rate.text = '5';
      controller.rules.first.cap.text = '500';
      expect(await controller.save(), isTrue);
      final d = repo.saved.single;
      expect(d.baseRatePercent.toString(), '1.5');
      expect(d.rules.single.categoryId, 'cat1');
      expect(d.rules.single.monthlyCap.toString(), '500');
    });

    testWidgets('reward program field is optional and trimmed', (tester) async {
      await pumpForm(tester);
      expect(find.byKey(const Key('field-reward-program')), findsOneWidget);
      controller.alias.text = 'Daily';
      controller.bank.text = 'BAC';
      controller.last4.text = '4321';
      controller.baseRate.text = '1';
      expect(await controller.save(), isTrue);
      expect(repo.saved.last.rewardProgramName, isNull);
      controller.rewardProgram.text = '  CASH BAC CREDOMATIC ';
      expect(await controller.save(), isTrue);
      expect(repo.saved.last.rewardProgramName, 'CASH BAC CREDOMATIC');
    });

    testWidgets('reward currency is optional, validated and picked by chip', (
      tester,
    ) async {
      await pumpForm(tester);
      expect(find.byKey(const Key('field-reward-currency')), findsOneWidget);
      expect(find.text(S.cardRewardCurrencyHelper), findsOneWidget);
      controller.alias.text = 'Daily';
      controller.bank.text = 'Ficohsa';
      controller.last4.text = '4321';
      controller.baseRate.text = '1';
      // Empty = detect automatically.
      expect(await controller.save(), isTrue);
      expect(repo.saved.last.rewardCurrency, isNull);
      // Invalid free entry blocks the form.
      controller.rewardCurrency.text = 'US';
      expect(controller.buildDraft(), isNull);
      await tester.pump();
      expect(find.text(S.currencyInvalid), findsOneWidget);
      // A common code is one tap away.
      await tester.tap(find.byKey(const Key('reward-currency-USD')));
      await tester.pump();
      expect(controller.rewardCurrency.text, 'USD');
      expect(await controller.save(), isTrue);
      expect(repo.saved.last.rewardCurrency, 'USD');
      // Free entry is uppercased.
      controller.rewardCurrency.text = 'kwd';
      expect(await controller.save(), isTrue);
      expect(repo.saved.last.rewardCurrency, 'KWD');
    });

    testWidgets('rejects duplicate categories and missing rates', (
      tester,
    ) async {
      await pumpForm(tester);
      controller.alias.text = 'A';
      controller.bank.text = 'B';
      controller.last4.text = '1111';
      controller.baseRate.text = '1';
      controller.rules.addAll([
        RuleDraft(categoryId: 'cat1', rate: '5'),
        RuleDraft(categoryId: 'cat1', rate: '3'),
        RuleDraft(categoryId: 'cat2'),
      ]);
      expect(controller.buildDraft(), isNull);
      expect(controller.ruleErrors[1], S.ruleDuplicateCategory);
      expect(controller.ruleErrors[2], S.numberInvalid);
      expect(controller.ruleErrors.containsKey(0), isFalse);
    });

    testWidgets('API failure shows a mapped message', (tester) async {
      await pumpForm(tester);
      controller.alias.text = 'A';
      controller.bank.text = 'B';
      controller.last4.text = '1111';
      controller.baseRate.text = '1';
      repo.error = const AppException(kind: AppErrorKind.network);
      expect(await controller.save(), isFalse);
      expect(controller.errorMessage.value, S.errNetwork);
    });
  });

  testWidgets('CardTile shows alias, last4 and handles taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: CardTile(
            card: CardMapper.fromJson(cardJson()),
            onTap: () => taps++,
          ),
        ),
      ),
    );
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('•••• 4321'), findsOneWidget);
    expect(find.text('1 regla'), findsOneWidget);
    await tester.tap(find.byType(CardTile));
    expect(taps, 1);
  });
}
