import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/utils/cached.dart';
import 'package:cashback_audit/features/cards/data/card_mapper.dart';
import 'package:cashback_audit/features/cards/domain/card_entities.dart';
import 'package:cashback_audit/features/cards/domain/card_repository.dart';
import 'package:cashback_audit/features/cards/presentation/cards_controller.dart';
import 'package:cashback_audit/features/categories/domain/catalog_entities.dart';
import 'package:cashback_audit/features/categories/presentation/catalog_controller.dart';
import 'package:cashback_audit/features/credits/presentation/credits_controller.dart';
import 'package:cashback_audit/features/home/presentation/home_controller.dart';
import 'package:cashback_audit/features/home/presentation/home_page.dart';
import 'package:cashback_audit/features/home/presentation/widgets/home_view.dart';
import 'package:cashback_audit/features/home/presentation/widgets/pending_banner.dart';
import 'package:cashback_audit/features/navigation/presentation/app_navigation_shell.dart';
import 'package:cashback_audit/features/navigation/presentation/shell_controller.dart';
import 'package:cashback_audit/features/onboarding/data/onboarding_draft_repository_impl.dart';
import 'package:cashback_audit/features/onboarding/data/onboarding_sync.dart';
import 'package:cashback_audit/features/onboarding/domain/onboarding_draft.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';
import 'package:cashback_audit/features/verifications/domain/verification_events.dart';
import 'package:cashback_audit/features/verifications/presentation/attention_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/history_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../core/ui/ui_harness.dart';
import '../../support/fake_credits_repository.dart';
import '../../support/fake_verification_repository.dart';
import '../../support/fakes.dart';
import '../../support/lifecycle.dart';
import '../../support/fixtures.dart';
import '../categories/fake_catalog.dart';

class FakeCardRepo implements CardRepository {
  FakeCardRepo(this.items);
  List<CreditCard> items;
  final created = <CardDraft>[];
  @override
  Future<Cached<List<CreditCard>>> getCards() async => Cached(items);
  @override
  Future<CreditCard> createCard(CardDraft draft) async {
    created.add(draft);
    final card = CardMapper.fromJson(cardJson(id: 'new'));
    items = [...items, card];
    return card;
  }

  @override
  Future<CreditCard> updateCard(String id, CardDraft draft) =>
      throw UnimplementedError();
  @override
  Future<void> deleteCard(String id) => throw UnimplementedError();
}

VerificationSummary _summary(
  String id,
  String status, {
  String? code,
  String? seenAt,
}) => VerificationMapper.summary({
  ...summaryJson(id),
  'status': status,
  'failureCode': code,
  'seenAt': seenAt,
  if (status != 'COMPLETED') 'verdict': null,
});

class HomeHarness {
  HomeHarness({
    List<CreditCard>? cards,
    bool signedIn = true,
    this.events,
    this.shell,
    this.routeOnTop,
  }) {
    cardRepo = FakeCardRepo(cards ?? []);
    drafts = OnboardingDraftRepositoryImpl(freshPrefs());
    cardsC = CardsController(cardRepo);
    catalog = CatalogController(
      categories: FakeCategoryRepository([
        const Category(id: 'cat1', name: 'Supermercados'),
      ]),
      merchants: FakeMerchantRepository(),
    );
    latest = LatestVerificationsController(verifications);
    credits = CreditsController(
      repository: FakeCreditsRepository([balance(free: 1)]),
    );
    attention = AttentionController(repository: verifications, navigator: nav);
    c = HomeController(
      attention: attention,
      cards: cardsC,
      catalog: catalog,
      latest: latest,
      credits: credits,
      drafts: drafts,
      verifications: verifications,
      sync: OnboardingSync(
        cards: cardRepo,
        categories: FakeCategoryRepository([]),
        drafts: drafts,
      ),
      startup: () async => startups++,
      isSignedIn: () => signedIn,
      events: events,
      shell: shell,
      isRouteOnTop: routeOnTop,
    );
  }

  final VerificationEvents? events;
  final RxInt? shell;
  final bool Function()? routeOnTop;
  final nav = FakeNavigator();
  final verifications = FakeVerificationRepository();
  int startups = 0;
  late final FakeCardRepo cardRepo;
  late final OnboardingDraftRepositoryImpl drafts;
  late final CardsController cardsC;
  late final CatalogController catalog;
  late final LatestVerificationsController latest;
  late final CreditsController credits;
  late final AttentionController attention;
  late final HomeController c;
}

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeController', () {
    test('loads pending verifications on start and on app resume', () async {
      final h = HomeHarness();
      h.verifications.attentionItems = [_summary('a', 'PROCESSING')];
      h.c.onInit();
      h.c.onReady();
      await _settle();
      expect(h.startups, 1);
      expect(h.verifications.attentionCalls, 1);
      expect(h.attention.items.map((e) => e.id), ['a']);

      h.verifications.attentionItems = [_summary('a', 'AWAITING_RATES')];
      setAppLifecycle(binding, AppLifecycleState.paused);
      expect(h.verifications.attentionCalls, 1); // only resume refreshes
      setAppLifecycle(binding, AppLifecycleState.resumed);
      await _settle();
      expect(h.verifications.attentionCalls, 2);
      expect(h.attention.items.single.isAwaitingRates, isTrue);
      h.c.onClose();
    });

    test('layout: loading, empty, fresh and full', () async {
      final h = HomeHarness();
      expect(h.c.layout, HomeLayout.loading);
      await h.cardsC.load();
      expect(h.c.layout, HomeLayout.empty);

      final card = CardMapper.fromJson(cardJson());
      final h2 = HomeHarness(cards: [card]);
      await h2.cardsC.load();
      expect(h2.c.layout, HomeLayout.full);
      h2.c.fresh.value = true;
      expect(h2.c.layout, HomeLayout.fresh);
      h2.latest.items.assignAll([
        _summary('a', 'COMPLETED'),
        _summary('b', 'COMPLETED'),
      ]);
      expect(h2.c.layout, HomeLayout.full); // more than the first check
    });

    test('just-onboarded flag shows the uncategorized notice', () async {
      final h = HomeHarness(cards: [CardMapper.fromJson(cardJson())]);
      await h.drafts.setJustOnboarded(true);
      h.verifications.items = [_summary('v1', 'COMPLETED')];
      h.verifications.detailJson = verificationJson();
      h.c.onInit();
      h.c.onReady();
      await _settle();
      expect(h.c.fresh.value, isTrue);
      expect(h.c.uncategorized.value, 1);
      await h.c.dismissFresh();
      expect(h.c.fresh.value, isFalse);
      expect(await h.drafts.isJustOnboarded(), isFalse);
      h.c.onClose();
    });

    test('finishes a draft that was signed in but never synced', () async {
      final h = HomeHarness();
      await h.drafts.save(
        const OnboardingDraft(
          step: OnboardingStep.pdf,
          bank: 'BAC Credomatic',
          alias: 'BAC Cash',
          last4: '4821',
        ),
      );
      h.c.onInit();
      h.c.onReady();
      await _settle();
      expect(h.cardRepo.created, hasLength(1));
      expect(h.c.cards.cards, hasLength(1));
      h.c.onClose();
    });

    test('a failing attention refresh keeps Home usable', () async {
      final h = HomeHarness();
      h.verifications.attentionError = const AppException(
        kind: AppErrorKind.network,
      );
      await h.attention.reload();
      expect(h.attention.items, isEmpty);
      expect(h.attention.failed.value, isTrue);
    });
  });

  testWidgets('greeting follows the hour and the name', (tester) async {
    await pumpUi(
      tester,
      Builder(
        builder: (context) => Column(
          children: [
            Text(HomePage.greetingFor(context, DateTime(2026, 1, 1, 8), 'Ana')),
            Text(HomePage.greetingFor(context, DateTime(2026, 1, 1, 15), null)),
            Text(
              HomePage.greetingFor(context, DateTime(2026, 1, 1, 22), 'Ana'),
            ),
          ],
        ),
      ),
    );
    expect(find.text('Buenos días, Ana'), findsOneWidget);
    expect(find.text('Buenas tardes'), findsOneWidget);
    expect(find.text('Buenas noches, Ana'), findsOneWidget);
    expect(HomePage.initialsOf('Ana Mora'), 'AM');
    expect(HomePage.initialsOf(null), '?');
  });

  group('PendingBanner', () {
    Future<void> pumpBanner(
      WidgetTester tester,
      VerificationSummary item, {
      bool dark = false,
      String lang = 'es',
      VoidCallback? onTap,
    }) => pumpUi(
      tester,
      PendingBanner(
        item: item,
        cardLabel: 'BAC Cash · 4821',
        onTap: onTap ?? () {},
      ),
      dark: dark,
      lang: lang,
    );

    testWidgets('processing shows a spinner and says you can close the app', (
      tester,
    ) async {
      await pumpBanner(tester, _summary('p', 'PROCESSING'));
      expect(find.text('Analizando…'), findsOneWidget);
      expect(find.textContaining('puedes cerrar la app'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('awaiting rates, new result and failed (ES + EN, dark)', (
      tester,
    ) async {
      var taps = 0;
      await pumpBanner(
        tester,
        _summary('r', 'AWAITING_RATES'),
        onTap: () => taps++,
      );
      expect(find.text('Lista para confirmar'), findsOneWidget);
      expect(find.text('Seguir'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pending-r')));
      expect(taps, 1);

      await pumpBanner(tester, _summary('c', 'COMPLETED'), dark: true);
      expect(find.text('Resultado nuevo'), findsOneWidget);

      await pumpBanner(
        tester,
        _summary('f', 'FAILED', code: 'NOT_A_STATEMENT'),
        lang: 'en',
      );
      expect(find.text('Could not analyze'), findsOneWidget);
      expect(find.textContaining('refunded'), findsOneWidget);

      await pumpBanner(
        tester,
        _summary('f2', 'FAILED', code: 'INTERRUPTED'),
        lang: 'es',
      );
      expect(find.textContaining('interrumpió'), findsOneWidget);
      expect(find.textContaining('devuelta'), findsOneWidget);
    });
  });

  group('HomeView states', () {
    const variants = [
      (dark: false, lang: 'es'),
      (dark: true, lang: 'es'),
      (dark: false, lang: 'en'),
      (dark: true, lang: 'en'),
    ];
    final card = CardMapper.fromJson(
      cardJson(
        id: 'c1',
        alias: 'BAC Cash',
        rules: [
          {'categoryId': 'cat1', 'ratePercent': '7'},
        ],
      ),
    );

    HomeView view(
      HomeLayout layout, {
      List<CreditCard> cards = const [],
      List<VerificationSummary> latest = const [],
      List<VerificationSummary> pending = const [],
      int? free,
      int? total,
      int uncategorized = 0,
      VoidCallback? onVerify,
      VoidCallback? onGuided,
      VoidCallback? onAdd,
      ValueChanged<VerificationSummary>? onPending,
    }) => HomeView(
      layout: layout,
      greeting: 'Hola, Ana',
      initials: 'AM',
      firstName: 'Ana',
      cards: cards,
      latest: latest,
      pending: pending,
      cardLabel: (_) => 'BAC Cash · 4321',
      categoryName: (_) => 'Supermercados',
      freeChecks: free,
      totalChecks: total,
      uncategorized: uncategorized,
      onRefresh: () async {},
      onProfile: () {},
      onVerify: onVerify ?? () {},
      onAddCard: onAdd ?? () {},
      onOpenCard: (_) {},
      onOpenVerification: (_) {},
      onOpenPending: onPending ?? (_) {},
      onSeeAll: () {},
      onGetMore: () {},
      onGuidedSetup: onGuided ?? () {},
    );

    for (final v in variants) {
      final tag = '${v.lang}${v.dark ? ' dark' : ''}';
      final es = v.lang == 'es';

      testWidgets('empty state offers the guided setup ($tag)', (tester) async {
        var guided = 0;
        var added = 0;
        await pumpUi(
          tester,
          view(
            HomeLayout.empty,
            free: 1,
            onGuided: () => guided++,
            onAdd: () => added++,
          ),
          dark: v.dark,
          lang: v.lang,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.text(
            es ? 'Empecemos por tu tarjeta' : 'Let us start with your card',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            es ? '1 verificación gratis disponible' : '1 free check available',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('home-add-card')));
        await tester.ensureVisible(find.byKey(const Key('home-guided-setup')));
        await tester.tap(find.byKey(const Key('home-guided-setup')));
        expect((added, guided), (1, 1));
        expect(tester.takeException(), isNull);
      });

      testWidgets('just-onboarded shows the exact registered data ($tag)', (
        tester,
      ) async {
        await pumpUi(
          tester,
          view(
            HomeLayout.fresh,
            cards: [card],
            latest: [_summary('v1', 'COMPLETED')],
            free: 0,
            uncategorized: 12,
          ),
          dark: v.dark,
          lang: v.lang,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('BAC Cash'), findsWidgets);
        expect(find.textContaining('Supermercados 7%'), findsOneWidget);
        expect(find.byKey(const Key('home-uncategorized')), findsOneWidget);
        expect(
          find.textContaining(
            es
                ? '12 compras quedaron sin rubro'
                : '12 purchases have no category',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            es ? 'Usaste tu verificación gratis' : 'You used your free check',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('continuous use lists cards and latest checks ($tag)', (
        tester,
      ) async {
        var verify = 0;
        await pumpUi(
          tester,
          view(
            HomeLayout.full,
            cards: [
              card,
              CardMapper.fromJson(cardJson(id: 'c2', alias: 'Ficohsa')),
            ],
            latest: [_summary('a', 'COMPLETED'), _summary('b', 'COMPLETED')],
            total: 3,
            onVerify: () => verify++,
          ),
          dark: v.dark,
          lang: v.lang,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(find.byKey(const Key('home-card-c1')), findsOneWidget);
        expect(find.byKey(const Key('home-card-c2')), findsOneWidget);
        expect(find.byKey(const Key('home-verification-a')), findsOneWidget);
        await tester.tap(find.byKey(const Key('home-verify')));
        expect(verify, 1);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('pending banners sit on top and open the tapped item', (
      tester,
    ) async {
      final opened = <String>[];
      await pumpUi(
        tester,
        view(
          HomeLayout.full,
          cards: [card],
          pending: [
            _summary('p', 'PROCESSING'),
            _summary('r', 'AWAITING_RATES'),
            _summary('c', 'COMPLETED'),
            _summary('f', 'FAILED', code: 'EXTRACTION_FAILED'),
          ],
          onPending: (i) => opened.add(i.id),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PendingBanner), findsNWidgets(4));
      await tester.tap(find.byKey(const Key('pending-r')));
      await tester.tap(find.byKey(const Key('pending-c')));
      expect(opened, ['r', 'c']);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('AppNavigationShell', () {
    testWidgets('shows the four tabs and builds them lazily', (tester) async {
      final shell = ShellController();
      final built = <int>[];
      Widget tab(int i) {
        built.add(i);
        return Center(child: Text('tab-$i'));
      }

      await pumpUi(
        tester,
        AppNavigationShell(
          controller: shell,
          tabs: [for (var i = 0; i < 4; i++) (_) => tab(i)],
        ),
      );
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Historial'), findsOneWidget);
      expect(find.text('Rubros'), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(built.toSet(), {0});

      await tester.tap(find.text('Rubros'));
      await tester.pumpAndSettle();
      expect(shell.tab.value, 2);
      expect(built.toSet(), {0, 2});

      shell.select(3);
      await tester.pumpAndSettle();
      expect(find.text('tab-3'), findsOneWidget);
      shell.select(9); // ignored
      expect(shell.tab.value, 3);
    });

    testWidgets('labels are English with an English phone', (tester) async {
      await pumpUi(
        tester,
        AppNavigationShell(
          controller: ShellController(),
          tabs: [for (var i = 0; i < 4; i++) (_) => const SizedBox()],
        ),
        lang: 'en',
        dark: true,
      );
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });
  });

  group('Home auto refresh', () {
    const five = Duration(seconds: 5);
    tearDown(() => setAppLifecycle(binding, AppLifecycleState.resumed));

    test('polls the pending list every 5 s while processing, then stops', () {
      fakeAsync((async) {
        final h = HomeHarness(events: VerificationEvents(), shell: 0.obs);
        h.verifications.attentionItems = [_summary('a', 'PROCESSING')];
        h.c.onInit();
        h.c.onReady();
        async.flushMicrotasks();
        expect(h.verifications.attentionCalls, 1);

        async.elapse(five);
        expect(h.verifications.attentionCalls, 2);
        async.elapse(five);
        expect(h.verifications.attentionCalls, 3);

        // The analysis ends: the pending row changes with no pull-to-refresh
        // and the latest list and the balance reload with it.
        final historyBefore = h.verifications.historyCalls;
        h.verifications.attentionItems = [_summary('a', 'AWAITING_RATES')];
        async.elapse(five);
        expect(h.attention.items.single.isAwaitingRates, isTrue);
        expect(h.verifications.historyCalls, greaterThan(historyBefore));

        // Nothing processing: no more requests.
        final settled = h.verifications.attentionCalls;
        async.elapse(five * 4);
        expect(h.verifications.attentionCalls, settled);
        h.c.onClose();
      });
    });

    test('does not poll when nothing is processing', () {
      fakeAsync((async) {
        final h = HomeHarness(events: VerificationEvents(), shell: 0.obs);
        h.verifications.attentionItems = [_summary('a', 'COMPLETED')];
        h.c.onInit();
        h.c.onReady();
        async.flushMicrotasks();
        async.elapse(five * 3);
        expect(h.verifications.attentionCalls, 1);
        h.c.onClose();
      });
    });

    test('stops on another tab or route and refreshes when shown again', () {
      fakeAsync((async) {
        final tab = 0.obs;
        var onTop = true;
        final h = HomeHarness(
          events: VerificationEvents(),
          shell: tab,
          routeOnTop: () => onTop,
        );
        h.verifications.attentionItems = [_summary('a', 'PROCESSING')];
        h.c.onInit();
        h.c.onReady();
        async.flushMicrotasks();
        async.elapse(five);
        expect(h.verifications.attentionCalls, 2);

        tab.value = 2; // Categories
        async.flushMicrotasks();
        async.elapse(five * 3);
        expect(h.verifications.attentionCalls, 2);

        tab.value = 0;
        async.flushMicrotasks();
        expect(h.verifications.attentionCalls, 3); // refreshed on show

        onTop = false; // a pushed route covers Home
        async.elapse(five * 3);
        expect(h.verifications.attentionCalls, 3);
        h.c.onClose();
      });
    });

    test('refreshes on upload / confirm / seen events and on resume', () {
      fakeAsync((async) {
        final events = VerificationEvents();
        final h = HomeHarness(events: events, shell: 0.obs);
        h.verifications.attentionItems = [];
        h.c.onInit();
        h.c.onReady();
        async.flushMicrotasks();
        expect(h.verifications.attentionCalls, 1);

        // Returning from verify / progress / confirm / result emits one.
        h.verifications.attentionItems = [_summary('n', 'PROCESSING')];
        events.notify();
        async.flushMicrotasks();
        expect(h.attention.items.single.id, 'n');
        expect(h.verifications.attentionCalls, 2);
        // The balance moves with it (an upload spends a credit).
        expect(h.credits.balance.value, isNotNull);

        setAppLifecycle(binding, AppLifecycleState.paused);
        h.verifications.attentionItems = [_summary('n', 'COMPLETED')];
        setAppLifecycle(binding, AppLifecycleState.resumed);
        async.flushMicrotasks();
        expect(h.attention.items.single.isCompleted, isTrue);
        h.c.onClose();
      });
    });
  });

  test('history controller can be created without arguments for the tab', () {
    final c = HistoryController(
      repository: FakeVerificationRepository(),
      navigator: FakeNavigator(),
    );
    expect(c.cardFilter.value, isNull);
  });
}
