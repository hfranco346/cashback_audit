import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';

import 'package:cashback_audit/features/auth/domain/auth_entities.dart';

import '../../support/email_flow.dart';

import 'package:cashback_audit/features/auth/presentation/widgets/login_view.dart';
import 'package:cashback_audit/features/onboarding/presentation/widgets/account_step.dart';
import 'package:cashback_audit/features/onboarding/presentation/widgets/demo_step.dart';
import 'package:cashback_audit/features/onboarding/presentation/widgets/first_pdf_step.dart';
import 'package:cashback_audit/features/onboarding/presentation/widgets/setup_steps.dart';
import 'package:cashback_audit/features/onboarding/presentation/widgets/verdict_step.dart';
import 'package:cashback_audit/features/onboarding/domain/onboarding_draft.dart';
import 'package:cashback_audit/features/onboarding/presentation/onboarding_controller.dart';
import 'package:cashback_audit/features/settings/data/locale_preference_repository_impl.dart';
import 'package:cashback_audit/features/settings/domain/locale_preference.dart';
import 'package:cashback_audit/features/settings/presentation/locale_controller.dart';
import 'package:cashback_audit/features/splash/presentation/splash_page.dart';
import 'package:cashback_audit/features/splash/presentation/splash_controller.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/core/storage/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../core/ui/ui_harness.dart';
import '../../support/fakes.dart';
import '../../support/fixtures.dart';
import 'onboarding_test.dart' show Harness;

Widget _account(
  Harness h, {
  bool dev = false,
  bool apple = true,
  AuthProviders providers = AuthProviders.emailOnly,
}) {
  final flow = EmailFlow(apple: apple, dev: dev);
  flow.login.providers.value = providers;
  return AccountStep(controller: h.c, login: flow.login, email: flow.email);
}

LocaleController _locale(List<Locale> applied) => LocaleController(
  repository: LocalePreferenceRepositoryImpl(freshPrefs()),
  systemLocale: () => const Locale('es', 'MX'),
  applyLocale: applied.add,
);

void main() {
  // Every step must render in light/dark and ES/EN.
  const variants = [
    (dark: false, lang: 'es'),
    (dark: true, lang: 'es'),
    (dark: false, lang: 'en'),
    (dark: true, lang: 'en'),
  ];

  for (final v in variants) {
    final tag = '${v.lang}${v.dark ? ' dark' : ''}';

    testWidgets('demo step renders ($tag)', (tester) async {
      final locale = _locale([]);
      var started = 0;
      await pumpUi(
        tester,
        DemoStep(
          locale: locale,
          onStart: () => started++,
          onHaveAccount: () {},
        ),
        dark: v.dark,
        lang: v.lang,
      );
      await tester.pump(const Duration(seconds: 3));
      expect(
        find.text(
          v.lang == 'es'
              ? '¿Tu banco te pagó todo tu cashback?'
              : 'Did your bank pay all your cashback?',
        ),
        findsOneWidget,
      );
      expect(find.text('HNL 1,526.84'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onb-start')));
      expect(started, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('setup steps render ($tag)', (tester) async {
      final h = Harness();
      await h.c.load();
      await h.c.start();
      h.c.selectBank('BAC Credomatic');
      for (final step in <Widget>[
        BankStep(controller: h.c),
        CardStep(controller: h.c),
        CategoriesStep(controller: h.c),
      ]) {
        await pumpUi(tester, step, dark: v.dark, lang: v.lang);
        await tester.pump(const Duration(seconds: 1));
        expect(find.byKey(const Key('onb-continue')), findsOneWidget);
        expect(find.byKey(const Key('onb-skip')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('splash and login render ($tag)', (tester) async {
      addTearDown(Get.reset);
      Get.put(
        SplashController(
          onboarding: Harness().seen,
          tokens: InMemoryTokenStorage(),
          navigator: FakeNavigator(),
          minimumDelay: const Duration(milliseconds: 1),
        ),
      );
      await pumpUi(tester, const SplashPage(), dark: v.dark, lang: v.lang);
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.text(
          v.lang == 'es'
              ? 'LO QUE TU BANCO TE DEBE'
              : 'WHAT YOUR BANK OWES YOU',
        ),
        findsOneWidget,
      );
      Get.reset();
      await pumpUi(
        tester,
        LoginView(
          emailSection: const SizedBox(),
          onGoogle: () {},
          onApple: () {},
          showApple: true,
        ),
        dark: v.dark,
        lang: v.lang,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('login-google')), findsOneWidget);
      expect(find.byKey(const Key('login-apple')), findsOneWidget);
    });
  }

  testWidgets('the language menu calls LocaleController.select', (
    tester,
  ) async {
    final applied = <Locale>[];
    final locale = _locale(applied);
    await pumpUi(
      tester,
      DemoStep(locale: locale, onStart: () {}, onHaveAccount: () {}),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byKey(const Key('onb-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onb-language-en')));
    await tester.pumpAndSettle();
    expect(locale.preference.value, LocalePreference.en);
    expect(applied.last, const Locale('en'));
  });

  group('bank / card / categories steps', () {
    testWidgets('bank: Continue needs a bank; "other" takes a name', (
      tester,
    ) async {
      final h = Harness();
      await h.c.load();
      await h.c.start();
      await pumpUi(tester, BankStep(controller: h.c));
      await tester.pump(const Duration(seconds: 1));
      FilledButton cont() => tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('onb-continue')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(cont().onPressed, isNull);
      await tester.tap(find.byKey(const Key('bank-BAC Credomatic')));
      await tester.pump();
      expect(h.c.draft.value.bank, 'BAC Credomatic');
      expect(cont().onPressed, isNotNull);
      await tester.ensureVisible(find.byKey(const Key('bank-other')));
      await tester.tap(find.byKey(const Key('bank-other')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('onb-bank-other-name')),
        'Mi Banco',
      );
      expect(h.c.draft.value.bank, 'Mi Banco');
      await tester.enterText(find.byKey(const Key('onb-bank-search')), 'zzz');
      await tester.pump();
      expect(find.byKey(const Key('bank-BAC Credomatic')), findsNothing);
    });

    testWidgets('card: typing fills the draft and the live card preview', (
      tester,
    ) async {
      final h = Harness();
      await h.c.load();
      h.c.selectBank('BAC Credomatic');
      await pumpUi(tester, CardStep(controller: h.c));
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(
        find.byKey(const Key('onb-card-name')),
        'BAC Cash',
      );
      await tester.enterText(find.byKey(const Key('onb-card-last4')), '48219');
      await tester.tap(find.byKey(const Key('currency-HNL')));
      await tester.pump();
      expect(h.c.draft.value.alias, 'BAC Cash');
      expect(h.c.draft.value.last4, '4821'); // capped at 4 digits
      expect(h.c.draft.value.currency, 'HNL');
      expect(find.text('•••• 4821'), findsOneWidget);
      await tester.tap(find.byKey(const Key('currency-detect')));
      await tester.pump();
      expect(h.c.draft.value.currency, isNull);
    });

    for (final lang in ['es', 'en']) {
      testWidgets('categories are prefilled like the design ($lang)', (
        tester,
      ) async {
        final h = Harness();
        await h.c.load();
        await pumpUi(tester, CategoriesStep(controller: h.c), lang: lang);
        await tester.pump(const Duration(seconds: 1));
        final names = lang == 'es'
            ? ['Supermercados', 'Farmacia']
            : ['Supermarkets', 'Pharmacy'];
        expect(h.c.draft.value.categories.map((e) => e.name), names);
        expect(h.c.draft.value.categories.map((e) => e.rate), ['7', '7']);
        for (final n in names) {
          expect(h.c.isSelected(n), isTrue);
          final field = tester.widget<TextField>(
            find.byKey(Key('cat-rate-$n')),
          );
          expect(field.controller?.text, '7');
        }
        expect(h.c.draft.value.baseRate, '0');
        // Deselecting sticks: coming back never restores the suggestion.
        await tester.tap(find.byKey(Key('cat-${names.first}')));
        await tester.pump();
        expect(h.c.isSelected(names.first), isFalse);
        await pumpUi(tester, CategoriesStep(controller: h.c), lang: lang);
        await tester.pump(const Duration(seconds: 1));
        expect(h.c.isSelected(names.first), isFalse);
        expect(h.c.isSelected(names.last), isTrue);
      });
    }

    testWidgets('categories: tick, set % and add another category', (
      tester,
    ) async {
      final h = Harness();
      await h.c.load();
      await pumpUi(tester, CategoriesStep(controller: h.c));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const Key('cat-Gasolineras')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('cat-rate-Gasolineras')),
        '3',
      );
      expect(
        h.c.draft.value.categories.last,
        const DraftCategory(name: 'Gasolineras', rate: '3'),
      );
      await tester.ensureVisible(find.byKey(const Key('onb-add-category')));
      await tester.tap(find.byKey(const Key('onb-add-category')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('onb-custom-category')),
        'Mascotas',
      );
      await tester.tap(find.byKey(const Key('onb-custom-category-add')));
      await tester.pumpAndSettle();
      expect(h.c.isSelected('Mascotas'), isTrue);
      expect(find.byKey(const Key('cat-Mascotas')), findsOneWidget);
    });
  });

  group('account, first PDF and verdict', () {
    testWidgets('account shows the summary and the dev sign-in', (
      tester,
    ) async {
      final h = Harness();
      await h.fillSetup();
      await pumpUi(
        tester,
        _account(
          h,
          dev: true,
          providers: const AuthProviders(google: true, apple: true),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('BAC Cash •••• 4821'), findsOneWidget);
      expect(find.text('7%'), findsNWidgets(2));
      expect(find.byKey(const Key('onb-apple')), findsOneWidget);
      expect(find.byKey(const Key('onb-google')), findsOneWidget);
      expect(find.byKey(const Key('dev-sign-in')), findsOneWidget);
    });

    testWidgets('account without dev/apple hides those buttons', (
      tester,
    ) async {
      final h = Harness();
      await h.fillSetup();
      await pumpUi(tester, _account(h, apple: false));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('onb-apple')), findsNothing);
      expect(find.byKey(const Key('dev-sign-in')), findsNothing);
    });

    testWidgets('account shows retry when the sync failed', (tester) async {
      final h = Harness();
      await h.fillSetup();
      h.c.syncError.value = 'boom';
      await pumpUi(
        tester,
        _account(h, providers: const AuthProviders(google: true, apple: true)),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('onb-retry-sync')), findsOneWidget);
      expect(find.byKey(const Key('onb-google')), findsNothing);
    });

    testWidgets('first PDF: pick, analyze, processing with leave option', (
      tester,
    ) async {
      final h = Harness();
      await h.fillSetup();
      await h.c.next();
      await h.c.afterSignIn(const AppUser(id: 'u'));
      await pumpUi(tester, FirstPdfStep(controller: h.c, userName: 'Ana'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Hola, Ana'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onb-pick-pdf')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Estado.pdf'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onb-analyze')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.c.pdfPhase.value, FirstPdfPhase.processing);
      expect(find.byKey(const Key('processing-step-0')), findsOneWidget);
      expect(find.byKey(const Key('onb-leave')), findsOneWidget);
      await tester.tap(find.byKey(const Key('onb-leave')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.nav.routes.last, '/home');
      // Dispose the checklist timers.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('first PDF failure explains the refund', (tester) async {
      final h = Harness();
      await h.fillSetup();
      h.c.pdfPhase.value = FirstPdfPhase.failed;
      h.c.failure.value = FailureCode.notAStatement;
      await pumpUi(tester, FirstPdfStep(controller: h.c));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('onb-failure')), findsOneWidget);
      expect(find.byKey(const Key('onb-retry-pdf')), findsOneWidget);
    });

    for (final v in variants) {
      testWidgets('verdict reveal (${v.lang}${v.dark ? ' dark' : ''})', (
        tester,
      ) async {
        final verification = VerificationMapper.detail(verificationJson());
        var detail = 0;
        await pumpUi(
          tester,
          VerdictStep(
            verification: verification,
            cardName: 'BAC Cash',
            categoryCount: 2,
            onDetail: () => detail++,
            onHome: () {},
          ),
          dark: v.dark,
          lang: v.lang,
        );
        await tester.pump(const Duration(seconds: 3));
        expect(find.byKey(const Key('onb-verdict-amount')), findsOneWidget);
        expect(
          find.text(
            v.lang == 'es' ? 'Te pagaron de menos' : 'You were underpaid',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('onb-detail')));
        expect(detail, 1);
      });
    }
  });
}
