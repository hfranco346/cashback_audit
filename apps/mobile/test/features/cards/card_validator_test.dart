import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/features/cards/domain/card_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('last4 must be exactly four digits', () {
    expect(CardValidator.last4('4321'), isNull);
    expect(CardValidator.last4('43210'), S.last4Invalid);
    expect(CardValidator.last4('43a1'), S.last4Invalid);
    expect(CardValidator.last4(''), S.fieldRequired);
  });

  test('percent: 0-100, max 4 decimals, comma accepted', () {
    expect(CardValidator.percent('5'), isNull);
    expect(CardValidator.percent('1,5'), isNull);
    expect(CardValidator.percent('100'), isNull);
    expect(CardValidator.percent('100.1'), S.percentRange);
    expect(CardValidator.percent('-1'), S.percentRange);
    expect(CardValidator.percent('1.23456'), S.numberInvalid);
    expect(CardValidator.percent('abc'), S.numberInvalid);
  });

  test('cap is optional but positive with <= 2 decimals', () {
    expect(CardValidator.positiveCap(''), isNull);
    expect(CardValidator.positiveCap('500.5'), isNull);
    expect(CardValidator.positiveCap('0'), S.capInvalid);
    expect(CardValidator.positiveCap('1.234'), S.capInvalid);
  });

  test('points factor in (0, 1000]', () {
    expect(CardValidator.pointsFactor('1'), isNull);
    expect(CardValidator.pointsFactor('1000'), isNull);
    expect(CardValidator.pointsFactor('1001'), S.pointsFactorInvalid);
    expect(CardValidator.pointsFactor('0'), S.pointsFactorInvalid);
  });

  test('currency is three letters', () {
    expect(CardValidator.currency('mxn'), isNull);
    expect(CardValidator.currency('MX'), S.currencyInvalid);
  });
}
