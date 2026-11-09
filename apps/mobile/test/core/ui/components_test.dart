import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/core/ui/ui.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'gallery.dart';
import 'ui_harness.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    await initializeDateFormatting('en_US');
  });

  group('gallery smoke', () {
    for (final dark in [false, true]) {
      for (final lang in ['es', 'en']) {
        testWidgets('renders without errors (dark=$dark, $lang)', (t) async {
          await pumpUi(t, const UiGallery(), dark: dark, lang: lang);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          expect(find.byType(CreditCardView), findsOneWidget);
          expect(find.byType(MovementRow), findsNWidgets(3));
          expect(find.byType(RateField), findsNWidgets(3));
        });
      }
    }

    testWidgets('fits a 320 px wide phone', (t) async {
      await pumpUi(t, const UiGallery(), size: const Size(320, 700));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  group('StatusPill', () {
    for (final dark in [false, true]) {
      testWidgets('shows icon + text with the tone (dark=$dark)', (t) async {
        await pumpUi(
          t,
          const Column(
            children: [
              StatusPill(kind: StatusKind.ok, label: 'OK'),
              StatusPill(kind: StatusKind.error, label: 'ER'),
            ],
          ),
          dark: dark,
        );
        final palette = dark ? AppStatusColors.dark : AppStatusColors.light;
        expect(find.text('OK'), findsOneWidget);
        final icon = t.widget<Icon>(find.byIcon(Icons.check_rounded));
        expect(icon.color, palette.success.fg);
        final text = t.widget<Text>(find.text('ER'));
        expect(text.style?.color, palette.error.fg);
        expect(find.byIcon(Icons.priority_high_rounded), findsOneWidget);
      });
    }
  });

  group('AppButton', () {
    testWidgets('is a 52 px pill and fires onPressed', (t) async {
      var taps = 0;
      await pumpUi(t, AppButton(label: 'Go', onPressed: () => taps++));
      expect(t.getSize(find.byType(FilledButton)).height, 52);
      await t.tap(find.text('Go'));
      expect(taps, 1);
    });

    testWidgets('ghost variant uses an outlined button', (t) async {
      await pumpUi(t, AppButton.ghost(label: 'Back', onPressed: () {}));
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('loading disables the button', (t) async {
      var taps = 0;
      await pumpUi(
        t,
        AppButton(label: 'Go', loading: true, onPressed: () => taps++),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await t.tap(find.byType(FilledButton), warnIfMissed: false);
      expect(taps, 0);
    });
  });

  testWidgets('AppChip toggles by tap and has a 44 px target', (t) async {
    var selected = false;
    await pumpUi(
      t,
      StatefulBuilder(
        builder: (_, set) => AppChip(
          label: 'BAC Cash',
          selected: selected,
          onTap: () => set(() => selected = !selected),
        ),
      ),
    );
    expect(t.getSize(find.byType(AppChip)).height, greaterThanOrEqualTo(44));
    await t.tap(find.text('BAC Cash'));
    await t.pump();
    expect(selected, isTrue);
  });

  testWidgets('AmountText formats ISO code, tabular and signed', (t) async {
    await pumpUi(
      t,
      Column(
        children: [
          AmountText(amount: Decimal.parse('1526.84'), currency: 'hnl'),
          AmountText(
            amount: Decimal.parse('79.84'),
            currency: 'HNL',
            signed: true,
          ),
        ],
      ),
      lang: 'en',
    );
    expect(find.text('HNL 1,526.84'), findsOneWidget);
    expect(find.text('+HNL 79.84'), findsOneWidget);
    final style = t.widget<Text>(find.text('HNL 1,526.84')).style!;
    expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
  });

  group('CreditCardView', () {
    testWidgets('alias in Bodoni, masked digits and currency', (t) async {
      await pumpUi(
        t,
        const SizedBox(
          width: 280,
          child: CreditCardView(
            alias: 'BAC Cash',
            last4: '4821',
            currency: 'HNL',
            rewardLabel: 'CASHBACK',
            subtitle: 'BAC Credomatic',
          ),
        ),
      );
      expect(
        t.widget<Text>(find.text('BAC Cash')).style?.fontFamily,
        AppFonts.display,
      );
      expect(find.text('•••• 4821'), findsOneWidget);
      expect(find.text('CASHBACK · HNL'), findsOneWidget);
      expect(find.text('BAC Credomatic'), findsOneWidget);
    });
  });

  testWidgets('VerdictCard shows chip, Bodoni title/amount, rows', (t) async {
    await pumpUi(
      t,
      const VerdictCard(
        kind: StatusKind.error,
        statusLabel: 'Te pagaron de menos',
        title: 'Te pagaron de menos',
        amount: '–HNL 1,526.84',
        expectedLabel: 'Esperado',
        expected: 'HNL 1,526.84',
        reportedLabel: 'Reportado',
        reported: 'HNL 0.00',
        equivalence: 'Equivale a USD 58.70',
      ),
      dark: true,
    );
    expect(find.text('Te pagaron de menos'), findsNWidgets(2));
    final amount = t.widget<Text>(find.text('–HNL 1,526.84'));
    expect(amount.style?.fontFamily, AppFonts.display);
    expect(amount.style?.color, AppStatusColors.dark.error.fg);
    expect(find.text('Esperado'), findsOneWidget);
    expect(find.text('Equivale a USD 58.70'), findsOneWidget);
  });

  group('MovementRow', () {
    testWidgets('assign button only when a callback is given', (t) async {
      var taps = 0;
      await pumpUi(
        t,
        Column(
          children: [
            MovementRow(
              kind: StatusKind.error,
              name: 'Eberso',
              bankText: 'COMIDAS ESPECIALES EBERSO',
              statusText: 'Sin rubro',
              amount: 'HNL 297.86',
              onAssignCategory: () => taps++,
            ),
            const MovementRow(
              kind: StatusKind.ok,
              name: 'Corral',
              statusText: 'En rubro',
              amount: 'HNL 1,140.56',
              reward: '+HNL 79.84',
            ),
          ],
        ),
      );
      expect(find.text('Asignar rubro'), findsOneWidget);
      expect(find.text('COMIDAS ESPECIALES EBERSO'), findsOneWidget);
      expect(find.text('+HNL 79.84'), findsOneWidget);
      await t.tap(find.text('Asignar rubro'));
      expect(taps, 1);
    });

    testWidgets('English label; bank text is not translated', (t) async {
      await pumpUi(
        t,
        MovementRow(
          kind: StatusKind.error,
          name: 'Eberso',
          bankText: 'COMIDAS ESPECIALES',
          statusText: 'No category',
          amount: 'HNL 1.00',
          onAssignCategory: () {},
        ),
        lang: 'en',
      );
      expect(find.text('Assign category'), findsOneWidget);
      expect(find.text('COMIDAS ESPECIALES'), findsOneWidget);
    });
  });

  group('RateField', () {
    final labels = {
      'es': {
        RateSource.detected: 'Detectado en tu estado de cuenta',
        RateSource.cardRules: 'De las reglas de tu tarjeta',
        RateSource.required: 'Obligatorio',
      },
      'en': {
        RateSource.detected: 'Detected in your statement',
        RateSource.cardRules: 'From your card rules',
        RateSource.required: 'Required',
      },
    };
    for (final lang in labels.keys) {
      for (final entry in labels[lang]!.entries) {
        testWidgets('${entry.key.name} label in $lang', (t) async {
          await pumpUi(
            t,
            RateField(title: 'Supermercados', source: entry.key),
            lang: lang,
          );
          expect(find.text(entry.value), findsOneWidget);
        });
      }
    }

    testWidgets('quote, error and typed value', (t) async {
      final controller = TextEditingController();
      final changes = <String>[];
      await pumpUi(
        t,
        RateField(
          title: 'Supermercados',
          source: RateSource.detected,
          quote: 'Acumula 7% Supermercados',
          errorText: 'Escribe el porcentaje',
          controller: controller,
          onChanged: changes.add,
        ),
      );
      expect(find.text('“Acumula 7% Supermercados”'), findsOneWidget);
      expect(find.text('Escribe el porcentaje'), findsOneWidget);
      await t.enterText(find.byType(TextField), '7.5');
      expect(changes.last, '7.5');
      await t.enterText(find.byType(TextField), 'abc');
      expect(controller.text, isEmpty);
    });
  });

  testWidgets('FilterSegmented shows counters and reports taps', (t) async {
    var selected = 0;
    await pumpUi(
      t,
      StatefulBuilder(
        builder: (_, set) => FilterSegmented<int>(
          selected: selected,
          onChanged: (v) => set(() => selected = v),
          options: const [
            FilterOption(value: 0, label: 'Todos', count: 52),
            FilterOption(value: 1, label: 'Rubro', count: 26),
            FilterOption(value: 2, label: 'Sin', count: 12),
            FilterOption(value: 3, label: 'Excl.', count: 14),
          ],
        ),
      ),
    );
    expect(find.text('52'), findsOneWidget);
    await t.tap(find.text('Sin'));
    await t.pump();
    expect(selected, 2);
  });

  testWidgets('CollapsibleWarning expands and collapses', (t) async {
    await pumpUi(
      t,
      const CollapsibleWarning(title: '2 avisos', messages: ['Uno', 'Dos']),
    );
    expect(find.text('Uno'), findsNothing);
    await t.tap(find.text('2 avisos'));
    await t.pumpAndSettle();
    expect(find.text('Uno'), findsOneWidget);
    expect(find.text('Dos'), findsOneWidget);
    await t.tap(find.text('2 avisos'));
    await t.pumpAndSettle();
    expect(find.text('Uno'), findsNothing);
  });

  group('StepProgress', () {
    testWidgets('Spanish and back', (t) async {
      var back = 0;
      await pumpUi(t, StepProgress(step: 2, onBack: () => back++));
      expect(find.text('Paso 2 de 5'), findsOneWidget);
      await t.tap(find.text('Atrás'));
      expect(back, 1);
    });

    testWidgets('English', (t) async {
      await pumpUi(t, const StepProgress(step: 4), lang: 'en');
      expect(find.text('Step 4 of 5'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });
  });

  testWidgets('AppBottomSheet shows title, body and actions', (t) async {
    await pumpUi(
      t,
      Builder(
        builder: (context) => AppButton(
          label: 'open',
          onPressed: () => showAppBottomSheet<void>(
            context: context,
            builder: (_) => AppBottomSheet(
              title: 'Cambiar rubro',
              subtitle: 'Sub',
              actions: [AppButton(label: 'Guardar', onPressed: () {})],
              child: const Text('cuerpo'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Cambiar rubro'), findsOneWidget);
    expect(find.text('cuerpo'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    final sheet = t.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet, isNotNull);
    final shape =
        Theme.of(t.element(find.byType(BottomSheet))).bottomSheetTheme.shape
            as RoundedRectangleBorder;
    expect(
      shape.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(28)),
    );
  });
}
