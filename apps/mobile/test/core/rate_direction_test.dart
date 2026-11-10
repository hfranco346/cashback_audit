import 'package:cashback_audit/core/utils/rate_direction.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

Decimal _d(String s) => Decimal.parse(s);

void main() {
  group('RateDirection.choose', () {
    test('the table puts the stronger currency as the unit', () {
      final a = RateDirection.choose(primary: 'HNL', other: 'USD');
      expect((a.unit, a.quote, a.flipped), ('USD', 'HNL', false));
      final b = RateDirection.choose(primary: 'USD', other: 'HNL');
      expect((b.unit, b.quote, b.flipped), ('USD', 'HNL', true));
      final c = RateDirection.choose(primary: 'CRC', other: 'EUR');
      expect((c.unit, c.quote, c.flipped), ('EUR', 'CRC', false));
      final d = RateDirection.choose(primary: 'EUR', other: 'CRC');
      expect((d.unit, d.quote, d.flipped), ('EUR', 'CRC', true));
      final e = RateDirection.choose(primary: 'MXN', other: 'GBP');
      expect(e.unit, 'GBP');
      final f = RateDirection.choose(primary: 'GBP', other: 'MXN');
      expect(f.unit, 'GBP');
    });

    test('a known rate wins over the table', () {
      // 1 HNL = 0.038 USD: HNL is the weaker one.
      final a = RateDirection.choose(
        primary: 'USD',
        other: 'HNL',
        knownStored: _d('0.038'),
      );
      expect(a.unit, 'USD');
      // A (made up) rate where the other currency is worth less.
      final b = RateDirection.choose(
        primary: 'HNL',
        other: 'USD',
        knownStored: _d('0.5'),
      );
      expect(b.unit, 'HNL');
    });

    test('unknown pairs: USD/EUR anchor, otherwise the other currency', () {
      expect(RateDirection.choose(primary: 'XYZ', other: 'USD').unit, 'USD');
      expect(RateDirection.choose(primary: 'EUR', other: 'XYZ').unit, 'EUR');
      expect(RateDirection.choose(primary: 'AAA', other: 'BBB').unit, 'BBB');
    });
  });

  group('conversion', () {
    test('not flipped: shown is what the API gets', () {
      final d = RateDirection.choose(primary: 'HNL', other: 'USD');
      expect(d.toStored(_d('26.30')), _d('26.30'));
      expect(d.toShown(_d('26.3')), _d('26.3'));
    });

    test('flipped: inverse rounded to 6 decimals, no float drift', () {
      final d = RateDirection.choose(primary: 'USD', other: 'HNL');
      expect(d.toStored(_d('26.30')), _d('0.038023'));
      expect(d.toStored(_d('4')), _d('0.25'));
      expect(d.toStored(_d('560')), _d('0.001786'));
    });

    test('flipped: re-editing shows the shortest number that round-trips', () {
      final d = RateDirection.choose(primary: 'USD', other: 'HNL');
      for (final typed in ['26.30', '26.5', '25.8', '27']) {
        final stored = d.toStored(_d(typed))!;
        expect(d.toShown(stored), _d(typed));
        expect(d.toStored(d.toShown(stored)), stored);
      }
      // A rate printed by the statement (not typed): still round-trips.
      final printed = _d('0.038');
      expect(d.toStored(d.toShown(printed)), printed);
    });

    test('values that cannot be represented are rejected', () {
      final d = RateDirection.choose(primary: 'USD', other: 'HNL');
      expect(d.toStored(_d('0')), isNull);
      expect(d.toStored(_d('-1')), isNull);
      expect(d.toStored(_d('9000000')), isNull); // 1/9e6 rounds to 0
    });

    test('inverted suggestion only for 0 < value < 1', () {
      final d = RateDirection.choose(primary: 'HNL', other: 'USD');
      expect(d.invertedSuggestion(_d('0.038')), _d('26.3158'));
      expect(d.invertedSuggestion(_d('26.3')), isNull);
      expect(d.invertedSuggestion(_d('1')), isNull);
      expect(d.invertedSuggestion(_d('0')), isNull);
    });

    test('example comes from the table when both are known', () {
      final d = RateDirection.choose(primary: 'HNL', other: 'USD');
      expect(d.exampleShown, isNotNull);
      expect(d.exampleShown! >= Decimal.one, isTrue);
      expect(
        RateDirection.choose(primary: 'AAA', other: 'BBB').exampleShown,
        isNull,
      );
    });
  });
}
