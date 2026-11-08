import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/network/dio_factory.dart';
import 'package:cashback_audit/core/network/session_events.dart';
import 'package:cashback_audit/core/storage/token_storage.dart';
import 'package:cashback_audit/features/auth/data/auth_repository_impl.dart';
import 'package:cashback_audit/features/auth/domain/auth_entities.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_adapter.dart';
import '../../support/fakes.dart';

const _authBody = {
  'accessToken': 'acc',
  'refreshToken': 'ref',
  'tokenType': 'Bearer',
  'expiresIn': 900,
  'user': {'id': 'u1', 'email': 'ana@example.com', 'name': 'Ana Perez'},
};

void main() {
  late InMemoryTokenStorage tokens;
  late FakeAdapter adapter;

  AuthRepositoryImpl build({FakeApple? apple, FakeGoogle? google}) {
    tokens = InMemoryTokenStorage();
    return AuthRepositoryImpl(
      dio: buildDio(
        baseUrl: 'http://test/api/v1',
        tokens: tokens,
        events: SessionEvents(),
        adapter: adapter,
      ),
      tokens: tokens,
      prefs: freshPrefs(),
      google: google ?? FakeGoogle(),
      apple: apple ?? FakeApple(),
    );
  }

  test('google sign-in stores tokens and the user', () async {
    adapter = FakeAdapter((o) => const FakeResponse(200, _authBody));
    final repo = build();
    final user = await repo.signInWithGoogle();
    expect(
      user,
      const AppUser(id: 'u1', email: 'ana@example.com', name: 'Ana Perez'),
    );
    expect(adapter.requests.single.path, '/auth/google');
    expect(adapter.requests.single.data, {'idToken': 'google-id-token'});
    expect(
      await tokens.read(),
      const AuthTokens(accessToken: 'acc', refreshToken: 'ref'),
    );
    expect(await repo.cachedUser(), user);
  });

  test('apple sign-in sends fullName only when present', () async {
    adapter = FakeAdapter((o) => const FakeResponse(200, _authBody));
    final repo = build(
      apple: FakeApple(
        credential: const AppleCredential(
          identityToken: 'tok',
          fullName: 'Beto Gomez',
        ),
      ),
    );
    await repo.signInWithApple();
    expect(adapter.requests.single.data, {
      'identityToken': 'tok',
      'fullName': 'Beto Gomez',
    });

    adapter = FakeAdapter((o) => const FakeResponse(200, _authBody));
    final again = build();
    await again.signInWithApple();
    expect(adapter.requests.single.data, {'identityToken': 'apple-token'});
  });

  test('backend rejection maps to AppException and stores nothing', () async {
    adapter = FakeAdapter(
      (o) => const FakeResponse(401, {
        'statusCode': 401,
        'code': 'INVALID_IDENTITY_TOKEN',
        'message': 'x',
      }),
    );
    final repo = build();
    await expectLater(
      repo.signInWithGoogle(),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          'INVALID_IDENTITY_TOKEN',
        ),
      ),
    );
    expect(await tokens.read(), isNull);
  });

  test('loadUser falls back to the stored user when offline', () async {
    adapter = FakeAdapter((o) {
      if (o.path == '/auth/google') return const FakeResponse(200, _authBody);
      return const FakeResponse(-1);
    });
    final repo = build();
    await repo.signInWithGoogle();
    expect((await repo.loadUser())?.id, 'u1');
  });

  test(
    'signOut revokes remotely, clears tokens even if the call fails',
    () async {
      adapter = FakeAdapter((o) {
        if (o.path == '/auth/google') return const FakeResponse(200, _authBody);
        return const FakeResponse(-1);
      });
      final repo = build();
      await repo.signInWithGoogle();
      await repo.signOut();
      expect(adapter.requests.last.path, '/auth/logout');
      expect(adapter.requests.last.data, {'refreshToken': 'ref'});
      expect(await tokens.read(), isNull);
      expect(await repo.cachedUser(), isNull);
    },
  );

  test('AppUser.firstName', () {
    expect(const AppUser(id: '1', name: 'Ana Perez').firstName, 'Ana');
    expect(const AppUser(id: '1', email: 'bob@x.com').firstName, 'bob');
    expect(const AppUser(id: '1').firstName, isNull);
  });
}
