import 'package:cashback_audit/core/l10n/active_locale.dart';
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

Decimal _d(String s) => Decimal.parse(s);

/// An AWAITING_RATES verification in [primary], with an optional reward
/// conversion to [reward] and one foreign-spend entry per [foreign] currency.
Map<String, dynamic> _json({
  required String primary,
  String? reward,
  String? rewardRate,
  String rewardSource = 'NONE',
  List<String> foreign = const [],
  String? foreignRate,
  String? reportedReward,
  Map<String, dynamic>? appliedReward,
  String? requestedRewardRate,
  Map<String, String> requestedRates = const {},
}) {
  final j = awaitingVerificationJson(
    transactions: [
      txJson(0, 'SUPER', '1000', currency: primary, awaiting: true),
      for (var i = 0; i < foreign.length; i++)
        txJson(
          i + 1,
          'ABROAD ${foreign[i]}',
          '100',
          currency: foreign[i],
          awaiting: true,
        ),
    ],
  );
  j['primaryCurrency'] = primary;
  (j['statement'] as Map<String, dynamic>)['currency'] = primary;
  j['conversion'] = {
    'primaryCurrency': primary,
    'requestedRate': null,
    'requestedRates': requestedRates,
    'requestedRewardRate': requestedRewardRate,
    'statementRates': <Map<String, dynamic>>[],
    'statementRate': null,
  };
  j['rewardConversion'] = reward == null
      ? null
      : {
          'fromCurrency': primary,
          'toCurrency': reward,
          'rate': rewardRate,
          'source': rewardSource,
          'required': rewardRate == null,
          'note': null,
        };
  j['exchangeRateProposal'] = [
    for (final f in foreign)
      {
        'currency': f,
        'rate': foreignRate,
        'source': foreignRate == null ? 'NONE' : 'STATEMENT',
        'required': false,
      },
  ];
  if (reportedReward != null && reward != null) {
    j['reported'] = {
      'amount': reportedReward,
      'unit': 'CASHBACK_CURRENCY',
      'currency': reward,
    };
  }
  if (appliedReward != null) {
    j['appliedRates'] = {
      'baseRatePercent': '1',
      'savedToCard': false,
      'categoryRates': <Map<String, dynamic>>[],
      'rewardExchangeRate': appliedReward,
    };
  }
  return j;
}

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
    for (final e in c.entries) {
      if (!e.hasRate) e.rate.text = '1';
    }
    return c;
  }

  Future<ConfirmRatesController> pumpPage(
    WidgetTester tester,
    Map<String, dynamic> json, {
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
        locale: Locale(lang),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const ConfirmRatesPage(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    return c;
  }

  group('payload follows the API convention', () {
    test('HNL primary, USD reward: 1 USD = 26.30 HNL is sent as 26.30', () {
      final c = make(_json(primary: 'HNL', reward: 'USD'));
      expect(c.rewardDirection!.unit, 'USD');
      expect(c.rewardDirection!.quote, 'HNL');
      c.rewardRate.text = '26.30';
      expect(c.buildRequest().rewardExchangeRate, _d('26.30'));
    });

    test('USD primary, HNL reward: asks 1 USD = ? HNL, sends the inverse', () {
      final c = make(_json(primary: 'USD', reward: 'HNL'));
      expect(c.rewardDirection!.unit, 'USD');
      expect(c.rewardDirection!.quote, 'HNL');
      c.rewardRate.text = '26.30';
      expect(c.rewardRateError, isNull);
      expect(c.buildRequest().rewardExchangeRate, _d('0.038023'));
    });

    test('USD primary, HNL foreign spend: same inverse', () {
      final c = make(_json(primary: 'USD', foreign: ['HNL']));
      final f = c.foreignRates.single;
      expect((f.direction.unit, f.direction.quote), ('USD', 'HNL'));
      f.rate.text = '26,3';
      expect(c.buildRequest().exchangeRates, {'HNL': _d('0.038023')});
    });

    test('CRC primary / EUR spend and EUR primary / CRC spend', () {
      final a = make(_json(primary: 'CRC', foreign: ['EUR']));
      expect(a.foreignRates.single.direction.unit, 'EUR');
      a.foreignRates.single.rate.text = '560';
      expect(a.buildRequest().exchangeRates, {'EUR': _d('560')});

      final b = make(_json(primary: 'EUR', foreign: ['CRC']));
      expect(b.foreignRates.single.direction.unit, 'EUR');
      b.foreignRates.single.rate.text = '560';
      expect(b.buildRequest().exchangeRates, {'CRC': _d('0.001786')});
    });

    test('a value too large to invert is invalid, not sent as 0', () {
      final c = make(_json(primary: 'USD', foreign: ['HNL']));
      c.foreignRates.single.rate.text = '9000000';
      expect(c.foreignRates.single.error, isNotNull);
      expect(c.canConfirm, isFalse);
    });
  });

  group('prefill and re-edit', () {
    test(
      'statement rate (API direction) is shown in the question direction',
      () {
        final c = make(
          _json(
            primary: 'USD',
            reward: 'HNL',
            rewardRate: '0.038',
            rewardSource: 'STATEMENT',
          ),
        );
        expect(c.rewardRateOrigin, RateOrigin.statement);
        final shown = Decimal.parse(c.rewardRate.text);
        expect(shown >= Decimal.one, isTrue);
        expect(c.buildRequest().rewardExchangeRate, _d('0.038'));
      },
    );

    test('saved rate fills in with its own label and direction', () {
      final c = make(
        _json(primary: 'USD', reward: 'HNL', foreign: ['HNL']),
        saved: {'HNL': _d('0.038023')},
        savedPrimary: 'USD',
      );
      expect(c.rewardRateOrigin, RateOrigin.lastRate);
      expect(c.rewardRate.text, '26.3');
      expect(c.foreignRates.single.origin, RateOrigin.lastRate);
      expect(c.foreignRates.single.rate.text, '26.3');
    });

    test('statement beats saved; sent before beats both', () {
      final statement = make(
        _json(
          primary: 'HNL',
          reward: 'USD',
          rewardRate: '26.35',
          rewardSource: 'STATEMENT',
        ),
        saved: {'USD': _d('26.5')},
        savedPrimary: 'HNL',
      );
      expect(statement.rewardRate.text, '26.35');
      expect(statement.rewardRateOrigin, RateOrigin.statement);
      final sent = make(
        _json(
          primary: 'HNL',
          reward: 'USD',
          rewardRate: '26.35',
          rewardSource: 'STATEMENT',
          requestedRewardRate: '26.1',
        ),
      );
      expect(sent.rewardRate.text, '26.1');
      expect(sent.rewardRateOrigin, RateOrigin.previous);
    });

    test('recalculation shows the same number the user typed', () {
      final c = make(_json(primary: 'USD', reward: 'HNL'));
      c.rewardRate.text = '26.30';
      final sent = c.buildRequest().rewardExchangeRate!;
      final again = make(
        _json(
          primary: 'USD',
          reward: 'HNL',
          appliedReward: {
            'fromCurrency': 'USD',
            'toCurrency': 'HNL',
            'rate': decimalText(sent),
            'source': 'USER_ENTERED',
          },
          requestedRewardRate: decimalText(sent),
        ),
      );
      expect(Decimal.parse(again.rewardRate.text), _d('26.3'));
      expect(again.buildRequest().rewardExchangeRate, sent);
    });

    test('foreign: sent rate comes back as the same human number', () {
      final c = make(
        _json(
          primary: 'USD',
          foreign: ['HNL'],
          requestedRates: {'HNL': '0.038023'},
        ),
      );
      expect(Decimal.parse(c.foreignRates.single.rate.text), _d('26.3'));
      expect(c.foreignRates.single.origin, RateOrigin.previous);
      expect(c.buildRequest().exchangeRates, {'HNL': _d('0.038023')});
    });
  });

  group('screen', () {
    testWidgets('asks with the stronger currency as the unit (ES)', (
      tester,
    ) async {
      await pumpPage(tester, _json(primary: 'USD', reward: 'HNL'));
      expect(find.text('1 USD = ¿cuántos HNL?'), findsOneWidget);
      expect(find.text('1 HNL = ¿cuántos USD?'), findsNothing);
    });

    testWidgets('asks the same in English', (tester) async {
      await pumpPage(
        tester,
        _json(primary: 'USD', foreign: ['HNL']),
        lang: 'en',
      );
      expect(find.text('1 USD = how many HNL?'), findsOneWidget);
    });

    testWidgets('live preview of the reward (ES)', (tester) async {
      await pumpPage(
        tester,
        _json(primary: 'HNL', reward: 'USD', reportedReward: '42'),
      );
      await tester.enterText(
        find.byKey(const Key('reward-rate-field')),
        '26.30',
      );
      await tester.pump();
      expect(
        find.text('Tu banco pagó USD 42.00 → equivale a HNL 1,104.60'),
        findsOneWidget,
      );
    });

    testWidgets('live preview of foreign purchases uses the API direction', (
      tester,
    ) async {
      await pumpPage(
        tester,
        _json(primary: 'USD', foreign: ['HNL']),
        lang: 'en',
      );
      await tester.enterText(find.byKey(const Key('foreign-rate-HNL')), '25');
      await tester.pump();
      // HNL 100 at 1 USD = 25 HNL -> USD 4.00
      expect(
        find.text('Your purchases of HNL 100.00 → USD 4.00'),
        findsOneWidget,
      );
    });

    testWidgets('without amounts it previews an example', (tester) async {
      await pumpPage(tester, _json(primary: 'HNL', reward: 'USD'));
      await tester.enterText(find.byKey(const Key('reward-rate-field')), '26');
      await tester.pump();
      expect(find.text('Ejemplo: USD 100.00 = HNL 2,600.00'), findsOneWidget);
    });

    testWidgets('an upside-down value warns and the button flips it', (
      tester,
    ) async {
      final c = await pumpPage(tester, _json(primary: 'HNL', reward: 'USD'));
      expect(find.byKey(const Key('inverted-rate-hint')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('reward-rate-field')),
        '0.038',
      );
      await tester.pump();
      expect(find.byKey(const Key('inverted-rate-hint')), findsOneWidget);
      expect(
        find.textContaining('¿Quisiste decir 1 USD = 26.3158 HNL?'),
        findsOneWidget,
      );
      // It warns, it does not block.
      expect(c.rewardRateError, isNull);
      await tester.ensureVisible(find.byKey(const Key('inverted-rate-use')));
      await tester.tap(find.byKey(const Key('inverted-rate-use')));
      await tester.pump();
      expect(c.rewardRate.text, '26.3158');
      expect(find.byKey(const Key('inverted-rate-hint')), findsNothing);
      for (final e in c.entries) {
        if (!e.hasRate) e.rate.text = '1';
      }
      expect(c.buildRequest().rewardExchangeRate, _d('26.3158'));
    });

    testWidgets('badges say where the number came from', (tester) async {
      await pumpPage(
        tester,
        _json(
          primary: 'HNL',
          reward: 'USD',
          rewardRate: '26.35',
          rewardSource: 'STATEMENT',
          foreign: ['EUR'],
        ),
        saved: {'EUR': _d('28.1')},
        savedPrimary: 'HNL',
      );
      expect(find.text('Del estado de cuenta'), findsOneWidget);
      expect(find.text('Tu último tipo de cambio'), findsOneWidget);
    });
  });
}

String decimalText(Decimal d) => d.toString();
