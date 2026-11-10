import 'package:cashback_audit/features/cards/domain/card_entities.dart';
import 'package:cashback_audit/features/claim/domain/claim_email.dart';
import 'package:cashback_audit/features/claim/domain/mail_launcher.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

Decimal d(String s) => Decimal.parse(s);

/// The BAC Credomatic case of `Reclamo.dc.html`.
ClaimData bac({
  String? name = 'Ana Martínez',
  String? bank = 'BAC Credomatic',
}) => ClaimData(
  bank: bank,
  program: 'CASH BAC CREDOMATIC',
  last4: '4821',
  unit: RewardUnit.cashbackCurrency,
  currency: 'HNL',
  rewardCurrency: 'HNL',
  reported: d('0'),
  expected: d('1526.84'),
  difference: d('-1526.84'),
  periodStart: DateTime(2026, 10, 3),
  periodEnd: DateTime(2026, 11, 3),
  userName: name,
  lines: [
    ClaimLine(
      categoryName: 'Supermercados',
      ratePercent: d('7'),
      spend: d('20686.07'),
      transactionCount: 23,
      expectedReward: d('1448.02'),
    ),
    ClaimLine(
      categoryName: 'Farmacia',
      ratePercent: d('7'),
      spend: d('1125.97'),
      transactionCount: 3,
      expectedReward: d('78.82'),
    ),
  ],
);

void main() {
  group('ClaimEmailBuilder', () {
    test('Spanish formal matches the design', () {
      final e = ClaimEmailBuilder.build(
        bac(),
        language: ClaimLanguage.es,
        tone: ClaimTone.formal,
      );
      expect(
        e.subject,
        'Cashback no acreditado · tarjeta •••• 4821 · 3 oct – 3 nov 2026',
      );
      expect(
        e.body,
        'Estimados señores de BAC Credomatic:\n\n'
        'Solicito la revisión del cashback de mi tarjeta terminada en 4821 '
        'para el periodo del 3 de octubre al 3 de noviembre de 2026. '
        'El programa CASH BAC CREDOMATIC reporta HNL 0.00; según las tasas '
        'de mi tarjeta, correspondía:\n\n'
        '• Supermercados 7%: HNL 20,686.07 en 23 compras → HNL 1,448.02\n'
        '• Farmacia 7%: HNL 1,125.97 en 3 compras → HNL 78.82\n\n'
        'Total esperado: HNL 1,526.84.\n\n'
        'Agradeceré confirmar la corrección y el número de gestión.\n\n'
        'Atentamente,\nAna Martínez',
      );
    });

    test('English formal matches the design', () {
      final e = ClaimEmailBuilder.build(
        bac(),
        language: ClaimLanguage.en,
        tone: ClaimTone.formal,
      );
      expect(
        e.subject,
        'Uncredited cashback · card •••• 4821 · Oct 3 – Nov 3, 2026',
      );
      expect(
        e.body,
        'Dear BAC Credomatic team,\n\n'
        'I am requesting a review of the cashback on my card ending in 4821 '
        'for the period October 3 – November 3, 2026. The CASH BAC '
        'CREDOMATIC program shows HNL 0.00; based on my card rates, I '
        'should have received:\n\n'
        '• Supermercados 7%: HNL 20,686.07 in 23 purchases → HNL 1,448.02\n'
        '• Farmacia 7%: HNL 1,125.97 in 3 purchases → HNL 78.82\n\n'
        'Total expected: HNL 1,526.84.\n\n'
        'Please confirm the correction and share a case number.\n\n'
        'Sincerely,\nAna Martínez',
      );
    });

    test('Spanish firm names the dates, amounts and asks for the credit', () {
      final e = ClaimEmailBuilder.build(
        bac(),
        language: ClaimLanguage.es,
        tone: ClaimTone.firm,
      );
      expect(e.body, startsWith('Estimados señores de BAC Credomatic:\n\n'));
      expect(
        e.body,
        contains(
          'Mi estado de cuenta del 3 oct al 3 nov 2026 '
          '(tarjeta •••• 4821) no acredita el cashback que me corresponde',
        ),
      );
      expect(e.body, contains('(reportado: HNL 0.00)'));
      expect(e.body, contains('23 compras → HNL 1,448.02'));
      expect(e.body, contains('Total esperado: HNL 1,526.84.'));
      expect(
        e.body,
        contains(
          'Solicito la acreditación de HNL 1,526.84 en el próximo corte y '
          'un número de gestión para dar seguimiento.',
        ),
      );
      expect(e.body, endsWith('Atentamente,\nAna Martínez'));
    });

    test('English firm', () {
      final e = ClaimEmailBuilder.build(
        bac(),
        language: ClaimLanguage.en,
        tone: ClaimTone.firm,
      );
      expect(e.body, startsWith('Dear BAC Credomatic team,\n\n'));
      expect(
        e.body,
        contains(
          'My statement for Oct 3 – Nov 3, 2026 (card •••• 4821) '
          'does not credit the cashback I earned on my purchases '
          '(reported: HNL 0.00):',
        ),
      );
      expect(
        e.body,
        contains(
          'I request that HNL 1,526.84 be credited on the next statement, '
          'along with a case number for follow-up.',
        ),
      );
      expect(e.body, endsWith('Sincerely,\nAna Martínez'));
    });

    test('without a user name the signature has no name line', () {
      for (final lang in ClaimLanguage.values) {
        for (final tone in ClaimTone.values) {
          final e = ClaimEmailBuilder.build(
            bac(name: null),
            language: lang,
            tone: tone,
          );
          expect(
            e.body,
            endsWith(lang == ClaimLanguage.es ? 'Atentamente,' : 'Sincerely,'),
          );
        }
      }
    });

    test('without a bank the greeting is generic', () {
      final es = ClaimEmailBuilder.build(
        bac(bank: null),
        language: ClaimLanguage.es,
        tone: ClaimTone.formal,
      );
      expect(es.body, startsWith('Estimados señores:\n\n'));
      final en = ClaimEmailBuilder.build(
        bac(bank: null),
        language: ClaimLanguage.en,
        tone: ClaimTone.firm,
      );
      expect(en.body, startsWith('Dear team,\n\n'));
    });

    test('email language does not depend on the app locale', () {
      // Same output whatever ActiveLocale holds: the builder only reads the
      // generated localizations of the requested language.
      final a = ClaimEmailBuilder.build(
        bac(),
        language: ClaimLanguage.en,
        tone: ClaimTone.formal,
      );
      expect(a.body, contains('Total expected'));
      expect(a.body, isNot(contains('Total esperado')));
    });

    test('formats amounts with the email language, not the app one', () {
      final data = bac();
      final es = ClaimEmailBuilder.build(
        data,
        language: ClaimLanguage.es,
        tone: ClaimTone.formal,
      );
      final en = ClaimEmailBuilder.build(
        data,
        language: ClaimLanguage.en,
        tone: ClaimTone.formal,
      );
      expect(es.body, contains('HNL 20,686.07'));
      expect(en.body, contains('HNL 20,686.07'));
    });

    test('a base-rate line and a single purchase read naturally', () {
      final data = ClaimData(
        bank: 'BBVA',
        last4: '4321',
        unit: RewardUnit.cashbackCurrency,
        currency: 'MXN',
        rewardCurrency: 'MXN',
        reported: d('40'),
        expected: d('58'),
        difference: d('-18'),
        periodStart: DateTime(2025, 12, 20),
        periodEnd: DateTime(2026, 1, 19),
        lines: [
          ClaimLine(
            categoryName: null,
            ratePercent: d('1.5'),
            spend: d('300'),
            transactionCount: 1,
            expectedReward: d('4.5'),
          ),
        ],
      );
      final es = ClaimEmailBuilder.build(
        data,
        language: ClaimLanguage.es,
        tone: ClaimTone.formal,
      );
      expect(es.body, contains('• Tasa base 1.5%: MXN 300.00 en 1 compra → '));
      // No program printed: falls back to the statement.
      expect(es.body, contains('Mi estado de cuenta reporta MXN 40.00;'));
      expect(es.body, contains('del 20 de diciembre de 2025 al 19 de enero'));
      final en = ClaimEmailBuilder.build(
        data,
        language: ClaimLanguage.en,
        tone: ClaimTone.formal,
      );
      expect(en.body, contains('• Base rate 1.5%: MXN 300.00 in 1 purchase'));
      expect(en.subject, contains('Dec 20, 2025 – Jan 19, 2026'));
    });

    test('points claims talk about points and format them as points', () {
      final data = ClaimData(
        bank: 'Banco',
        last4: '1111',
        unit: RewardUnit.points,
        currency: 'MXN',
        rewardCurrency: 'MXN',
        reported: d('100'),
        expected: d('250'),
        difference: d('-150'),
        periodStart: DateTime(2026, 1, 1),
        periodEnd: DateTime(2026, 1, 31),
        lines: const [],
      );
      final es = ClaimEmailBuilder.build(
        data,
        language: ClaimLanguage.es,
        tone: ClaimTone.formal,
      );
      expect(es.subject, startsWith('Puntos no acreditados'));
      expect(es.body, contains('revisión de los puntos'));
      expect(es.body, contains('100 pts'));
      expect(es.body, contains('Total esperado: 250 pts.'));
    });
  });

  group('ClaimData.fromVerification', () {
    test('takes bank, program, last 4, period and lines from the result', () {
      final v = VerificationMapper.detail(verificationJson());
      final data = ClaimData.fromVerification(v, userName: '  Ana  ');
      expect(data.bank, 'BBVA');
      expect(data.program, 'Bonificacion');
      expect(data.last4, '4321');
      expect(data.reported, d('40'));
      expect(data.expected, d('58'));
      expect(data.difference, d('-18'));
      expect(data.userName, 'Ana');
      expect(data.lines.map((l) => l.categoryName), ['Super', null]);
      expect(data.lines.first.transactionCount, 3);
      final e = ClaimEmailBuilder.build(
        data,
        language: ClaimLanguage.es,
        tone: ClaimTone.formal,
      );
      expect(e.body, contains('BBVA'));
      expect(e.body, contains('El programa Bonificacion reporta MXN 40.00'));
      expect(e.body, contains('• Super 5%: MXN 1,100.00 en 3 compras'));
    });
  });

  group('buildMailto', () {
    test('percent-encodes spaces and line breaks and keeps the recipient', () {
      final uri = buildMailto(
        to: ' reclamos@bac.net ',
        subject: 'Cashback no acreditado · 4821',
        body: 'Línea 1\nLínea 2 & más',
      );
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'reclamos@bac.net');
      expect(uri.toString(), isNot(contains('+')));
      expect(uri.toString(), contains('subject=Cashback%20no%20acreditado'));
      expect(uri.toString(), contains('%0A'));
      expect(uri.toString(), contains('%26'));
      expect(uri.queryParameters['subject'], 'Cashback no acreditado · 4821');
      expect(uri.queryParameters['body'], 'Línea 1\nLínea 2 & más');
    });

    test('an empty recipient still builds a valid mailto', () {
      final uri = buildMailto(to: '', subject: 's', body: 'b');
      expect(uri.toString(), 'mailto:?subject=s&body=b');
    });
  });
}
