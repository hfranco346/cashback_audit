import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/errors/error_messages.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  group('step 1 (live Ficohsa shape)', () {
    final v = VerificationMapper.detail(ficohsaAwaitingJson());

    test('reward conversion is required and has no rate', () {
      final c = v.rewardConversion!;
      expect(c.fromCurrency, 'HNL');
      expect(c.toCurrency, 'USD');
      expect(c.rate, isNull);
      expect(c.required, isTrue);
      expect(c.fromStatement, isFalse);
      expect(v.rewardCurrency, isNull);
    });

    test('exchange rate proposal is optional per foreign currency', () {
      expect(v.exchangeRateProposal, hasLength(1));
      expect(v.exchangeRateProposal.single.currency, 'EUR');
      expect(v.exchangeRateProposal.single.rate, isNull);
    });

    test('suggested categories keep their order, % and line counts', () {
      expect(v.suggestedCategories.map((c) => c.name), [
        'Tiendas por Departamento',
        'Restaurantes y Comida rápida',
        'Débitos automáticos en educación',
      ]);
      expect(v.suggestedCategories[1].matchingTransactionCount, 7);
      expect(v.suggestedCategories[1].ratePercent, d('7'));
      expect(v.suggestedCategories[0].matchingTransactionCount, 0);
    });

    test('lines carry suggestedHint', () {
      expect(v.transactions[1].suggestedHint, 'Restaurantes y Comida rápida');
      expect(v.transactions[0].suggestedHint, isNull);
    });

    test('statement-printed rate prefills the conversion', () {
      final json = ficohsaAwaitingJson();
      json['rewardConversion'] = {
        'fromCurrency': 'HNL',
        'toCurrency': 'USD',
        'rate': '26.35',
        'source': 'STATEMENT',
        'required': false,
        'note': 'x',
      };
      final c = VerificationMapper.detail(json).rewardConversion!;
      expect(c.rate, d('26.35'));
      expect(c.fromStatement, isTrue);
      expect(c.required, isFalse);
    });
  });

  group('step 2 (completed, reward in USD)', () {
    final v = VerificationMapper.detail(ficohsaCompletedJson());

    test('reward figures are in the reward currency', () {
      expect(v.currency, 'HNL');
      expect(v.rewardCurrency, 'USD');
      expect(v.resolvedRewardCurrency, 'USD');
      expect(v.rewardCurrencyDiffers, isTrue);
      expect(v.expectedAmount, d('22.68'));
      expect(v.expectedInPrimaryCurrency, d('589.61'));
      expect(v.reported?.amount, d('42'));
      expect(v.reported?.currency, 'USD');
    });

    test('applied reward exchange rate and conversion details', () {
      final r = v.appliedRates!.rewardExchangeRate!;
      expect(r.fromCurrency, 'HNL');
      expect(r.toCurrency, 'USD');
      expect(r.rate, d('25.9969'));
      expect(r.source, 'USER_ENTERED');
      expect(v.conversion.requestedRewardRate, d('25.9969'));
      expect(v.conversion.statementRates.single.rate, d('26.1'));
      expect(v.conversion.statementRate?.to, 'USD');
    });

    test('program currency and statement summaries', () {
      expect(v.loyalty.selectedProgram?.currency, 'USD');
      final s = v.statement.summaries.single;
      expect(s.currency, 'HNL');
      expect(s.purchases, d('22242.56'));
      expect(s.chargesAndInterest, d('725.16'));
    });

    test('credit types are kept as sent', () {
      expect(v.transactions[0].creditType, isNull);
      expect(v.transactions[2].creditType, CreditType.payment);
      expect(v.transactions[3].creditType, CreditType.refund);
      expect(v.transactions[4].creditType, CreditType.otherCredit);
    });

    test('summary derived for history carries the reward currency', () {
      final summary = VerificationMapper.summary(
        VerificationMapper.summaryJsonFromDetail(ficohsaCompletedJson()),
      );
      expect(summary.rewardCurrency, 'USD');
      expect(summary.resolvedRewardCurrency, 'USD');
      expect(summary.expectedAmount, d('22.68'));
      expect(summary.currency, 'HNL');
    });
  });

  group('legacy / tolerant parsing', () {
    test(
      'a pre-reward-currency completed row falls back to the card currency',
      () {
        final v = VerificationMapper.detail(verificationJson());
        expect(v.rewardCurrency, isNull);
        expect(v.resolvedRewardCurrency, 'MXN');
        expect(v.rewardCurrencyDiffers, isFalse);
        expect(v.rewardConversion, isNull);
        expect(v.exchangeRateProposal, isEmpty);
        expect(v.suggestedCategories, isEmpty);
        expect(v.expectedInPrimaryCurrency, isNull);
        expect(v.appliedRates!.rewardExchangeRate, isNull);
        expect(v.conversion.statementRates, isEmpty);
        expect(v.conversion.requestedRates, isEmpty);
        expect(v.statement.summaries, isEmpty);
        expect(v.transactions.every((t) => t.creditType == null), isTrue);
      },
    );

    test('old single statementRate is read as statementRates[0]', () {
      final json = verificationJson();
      json['conversion'] = {
        'primaryCurrency': 'MXN',
        'requestedRate': '17.5',
        'statementRate': {'from': 'MXN', 'to': 'USD', 'rate': '17.1'},
      };
      final c = VerificationMapper.detail(json).conversion;
      expect(c.requestedRate, d('17.5'));
      expect(c.statementRates.single.rate, d('17.1'));
      expect(c.statementRate?.rate, d('17.1'));
    });

    test('legacy credit lines derive a creditType from the kind', () {
      final v = VerificationMapper.detail(
        verificationJson(
          transactions: [
            txJson(0, 'PAGO', '500', credit: true, kind: 'PAYMENT'),
            txJson(1, 'DEV', '50', credit: true, kind: 'REFUND'),
            txJson(2, 'BONO', '5', credit: true, kind: 'OTHER'),
          ],
        ),
      );
      expect(v.transactions.map((t) => t.creditType), [
        CreditType.payment,
        CreditType.refund,
        CreditType.otherCredit,
      ]);
      final old = VerificationMapper.detail(legacyVerificationJson());
      expect(old.transactions.single.creditType, isNull);
    });

    test('garbage in the new fields never throws', () {
      final json = ficohsaAwaitingJson()
        ..['rewardConversion'] = {'fromCurrency': 'HNL'}
        ..['exchangeRateProposal'] = [
          {'currency': '', 'rate': 'abc'},
          {'currency': 'eur', 'rate': '-3', 'source': 'STATEMENT'},
          'oops',
        ]
        ..['suggestedCategories'] = [
          {'name': '  '},
          {'name': 'Gasolineras'},
        ];
      final v = VerificationMapper.detail(json);
      expect(v.rewardConversion, isNull);
      expect(v.exchangeRateProposal.single.currency, 'EUR');
      expect(v.exchangeRateProposal.single.rate, isNull);
      expect(v.suggestedCategories.single.name, 'Gasolineras');
      expect(v.suggestedCategories.single.matchingTransactionCount, 0);
    });
  });

  group('confirm request body', () {
    test('sends reward rate and the per-currency map as strings', () {
      final body = VerificationMapper.confirmBody(
        ConfirmRequest(
          baseRatePercent: d('1'),
          categoryRates: const [],
          exchangeRates: {'eur': d('28.1'), 'USD': d('25.8')},
          rewardExchangeRate: d('25.9969'),
        ),
      );
      expect(body['rewardExchangeRate'], '25.9969');
      expect(body['exchangeRates'], {'EUR': '28.1', 'USD': '25.8'});
    });

    test('omits both when not provided', () {
      final body = VerificationMapper.confirmBody(
        ConfirmRequest(baseRatePercent: d('1'), categoryRates: const []),
      );
      expect(body.containsKey('rewardExchangeRate'), isFalse);
      expect(body.containsKey('exchangeRates'), isFalse);
    });

    test('a recalculation resends the applied reward rate', () {
      final v = VerificationMapper.detail(ficohsaCompletedJson());
      final req = ConfirmRequest.fromApplied(v.appliedRates!);
      expect(req.rewardExchangeRate, d('25.9969'));
    });
  });

  test('new error codes map to Spanish messages', () {
    expect(
      userMessageFor(
        const AppException(
          kind: AppErrorKind.unprocessable,
          code: 'REWARD_EXCHANGE_RATE_REQUIRED',
        ),
      ),
      S.errRewardRateRequired,
    );
    expect(
      userMessageFor(
        const AppException(
          kind: AppErrorKind.validation,
          code: 'INVALID_EXCHANGE_RATE',
        ),
      ),
      S.errInvalidExchangeRate,
    );
  });
}
