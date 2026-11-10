import 'dart:io';

import 'package:cashback_audit/core/db/app_database.dart';
import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/network/dio_factory.dart';
import 'package:cashback_audit/core/network/session_events.dart';
import 'package:cashback_audit/core/storage/token_storage.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/data/verification_repository_impl.dart';
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';
import 'package:cashback_audit/features/verifications/domain/verification_events.dart';
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

  group('mapper (two-step contract)', () {
    test('completed verification exposes the new sections', () {
      final v = VerificationMapper.detail(verificationJson());
      expect(v.status, VerificationStatus.completed);
      expect(v.primaryCurrency, 'MXN');
      expect(v.reported?.label, 'Bonificacion');
      expect(v.expectedAmount, Decimal.parse('58'));
      expect(v.explanation, contains('18'));
      expect(v.appliedRates?.baseRatePercent, Decimal.parse('1'));
      expect(v.appliedRates?.categoryRates.single.categoryId, 'cat1');
      expect(v.currencies.single.isPrimary, isTrue);
      expect(v.loyalty.selectedProgram?.name, 'Bonificacion');
      expect(v.loyalty.programs, hasLength(1));
      expect(v.models['classification'], 'claude-haiku-5-5');
      final proposal = v.rateProposal;
      expect(proposal.first.isBase, isTrue);
      expect(proposal.last.source, RateSource.statement);
      expect(proposal.last.evidence, '5% en super');
    });

    test('awaiting verification: no result, required entries, nulls', () {
      final v = VerificationMapper.detail(awaitingVerificationJson());
      expect(v.isAwaitingRates, isTrue);
      expect(v.verdict, isNull);
      expect(v.reported, isNull);
      expect(v.expectedAmount, isNull);
      expect(v.appliedRates, isNull);
      expect(v.rateProposal.every((e) => e.required), isTrue);
      expect(v.rateProposal.first.ratePercent, isNull);
      expect(v.transactions.single.appliedRatePercent, isNull);
      expect(v.transactions.single.matchSource, MatchSource.aiCategory);
      expect(v.transactions.single.matchSource.isAi, isTrue);
    });

    test('transaction kinds, sources, reasons and exclusions', () {
      final v = VerificationMapper.detail(
        verificationJson(
          transactions: [
            txJson(0, 'PAGO', '500', kind: 'PAYMENT', source: 'NONE'),
            txJson(
              1,
              'AMAZON',
              '20',
              currency: 'USD',
              excludedReason: 'NO_EXCHANGE_RATE',
              source: 'NONE',
            ),
            txJson(
              2,
              'SUPER',
              '90',
              source: 'AI_CATEGORY',
              reason: 'Es un super',
            ),
            txJson(3, 'FARMA', '10', source: 'AI_MERCHANT'),
            txJson(4, 'TIENDA', '10', source: 'USER'),
            txJson(5, 'OTRO', '10', source: 'NONE'),
          ],
        ),
      );
      final t = v.transactions;
      expect(t[0].kind, TransactionKind.payment);
      expect(t[0].excludedReason, ExcludedReason.nonPurchaseKind);
      expect(t[0].isExcluded, isTrue);
      expect(t[1].excludedReason, ExcludedReason.noExchangeRate);
      expect(t[1].currency, 'USD');
      expect(t[2].matchReason, 'Es un super');
      expect(t[3].matchSource, MatchSource.aiMerchant);
      expect(t[4].matchSource, MatchSource.user);
      expect(t[4].matchSource.isAi, isFalse);
      expect(v.countedTransactions, 3);
      expect(v.uncountedTransactions, 1);
      expect(v.excludedTransactions, 2);
      expect(v.hasForeignPurchases, isTrue);
    });

    test(
      'legacy cached JSON (pre multi-currency, source AI) does not crash',
      () {
        final v = VerificationMapper.detail(legacyVerificationJson());
        expect(v.status, VerificationStatus.completed);
        expect(v.verdict, Verdict.underpaid);
        expect(v.rateProposal, isEmpty);
        expect(v.appliedRates, isNull);
        expect(v.loyalty.programs, isEmpty);
        expect(v.currencies, isEmpty);
        expect(v.explanation, isNull);
        expect(v.currency, 'MXN');
        final t = v.transactions.single;
        expect(t.matchSource, MatchSource.aiMerchant);
        expect(t.kind, TransactionKind.purchase);
        expect(t.currency, 'MXN');
        expect(t.isExcluded, isFalse);
        expect(v.hasForeignPurchases, isFalse);
      },
    );

    test('summaries: awaiting has no figures, legacy has no status', () {
      final awaiting = VerificationMapper.summary({
        ...summaryJson('a'),
        'status': 'AWAITING_RATES',
        'reportedAmount': null,
        'expectedAmount': null,
        'difference': null,
        'verdict': null,
      });
      expect(awaiting.isAwaitingRates, isTrue);
      expect(awaiting.verdict, isNull);
      final legacy = summaryJson('b')
        ..remove('status')
        ..remove('primaryCurrency');
      final s = VerificationMapper.summary(legacy);
      expect(s.status, VerificationStatus.completed);
      expect(s.currency, 'MXN');
    });

    test('summaryJsonFromDetail keeps status and nullable figures', () {
      final s = VerificationMapper.summaryJsonFromDetail(
        awaitingVerificationJson(),
      );
      expect(s['status'], 'AWAITING_RATES');
      expect(s['reportedAmount'], isNull);
      expect(VerificationMapper.summary(s).isAwaitingRates, isTrue);
    });

    test('confirm body serializes decimals as strings', () {
      final body = VerificationMapper.confirmBody(
        ConfirmRequest(
          baseRatePercent: Decimal.parse('1.5'),
          categoryRates: [
            CategoryRateInput(
              categoryId: 'cat1',
              ratePercent: Decimal.parse('7'),
              monthlyCap: Decimal.parse('50'),
            ),
          ],
          saveToCard: true,
          exchangeRate: Decimal.parse('26.35'),
          rewardProgramName: ' CASH BAC ',
        ),
      );
      expect(body['baseRatePercent'], '1.5');
      expect(body['saveToCard'], true);
      expect(body['exchangeRate'], '26.35');
      expect(body['rewardProgramName'], 'CASH BAC');
      expect(body.containsKey('reportedRewardOverride'), isFalse);
      final cat = (body['categoryRates'] as List).single as Map;
      expect(cat, {
        'categoryId': 'cat1',
        'ratePercent': '7',
        'monthlyCap': '50',
      });
    });
  });

  test('credits expose negative signed amounts', () {
    final v = VerificationMapper.detail(
      verificationJson(transactions: [txJson(0, 'REFUND', '58', credit: true)]),
    );
    expect(v.transactions.single.signedAmount, Decimal.parse('-58'));
  });

  test(
    'upload sends multipart with cardId, pdf and optional rate/program',
    () async {
      final file = File('${tmp.path}/s.pdf')
        ..writeAsBytesSync([37, 80, 68, 70]);
      adapter = FakeAdapter(
        (o) => FakeResponse(202, processingVerificationJson()),
      );
      final progress = <int>[];
      final v = await repo().upload(
        cardId: 'c1',
        filePath: file.path,
        exchangeRate: '26,35',
        rewardProgramName: 'CASH BAC',
        onProgress: (s, t) => progress.add(s),
      );
      expect(v.id, 'v1');
      expect(v.isProcessing, isTrue);
      final req = adapter.requests.single;
      expect(req.path, '/verifications');
      final form = req.data as FormData;
      final fields = {for (final f in form.fields) f.key: f.value};
      expect(fields['cardId'], 'c1');
      expect(fields['exchangeRate'], '26.35');
      expect(fields['rewardProgramName'], 'CASH BAC');
      expect(fields.containsKey('reportedRewardOverride'), isFalse);
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.contentType.toString(), 'application/pdf');
      expect(req.receiveTimeout, const Duration(minutes: 1));
      // The 202 summary feeds the offline history (no detail yet).
      expect(await db.readVerificationSummaries(), hasLength(1));
      expect(await db.readVerificationDetail('v1'), isNull);
    },
  );

  test('upload maps 402 NO_CREDITS', () async {
    final file = File('${tmp.path}/s.pdf')..writeAsBytesSync([37]);
    adapter = FakeAdapter(
      (o) => const FakeResponse(402, {
        'statusCode': 402,
        'code': 'NO_CREDITS',
        'message': 'x',
        'details': {'total': 0},
      }),
    );
    await expectLater(
      repo().upload(cardId: 'c1', filePath: file.path),
      throwsA(
        isA<AppException>().having((e) => e.isNoCredits, 'noCredits', true),
      ),
    );
  });

  group('async lifecycle', () {
    test('status and failure code are parsed, unknown status = completed', () {
      expect(
        VerificationStatus.fromApi('PROCESSING'),
        VerificationStatus.processing,
      );
      expect(VerificationStatus.fromApi('FAILED'), VerificationStatus.failed);
      expect(VerificationStatus.fromApi(null), VerificationStatus.completed);
      expect(
        FailureCode.tryFromApi('NOT_A_STATEMENT'),
        FailureCode.notAStatement,
      );
      expect(FailureCode.tryFromApi('INTERRUPTED'), FailureCode.interrupted);
      expect(FailureCode.tryFromApi('WHATEVER'), FailureCode.extractionFailed);
      expect(FailureCode.tryFromApi(null), isNull);
    });

    test('a processing summary maps without lines and keeps seenAt', () {
      final v = VerificationMapper.detail(
        processingVerificationJson(seenAt: '2026-02-01T10:00:00.000Z'),
      );
      expect(v.isProcessing, isTrue);
      expect(v.transactions, isEmpty);
      expect(v.seenAt, DateTime.utc(2026, 2, 1, 10));
      final failed = VerificationMapper.summary(
        failedSummaryJson('v9', 'EXTRACTION_FAILED'),
      );
      expect(failed.isFailed, isTrue);
      expect(failed.failureCode, FailureCode.extractionFailed);
      expect(failed.isUnseenResult, isTrue);
    });

    test('get always hits the network and refreshes the cache', () async {
      adapter = FakeAdapter((o) {
        expect(o.path, '/verifications/v1');
        return FakeResponse(200, {
          ...verificationJson(),
          'status': 'PROCESSING',
        });
      });
      final v = await repo().get('v1');
      expect(v.isProcessing, isTrue);
      expect(await db.readVerificationDetail('v1'), isNotNull);
    });

    test('attention maps the items and tolerates a missing list', () async {
      adapter = FakeAdapter(
        (o) => FakeResponse(200, {
          'items': [
            failedSummaryJson('a', 'NOT_A_STATEMENT'),
            summaryJson('b'),
          ],
        }),
      );
      final items = await repo().attention();
      expect(items.map((e) => e.id), ['a', 'b']);
      expect(items.first.failureCode, FailureCode.notAStatement);
      adapter = FakeAdapter(
        (o) => const FakeResponse(200, <String, dynamic>{}),
      );
      expect(await repo().attention(), isEmpty);
    });

    test('markSeen posts to /seen', () async {
      adapter = FakeAdapter((o) => const FakeResponse(204, null));
      await repo().markSeen('v1');
      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/verifications/v1/seen');
    });
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
    // The cache says when it was saved (shown in the offline banner).
    expect(cached.cachedAt, isNotNull);
    expect(first.cachedAt, isNull);
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

  test('confirm posts the rates and refreshes the cache', () async {
    adapter = FakeAdapter((o) => FakeResponse(200, verificationJson()));
    final v = await repo().confirm(
      'v1',
      ConfirmRequest(
        baseRatePercent: Decimal.parse('1'),
        categoryRates: const [],
      ),
    );
    expect(v.isCompleted, isTrue);
    final req = adapter.requests.single;
    expect(req.method, 'POST');
    expect(req.path, '/verifications/v1/confirm');
    expect((req.data as Map)['baseRatePercent'], '1');
    final cached = await db.readVerificationSummaries();
    expect(cached.single['status'], 'COMPLETED');
  });

  test('confirm surfaces RATES_REQUIRED details', () async {
    adapter = FakeAdapter(
      (o) => const FakeResponse(422, {
        'statusCode': 422,
        'code': 'RATES_REQUIRED',
        'message': 'x',
        'details': {
          'missing': [
            {'categoryId': 'cat1', 'categoryName': 'Super'},
          ],
        },
      }),
    );
    await expectLater(
      repo().confirm(
        'v1',
        ConfirmRequest(
          baseRatePercent: Decimal.parse('1'),
          categoryRates: const [],
        ),
      ),
      throwsA(
        isA<AppException>()
            .having((e) => e.code, 'code', 'RATES_REQUIRED')
            .having((e) => e.details, 'details', isA<Map>()),
      ),
    );
  });

  test('correctTransaction patches the line and caches the result', () async {
    adapter = FakeAdapter((o) => FakeResponse(200, verificationJson()));
    await repo().correctTransaction('v1', 1, 'cat1');
    final req = adapter.requests.single;
    expect(req.method, 'PATCH');
    expect(req.path, '/verifications/v1/transactions/1');
    expect(req.data, {'categoryId': 'cat1'});
    expect(await db.readVerificationDetail('v1'), isNotNull);
  });

  group('change events', () {
    late VerificationEvents events;
    late int emitted;

    VerificationRepositoryImpl withEvents() => VerificationRepositoryImpl(
      buildDio(
        baseUrl: 'http://test/api/v1',
        tokens: InMemoryTokenStorage(),
        events: SessionEvents(),
        adapter: adapter,
      ),
      db,
      events: events,
    );

    setUp(() {
      events = VerificationEvents();
      emitted = 0;
      events.changes.listen((_) => emitted++);
    });

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('upload, confirm, seen and delete announce a change', () async {
      final file = File('${tmp.path}/e.pdf')..writeAsBytesSync([37]);
      adapter = FakeAdapter(
        (o) => FakeResponse(
          o.method == 'DELETE' || o.path.endsWith('/seen') ? 204 : 200,
          o.path == '/verifications'
              ? processingVerificationJson()
              : verificationJson(),
        ),
      );
      final r = withEvents();
      await r.upload(cardId: 'c1', filePath: file.path);
      await settle();
      expect(emitted, 1);
      await r.confirm(
        'v1',
        ConfirmRequest(
          baseRatePercent: Decimal.parse('1'),
          categoryRates: const [],
        ),
      );
      await settle();
      expect(emitted, 2);
      await r.markSeen('v1');
      await settle();
      expect(emitted, 3);
      await r.delete('v1');
      await settle();
      expect(emitted, 4);
    });

    test(
      'delete of a verification already gone still clears and announces',
      () async {
        adapter = FakeAdapter(
          (o) => o.method == 'DELETE'
              ? const FakeResponse(404, {
                  'statusCode': 404,
                  'code': 'VERIFICATION_NOT_FOUND',
                  'message': 'gone',
                })
              : FakeResponse(200, verificationJson()),
        );
        final r = withEvents();
        await r.detail('v1');
        await r.delete('v1');
        await settle();
        expect(await db.readVerificationDetail('v1'), isNull);
        expect(emitted, 1);
      },
    );

    test('a failed delete keeps the cache and stays silent', () async {
      adapter = FakeAdapter(
        (o) => o.method == 'DELETE'
            ? const FakeResponse(500, {'statusCode': 500, 'code': 'X'})
            : FakeResponse(200, verificationJson()),
      );
      final r = withEvents();
      await r.detail('v1');
      await expectLater(r.delete('v1'), throwsA(isA<AppException>()));
      await settle();
      expect(await db.readVerificationDetail('v1'), isNotNull);
      expect(emitted, 0);
    });

    test('get announces only once the analysis left PROCESSING', () async {
      adapter = FakeAdapter(
        (o) => FakeResponse(200, processingVerificationJson()),
      );
      await withEvents().get('v1');
      await settle();
      expect(emitted, 0);
      adapter = FakeAdapter((o) => FakeResponse(200, verificationJson()));
      await withEvents().get('v1');
      await settle();
      expect(emitted, 1);
    });

    test(
      'reading lists and details never announces (no refresh loop)',
      () async {
        adapter = FakeAdapter(
          (o) => FakeResponse(200, {
            'items': [summaryJson('v1')],
            'page': 1,
            'pageSize': 20,
            'total': 1,
          }),
        );
        await withEvents().history();
        await withEvents().attention();
        await settle();
        expect(emitted, 0);
      },
    );
  });
}
