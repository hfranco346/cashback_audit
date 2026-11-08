import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/network/dio_factory.dart';
import 'package:cashback_audit/core/network/session_events.dart';
import 'package:cashback_audit/core/storage/token_storage.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
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
    PaywallPackage(id: 'monthly', title: 'Mensual', priceString: r'\$49.00'),
    PaywallPackage(id: 'annual', title: 'Anual', priceString: r'\$399.00'),
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

    PaywallController build(_Repo repo, {_Billing? b}) {
      billing = b ?? _Billing();
      nav = FakeNavigator();
      return PaywallController(
        billing: billing,
        subscription: _sub(repo, billing),
        navigator: nav,
      );
    }

    test('loads packages and preselects the first', () async {
      final c = build(_Repo());
      await c.loadPackages();
      expect(c.packages, hasLength(2));
      expect(c.selectedId.value, 'monthly');
    });

    test('purchase confirms with the backend and closes the paywall', () async {
      final c = build(_Repo(activeAfter: 2));
      await c.loadPackages();
      c.select('annual');
      await c.purchase();
      expect(billing.log, ['purchase:annual']);
      expect(nav.pops, 1);
      expect(nav.notices, [S.paywallSuccessTitle]);
      expect(c.pending.value, isFalse);
      expect(c.busy.value, PaywallBusy.none);
    });

    test('user cancellation is silent', () async {
      final c = build(
        _Repo(),
        b: _Billing(purchaseError: const PurchaseCancelled()),
      );
      await c.loadPackages();
      await c.purchase();
      expect(c.errorMessage.value, isNull);
      expect(nav.pops, 0);
      expect(c.busy.value, PaywallBusy.none);
    });

    test('store failures show an error', () async {
      final c = build(
        _Repo(),
        b: _Billing(purchaseError: const BillingException('x')),
      );
      await c.loadPackages();
      await c.purchase();
      expect(c.errorMessage.value, S.paywallPurchaseFailed);
    });

    test('webhook lag leaves a pending state that can be re-checked', () async {
      final repo = _Repo(activeAfter: 99);
      final c = build(repo);
      await c.loadPackages();
      await c.purchase();
      expect(c.pending.value, isTrue);
      expect(nav.pops, 0);
    });

    test('restore goes through the same confirmation', () async {
      final c = build(_Repo());
      await c.restore();
      expect(billing.log, ['restore']);
      expect(nav.pops, 1);
    });

    test('unconfigured builds do not load packages', () async {
      final c = build(_Repo(), b: _Billing(configured: false));
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
      ValueChanged<String>? onSelect,
      VoidCallback? onSubscribe,
      VoidCallback? onCheckAgain,
    }) => PaywallView(
      configured: configured,
      packages: const [
        PaywallPackage(id: 'monthly', title: 'Mensual', priceString: r'$49.00'),
        PaywallPackage(id: 'annual', title: 'Anual', priceString: r'$399.00'),
      ],
      selectedId: selected,
      onSelect: onSelect ?? (_) {},
      busy: busy,
      pending: pending,
      onSubscribe: onSubscribe ?? () {},
      onRestore: () {},
      onCheckAgain: onCheckAgain ?? () {},
      onClose: () {},
    );

    testWidgets('lists packages and subscribes', (tester) async {
      String? picked;
      var subscribed = 0;
      await tester.pumpWidget(
        wrap(
          view(onSelect: (id) => picked = id, onSubscribe: () => subscribed++),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(r'$49.00'), findsOneWidget);
      await tester.tap(find.byKey(const Key('package-annual')));
      expect(picked, 'annual');
      await tester.ensureVisible(find.byKey(const Key('subscribe-button')));
      await tester.tap(find.byKey(const Key('subscribe-button')));
      expect(subscribed, 1);
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
