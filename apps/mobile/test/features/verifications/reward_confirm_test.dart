import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/core/utils/cached.dart';
import 'package:cashback_audit/features/cards/data/card_mapper.dart';
import 'package:cashback_audit/features/cards/domain/card_entities.dart';
import 'package:cashback_audit/features/cards/domain/card_repository.dart';
import 'package:cashback_audit/features/cards/presentation/cards_controller.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/presentation/confirm_rates_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/confirm_rates_page.dart';
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

Decimal d(String s) => Decimal.parse(s);

Map<String, dynamic> _withConversion({
  String? rate,
  String source = 'NONE',
  bool required = true,
}) => ficohsaAwaitingJson()
  ..['rewardConversion'] = {
    'fromCurrency': 'HNL',
    'toCurrency': 'USD',
    'rate': rate,
    'source': source,
    'required': required,
    'note': null,
  };

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));

  late FakeVerificationRepository repo;
  late FakeNavigator nav;

  ConfirmRatesController make(Map<String, dynamic> json) {
    final c = ConfirmRatesController(
      repository: repo,
      cards: CardsController(_CardRepo()),
      navigator: nav,
      args: ConfirmRatesArgs.verification(VerificationMapper.detail(json)),
    )..onInit();
    addTearDown(c.onClose);
    return c;
  }

  setUp(() {
    repo = FakeVerificationRepository()..detailJson = ficohsaCompletedJson();
    nav = FakeNavigator();
  });
  tearDown(Get.reset);

  /// Fills every required category/base rate so only currency fields matter.
  void fillRates(ConfirmRatesController c) {
    for (final e in c.entries) {
      if (!e.hasRate) e.rate.text = '1';
    }
  }

  group('reward conversion', () {
    test('required rate blocks submit until it is a valid number', () {
      final c = make(_withConversion());
      fillRates(c);
      expect(c.rewardConversion.value?.toCurrency, 'USD');
      expect(c.rewardRateOrigin, RateOrigin.none);
      expect(c.rewardRateError, S.rewardRateRequiredError);
      expect(c.canConfirm, isFalse);

      for (final bad in ['0', 'abc', '25.1234567', '-3']) {
        c.rewardRate.text = bad;
        expect(c.rewardRateError, S.exchangeRateInvalid, reason: bad);
        expect(c.canConfirm, isFalse, reason: bad);
      }
      c.rewardRate.text = '25,9969';
      expect(c.rewardRateError, isNull);
      expect(c.canConfirm, isTrue);
    });

    test('is sent as rewardExchangeRate', () async {
      final c = make(_withConversion());
      fillRates(c);
      c.rewardRate.text = '25.9969';
      await c.confirm();
      expect(repo.confirmRequests.single.rewardExchangeRate, d('25.9969'));
    });

    test('prefills from the statement and no longer blocks', () async {
      final c = make(
        _withConversion(rate: '26.35', source: 'STATEMENT', required: false),
      );
      fillRates(c);
      expect(c.rewardRate.text, '26.35');
      expect(c.rewardRateOrigin, RateOrigin.statement);
      expect(c.canConfirm, isTrue);
      await c.confirm();
      expect(repo.confirmRequests.single.rewardExchangeRate, d('26.35'));
    });

    test('a recalculation prefills the rate the audit used', () {
      final c = make(ficohsaCompletedJson());
      expect(c.rewardRate.text, '25.9969');
      expect(c.rewardRateOrigin, RateOrigin.previous);
      expect(c.canConfirm, isTrue);
    });

    test('no conversion: no field, nothing sent', () async {
      final json = ficohsaAwaitingJson()..['rewardConversion'] = null;
      final c = make(json);
      fillRates(c);
      expect(c.rewardConversion.value, isNull);
      expect(c.canConfirm, isTrue);
      await c.confirm();
      expect(repo.confirmRequests.single.rewardExchangeRate, isNull);
    });

    test(
      'server REWARD_EXCHANGE_RATE_REQUIRED makes the field required',
      () async {
        final json = ficohsaAwaitingJson()
          ..['rewardConversion'] = null
          ..['exchangeRateProposal'] = <Map<String, dynamic>>[];
        final c = make(json);
        fillRates(c);
        repo.confirmErrors.add(
          const AppException(
            kind: AppErrorKind.unprocessable,
            code: 'REWARD_EXCHANGE_RATE_REQUIRED',
            details: {'fromCurrency': 'HNL', 'toCurrency': 'USD'},
          ),
        );
        await c.confirm();
        expect(c.errorMessage.value, S.errRewardRateRequired);
        expect(c.rewardConversion.value?.required, isTrue);
        expect(c.rewardConversion.value?.toCurrency, 'USD');
        expect(c.canConfirm, isFalse);
        c.rewardRate.text = '26';
        await c.confirm();
        expect(repo.confirmRequests.last.rewardExchangeRate, d('26'));
      },
    );
  });

  group('foreign spend rates', () {
    Map<String, dynamic> multi() => _withConversion()
      ..['exchangeRateProposal'] = [
        {
          'currency': 'USD',
          'rate': '25.8',
          'source': 'STATEMENT',
          'required': false,
        },
        {'currency': 'EUR', 'rate': null, 'source': 'NONE', 'required': false},
      ];

    test('one optional field per proposal entry, statement prefilled', () {
      final c = make(multi());
      expect(c.foreignRates.map((f) => f.currency), ['USD', 'EUR']);
      expect(c.foreignRates[0].rate.text, '25.8');
      expect(c.foreignRates[0].origin, RateOrigin.statement);
      expect(c.foreignRates[1].rate.text, '');
      expect(c.foreignRates[1].willBeExcluded, isTrue);
      // The old single field is replaced.
      expect(c.showExchangeRate, isFalse);
    });

    test('payload is a per-currency map; empty ones are left out', () async {
      final c = make(multi());
      fillRates(c);
      c.rewardRate.text = '25.9969';
      await c.confirm();
      var req = repo.confirmRequests.single;
      expect(req.exchangeRates, {'USD': d('25.8')});
      c.foreignRates[1].rate.text = '28,1';
      c.foreignRates[0].rate.text = '';
      await c.confirm();
      req = repo.confirmRequests.last;
      expect(req.exchangeRates, {'EUR': d('28.1')});
    });

    test('an invalid optional rate blocks, an empty one does not', () {
      final c = make(multi());
      fillRates(c);
      c.rewardRate.text = '26';
      expect(c.canConfirm, isTrue);
      c.foreignRates[1].rate.text = '0';
      expect(c.canConfirm, isFalse);
      c.foreignRates[1].rate.text = '';
      expect(c.canConfirm, isTrue);
    });

    test('a spend rate for the reward currency also covers the reward rate', () async {
      final c = make(multi());
      fillRates(c);
      // USD is both the reward currency and a spend currency (25.8 prefilled).
      expect(c.rewardRate.text, '');
      expect(c.rewardRateError, isNull);
      expect(c.canConfirm, isTrue);
      await c.confirm();
      expect(repo.confirmRequests.single.rewardExchangeRate, isNull);
      expect(repo.confirmRequests.single.exchangeRates['USD'], d('25.8'));
      c.foreignRates[0].rate.text = '';
      expect(c.canConfirm, isFalse);
    });

    test('a recalculation prefills the rates sent earlier', () {
      final json = ficohsaCompletedJson()
        ..['exchangeRateProposal'] = [
          {
            'currency': 'EUR',
            'rate': null,
            'source': 'NONE',
            'required': false,
          },
        ];
      (json['conversion'] as Map)['requestedRates'] = {'EUR': '28.1'};
      final c = make(json);
      expect(c.foreignRates.single.rate.text, '28.1');
      expect(c.foreignRates.single.origin, RateOrigin.previous);
    });
  });

  group('suggested categories', () {
    Map<String, dynamic> refreshed() => ficohsaAwaitingJson()
      ..['rewardConversion'] = null
      ..['rateProposal'] = [
        proposalJson(null, null, '1', 'CARD_RULE'),
        proposalJson('cat1', 'Supermercados', '7', 'STATEMENT'),
        proposalJson(
          'cat-rest',
          'Restaurantes y Comida rápida',
          '7',
          'STATEMENT',
          evidence: '7% Restaurantes y Comida rápida',
        ),
      ]
      // The server may keep listing the handled wording.
      ..['categoriesResult'] = {
        'created': [
          {'id': 'cat-rest', 'name': 'Restaurantes y Comida rápida'},
        ],
        'reused': <Map<String, dynamic>>[],
      };

    test('those with matching lines are preselected', () {
      final c = make(_withConversion());
      expect(c.suggestions, hasLength(3));
      expect(c.selectedSuggestions, {'Restaurantes y Comida rápida'});
    });

    test(
      'creating refreshes the proposal in place and keeps user input',
      () async {
        final c = make(_withConversion());
        c.entries.firstWhere((e) => e.isBase).rate.text = '2.5';
        c.rewardRate.text = '26';
        repo.suggestionsResultJson = refreshed();

        await c.createSuggestedCategories();

        expect(repo.suggestionRequests.single.id, 'fico');
        expect(repo.suggestionRequests.single.names, [
          'Restaurantes y Comida rápida',
        ]);
        // New category, prefilled with the STATEMENT rate.
        final added = c.entries.firstWhere((e) => e.categoryId == 'cat-rest');
        expect(added.rate.text, '7');
        expect(added.origin, RateOrigin.statement);
        expect(added.evidence, '7% Restaurantes y Comida rápida');
        // Untouched user input survives the refresh.
        expect(c.entries.firstWhere((e) => e.isBase).rate.text, '2.5');
        expect(c.rewardRate.text, '26');
        // Handled suggestion disappears; the others stay, unselected.
        expect(c.suggestions.map((s) => s.name), [
          'Tiendas por Departamento',
          'Débitos automáticos en educación',
        ]);
        expect(c.selectedSuggestions, isEmpty);
        expect(c.suggestionsCreatedNotice.value, isTrue);
        expect(c.creatingSuggestions.value, isFalse);
        // The created category also takes part in the confirm request.
        fillRates(c);
        await c.confirm();
        expect(
          c.buildRequest().categoryRates.map((r) => r.categoryId),
          contains('cat-rest'),
        );
      },
    );

    test('nothing selected: no request; failures keep the state', () async {
      final c = make(_withConversion());
      c.toggleSuggestion('Restaurantes y Comida rápida', false);
      await c.createSuggestedCategories();
      expect(repo.suggestionRequests, isEmpty);

      c.toggleSuggestion('Tiendas por Departamento', true);
      repo.suggestionsError = const AppException(kind: AppErrorKind.network);
      await c.createSuggestedCategories();
      expect(c.errorMessage.value, S.errNetwork);
      expect(c.suggestions, hasLength(3));
      expect(c.selectedSuggestions, {'Tiendas por Departamento'});
      expect(c.creatingSuggestions.value, isFalse);
    });
  });

  group('page', () {
    Future<ConfirmRatesController> pumpPage(
      WidgetTester tester,
      Map<String, dynamic> json, {
      ThemeData? theme,
    }) async {
      tester.view.physicalSize = const Size(800, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = make(json);
      Get.put<ConfirmRatesController>(c);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme ?? AppTheme.light,
          home: const ConfirmRatesPage(),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      return c;
    }

    FilledButton button(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byKey(const Key('confirm-button')));

    for (final (name, theme) in [
      ('light', AppTheme.light),
      ('dark', AppTheme.dark),
    ]) {
      testWidgets('reward conversion field blocks submit ($name)', (
        tester,
      ) async {
        final c = await pumpPage(tester, _withConversion(), theme: theme);
        fillRates(c);
        c.touchRewardRate();
        await tester.pump();

        expect(
          find.text(
            'Tu banco paga la recompensa en USD y tus compras están en HNL',
          ),
          findsOneWidget,
        );
        expect(find.text('¿Cuántos HNL vale 1 USD?'), findsOneWidget);
        expect(find.text(S.rewardRateRequiredError), findsOneWidget);
        expect(find.text(S.badgeRequired), findsWidgets);
        expect(button(tester).onPressed, isNull);

        await tester.enterText(
          find.byKey(const Key('reward-rate-field')),
          '26',
        );
        await tester.pump();
        expect(find.text(S.rewardRateRequiredError), findsNothing);
        expect(button(tester).onPressed, isNotNull);

        await tester.enterText(find.byKey(const Key('reward-rate-field')), '0');
        await tester.pump();
        expect(find.text(S.exchangeRateInvalid), findsOneWidget);
        expect(button(tester).onPressed, isNull);
      });

      testWidgets('suggestions card lists % and lines, preselects ($name)', (
        tester,
      ) async {
        await pumpPage(tester, _withConversion(), theme: theme);
        expect(find.text(S.suggestionsTitle), findsOneWidget);
        expect(find.text(S.suggestionsFree), findsOneWidget);
        expect(find.text('7% · 7 movimientos'), findsOneWidget);
        expect(find.text('7% · Sin movimientos'), findsNWidgets(2));
        bool checked(String name) => tester
            .widget<CheckboxListTile>(find.byKey(Key('suggestion-$name')))
            .value!;
        expect(checked('Restaurantes y Comida rápida'), isTrue);
        expect(checked('Tiendas por Departamento'), isFalse);
        expect(find.text(S.createSuggestions), findsOneWidget);
      });
    }

    testWidgets('statement-prefilled reward rate shows the badge', (
      tester,
    ) async {
      final c = await pumpPage(
        tester,
        _withConversion(rate: '26.35', source: 'STATEMENT', required: false),
      );
      fillRates(c);
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const Key('reward-rate-field')),
      );
      expect(field.controller?.text, '26.35');
      expect(find.text(S.badgeStatement), findsWidgets);
      expect(
        find.descendant(
          of: find.byKey(const Key('reward-conversion-card')),
          matching: find.text(S.badgeStatement),
        ),
        findsOneWidget,
      );
    });

    testWidgets('one field per foreign currency with the left-out note', (
      tester,
    ) async {
      await pumpPage(tester, _withConversion());
      expect(find.byKey(const Key('foreign-rate-EUR')), findsOneWidget);
      expect(find.text('¿Cuántos HNL vale 1 EUR?'), findsOneWidget);
      expect(find.byKey(const Key('foreign-excluded-EUR')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('foreign-rate-EUR')), '28.1');
      await tester.pump();
      expect(find.byKey(const Key('foreign-excluded-EUR')), findsNothing);
    });

    testWidgets('tapping Crear rubros seleccionados refreshes in place', (
      tester,
    ) async {
      final c = await pumpPage(tester, _withConversion());
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
      expect(find.byKey(const Key('suggestions-created')), findsOneWidget);
      expect(c.entries.length, 3);
    });
  });
}
