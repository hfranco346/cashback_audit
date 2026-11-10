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

  test('AppUser reads preferences from /me and from its own cache', () {
    final user = AppUser.fromJson({
      'id': 'u1',
      'primaryCurrency': 'HNL',
      'currencies': [
        {'code': 'HNL', 'lastRateToPrimary': null},
        {'code': 'USD', 'lastRateToPrimary': '24.7'},
      ],
    });
    expect(user.primaryCurrency, 'HNL');
    expect(user.currencies, ['HNL', 'USD']);
    expect(AppUser.fromJson(user.toJson()), user);
    expect(AppUser.fromJson({'id': 'u2'}).currencies, isEmpty);
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

  group('email code', () {
    test('start posts the address and the app language', () async {
      adapter = FakeAdapter(
        (o) => const FakeResponse(202, {
          'expiresInSeconds': 600,
          'resendAfterSeconds': 45,
        }),
      );
      final challenge = await build().startEmailSignIn(
        email: 'ana@example.com',
        locale: 'en',
      );
      expect(
        challenge,
        const EmailChallenge(expiresInSeconds: 600, resendAfterSeconds: 45),
      );
      expect(adapter.requests.single.path, '/auth/email/start');
      expect(adapter.requests.single.data, {
        'email': 'ana@example.com',
        'locale': 'en',
      });
    });

    test('start surfaces the rate limit with retryAfterSeconds', () async {
      adapter = FakeAdapter(
        (o) => const FakeResponse(429, {
          'statusCode': 429,
          'code': 'TOO_MANY_REQUESTS',
          'message': 'Too many',
          'retryAfterSeconds': 42,
        }),
      );
      await expectLater(
        build().startEmailSignIn(email: 'a@b.co', locale: 'es'),
        throwsA(
          isA<AppException>()
              .having((e) => e.kind, 'kind', AppErrorKind.rateLimited)
              .having((e) => e.code, 'code', 'TOO_MANY_REQUESTS')
              .having((e) => e.intField('retryAfterSeconds'), 'retry', 42),
        ),
      );
    });

    test('verify stores tokens and the user like other providers', () async {
      adapter = FakeAdapter((o) => const FakeResponse(200, _authBody));
      final repo = build();
      final user = await repo.verifyEmailCode(
        email: 'ana@example.com',
        code: '123456',
      );
      expect(user.id, 'u1');
      expect(adapter.requests.single.path, '/auth/email/verify');
      expect(adapter.requests.single.data, {
        'email': 'ana@example.com',
        'code': '123456',
      });
      expect(
        await tokens.read(),
        const AuthTokens(accessToken: 'acc', refreshToken: 'ref'),
      );
      expect(await repo.cachedUser(), user);
    });

    test('verify keeps attemptsLeft and the expired code', () async {
      adapter = FakeAdapter(
        (o) => const FakeResponse(400, {
          'statusCode': 400,
          'code': 'INVALID_CODE',
          'attemptsLeft': 3,
        }),
      );
      await expectLater(
        build().verifyEmailCode(email: 'a@b.co', code: '000000'),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', 'INVALID_CODE')
              .having((e) => e.intField('attemptsLeft'), 'left', 3),
        ),
      );
      adapter = FakeAdapter(
        (o) => const FakeResponse(410, {
          'statusCode': 410,
          'code': 'CODE_EXPIRED',
        }),
      );
      await expectLater(
        build().verifyEmailCode(email: 'a@b.co', code: '000000'),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'CODE_EXPIRED'),
        ),
      );
      expect(await tokens.read(), isNull);
    });

    test('providers are read from GET /auth/providers', () async {
      adapter = FakeAdapter(
        (o) => const FakeResponse(200, {
          'email': true,
          'google': false,
          'apple': true,
        }),
      );
      final providers = await build().fetchProviders();
      expect(providers, const AuthProviders(apple: true));
      expect(adapter.requests.single.path, '/auth/providers');
      expect(adapter.requests.single.method, 'GET');
    });
  });
}
