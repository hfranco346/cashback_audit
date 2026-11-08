import 'dart:async';

import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/network/session_events.dart';
import 'package:cashback_audit/features/auth/domain/auth_entities.dart';
import 'package:cashback_audit/features/auth/domain/auth_repository.dart';
import 'package:cashback_audit/features/auth/presentation/login_controller.dart';
import 'package:cashback_audit/features/auth/presentation/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

class _Repo implements AuthRepository {
  _Repo({this.googleResult, this.googleError});
  final AppUser? googleResult;
  final Object? googleError;
  Completer<AppUser>? gate;
  int signOuts = 0;

  @override
  Future<AppUser> signInWithGoogle() async {
    if (gate != null) return gate!.future;
    if (googleError != null) throw googleError!;
    return googleResult!;
  }

  @override
  Future<AppUser> signInWithApple() => signInWithGoogle();
  @override
  Future<AppUser?> cachedUser() async => null;
  @override
  Future<AppUser?> loadUser() async => googleResult;
  @override
  Future<void> signOut() async => signOuts++;
}

void main() {
  const user = AppUser(id: 'u1', name: 'Ana');
  late FakeNavigator nav;
  setUp(() => nav = FakeNavigator());

  (LoginController, SessionController, _Repo) build(_Repo repo) {
    final session = SessionController(
      repository: repo,
      events: SessionEvents(),
      clearLocalData: () async {},
      navigator: nav,
    );
    return (
      LoginController(
        repository: repo,
        session: session,
        navigator: nav,
        showApple: true,
      ),
      session,
      repo,
    );
  }

  test('successful sign-in sets the session user and runs hooks', () async {
    final (login, session, _) = build(_Repo(googleResult: user));
    AppUser? hooked;
    session.addSignedInHook((u) async => hooked = u);
    await login.signInWithGoogle();
    expect(session.user.value, user);
    expect(hooked, user);
    expect(login.errorMessage.value, isNull);
    expect(login.loading.value, isNull);
    expect(nav.routes, ['/home']);
  });

  test('development sign-in is off unless a callback is given', () async {
    final (login, session, _) = build(_Repo(googleResult: user));
    expect(login.showDevSignIn, isFalse);
    await login.signInForDevelopment();
    expect(session.user.value, isNull);
    expect(nav.routes, isEmpty);
  });

  test('development sign-in signs in and goes home', () async {
    final repo = _Repo(googleResult: user);
    final session = SessionController(
      repository: repo,
      events: SessionEvents(),
      clearLocalData: () async {},
      navigator: nav,
    );
    final login = LoginController(
      repository: repo,
      session: session,
      navigator: nav,
      showApple: false,
      devSignIn: () async => user,
    );
    expect(login.showDevSignIn, isTrue);
    await login.signInForDevelopment();
    expect(session.user.value, user);
    expect(nav.routes, ['/home']);
  });

  test('cancellation is silent', () async {
    final (login, session, _) = build(
      _Repo(googleError: const SignInCancelled()),
    );
    await login.signInWithGoogle();
    expect(login.errorMessage.value, isNull);
    expect(session.user.value, isNull);
  });

  test('failures show a Spanish message', () async {
    final (login, _, _) = build(
      _Repo(googleError: const AppException(kind: AppErrorKind.network)),
    );
    await login.signInWithGoogle();
    expect(login.errorMessage.value, S.errNetwork);
  });

  test('ignores taps while a sign-in is running', () async {
    final repo = _Repo(googleResult: user)..gate = Completer<AppUser>();
    final (login, _, _) = build(repo);
    final first = login.signInWithGoogle();
    expect(login.loading.value, LoginProvider.google);
    await login.signInWithApple(); // no-op
    repo.gate!.complete(user);
    await first;
    expect(login.loading.value, isNull);
  });

  test('session expiry clears the user and local data', () async {
    final events = SessionEvents();
    var cleared = 0;
    final repo = _Repo(googleResult: user);
    final session = SessionController(
      repository: repo,
      events: events,
      clearLocalData: () async => cleared++,
      navigator: nav,
    )..onInit();
    session.user.value = user;
    events.notifyExpired();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(session.user.value, isNull);
    expect(cleared, 1);
    expect(nav.routes, ['/login']);
    expect(nav.notices, hasLength(1));
    session.onClose();
  });

  test('signOut revokes, clears and runs sign-out hooks', () async {
    final repo = _Repo(googleResult: user);
    var cleared = 0;
    var hookRan = false;
    final session = SessionController(
      repository: repo,
      events: SessionEvents(),
      clearLocalData: () async => cleared++,
      navigator: nav,
    )..addSignedOutHook(() async => hookRan = true);
    await session.signOut();
    expect(repo.signOuts, 1);
    expect(cleared, 1);
    expect(hookRan, isTrue);
  });
}
