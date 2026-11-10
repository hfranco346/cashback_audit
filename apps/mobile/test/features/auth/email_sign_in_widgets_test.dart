import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/features/auth/domain/auth_entities.dart';
import 'package:cashback_audit/features/auth/presentation/email_sign_in_controller.dart';
import 'package:cashback_audit/features/auth/presentation/widgets/email_sign_in_section.dart';
import 'package:cashback_audit/features/auth/presentation/widgets/login_view.dart';
import 'package:cashback_audit/features/onboarding/domain/onboarding_draft.dart';
import 'package:cashback_audit/features/onboarding/presentation/widgets/account_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/ui/ui_harness.dart';
import '../../support/email_flow.dart';
import '../onboarding/onboarding_test.dart' show Harness;

const _variants = [
  (dark: false, lang: 'es'),
  (dark: true, lang: 'es'),
  (dark: false, lang: 'en'),
  (dark: true, lang: 'en'),
];

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget _login(EmailFlow f) => ListenableBuilder(
  listenable: f.email.codeText,
  builder: (_, _) => _LoginHost(f),
);

class _LoginHost extends StatelessWidget {
  const _LoginHost(this.f);
  final EmailFlow f;

  @override
  Widget build(BuildContext context) => LoginView(
    emailSection: EmailSignInSection(controller: f.email, login: f.login),
    onGoogle: f.login.signInWithGoogle,
    onApple: f.login.signInWithApple,
    showApple: f.login.showApple,
    showGoogle: f.login.showGoogle,
    onDevSignIn: f.login.showDevSignIn ? f.login.signInForDevelopment : null,
    showAlternatives: f.email.stage.value == EmailStage.address,
  );
}

Future<void> _sendCode(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('email-field')),
    'ana@example.com',
  );
  await tester.tap(find.byKey(const Key('email-send')));
  await _settle(tester);
}

/// [testWidgets] that stops the countdown timers before the framework checks
/// for pending ones.
void flowTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      EmailFlow.stopAll();
    }
  });
}

void main() {
  for (final v in _variants) {
    final tag = '${v.lang}${v.dark ? ' dark' : ''}';

    flowTest('login: email first, then the code step ($tag)', (tester) async {
      final f = EmailFlow(lang: v.lang, dev: true);
      f.login.providers.value = const AuthProviders(google: true, apple: true);
      await pumpUi(
        tester,
        ListenableBuilder(
          listenable: f.email.emailText,
          builder: (_, _) => _LoginHost(f),
        ),
        dark: v.dark,
        lang: v.lang,
      );
      await _settle(tester);
      final es = v.lang == 'es';
      expect(find.text(es ? 'Enviar código' : 'Send code'), findsOneWidget);
      expect(find.byKey(const Key('login-google')), findsOneWidget);
      expect(find.byKey(const Key('login-apple')), findsOneWidget);
      expect(find.byKey(const Key('dev-sign-in')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('email-field')), 'bad');
      await tester.tap(find.byKey(const Key('email-send')));
      await _settle(tester);
      expect(
        find.text(
          es
              ? 'Revisa tu correo: no parece válido.'
              : 'Check your email address: it does not look valid.',
        ),
        findsOneWidget,
      );

      await _sendCode(tester);
      expect(f.repo.starts.single.locale, v.lang);
      expect(find.byKey(const Key('email-code-field')), findsOneWidget);
      expect(find.byKey(const Key('email-sent-to')), findsOneWidget);
      expect(find.textContaining('ana@example.com'), findsWidgets);
      expect(
        find.text(es ? 'Reenviar en 60 s' : 'Resend in 60s'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('email-expiry-hint')), findsOneWidget);
      // The alternatives step aside while the code is typed.
      expect(find.byKey(const Key('login-google')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    flowTest('login: code errors are explained ($tag)', (tester) async {
      final f = EmailFlow(lang: v.lang);
      await pumpUi(tester, _login(f), dark: v.dark, lang: v.lang);
      await _settle(tester);
      await _sendCode(tester);
      final es = v.lang == 'es';

      f.repo.verifyError = const AppException(
        kind: AppErrorKind.validation,
        statusCode: 400,
        code: 'INVALID_CODE',
        body: {'attemptsLeft': 1},
      );
      await tester.enterText(
        find.byKey(const Key('email-code-field')),
        '000000',
      );
      await _settle(tester);
      expect(
        find.text(
          es
              ? 'Código incorrecto. Te queda 1 intento.'
              : 'That code is not correct. You have 1 try left.',
        ),
        findsOneWidget,
      );

      f.repo.verifyError = const AppException(
        kind: AppErrorKind.validation,
        statusCode: 410,
        code: 'CODE_EXPIRED',
      );
      await tester.enterText(
        find.byKey(const Key('email-code-field')),
        '111111',
      );
      await _settle(tester);
      expect(
        find.text(
          es
              ? 'El código venció. Pide uno nuevo.'
              : 'That code has expired. Request a new one.',
        ),
        findsOneWidget,
      );

      f.repo.verifyError = const AppException(
        kind: AppErrorKind.rateLimited,
        statusCode: 429,
        code: 'TOO_MANY_ATTEMPTS',
      );
      await tester.enterText(
        find.byKey(const Key('email-code-field')),
        '222222',
      );
      await _settle(tester);
      expect(
        find.text(
          es
              ? 'Demasiados intentos. Pide un código nuevo.'
              : 'Too many attempts. Request a new code.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  flowTest('pasting a full code submits it once, extra digits cut', (
    tester,
  ) async {
    final f = EmailFlow();
    await pumpUi(tester, _login(f));
    await _settle(tester);
    await _sendCode(tester);
    await tester.enterText(
      find.byKey(const Key('email-code-field')),
      '123 4567',
    );
    await _settle(tester);
    expect(f.repo.verifies.single.code, '123456');
    expect(f.nav.routes, ['/home']);
  });

  flowTest('the code field offers the one-time-code autofill hint', (
    tester,
  ) async {
    final f = EmailFlow();
    await pumpUi(tester, _login(f));
    await _settle(tester);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('email-field')))
          .autofillHints,
      contains(AutofillHints.email),
    );
    await _sendCode(tester);
    final field = tester.widget<TextField>(
      find.byKey(const Key('email-code-field')),
    );
    expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
    expect(field.keyboardType, TextInputType.number);
  });

  flowTest('resend counts down, then sends a new code; change goes back', (
    tester,
  ) async {
    final f = EmailFlow();
    f.repo.challenge = const EmailChallenge(
      expiresInSeconds: 600,
      resendAfterSeconds: 3,
    );
    await pumpUi(tester, _login(f));
    await _settle(tester);
    await _sendCode(tester);
    final resend = find.descendant(
      of: find.byKey(const Key('email-resend')),
      matching: find.byType(OutlinedButton),
    );
    expect(tester.widget<OutlinedButton>(resend).onPressed, isNull);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.widget<OutlinedButton>(resend).onPressed, isNotNull);
    await tester.tap(resend);
    await _settle(tester);
    expect(f.repo.starts, hasLength(2));

    await tester.tap(find.byKey(const Key('email-change')));
    await _settle(tester);
    expect(find.byKey(const Key('email-field')), findsOneWidget);
  });

  flowTest('a rate-limited send disables the button with the wait', (
    tester,
  ) async {
    final f = EmailFlow(lang: 'en');
    f.repo.startError = const AppException(
      kind: AppErrorKind.rateLimited,
      statusCode: 429,
      code: 'TOO_MANY_REQUESTS',
      body: {'retryAfterSeconds': 30},
    );
    await pumpUi(tester, _login(f), lang: 'en');
    await _settle(tester);
    await _sendCode(tester);
    expect(find.text('Too many requests. Try again in 30s.'), findsOneWidget);
    expect(find.text('Try again in 30s'), findsOneWidget);
  });

  group('onboarding account step', () {
    for (final v in _variants) {
      flowTest('email first, providers only when configured (${v.lang}'
          '${v.dark ? ' dark' : ''})', (tester) async {
        final h = Harness();
        await h.fillSetup();
        final f = EmailFlow(lang: v.lang, dev: true);
        await pumpUi(
          tester,
          AccountStep(controller: h.c, login: f.login, email: f.email),
          dark: v.dark,
          lang: v.lang,
        );
        await _settle(tester);
        expect(find.byKey(const Key('email-field')), findsOneWidget);
        expect(find.byKey(const Key('onb-google')), findsNothing);
        expect(find.byKey(const Key('onb-apple')), findsNothing);
        expect(find.byKey(const Key('dev-sign-in')), findsOneWidget);
        expect(find.text('BAC Cash •••• 4821'), findsOneWidget);

        f.login.providers.value = const AuthProviders(
          google: true,
          apple: true,
        );
        await _settle(tester);
        expect(find.byKey(const Key('onb-google')), findsOneWidget);
        expect(find.byKey(const Key('onb-apple')), findsOneWidget);

        await _sendCode(tester);
        expect(find.byKey(const Key('email-code-field')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    flowTest('signing in with the emailed code syncs the draft', (
      tester,
    ) async {
      final h = Harness();
      await h.fillSetup();
      await h.c.next(); // categories -> account
      final f = EmailFlow();
      f.login.onAuthenticated = h.c.afterSignIn;
      await pumpUi(
        tester,
        AccountStep(controller: h.c, login: f.login, email: f.email),
      );
      await _settle(tester);
      await _sendCode(tester);
      await tester.enterText(
        find.byKey(const Key('email-code-field')),
        '123456',
      );
      await _settle(tester);

      expect(f.session.user.value?.id, 'u1');
      expect(h.cards.created.single.last4, '4821');
      expect(h.c.step.value, OnboardingStep.pdf);
      expect(f.nav.routes, isEmpty);
    });

    flowTest('a failed sync after email sign-in offers retry', (tester) async {
      final h = Harness();
      await h.fillSetup();
      await h.c.next();
      h.cards.error = const AppException(kind: AppErrorKind.network);
      final f = EmailFlow();
      f.login.onAuthenticated = h.c.afterSignIn;
      await pumpUi(
        tester,
        AccountStep(controller: h.c, login: f.login, email: f.email),
      );
      await _settle(tester);
      await _sendCode(tester);
      await tester.enterText(
        find.byKey(const Key('email-code-field')),
        '123456',
      );
      await _settle(tester);
      expect(find.byKey(const Key('onb-retry-sync')), findsOneWidget);
      h.cards.error = null;
      await tester.tap(find.byKey(const Key('onb-retry-sync')));
      await _settle(tester);
      expect(h.cards.created, hasLength(1));
    });
  });
}
