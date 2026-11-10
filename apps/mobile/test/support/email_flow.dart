import 'package:cashback_audit/core/network/session_events.dart';
import 'package:cashback_audit/features/auth/domain/auth_entities.dart';
import 'package:cashback_audit/features/auth/domain/auth_repository.dart';
import 'package:cashback_audit/features/auth/presentation/email_sign_in_controller.dart';
import 'package:cashback_audit/features/auth/presentation/login_controller.dart';
import 'package:cashback_audit/features/auth/presentation/session_controller.dart';

import 'fakes.dart';

/// Scriptable repository for the email-code flow.
class FakeEmailRepo implements AuthRepository {
  FakeEmailRepo({
    this.user = const AppUser(id: 'u1', email: 'ana@example.com'),
    this.providers = AuthProviders.emailOnly,
  });

  AppUser user;
  AuthProviders providers;
  Object? providersError;
  Object? startError;
  Object? verifyError;
  EmailChallenge challenge = const EmailChallenge(
    expiresInSeconds: 600,
    resendAfterSeconds: 60,
  );
  final starts = <({String email, String locale})>[];
  final verifies = <({String email, String code})>[];

  @override
  Future<EmailChallenge> startEmailSignIn({
    required String email,
    required String locale,
  }) async {
    starts.add((email: email, locale: locale));
    if (startError != null) throw startError!;
    return challenge;
  }

  @override
  Future<AppUser> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    verifies.add((email: email, code: code));
    if (verifyError != null) throw verifyError!;
    return user;
  }

  @override
  Future<AuthProviders> fetchProviders() async {
    if (providersError != null) throw providersError!;
    return providers;
  }

  @override
  Future<AppUser> signInWithGoogle() async => user;
  @override
  Future<AppUser> signInWithApple() async => user;
  @override
  Future<AppUser?> cachedUser() async => null;
  @override
  Future<AppUser?> loadUser() async => user;
  @override
  Future<void> signOut() async {}
}

class EmailFlow {
  EmailFlow({
    FakeEmailRepo? repo,
    this.lang = 'es',
    bool apple = true,
    bool dev = false,
  }) : repo = repo ?? FakeEmailRepo() {
    session = SessionController(
      repository: this.repo,
      events: SessionEvents(),
      clearLocalData: () async {},
      navigator: nav,
    );
    login = LoginController(
      repository: this.repo,
      session: session,
      navigator: nav,
      showApple: apple,
      devSignIn: dev ? () async => const AppUser(id: 'dev') : null,
    );
    email = EmailSignInController(
      repository: this.repo,
      login: login,
      localeCode: () => lang,
    );
    _live.add(this);
  }

  final FakeEmailRepo repo;
  String lang;
  final nav = FakeNavigator();
  late final SessionController session;
  late final LoginController login;
  late final EmailSignInController email;

  /// Every flow built since the last [stopAll], so a test body can stop the
  /// countdown timers before the framework checks for pending timers.
  static final _live = <EmailFlow>[];

  static void stopAll() {
    for (final f in _live) {
      f.email.cancelTimers();
    }
    _live.clear();
  }

  void dispose() => email.onClose();
}
