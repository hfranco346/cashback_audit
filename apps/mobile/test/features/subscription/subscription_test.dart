import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/network/dio_factory.dart';
import 'package:cashback_audit/core/network/session_events.dart';
import 'package:cashback_audit/core/storage/token_storage.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/features/credits/domain/credit_entities.dart';
import 'package:cashback_audit/features/credits/presentation/credits_controller.dart';
import 'package:cashback_audit/features/subscription/data/revenuecat_billing_service.dart';
import 'package:cashback_audit/features/subscription/data/subscription_repository_impl.dart';
import 'package:cashback_audit/features/subscription/domain/subscription_entities.dart';
import 'package:cashback_audit/features/subscription/domain/subscription_repository.dart';
import 'package:cashback_audit/features/subscription/presentation/paywall_controller.dart';
import 'package:cashback_audit/features/subscription/presentation/subscription_controller.dart';
import 'package:cashback_audit/features/subscription/presentation/widgets/paywall_view.dart';
import 'package:cashback_audit/features/subscription/presentation/widgets/subscription_status_card.dart';
import 'package:cashback_audit/features/auth/domain/auth_entities.dart';
import 'package:cashback_audit/features/auth/domain/auth_repository.dart';
import 'package:cashback_audit/features/auth/presentation/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/fake_adapter.dart';
import '../../support/fake_credits_repository.dart';
import '../../support/fakes.dart';

const _active = SubscriptionStatus(
  entitlementId: 'pro',
  active: true,
  state: SubscriptionState.active,
);

class _Repo implements SubscriptionRepository {
  _Repo({this.activeAfter = 1, this.error});
  int calls = 0;
  final int activeAfter;
  final Object? error;

  @override
  Future<SubscriptionStatus> getStatus() async {
    calls++;
    if (error != null) throw error!;
    return calls >= activeAfter ? _active : SubscriptionStatus.none;
  }
}

class _Billing implements BillingService {
  _Billing({this.configured = true, this.purchaseError});
  final bool configured;
  final Object? purchaseError;
  final pkgs = const [
    PaywallPackage(id: 'monthly', title: 'Mensual', priceString: r'$4.99'),
    PaywallPackage(
      id: 'pack3',
      title: '3',
      priceString: r'$2.99',
      kind: PaywallPackageKind.creditPack,
      credits: 3,
    ),
    PaywallPackage(
      id: 'pack10',
      title: '10',
      priceString: r'$7.99',
      kind: PaywallPackageKind.creditPack,
      credits: 10,
    ),
  ];
  final log = <String>[];

  @override
  bool get isConfigured => configured;
  @override
  Future<void> configure() async {}
  @override
  Future<void> logIn(String userId) async => log.add('logIn:$userId');
  @override
  Future<void> logOut() async => log.add('logOut');
  @override
  Future<List<PaywallPackage>> packages() async => pkgs;
  @override
  Future<void> purchase(PaywallPackage package) async {
    if (purchaseError != null) throw purchaseError!;
    log.add('purchase:${package.id}');
  }

  @override
  Future<void> restore() async => log.add('restore');
}

class _NoopAuthRepo implements AuthRepository {
  @override
  Future<AppUser> signInWithGoogle() => throw UnimplementedError();
  @override
  Future<AppUser> signInWithApple() => throw UnimplementedError();
  @override
  Future<AppUser?> cachedUser() async => null;
  @override
  Future<AppUser?> loadUser() async => null;
  @override
  Future<void> signOut() async {}
}

SubscriptionController _sub(_Repo repo, _Billing billing) =>
    SubscriptionController(
      repository: repo,
      billing: billing,
      pollDelays: List.filled(3, const Duration(seconds: 1)),
      wait: (_) async {},
    );

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));

  test('repository parses the subscription status', () async {
    final adapter = FakeAdapter(
      (o) => const FakeResponse(200, {
        'entitlementId': 'pro',
        'active': true,
        'status': 'CANCELLED',
        'expiresAt': '2026-03-01T10:00:00.000Z',
        'willRenew': false,
        'store': 'APP_STORE',
        'productId': 'pro_monthly',
      }),
    );
    final repo = SubscriptionRepositoryImpl(
      buildDio(
        baseUrl: 'http://test/api/v1',
        tokens: InMemoryTokenStorage(),
        events: SessionEvents(),
        adapter: adapter,
      ),
    );
    final s = await repo.getStatus();
    expect(adapter.requests.single.path, '/subscriptions/me');
    expect(s.state, SubscriptionState.cancelled);
    expect(s.active, isTrue); // cancelled still active until expiry
    expect(s.expiresAt, DateTime.utc(2026, 3, 1, 10));
    expect(s.productId, 'pro_monthly');
  });

  test('unconfigured RevenueCat is a harmless no-op', () async {
    final billing = RevenueCatBillingService(apiKey: '');
    expect(billing.isConfigured, isFalse);
    await billing.logIn('u1');
    await billing.logOut();
    await billing.restore();
    expect(await billing.packages(), isEmpty);
  });

  group('SubscriptionController', () {
    test('polls with backoff until the backend reports active', () async {
      final repo = _Repo(activeAfter: 3);
      final waits = <Duration>[];
      final c = SubscriptionController(
        repository: repo,
        billing: _Billing(),
        pollDelays: const [Duration(seconds: 1), Duration(seconds: 2)],
        wait: (d) async => waits.add(d),
      );
      expect(await c.waitUntilActive(), isTrue);
      expect(repo.calls, 3);
      expect(waits, const [Duration(seconds: 1), Duration(seconds: 2)]);
      expect(c.isActive, isTrue);
    });

    test('gives up after the last delay', () async {
      final repo = _Repo(activeAfter: 99);
      final c = _sub(repo, _Billing());
      expect(await c.waitUntilActive(), isFalse);
      expect(repo.calls, 4); // initial + 3 retries
    });

    test('keeps a mapped error message when the status call fails', () async {
      final c = _sub(
        _Repo(error: const AppException(kind: AppErrorKind.network)),
        _Billing(),
      );
      expect(await c.fetchStatus(), isNull);
      expect(c.errorMessage.value, S.errNetwork);
    });

    test('restorePurchases reports the dev notice when unconfigured', () async {
      final c = _sub(_Repo(), _Billing(configured: false));
      expect(await c.restorePurchases(), S.paywallDevNotice);
    });
  });

  group('PaywallController', () {
    late _Billing billing;
    late FakeNavigator nav;
    late CreditsController credits;
    late SubscriptionController sub;

    PaywallController build(
      List<CreditBalance> balances, {
      _Billing? b,
      _Repo? subRepo,
    }) {
      billing = b ?? _Billing();
      nav = FakeNavigator();
      credits = CreditsController(
        repository: FakeCreditsRepository(balances),
        pollDelays: List.filled(3, const Duration(seconds: 1)),
        wait: (_) async {},
      );
      sub = _sub(subRepo ?? _Repo(activeAfter: 1), billing);
      return PaywallController(
        billing: billing,
        credits: credits,
        subscription: sub,
        navigator: nav,
      );
    }

    test('loads packages, preselects the subscription, sorts packs', () async {
      final c = build([balance()]);
      await c.loadPackages();
      expect(c.packages, hasLength(3));
      expect(c.selectedId.value, 'monthly');
      expect(c.subscriptionPackage?.id, 'monthly');
      expect(c.packs.map((p) => p.credits), [3, 10]);
    });

    test('buying a pack polls the balance until credits appear', () async {
      // before: 0; webhook lag: still 0 once; then 3 credits.
      final c = build([balance(), balance(), balance(), balance(purchased: 3)]);
      await c.loadPackages();
      c.select('pack3');
      await c.purchase();
      expect(billing.log, ['purchase:pack3']);
      expect(credits.balance.value?.purchased, 3);
      expect(nav.pops, 1);
      expect(nav.notices, [S.paywallSuccessTitle]);
      expect(c.pending.value, isFalse);
      expect(c.busy.value, PaywallBusy.none);
    });

    test('subscribing is confirmed by the plan credits arriving', () async {
      final c = build([balance(), balance(plan: 5, subscriptionActive: true)]);
      await c.loadPackages();
      await c.purchase();
      expect(billing.log, ['purchase:monthly']);
      expect(credits.balance.value?.plan, 5);
      expect(nav.pops, 1);
    });

    test('user cancellation is silent', () async {
      final c = build([
        balance(),
      ], b: _Billing(purchaseError: const PurchaseCancelled()));
      await c.loadPackages();
      await c.purchase();
      expect(c.errorMessage.value, isNull);
      expect(nav.pops, 0);
      expect(c.busy.value, PaywallBusy.none);
    });

    test('store failures show an error', () async {
      final c = build([
        balance(),
      ], b: _Billing(purchaseError: const BillingException('x')));
      await c.loadPackages();
      await c.purchase();
      expect(c.errorMessage.value, S.paywallPurchaseFailed);
    });

    test('webhook lag leaves a pending state that can be re-checked', () async {
      final c = build([balance()]); // never changes
      await c.loadPackages();
      c.select('pack10');
      await c.purchase();
      expect(c.pending.value, isTrue);
      expect(nav.pops, 0);
    });

    test('restore refreshes what the backend knows', () async {
      final c = build([balance(plan: 5, subscriptionActive: true)]);
      await c.restore();
      expect(billing.log, ['restore']);
      expect(nav.pops, 1);
    });

    test('restore with nothing to restore says so', () async {
      final c = build([balance()], subRepo: _Repo(activeAfter: 99));
      await c.restore();
      expect(nav.pops, 0);
      expect(c.errorMessage.value, S.restoreNothing);
    });

    test('unconfigured builds do not load packages', () async {
      final c = build([balance()], b: _Billing(configured: false));
      await c.loadPackages();
      expect(c.configured, isFalse);
      expect(c.packages, isEmpty);
    });
  });

  test(
    'sign-in hook identifies the RevenueCat customer with our user id',
    () async {
      final billing = _Billing();
      // Mirrors the wiring done in InitialBinding.
      final session = SessionController(
        repository: _NoopAuthRepo(),
        events: SessionEvents(),
        clearLocalData: () async {},
        navigator: FakeNavigator(),
      );
      session
        ..addSignedInHook((u) => billing.logIn(u.id))
        ..addSignedOutHook(billing.logOut);
      await session.onSignedIn(const AppUser(id: 'u1'));
      expect(billing.log, ['logIn:u1']);
      await session.signOut();
      expect(billing.log.last, 'logOut');
    },
  );

  group('widgets', () {
    Widget wrap(Widget c) => MaterialApp(theme: AppTheme.light, home: c);

    PaywallView view({
      bool configured = true,
      PaywallBusy busy = PaywallBusy.none,
      bool pending = false,
      String? selected = 'monthly',
      int freeCredits = 0,
      ValueChanged<String>? onSelect,
      VoidCallback? onPurchase,
      VoidCallback? onCheckAgain,
    }) => PaywallView(
      configured: configured,
      subscription: _Billing().pkgs[0],
      packs: _Billing().pkgs.sublist(1),
      selectedId: selected,
      onSelect: onSelect ?? (_) {},
      busy: busy,
      pending: pending,
      freeCredits: freeCredits,
      onPurchase: onPurchase ?? () {},
      onRestore: () {},
      onCheckAgain: onCheckAgain ?? () {},
      onClose: () {},
    );

    testWidgets('shows the subscription and the credit packs', (tester) async {
      String? picked;
      var purchased = 0;
      await tester.binding.setSurfaceSize(const Size(500, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        wrap(
          view(onSelect: (id) => picked = id, onPurchase: () => purchased++),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(S.paywallSubscriptionTitle), findsOneWidget);
      expect(find.text(S.paywallSubscriptionPerks), findsOneWidget);
      expect(find.text(r'$4.99'), findsOneWidget);
      expect(find.text(S.paywallPacksTitle), findsOneWidget);
      expect(find.text(S.packTitle(3)), findsOneWidget);
      expect(find.text(S.packTitle(10)), findsOneWidget);
      expect(find.text(r'$2.99'), findsOneWidget);
      expect(find.text(S.paywallSubscribe), findsOneWidget);
      await tester.tap(find.byKey(const Key('package-pack10')));
      expect(picked, 'pack10');
      await tester.tap(find.byKey(const Key('subscribe-button')));
      expect(purchased, 1);
    });

    testWidgets('the button says Comprar when a pack is selected', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(wrap(view(selected: 'pack3')));
      await tester.pumpAndSettle();
      expect(find.text(S.paywallBuy), findsOneWidget);
      expect(find.text(S.paywallSubscribe), findsNothing);
    });

    testWidgets('first-free messaging only with free credits', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(wrap(view()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('paywall-free-banner')), findsNothing);
      await tester.pumpWidget(wrap(view(freeCredits: 1)));
      await tester.pumpAndSettle();
      expect(find.text(S.paywallFreeBanner(1)), findsOneWidget);
    });

    testWidgets('no external or web payment is mentioned', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(wrap(view(freeCredits: 1, pending: true)));
      await tester.pumpAndSettle();
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => (t.data ?? '').toLowerCase())
          .join(' ');
      for (final banned in ['web', 'stripe', 'paddle', 'http', 'sitio']) {
        expect(texts.contains(banned), isFalse, reason: banned);
      }
    });

    testWidgets('shows a dev notice and disables purchase without a key', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(view(configured: false)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('paywall-dev-notice')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('subscribe-button')));
      final btn = tester.widget<FilledButton>(
        find.byKey(const Key('subscribe-button')),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('pending purchase offers a re-check', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var checked = 0;
      await tester.pumpWidget(
        wrap(view(pending: true, onCheckAgain: () => checked++)),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(S.paywallCheckAgain));
      await tester.tap(find.text(S.paywallCheckAgain));
      expect(checked, 1);
    });

    testWidgets('status card renders each state', (tester) async {
      Future<void> pump(SubscriptionStatus? s) => tester.pumpWidget(
        wrap(
          SubscriptionStatusCard(status: s, loading: false, onManage: () {}),
        ),
      );
      await pump(null);
      expect(find.text(S.subscriptionNone), findsOneWidget);
      expect(find.byKey(const Key('manage-subscription')), findsOneWidget);

      await pump(
        SubscriptionStatus(
          entitlementId: 'pro',
          active: true,
          state: SubscriptionState.active,
          willRenew: true,
          expiresAt: DateTime.utc(2026, 3, 1, 12),
        ),
      );
      expect(find.text(S.subscriptionActive), findsOneWidget);
      expect(find.byKey(const Key('manage-subscription')), findsNothing);
      expect(find.textContaining('Se renueva el'), findsOneWidget);

      await pump(
        SubscriptionStatus(
          entitlementId: 'pro',
          active: true,
          state: SubscriptionState.cancelled,
          expiresAt: DateTime.utc(2026, 3, 1, 12),
        ),
      );
      expect(find.text(S.subscriptionCancelled), findsOneWidget);
      expect(find.textContaining('Activa hasta el'), findsOneWidget);

      await pump(
        const SubscriptionStatus(
          entitlementId: 'pro',
          active: false,
          state: SubscriptionState.expired,
        ),
      );
      expect(find.text(S.subscriptionExpired), findsOneWidget);
      expect(find.byKey(const Key('manage-subscription')), findsOneWidget);
    });
  });
}
