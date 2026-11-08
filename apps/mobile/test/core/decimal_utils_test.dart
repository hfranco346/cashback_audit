import 'package:cashback_audit/core/utils/decimal_utils.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));

  test('parses API decimal strings exactly', () {
    expect(parseDecimal('0.1') + parseDecimal('0.2'), Decimal.parse('0.3'));
    expect(parseDecimal(null), Decimal.zero);
    expect(tryParseDecimal('abc'), isNull);
    expect(decimalToApi(Decimal.parse('125.40')), '125.4');
  });

  test('rounds half up', () {
    expect(roundDecimal(Decimal.parse('1.005')), Decimal.parse('1.01'));
  });

  test('formats money, points and rates', () {
    expect(formatMoney(Decimal.parse('1234.5')), r'$1,234.50');
    expect(formatMoney(Decimal.parse('-58')), contains('58.00'));
    expect(formatPoints(Decimal.parse('12500')), '12,500 pts');
    expect(formatRate(Decimal.parse('5')), '5%');
    expect(formatRate(Decimal.parse('1.5')), '1.5%');
  });
}
