import 'package:cashback_audit/core/config/credit_packs.dart';
import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/network/dio_factory.dart';
import 'package:cashback_audit/core/network/session_events.dart';
import 'package:cashback_audit/core/storage/token_storage.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/features/cards/data/card_mapper.dart';
import 'package:cashback_audit/features/credits/data/credits_repository_impl.dart';
import 'package:cashback_audit/features/credits/domain/credit_entities.dart';
import 'package:cashback_audit/features/credits/presentation/credit_history_controller.dart';
import 'package:cashback_audit/features/credits/presentation/credits_controller.dart';
import 'package:cashback_audit/features/credits/presentation/widgets/credit_history_view.dart';
import 'package:cashback_audit/features/credits/presentation/widgets/credits_chip.dart';
import 'package:cashback_audit/features/credits/presentation/widgets/credits_summary_card.dart';
import 'package:cashback_audit/features/subscription/data/revenuecat_billing_service.dart';
import 'package:cashback_audit/features/subscription/domain/subscription_entities.dart';
import 'package:cashback_audit/features/verifications/presentation/widgets/upload_view.dart';
import 'package:cashback_audit/features/verifications/presentation/upload_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/fake_adapter.dart';
import '../../support/fake_credits_repository.dart';
import '../../support/fixtures.dart';

CreditsRepositoryImpl _repo(FakeAdapter adapter) => CreditsRepositoryImpl(
  buildDio(
    baseUrl: 'http://test/api/v1',
    tokens: InMemoryTokenStorage(),
    events: SessionEvents(),
    adapter: adapter,
  ),
);

Map<String, dynamic> _entry(String id, int delta, String reason) => {
  'id': id,
  'delta': delta,
  'bucket': delta > 0 ? 'PURCHASED' : 'FREE',
  'reason': reason,
  'source': 'SYSTEM',
  'verificationId': null,
  'periodEnd': null,
  'createdAt': '2026-02-01T10:00:00.000Z',
};

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));

  Widget wrap(Widget c) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: c),
  );

  group('CREDIT_PACKS config', () {
    test('parses productId:credits pairs and skips malformed ones', () {
      expect(parseCreditPacks('credits_3:3,credits_10:10'), {
        'credits_3': 3,
        'credits_10': 10,
      });
      expect(parseCreditPacks(' a : 2 ,bad,c:0,d:x,:4'), {'a': 2});
      expect(parseCreditPacks(''), isEmpty);
    });

    test('products are classified as pack, subscription or hidden', () {
      const packs = {'credits_3': 3, 'credits_10': 10};
      final pack = classifyPackage(
        productId: 'credits_10',
        hasSubscriptionPeriod: false,
        creditPacks: packs,
      );
      expect(pack?.kind, PaywallPackageKind.creditPack);
      expect(pack?.credits, 10);
      final sub = classifyPackage(
        productId: 'pro_monthly:base',
        hasSubscriptionPeriod: true,
        creditPacks: packs,
      );
      expect(sub?.kind, PaywallPackageKind.subscription);
      expect(sub?.credits, isNull);
      // A one-off product the backend does not credit is not offered.
      expect(
        classifyPackage(
          productId: 'lifetime',
          hasSubscriptionPeriod: false,
          creditPacks: packs,
        ),
        isNull,
      );
      // Google Play style `productId:basePlan` still matches a pack id.
      expect(
        classifyPackage(
          productId: 'credits_3:default',
          hasSubscriptionPeriod: false,
          creditPacks: packs,
        )?.credits,
        3,
      );
    });
  });

  group('CreditsRepositoryImpl', () {
    test('parses the balance', () async {
      final adapter = FakeAdapter(
        (o) => const FakeResponse(200, {
          'free': 0,
          'plan': 3,
          'planPeriodEnd': '2026-03-01T10:00:00.000Z',
          'purchased': 2,
          'total': 5,
          'subscriptionActive': true,
        }),
      );
      final b = await _repo(adapter).getBalance();
      expect(adapter.requests.single.path, '/credits/me');
      expect(b.total, 5);
      expect(b.plan, 3);
      expect(b.purchased, 2);
      expect(b.subscriptionActive, isTrue);
      expect(b.planPeriodEnd, DateTime.utc(2026, 3, 1, 10));
    });

    test('parses the ledger page', () async {
      final adapter = FakeAdapter(
        (o) => FakeResponse(200, {
          'items': [_entry('a', -1, 'CONSUME'), _entry('b', 3, 'GRANT_PACK')],
          'page': 1,
          'pageSize': 20,
          'total': 2,
        }),
      );
      final page = await _repo(adapter).history();
      expect(adapter.requests.single.path, '/credits/me/history');
      expect(adapter.requests.single.queryParameters['pageSize'], 20);
      expect(page.items.first.reason, CreditReason.consume);
      expect(page.items.first.delta, -1);
      expect(page.items.last.bucket, CreditBucket.purchased);
      expect(page.hasMore, isFalse);
    });

    test('the NO_CREDITS body carries the balance', () {
      final e = AppException(
        kind: AppErrorKind.noCredits,
        code: 'NO_CREDITS',
        details: const {
          'free': 0,
          'plan': 0,
          'purchased': 0,
          'total': 0,
          'subscriptionActive': false,
        },
      );
      expect(CreditBalance.tryFromDetails(e.details)?.hasCredits, isFalse);
      expect(CreditBalance.tryFromDetails(null), isNull);
    });
  });

  group('CreditsController polling', () {
    CreditsController make(FakeCreditsRepository repo, List<Duration> waits) =>
        CreditsController(
          repository: repo,
          pollDelays: const [
            Duration(seconds: 1),
            Duration(seconds: 2),
            Duration(seconds: 4),
          ],
          wait: (d) async => waits.add(d),
        );

    test('polls with backoff until the balance changes', () async {
      final waits = <Duration>[];
      final repo = FakeCreditsRepository([
        balance(),
        balance(),
        balance(purchased: 3),
      ]);
      final c = make(repo, waits);
      expect(await c.waitForChange(balance()), isTrue);
      expect(repo.calls, 3);
      expect(waits, const [Duration(seconds: 1), Duration(seconds: 2)]);
      expect(c.balance.value?.purchased, 3);
    });

    test('gives up after the last delay when nothing changes', () async {
      final waits = <Duration>[];
      final repo = FakeCreditsRepository([balance()]);
      final c = make(repo, waits);
      expect(await c.waitForChange(balance()), isFalse);
      expect(repo.calls, 4); // initial + one per delay
      expect(waits, hasLength(3));
    });

    test('a subscription starting counts as a change', () async {
      final repo = FakeCreditsRepository([
        balance(plan: 5, subscriptionActive: true),
      ]);
      final c = make(repo, []);
      expect(await c.waitForChange(balance()), isTrue);
      expect(repo.calls, 1);
    });

    test('without a previous balance any credit counts', () async {
      final repo = FakeCreditsRepository([balance(), balance(free: 1)]);
      final c = make(repo, []);
      expect(await c.waitForChange(null), isTrue);
      expect(repo.calls, 2);
    });

    test('keeps the old balance and a message when the fetch fails', () async {
      final repo = FakeCreditsRepository([
        balance(),
      ], error: const AppException(kind: AppErrorKind.network));
      final c = make(repo, [])..balance.value = balance(free: 2);
      expect(await c.fetch(), isNull);
      expect(c.balance.value?.free, 2);
      expect(c.errorMessage.value, S.errNetwork);
    });

    test('reset clears the balance (logout)', () {
      final c = make(FakeCreditsRepository([balance()]), [])
        ..balance.value = balance(free: 1);
      c.reset();
      expect(c.balance.value, isNull);
    });
  });

  group('CreditHistoryController', () {
    test('loads and paginates', () async {
      CreditHistoryEntry e(String id) => CreditHistoryEntry(
        id: id,
        delta: -1,
        bucket: CreditBucket.free,
        reason: CreditReason.consume,
        createdAt: DateTime.utc(2026, 2),
      );
      final repo = FakeCreditsRepository([balance()])
        ..pages = [
          CreditHistoryPage(items: [e('a')], page: 1, pageSize: 1, total: 2),
          CreditHistoryPage(items: [e('b')], page: 2, pageSize: 1, total: 2),
        ];
      final c = CreditHistoryController(repository: repo, pageSize: 1);
      await c.load();
      expect(c.items.map((i) => i.id), ['a']);
      expect(c.hasMore.value, isTrue);
      await c.loadMore();
      expect(c.items.map((i) => i.id), ['a', 'b']);
      expect(c.hasMore.value, isFalse);
    });
  });

  group('widgets', () {
    testWidgets('credits chip shows the available count; hidden if unknown', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          CreditsChip(
            balance: balance(plan: 3, purchased: 2),
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.text(S.creditsAvailable(5)), findsOneWidget);
      await tester.tap(find.byKey(const Key('credits-chip')));
      expect(taps, 1);

      await tester.pumpWidget(
        wrap(CreditsChip(balance: balance(free: 1), onTap: () {})),
      );
      expect(find.text('1 verificación disponible'), findsOneWidget);

      await tester.pumpWidget(
        wrap(CreditsChip(balance: balance(), onTap: () {})),
      );
      expect(find.text(S.creditsNone), findsOneWidget);

      await tester.pumpWidget(wrap(CreditsChip(balance: null, onTap: () {})));
      expect(find.byKey(const Key('credits-chip')), findsNothing);
    });

    testWidgets('summary card shows buckets, plan expiry and actions', (
      tester,
    ) async {
      var bought = 0;
      var history = 0;
      await tester.pumpWidget(
        wrap(
          CreditsSummaryCard(
            balance: CreditBalance(
              free: 0,
              plan: 3,
              purchased: 2,
              total: 5,
              subscriptionActive: true,
              planPeriodEnd: DateTime.utc(2026, 3, 1, 12),
            ),
            loading: false,
            onBuy: () => bought++,
            onHistory: () => history++,
          ),
        ),
      );
      expect(find.text(S.creditsBreakdown(0, 3, 2)), findsOneWidget);
      expect(find.textContaining('Las del plan vencen el'), findsOneWidget);
      await tester.tap(find.byKey(const Key('credits-buy')));
      await tester.tap(find.byKey(const Key('credits-history')));
      expect((bought, history), (1, 1));
    });

    testWidgets('history lists entries in Spanish; empty state', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          CreditHistoryView(
            items: [
              CreditHistoryEntry(
                id: 'a',
                delta: -1,
                bucket: CreditBucket.free,
                reason: CreditReason.consume,
                createdAt: DateTime.utc(2026, 2),
              ),
              CreditHistoryEntry(
                id: 'b',
                delta: 3,
                bucket: CreditBucket.purchased,
                reason: CreditReason.grantPack,
                createdAt: DateTime.utc(2026, 2),
              ),
            ],
            loading: false,
            loadingMore: false,
            hasMore: true,
            onRefresh: () async {},
            onLoadMore: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(S.creditReasonConsume), findsOneWidget);
      expect(find.text(S.creditReasonGrantPack), findsOneWidget);
      expect(find.text('-1'), findsOneWidget);
      expect(find.text('+3'), findsOneWidget);

      await tester.pumpWidget(
        wrap(
          CreditHistoryView(
            items: const [],
            loading: false,
            loadingMore: false,
            hasMore: false,
            onRefresh: () async {},
            onLoadMore: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(S.creditsHistoryEmptyTitle), findsOneWidget);
    });

    UploadView upload(CreditBalance? b, {VoidCallback? onSeePlans}) =>
        UploadView(
          cards: [CardMapper.fromJson(cardJson())],
          selectedCardId: 'c1',
          onSelectCard: (_) {},
          file: null,
          onPick: () {},
          phase: UploadPhase.idle,
          progress: 0,
          canSubmit: false,
          onSubmit: () {},
          onAddCard: () {},
          balance: b,
          onSeePlans: onSeePlans,
        );

    testWidgets('upload tells what the analysis will cost', (tester) async {
      await tester.pumpWidget(wrap(upload(balance(plan: 5))));
      expect(find.text(S.uploadCreditNotice(5)), findsOneWidget);

      await tester.pumpWidget(wrap(upload(balance(free: 1))));
      expect(find.text(S.uploadFreeNotice), findsOneWidget);

      await tester.pumpWidget(wrap(upload(null)));
      expect(find.byKey(const Key('upload-credit-notice')), findsNothing);
    });

    testWidgets('upload with no credits offers the plans', (tester) async {
      var seen = 0;
      await tester.pumpWidget(
        wrap(upload(balance(), onSeePlans: () => seen++)),
      );
      expect(find.text(S.uploadNoCredits), findsOneWidget);
      await tester.tap(find.text(S.seePlans));
      expect(seen, 1);
    });
  });
}
