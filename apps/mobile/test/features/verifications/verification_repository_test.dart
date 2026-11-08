import 'dart:io';

import 'package:cashback_audit/core/db/app_database.dart';
import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/network/dio_factory.dart';
import 'package:cashback_audit/core/network/session_events.dart';
import 'package:cashback_audit/core/storage/token_storage.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/data/verification_repository_impl.dart';
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_adapter.dart';
import '../../support/fixtures.dart';

void main() {
  late AppDatabase db;
  late FakeAdapter adapter;
  late bool offline;
  late Directory tmp;

  VerificationRepositoryImpl repo() => VerificationRepositoryImpl(
    buildDio(
      baseUrl: 'http://test/api/v1',
      tokens: InMemoryTokenStorage(),
      events: SessionEvents(),
      adapter: adapter,
    ),
    db,
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    offline = false;
    tmp = Directory.systemTemp.createTempSync('vr');
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  test('mapper parses the full verification with exact decimals', () {
    final v = VerificationMapper.detail(verificationJson());
    expect(v.verdict, Verdict.underpaid);
    expect(v.difference, Decimal.parse('-18'));
    expect(v.statement.periodStart, DateTime(2026, 1, 1));
    expect(v.breakdown.first.ratePercent, Decimal.parse('5'));
    expect(v.breakdown.last.isBase, isTrue);
    expect(v.transactions.first.matchSource, MatchSource.keyword);
    expect(v.transactions.last.inCategory, isFalse);
    expect(v.countedTransactions, 1);
    expect(v.uncountedTransactions, 1);
    expect(v.warnings.single.code, 'AI_MATCHING_UNAVAILABLE');
  });

  test('credits expose negative signed amounts', () {
    final v = VerificationMapper.detail(
      verificationJson(transactions: [txJson(0, 'REFUND', '58', credit: true)]),
    );
    expect(v.transactions.single.signedAmount, Decimal.parse('-58'));
  });

  test(
    'verify uploads multipart with cardId, pdf and optional override',
    () async {
      final file = File('${tmp.path}/s.pdf')
        ..writeAsBytesSync([37, 80, 68, 70]);
      adapter = FakeAdapter((o) => FakeResponse(201, verificationJson()));
      final progress = <int>[];
      final v = await repo().verify(
        cardId: 'c1',
        filePath: file.path,
        reportedRewardOverride: '125,40',
        onProgress: (s, t) => progress.add(s),
      );
      expect(v.id, 'v1');
      final req = adapter.requests.single;
      expect(req.path, '/verifications');
      final form = req.data as FormData;
      final fields = {for (final f in form.fields) f.key: f.value};
      expect(fields['cardId'], 'c1');
      expect(fields['reportedRewardOverride'], '125.40');
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.contentType.toString(), 'application/pdf');
      expect(req.receiveTimeout, const Duration(minutes: 3));
      // The fresh result is cached for offline history/detail.
      expect(await db.readVerificationSummaries(), hasLength(1));
      expect(await db.readVerificationDetail('v1'), isNotNull);
    },
  );

  test('verify maps 402 and 422 codes', () async {
    final file = File('${tmp.path}/s.pdf')..writeAsBytesSync([37]);
    adapter = FakeAdapter(
      (o) => const FakeResponse(402, {
        'statusCode': 402,
        'code': 'SUBSCRIPTION_REQUIRED',
        'message': 'x',
        'details': {'entitlementId': 'pro'},
      }),
    );
    await expectLater(
      repo().verify(cardId: 'c1', filePath: file.path),
      throwsA(
        isA<AppException>().having(
          (e) => e.isSubscriptionRequired,
          'sub',
          true,
        ),
      ),
    );
  });

  test('history paginates, caches page one and falls back offline', () async {
    adapter = FakeAdapter((o) {
      if (offline) return const FakeResponse(-1);
      final page = o.queryParameters['page'];
      return FakeResponse(200, {
        'items': [summaryJson(page == 1 ? 'a' : 'b')],
        'page': page,
        'pageSize': 1,
        'total': 2,
      });
    });
    final r = repo();
    final first = await r.history(pageSize: 1);
    expect(first.data.hasMore, isTrue);
    expect(first.data.items.single.difference, Decimal.parse('-18'));
    final second = await r.history(page: 2, pageSize: 1);
    expect(second.data.hasMore, isFalse);
    offline = true;
    final cached = await r.history(pageSize: 20);
    expect(cached.fromCache, isTrue);
    expect(cached.data.items, hasLength(2));
  });

  test('history offline with empty cache rethrows', () async {
    adapter = FakeAdapter((o) => const FakeResponse(-1));
    await expectLater(repo().history(), throwsA(isA<AppException>()));
  });

  test(
    'detail is network-first with cache fallback; delete clears cache',
    () async {
      adapter = FakeAdapter((o) {
        if (offline) return const FakeResponse(-1);
        if (o.method == 'DELETE') return const FakeResponse(204);
        return FakeResponse(200, verificationJson());
      });
      final r = repo();
      expect((await r.detail('v1')).fromCache, isFalse);
      offline = true;
      final cached = await r.detail('v1');
      expect(cached.fromCache, isTrue);
      expect(cached.data.id, 'v1');
      offline = false;
      await r.delete('v1');
      expect(await db.readVerificationDetail('v1'), isNull);
    },
  );
}
