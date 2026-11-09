import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/utils/cached.dart';
import 'package:cashback_audit/features/cards/data/card_mapper.dart';
import 'package:cashback_audit/features/cards/domain/card_entities.dart';
import 'package:cashback_audit/features/cards/domain/card_repository.dart';
import 'package:cashback_audit/features/cards/presentation/cards_controller.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';
import 'package:cashback_audit/features/verifications/presentation/confirm_rates_controller.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
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

Verification _awaiting({
  List<Map<String, dynamic>>? proposal,
  List<Map<String, dynamic>>? transactions,
  List<Map<String, dynamic>>? programs,
}) => VerificationMapper.detail(
  awaitingVerificationJson(
    rateProposal: proposal,
    transactions: transactions,
    programs: programs,
  ),
);

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));

  late FakeVerificationRepository repo;
  late FakeNavigator nav;

  ConfirmRatesController make(ConfirmRatesArgs args, {CardsController? cards}) {
    final c = ConfirmRatesController(
      repository: repo,
      cards: cards ?? CardsController(_CardRepo()),
      navigator: nav,
      args: args,
    )..onInit();
    addTearDown(c.onClose);
    return c;
  }

  setUp(() {
    repo = FakeVerificationRepository();
    nav = FakeNavigator();
  });

  RateEntryDraft entry(ConfirmRatesController c, String? categoryId) =>
      c.entries.firstWhere((e) => e.categoryId == categoryId);

  group('prefill priority', () {
    test('statement > card rule > empty and required', () {
      final v = _awaiting(
        proposal: [
          proposalJson(null, null, '1', 'CARD_RULE'),
          proposalJson(
            'cat1',
            'Super',
            '7',
            'STATEMENT',
            evidence: '7% en súper',
          ),
          proposalJson('cat2', 'Farmacia', '3', 'CARD_RULE', cap: '50'),
          proposalJson('cat3', 'Gasolina', null, 'NONE'),
        ],
      );
      final c = make(ConfirmRatesArgs.verification(v));
      expect(entry(c, null).origin, RateOrigin.cardRule);
      expect(entry(c, null).rate.text, '1');
      final statement = entry(c, 'cat1');
      expect(statement.origin, RateOrigin.statement);
      expect(statement.rate.text, '7');
      expect(statement.evidence, '7% en súper');
      final card = entry(c, 'cat2');
      expect(card.origin, RateOrigin.cardRule);
      expect(card.cap.text, '50');
      expect(card.evidence, isNull);
      final none = entry(c, 'cat3');
      expect(none.origin, RateOrigin.none);
      expect(none.rate.text, isEmpty);
      expect(none.required, isTrue);
    });

    test('the base entry always comes first', () {
      final v = _awaiting(
        proposal: [
          proposalJson('cat1', 'Super', '7', 'STATEMENT'),
          proposalJson(null, null, '1', 'CARD_RULE'),
        ],
      );
      final c = make(ConfirmRatesArgs.verification(v));
      expect(c.entries.first.isBase, isTrue);
    });

    test('a recalculation prefills with the rates it was audited with', () {
      final v = VerificationMapper.detail(verificationJson());
      final c = make(ConfirmRatesArgs.verification(v, returnToResult: true));
      expect(c.isRecalculation, isTrue);
      // applied: base 1, cat1 5. Proposal says the statement states 5 too.
      expect(entry(c, null).origin, RateOrigin.previous);
      expect(entry(c, 'cat1').origin, RateOrigin.previous);
      expect(entry(c, 'cat1').rate.text, '5');
    });

    test('applied rates win over the proposal values', () {
      final json = verificationJson();
      (json['appliedRates'] as Map)['baseRatePercent'] = '2.5';
      final c = make(
        ConfirmRatesArgs.verification(VerificationMapper.detail(json)),
      );
      expect(entry(c, null).rate.text, '2.5');
    });
  });

  group('required logic', () {
    test('confirm stays disabled until every required rate is filled', () {
      final c = make(ConfirmRatesArgs.verification(_awaiting()));
      expect(c.canConfirm, isFalse);
      entry(c, null).rate.text = '1';
      expect(c.canConfirm, isFalse); // category still required
      entry(c, 'cat1').rate.text = '7';
      expect(c.canConfirm, isTrue);
      entry(c, 'cat1').rate.text = '101';
      expect(c.canConfirm, isFalse);
      expect(entry(c, 'cat1').rateError, S.percentRange);
    });

    test('an optional category left blank is omitted from the request', () {
      final v = _awaiting(
        proposal: [
          proposalJson(null, null, '1', 'CARD_RULE'),
          proposalJson('cat1', 'Super', '5', 'CARD_RULE'),
        ],
      );
      final c = make(ConfirmRatesArgs.verification(v));
      expect(c.canConfirm, isTrue);
      entry(c, 'cat1').rate.clear();
      expect(c.canConfirm, isTrue);
      expect(c.buildRequest().categoryRates, isEmpty);
    });

    test('cap must be positive with at most 2 decimals', () {
      final c = make(ConfirmRatesArgs.verification(_awaiting()));
      entry(c, null).rate.text = '1';
      entry(c, 'cat1').rate.text = '7';
      entry(c, 'cat1').cap.text = '0';
      expect(c.canConfirm, isFalse);
      entry(c, 'cat1').cap.text = '50,5';
      expect(c.canConfirm, isTrue);
      expect(
        c.buildRequest().categoryRates.single.monthlyCap,
        Decimal.parse('50.5'),
      );
    });
  });

  group('confirm', () {
    ConfirmRatesController ready({
      List<Map<String, dynamic>>? programs,
      List<Map<String, dynamic>>? transactions,
      bool returnToResult = false,
    }) {
      final c = make(
        ConfirmRatesArgs.verification(
          _awaiting(programs: programs, transactions: transactions),
          returnToResult: returnToResult,
        ),
      );
      entry(c, null).rate.text = '0';
      entry(c, 'cat1').rate.text = '7';
      return c;
    }

    test('sends the confirmed rates and routes to the result', () async {
      final c = ready();
      c.setSaveToCard(true);
      entry(c, 'cat1').cap.text = '100';
      await c.confirm();
      final req = repo.confirmRequests.single;
      expect(repo.confirmedIds.single, 'v1');
      expect(req.baseRatePercent, Decimal.zero);
      expect(req.categoryRates.single.categoryId, 'cat1');
      expect(req.categoryRates.single.ratePercent, Decimal.parse('7'));
      expect(req.categoryRates.single.monthlyCap, Decimal.parse('100'));
      expect(req.saveToCard, isTrue);
      expect(req.exchangeRate, isNull);
      expect(nav.replaced, ['/result']);
      expect((nav.replacedArgs.single as Verification).isCompleted, isTrue);
      expect(c.submitting.value, isFalse);
    });

    test('saveToCard defaults to false', () async {
      final c = ready();
      await c.confirm();
      expect(repo.confirmRequests.single.saveToCard, isFalse);
    });

    test(
      'recalculation from the result pops with the new verification',
      () async {
        final c = ready(returnToResult: true);
        await c.confirm();
        expect(nav.replaced, isEmpty);
        expect(nav.pops, 1);
        expect((nav.lastPopResult as Verification).isCompleted, isTrue);
      },
    );

    test('does nothing while a required rate is missing', () async {
      final c = make(ConfirmRatesArgs.verification(_awaiting()));
      await c.confirm();
      expect(repo.confirmRequests, isEmpty);
    });

    test(
      'exchange rate field only with foreign purchases, and is sent',
      () async {
        final none = ready();
        expect(none.showExchangeRate, isFalse);

        final foreign = ready(
          transactions: [
            txJson(0, 'SUPER', '1000', currency: 'HNL', awaiting: true),
            txJson(1, 'AMAZON', '20', currency: 'USD', awaiting: true),
          ],
        );
        expect(foreign.showExchangeRate, isTrue);
        expect(foreign.foreignWillBeExcluded, isTrue);
        foreign.exchangeRate.text = '24,6';
        expect(foreign.foreignWillBeExcluded, isFalse);
        foreign.exchangeRate.text = '0';
        expect(foreign.canConfirm, isFalse);
        expect(foreign.exchangeRateError, S.exchangeRateInvalid);
        foreign.exchangeRate.text = '24,6';
        await foreign.confirm();
        expect(repo.confirmRequests.single.exchangeRate, Decimal.parse('24.6'));
      },
    );

    test('a statement rate is shown and not flagged as missing', () {
      final json = awaitingVerificationJson(
        transactions: [
          txJson(0, 'AMAZON', '20', currency: 'USD', awaiting: true),
        ],
      );
      json['conversion'] = {
        'primaryCurrency': 'HNL',
        'requestedRate': null,
        'statementRate': {
          'from': 'USD',
          'to': 'HNL',
          'rate': '24.6',
          'source': 'STATEMENT',
        },
      };
      final c = make(
        ConfirmRatesArgs.verification(VerificationMapper.detail(json)),
      );
      expect(c.statementRate?.rate, Decimal.parse('24.6'));
      expect(c.foreignWillBeExcluded, isFalse);
    });

    test(
      'ambiguous program: chooser from details, retry with the pick',
      () async {
        final c = ready();
        repo.confirmErrors.add(
          const AppException(
            kind: AppErrorKind.unprocessable,
            statusCode: 422,
            code: 'REWARD_PROGRAM_AMBIGUOUS',
            details: {
              'programs': ['PUNTOS BAC', 'CASH BAC'],
            },
          ),
        );
        await c.confirm();
        expect(nav.replaced, isEmpty);
        expect(c.programChoices, ['PUNTOS BAC', 'CASH BAC']);
        expect(c.errorMessage.value, S.errProgramAmbiguous);
        expect(c.canConfirm, isFalse);
        c.selectProgram('CASH BAC');
        expect(c.canConfirm, isTrue);
        await c.confirm();
        expect(repo.confirmRequests, hasLength(2));
        expect(repo.confirmRequests.last.rewardProgramName, 'CASH BAC');
        expect(nav.replaced, ['/result']);
      },
    );

    test('several programs and none selected: chooser up front', () {
      final c = make(
        ConfirmRatesArgs.verification(
          _awaiting(
            programs: [
              programJson('PUNTOS BAC', '6534'),
              programJson('CASH BAC', '0'),
            ],
          ),
        ),
      );
      expect(c.programChoices, ['PUNTOS BAC', 'CASH BAC']);
      entry(c, null).rate.text = '0';
      entry(c, 'cat1').rate.text = '7';
      expect(c.canConfirm, isFalse);
      c.selectProgram('CASH BAC');
      expect(c.canConfirm, isTrue);
    });

    test('RATES_REQUIRED marks the missing entries as required', () async {
      final v = _awaiting(
        proposal: [
          proposalJson(null, null, '1', 'CARD_RULE'),
          proposalJson('cat1', 'Super', '5', 'CARD_RULE'),
        ],
      );
      final c = make(ConfirmRatesArgs.verification(v));
      repo.confirmErrors.add(
        const AppException(
          kind: AppErrorKind.unprocessable,
          statusCode: 422,
          code: 'RATES_REQUIRED',
          details: {
            'missing': [
              {'categoryId': 'cat1', 'categoryName': 'Super'},
            ],
          },
        ),
      );
      entry(c, 'cat1').rate.clear();
      await c.confirm();
      expect(entry(c, 'cat1').required, isTrue);
      expect(c.canConfirm, isFalse);
      expect(c.errorMessage.value, S.errRatesRequired);
    });

    test('missing reported reward asks for it and retries with it', () async {
      final c = ready();
      repo.confirmErrors.add(
        const AppException(
          kind: AppErrorKind.unprocessable,
          statusCode: 422,
          code: 'REPORTED_REWARD_NOT_FOUND',
        ),
      );
      await c.confirm();
      expect(c.needsReportedOverride.value, isTrue);
      expect(c.canConfirm, isFalse);
      c.reportedOverride.text = '125,40';
      expect(c.canConfirm, isTrue);
      await c.confirm();
      expect(
        repo.confirmRequests.last.reportedRewardOverride,
        Decimal.parse('125.40'),
      );
      expect(nav.replaced, ['/result']);
    });

    test('other API errors keep the form and show the message', () async {
      final c = ready();
      repo.confirmErrors.add(const AppException(kind: AppErrorKind.network));
      await c.confirm();
      expect(c.errorMessage.value, S.errNetwork);
      expect(nav.replaced, isEmpty);
      expect(c.canConfirm, isTrue);
    });
  });

  test('resuming from history loads the detail by id', () async {
    repo.detailJson = awaitingVerificationJson(id: 'pending');
    final c = make(const ConfirmRatesArgs.byId('pending'));
    await Future<void>.delayed(Duration.zero);
    expect(c.verification.value?.id, 'pending');
    expect(c.entries, isNotEmpty);
    expect(c.isRecalculation, isFalse);
  });
}
