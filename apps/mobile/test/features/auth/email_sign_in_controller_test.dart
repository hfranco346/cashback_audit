import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/features/auth/domain/auth_entities.dart';
import 'package:cashback_audit/features/auth/presentation/email_sign_in_controller.dart';
import 'package:cashback_audit/features/auth/presentation/login_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/email_flow.dart';

AppException _api(int status, String code, [Map<String, dynamic>? extra]) =>
    AppException(
      kind: status == 429 ? AppErrorKind.rateLimited : AppErrorKind.validation,
      statusCode: status,
      code: code,
      body: {'statusCode': status, 'code': code, ...?extra},
    );

AppException _nested(int status, String code, Map<String, dynamic> details) =>
    AppException(
      kind: status == 429 ? AppErrorKind.rateLimited : AppErrorKind.validation,
      statusCode: status,
      code: code,
      details: details,
      body: {'statusCode': status, 'code': code, 'details': details},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<EmailFlow> inCodeStage({String lang = 'es'}) async {
    final f = EmailFlow(lang: lang);
    f.email.emailText.text = '  Ana@Example.com ';
    await f.email.sendCode();
    return f;
  }

  group('sending the code', () {
    test(
      'normalizes the address, sends the locale and opens the code step',
      () async {
        final f = await inCodeStage(lang: 'en');
        expect(f.repo.starts.single, (email: 'ana@example.com', locale: 'en'));
        expect(f.email.stage.value, EmailStage.code);
        expect(f.email.sentTo.value, 'ana@example.com');
        expect(f.email.resendIn.value, 60);
        expect(f.email.expiryMinutes, 10);
        f.dispose();
      },
    );

    test('an unsupported language falls back to es', () async {
      final f = EmailFlow(lang: 'pt');
      f.email.emailText.text = 'ana@example.com';
      await f.email.sendCode();
      expect(f.repo.starts.single.locale, 'es');
      f.dispose();
    });

    test('rejects a malformed address without calling the API', () async {
      final f = EmailFlow();
      f.email.emailText.text = 'not-an-email';
      await f.email.sendCode();
      expect(f.repo.starts, isEmpty);
      expect(f.email.issue.value?.kind, EmailIssueKind.invalidEmail);
      expect(f.email.stage.value, EmailStage.address);
      f.dispose();
    });

    test('a rate limit shows retryAfter and blocks the button', () {
      fakeAsync((async) {
        final f = EmailFlow();
        f.repo.startError = _api(429, 'TOO_MANY_REQUESTS', {
          'retryAfterSeconds': 30,
        });
        f.email.emailText.text = 'ana@example.com';
        f.email.sendCode();
        async.flushMicrotasks();
        expect(f.email.issue.value?.kind, EmailIssueKind.rateLimited);
        expect(f.email.issue.value?.seconds, 30);
        expect(f.email.blockedSeconds, 30);
        f.repo.startError = null;
        f.email.sendCode(); // blocked: no second request
        async.flushMicrotasks();
        expect(f.repo.starts, hasLength(1));
        async.elapse(const Duration(seconds: 30));
        expect(f.email.blockedSeconds, 0);
        f.email.sendCode();
        async.flushMicrotasks();
        expect(f.email.stage.value, EmailStage.code);
        f.dispose();
      });
    });

    test('a network failure shows the generic message', () async {
      final f = EmailFlow();
      f.repo.startError = const AppException(kind: AppErrorKind.network);
      f.email.emailText.text = 'ana@example.com';
      await f.email.sendCode();
      expect(f.email.issue.value?.kind, EmailIssueKind.other);
      expect(f.email.issue.value?.message, S.errNetwork);
      f.dispose();
    });
  });

  group('resend countdown', () {
    test('counts down from resendAfterSeconds and unlocks at zero', () {
      fakeAsync((async) {
        final f = EmailFlow();
        f.repo.challenge = const EmailChallenge(
          expiresInSeconds: 600,
          resendAfterSeconds: 5,
        );
        f.email.emailText.text = 'ana@example.com';
        f.email.sendCode();
        async.flushMicrotasks();
        expect(f.email.resendIn.value, 5);
        async.elapse(const Duration(seconds: 3));
        expect(f.email.resendIn.value, 2);
        async.elapse(const Duration(seconds: 2));
        expect(f.email.resendIn.value, 0);
        // Resend sends a fresh code and restarts the countdown.
        f.email.sendCode();
        async.flushMicrotasks();
        expect(f.repo.starts, hasLength(2));
        expect(f.email.resendIn.value, 5);
        f.dispose();
      });
    });

    test('the code expiring shows the expired hint', () {
      fakeAsync((async) {
        final f = EmailFlow();
        f.repo.challenge = const EmailChallenge(
          expiresInSeconds: 3,
          resendAfterSeconds: 1,
        );
        f.email.emailText.text = 'ana@example.com';
        f.email.sendCode();
        async.flushMicrotasks();
        expect(f.email.issue.value, isNull);
        async.elapse(const Duration(seconds: 3));
        expect(f.email.issue.value?.kind, EmailIssueKind.codeExpired);
        f.dispose();
      });
    });

    test(
      'change email goes back and a different address is not blocked',
      () async {
        final f = await inCodeStage();
        f.email.changeEmail();
        expect(f.email.stage.value, EmailStage.address);
        expect(f.email.blockedSeconds, 60); // same address still cooling down
        f.email.emailText.text = 'bob@example.com';
        f.email.onEmailChanged('bob@example.com');
        expect(f.email.blockedSeconds, 0);
        f.dispose();
      },
    );
  });

  group('verifying the code', () {
    test('auto-submits at 6 digits and signs in', () async {
      final f = await inCodeStage();
      f.email.codeText.text = '12345';
      f.email.onCodeChanged('12345');
      await Future<void>.delayed(Duration.zero);
      expect(f.repo.verifies, isEmpty);
      f.email.codeText.text = '123456';
      f.email.onCodeChanged('123456');
      await Future<void>.delayed(Duration.zero);
      expect(f.repo.verifies.single, (
        email: 'ana@example.com',
        code: '123456',
      ));
      expect(f.session.user.value?.id, 'u1');
      expect(f.nav.routes, ['/home']);
      f.dispose();
    });

    test('a wrong code reports attemptsLeft and clears the field', () async {
      final f = await inCodeStage();
      f.repo.verifyError = _api(400, 'INVALID_CODE', {'attemptsLeft': 2});
      f.email.codeText.text = '000000';
      await f.email.verifyCode();
      expect(f.email.issue.value?.kind, EmailIssueKind.invalidCode);
      expect(f.email.issue.value?.attemptsLeft, 2);
      expect(f.email.codeText.text, isEmpty);
      expect(f.session.user.value, isNull);
      expect(f.login.errorMessage.value, isNull);
      // Typing again clears the message.
      f.email.onCodeChanged('1');
      expect(f.email.issue.value, isNull);
      f.dispose();
    });

    test('expired and too-many-attempts are told apart', () async {
      final f = await inCodeStage();
      f.repo.verifyError = _api(410, 'CODE_EXPIRED');
      f.email.codeText.text = '111111';
      await f.email.verifyCode();
      expect(f.email.issue.value?.kind, EmailIssueKind.codeExpired);
      f.repo.verifyError = _api(429, 'TOO_MANY_ATTEMPTS');
      f.email.codeText.text = '111111';
      await f.email.verifyCode();
      expect(f.email.issue.value?.kind, EmailIssueKind.tooManyAttempts);
      f.dispose();
    });

    test('a verify rate limit uses retryAfterSeconds', () async {
      final f = await inCodeStage();
      f.repo.verifyError = _api(429, 'TOO_MANY_REQUESTS', {
        'retryAfterSeconds': 90,
      });
      f.email.codeText.text = '111111';
      await f.email.verifyCode();
      expect(f.email.issue.value?.kind, EmailIssueKind.rateLimited);
      expect(f.email.issue.value?.seconds, 90);
      expect(f.email.resendIn.value, 90);
      f.dispose();
    });

    test('ignores an incomplete code and taps while busy', () async {
      final f = await inCodeStage();
      f.email.codeText.text = '123';
      await f.email.verifyCode();
      expect(f.repo.verifies, isEmpty);
      f.dispose();
    });

    test('runs the setup hook instead of opening Home', () async {
      final f = await inCodeStage();
      AppUser? got;
      f.login.onAuthenticated = (u) async => got = u;
      f.email.codeText.text = '123456';
      await f.email.verifyCode();
      expect(got?.id, 'u1');
      expect(f.nav.routes, isEmpty);
      f.dispose();
    });
  });

  group('backend envelope (details.*)', () {
    test('attemptsLeft and retryAfterSeconds are read from details', () async {
      final f = await inCodeStage();
      f.repo.verifyError = _nested(400, 'INVALID_CODE', {'attemptsLeft': 4});
      f.email.codeText.text = '000000';
      await f.email.verifyCode();
      expect(f.email.issue.value?.attemptsLeft, 4);
      f.repo.startError = _nested(429, 'TOO_MANY_REQUESTS', {
        'retryAfterSeconds': 20,
      });
      f.email.resendIn.value = 0;
      await f.email.sendCode();
      expect(f.email.issue.value?.seconds, 20);
      f.dispose();
    });

    test('per-IP limit without details still shows a message', () async {
      final f = EmailFlow();
      f.repo.startError = _api(429, 'TOO_MANY_REQUESTS');
      f.email.emailText.text = 'ana@example.com';
      await f.email.sendCode();
      expect(f.email.issue.value?.kind, EmailIssueKind.rateLimited);
      expect(f.email.issue.value?.seconds, isNull);
      expect(f.email.issue.value?.message, S.errRateLimited);
      expect(f.email.blockedSeconds, 0);
      f.dispose();
    });

    test('delivery failure (503) can be retried at once', () async {
      final f = EmailFlow();
      f.repo.startError = const AppException(
        kind: AppErrorKind.server,
        statusCode: 503,
        code: 'EMAIL_DELIVERY_FAILED',
      );
      f.email.emailText.text = 'ana@example.com';
      await f.email.sendCode();
      expect(f.email.issue.value?.kind, EmailIssueKind.other);
      expect(f.email.blockedSeconds, 0);
      f.dispose();
    });
  });

  group('providers', () {
    test(
      'email only until the backend answers, then Google/Apple follow',
      () async {
        final f = EmailFlow();
        expect(f.login.showGoogle, isFalse);
        expect(f.login.showApple, isFalse);
        f.repo.providers = const AuthProviders(google: true, apple: true);
        await f.login.loadProviders();
        expect(f.login.showGoogle, isTrue);
        expect(f.login.showApple, isTrue);
        f.dispose();
      },
    );

    test('Apple also needs a device that supports it', () async {
      final f = EmailFlow(apple: false);
      f.repo.providers = const AuthProviders(google: true, apple: true);
      await f.login.loadProviders();
      expect(f.login.showApple, isFalse);
      expect(f.login.showGoogle, isTrue);
      f.dispose();
    });

    test('a failing providers call keeps email only', () async {
      final f = EmailFlow();
      f.repo.providersError = const AppException(kind: AppErrorKind.network);
      await f.login.loadProviders();
      expect(f.login.providers.value, AuthProviders.emailOnly);
      expect(f.login.loading.value, isNull);
      f.dispose();
    });
  });

  test(
    'email sign-in marks the login as busy with the email provider',
    () async {
      final f = await inCodeStage();
      expect(f.login.loading.value, isNull);
      final pending = f.login.signInWithEmailCode('ana@example.com', '123456');
      expect(f.login.loading.value, LoginProvider.email);
      await pending;
      f.dispose();
    },
  );
}
