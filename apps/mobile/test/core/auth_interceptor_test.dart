import 'dart:async';

import 'package:cashback_audit/core/network/dio_factory.dart';
import 'package:cashback_audit/core/network/session_events.dart';
import 'package:cashback_audit/core/storage/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_adapter.dart';

const _expired = FakeResponse(401, {
  'statusCode': 401,
  'code': 'INVALID_ACCESS_TOKEN',
  'message': 'x',
});

void main() {
  late InMemoryTokenStorage tokens;
  late SessionEvents events;
  late int expiredCount;

  setUp(() {
    tokens = InMemoryTokenStorage(
      const AuthTokens(accessToken: 'old', refreshToken: 'r1'),
    );
    events = SessionEvents();
    expiredCount = 0;
    events.onExpired.listen((_) => expiredCount++);
  });

  Dio client(FakeAdapter adapter) => buildDio(
    baseUrl: 'http://test/api/v1',
    tokens: tokens,
    events: events,
    adapter: adapter,
  );

  test('adds bearer token and skips it for /auth routes', () async {
    final adapter = FakeAdapter((o) => const FakeResponse(200, {'ok': true}));
    final dio = client(adapter);
    await dio.get<dynamic>('/cards');
    await dio.post<dynamic>('/auth/google', data: {'idToken': 'x'});
    expect(adapter.requests[0].headers['Authorization'], 'Bearer old');
    expect(adapter.requests[1].headers.containsKey('Authorization'), isFalse);
  });

  test('refreshes on 401 and retries once with the new token', () async {
    final adapter = FakeAdapter((o) {
      if (o.path == '/auth/refresh') {
        return const FakeResponse(200, {
          'accessToken': 'new',
          'refreshToken': 'r2',
        });
      }
      return o.headers['Authorization'] == 'Bearer new'
          ? const FakeResponse(200, {'ok': true})
          : _expired;
    });
    final res = await client(adapter).get<dynamic>('/cards');
    expect(res.statusCode, 200);
    expect(adapter.count('/auth/refresh'), 1);
    expect(adapter.count('/cards'), 2);
    expect(
      await tokens.read(),
      const AuthTokens(accessToken: 'new', refreshToken: 'r2'),
    );
  });

  test('concurrent 401s share a single refresh call', () async {
    final gate = Completer<void>();
    final adapter = FakeAdapter((o) async {
      if (o.path == '/auth/refresh') {
        await gate.future;
        return const FakeResponse(200, {
          'accessToken': 'new',
          'refreshToken': 'r2',
        });
      }
      return o.headers['Authorization'] == 'Bearer new'
          ? const FakeResponse(200, {'ok': true})
          : _expired;
    });
    final dio = client(adapter);
    final calls = Future.wait([
      dio.get<dynamic>('/cards'),
      dio.get<dynamic>('/categories'),
      dio.get<dynamic>('/merchants'),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    gate.complete();
    final results = await calls;
    expect(results.map((r) => r.statusCode), everyElement(200));
    expect(adapter.count('/auth/refresh'), 1);
  });

  test(
    'a request sent with a stale token reuses already refreshed tokens',
    () async {
      var refreshed = false;
      final adapter = FakeAdapter((o) {
        if (o.path == '/auth/refresh') {
          refreshed = true;
          return const FakeResponse(200, {
            'accessToken': 'new',
            'refreshToken': 'r2',
          });
        }
        return o.headers['Authorization'] == 'Bearer new'
            ? const FakeResponse(200, {})
            : _expired;
      });
      final dio = client(adapter);
      await dio.get<dynamic>('/cards');
      expect(refreshed, isTrue);
      // Simulate a late 401 that carried the old token.
      await tokens.save(
        const AuthTokens(accessToken: 'new', refreshToken: 'r2'),
      );
      final res = await dio.get<dynamic>('/x', options: Options(headers: {}));
      expect(res.statusCode, 200);
      expect(adapter.count('/auth/refresh'), 1);
    },
  );

  test(
    'logs out (clears tokens, emits event) when refresh is rejected',
    () async {
      final adapter = FakeAdapter((o) {
        if (o.path == '/auth/refresh') {
          return const FakeResponse(401, {
            'statusCode': 401,
            'code': 'INVALID_REFRESH_TOKEN',
            'message': 'x',
          });
        }
        return _expired;
      });
      await expectLater(
        client(adapter).get<dynamic>('/cards'),
        throwsA(isA<DioException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(await tokens.read(), isNull);
      expect(expiredCount, 1);
    },
  );

  test('keeps the session when refresh fails because of the network', () async {
    final adapter = FakeAdapter((o) {
      if (o.path == '/auth/refresh') return const FakeResponse(-1);
      return _expired;
    });
    await expectLater(
      client(adapter).get<dynamic>('/cards'),
      throwsA(isA<DioException>()),
    );
    expect(await tokens.read(), isNotNull);
    expect(expiredCount, 0);
  });

  test('does not try to refresh other 401 codes or retry twice', () async {
    final adapter = FakeAdapter(
      (o) => const FakeResponse(401, {
        'statusCode': 401,
        'code': 'INVALID_IDENTITY_TOKEN',
        'message': 'x',
      }),
    );
    await expectLater(
      client(adapter).get<dynamic>('/cards'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.count('/auth/refresh'), 0);

    final loop = FakeAdapter((o) {
      if (o.path == '/auth/refresh') {
        return const FakeResponse(200, {
          'accessToken': 'n',
          'refreshToken': 'r',
        });
      }
      return _expired;
    });
    await expectLater(
      client(loop).get<dynamic>('/cards'),
      throwsA(isA<DioException>()),
    );
    expect(loop.count('/cards'), 2);
    expect(loop.count('/auth/refresh'), 1);
  });

  test(
    'UNAUTHORIZED (account deleted) ends the session without refreshing',
    () async {
      final adapter = FakeAdapter(
        (o) => const FakeResponse(401, {
          'statusCode': 401,
          'code': 'UNAUTHORIZED',
          'message': 'x',
        }),
      );
      await expectLater(
        client(adapter).get<dynamic>('/cards'),
        throwsA(isA<DioException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(adapter.count('/auth/refresh'), 0);
      expect(await tokens.read(), isNull);
      expect(expiredCount, 1);
    },
  );
}
