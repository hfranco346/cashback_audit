import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/utils/cached.dart';
import 'package:cashback_audit/features/auth/domain/auth_entities.dart';
import 'package:cashback_audit/features/cards/data/card_mapper.dart';
import 'package:cashback_audit/features/cards/domain/card_entities.dart';
import 'package:cashback_audit/features/cards/domain/card_repository.dart';
import 'package:cashback_audit/features/onboarding/data/onboarding_draft_repository_impl.dart';
import 'package:cashback_audit/features/onboarding/data/onboarding_sync.dart';
import 'package:cashback_audit/features/onboarding/domain/onboarding_draft.dart';
import 'package:cashback_audit/features/onboarding/domain/onboarding_repository.dart';
import 'package:cashback_audit/features/onboarding/presentation/onboarding_controller.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/domain/pdf_picker.dart';
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';
import 'package:cashback_audit/features/verifications/presentation/confirm_rates_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/verification_poller.dart';
import 'package:decimal/decimal.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_verification_repository.dart';
import '../../support/fakes.dart';
import '../../support/fixtures.dart';
import '../categories/fake_catalog.dart';

import 'package:cashback_audit/features/categories/domain/catalog_entities.dart';

class _Seen implements OnboardingRepository {
  bool seen = false;
  @override
  Future<bool> hasSeenOnboarding() async => seen;
  @override
  Future<void> markOnboardingSeen() async => seen = true;
}

class _Cards implements CardRepository {
  final created = <CardDraft>[];
  Object? error;
  @override
  Future<Cached<List<CreditCard>>> getCards() async => Cached(const []);
  @override
  Future<CreditCard> createCard(CardDraft draft) async {
    if (error != null) throw error!;
    created.add(draft);
    return CardMapper.fromJson(cardJson(id: 'card-1'));
  }

  @override
  Future<CreditCard> updateCard(String id, CardDraft draft) =>
      throw UnimplementedError();
  @override
  Future<void> deleteCard(String id) => throw UnimplementedError();
}

class _Picker implements PdfPicker {
  PickedPdf? result = const PickedPdf(
    name: 'Estado.pdf',
    path: '/tmp/Estado.pdf',
    sizeBytes: 1000,
  );
  @override
  Future<PickedPdf?> pick() async => result;
}

class Harness {
  Harness({bool signedIn = false, bool freeCheck = true}) {
    drafts = OnboardingDraftRepositoryImpl(freshPrefs());
    sync = OnboardingSync(cards: cards, categories: categories, drafts: drafts);
    c = OnboardingController(
      drafts: drafts,
      onboarding: seen,
      navigator: nav,
      sync: sync,
      verifications: verifications,
      picker: picker,
      isSignedIn: () => signedIn,
      userName: () => 'Ana',
      onDataChanged: () async => dataChanged++,
      hasFreeCheck: () => freeCheck,
    );
  }

  final seen = _Seen();
  final nav = FakeNavigator();
  final cards = _Cards();
  final categories = FakeCategoryRepository([
    const Category(id: 'cat-existing', name: 'Farmacia'),
  ]);
  final verifications = FakeVerificationRepository();
  final picker = _Picker();
  late final OnboardingDraftRepositoryImpl drafts;
  late final OnboardingSync sync;
  late final OnboardingController c;
  int dataChanged = 0;

  /// Fills bank, card and categories.
  Future<void> fillSetup() async {
    await c.load();
    await c.start();
    c.selectBank('BAC Credomatic');
    await c.next();
    c.setAlias('BAC Cash');
    c.setLast4('4821');
    c.setCurrency('HNL');
    await c.next();
    c.toggleCategory('Supermercados');
    c.setCategoryRate('Supermercados', '7');
    c.toggleCategory('Farmacia');
    c.setCategoryRate('Farmacia', '7');
    c.toggleCategory('Gasolineras'); // unknown %: read from the statement
  }
}

void main() {
  group('draft persistence', () {
    test('every step is saved and a new controller resumes it', () async {
      final h = Harness();
      await h.fillSetup();
      await h.c.next(); // categories -> account
      expect(h.c.step.value, OnboardingStep.account);

      final saved = await h.drafts.read();
      expect(saved?.step, OnboardingStep.account);
      expect(saved?.bank, 'BAC Credomatic');
      expect(saved?.last4, '4821');
      expect(saved?.categories.map((e) => e.name), [
        'Supermercados',
        'Farmacia',
        'Gasolineras',
      ]);

      // Same storage, new controller (app restarted before sign-in).
      final again = OnboardingController(
        drafts: h.drafts,
        onboarding: _Seen(),
        navigator: FakeNavigator(),
        sync: h.sync,
        verifications: h.verifications,
        picker: h.picker,
        isSignedIn: () => false,
      );
      await again.load();
      expect(again.step.value, OnboardingStep.account);
      expect(again.draft.value.alias, 'BAC Cash');
      again.onClose();
    });

    test('draft JSON survives a round trip and bad data', () async {
      const d = OnboardingDraft(
        step: OnboardingStep.categories,
        bank: 'Banpaís',
        last4: '1234',
        rewardUnit: RewardUnit.points,
        categories: [DraftCategory(name: 'X', rate: '3')],
        cardId: 'c',
      );
      expect(OnboardingDraft.fromJson(d.toJson()), d);
      final repo = OnboardingDraftRepositoryImpl(freshPrefs());
      expect(await repo.read(), isNull);
      await repo.setJustOnboarded(true);
      expect(await repo.isJustOnboarded(), isTrue);
      await repo.setJustOnboarded(false);
      expect(await repo.isJustOnboarded(), isFalse);
    });

    test('step validation gates Continue', () async {
      final h = Harness();
      await h.c.load();
      await h.c.start();
      expect(h.c.canContinue, isFalse); // no bank
      h.c.selectBank('Banpaís');
      expect(h.c.canContinue, isTrue);
      await h.c.next();
      expect(h.c.canContinue, isFalse); // last 4 missing
      h.c.setLast4('12a');
      expect(h.c.canContinue, isFalse);
      h.c.setLast4('1234');
      await h.c.next();
      h.c.setBaseRate('150');
      expect(h.c.canContinue, isFalse);
      h.c.setBaseRate('0');
      h.c.toggleCategory('Farmacia');
      h.c.setCategoryRate('Farmacia', 'abc');
      expect(h.c.canContinue, isFalse);
      h.c.setCategoryRate('Farmacia', '');
      expect(h.c.canContinue, isTrue); // empty = read it from the PDF
    });

    test('back walks the steps; skipping drops the draft', () async {
      final h = Harness();
      await h.c.load();
      await h.c.start();
      h.c.selectBank('Banpaís');
      await h.c.next();
      await h.c.back();
      expect(h.c.step.value, OnboardingStep.bank);
      await h.c.back();
      expect(h.c.step.value, OnboardingStep.demo);
      await h.c.start();
      await h.c.skipSetup();
      expect(h.seen.seen, isTrue);
      expect(await h.drafts.read(), isNull);
      expect(h.nav.routes, ['/login']);
    });
  });

  group('sync after sign-in', () {
    test('creates missing categories, reuses existing, builds rules', () async {
      final h = Harness();
      await h.fillSetup();
      await h.c.next();
      await h.c.afterSignIn(const AppUser(id: 'u1', name: 'Ana Maria'));

      expect(h.categories.items.map((e) => e.name), [
        'Farmacia',
        'Supermercados',
        'Gasolineras',
      ]);
      final card = h.cards.created.single;
      expect(card.bank, 'BAC Credomatic');
      expect(card.alias, 'BAC Cash');
      expect(card.last4, '4821');
      expect(card.currency, 'HNL');
      expect(card.baseRatePercent, Decimal.zero);
      // The category without % is created but gets no rule.
      expect(card.rules.map((r) => r.categoryId), [
        'new-Supermercados',
        'cat-existing',
      ]);
      expect(card.rules.map((r) => r.ratePercent), [
        Decimal.fromInt(7),
        Decimal.fromInt(7),
      ]);
      expect(h.c.draft.value.cardId, 'card-1');
      expect(h.c.step.value, OnboardingStep.pdf);
      expect(h.seen.seen, isTrue);
      expect(h.dataChanged, 1);
    });

    test('prefilled categories sync exactly what is selected', () async {
      final h = Harness();
      await h.c.load();
      await h.c.start();
      h.c.selectBank('BAC Credomatic');
      await h.c.next();
      h.c.setLast4('4821');
      await h.c.next();
      h.c.seedCategories(['Supermercados', 'Farmacia']);
      h.c.seedCategories(['Otra']); // seeding happens once
      expect(h.c.draft.value.categories.map((e) => '${e.name} ${e.rate}'), [
        'Supermercados 7',
        'Farmacia 7',
      ]);
      h.c.toggleCategory('Farmacia'); // the user unticks one
      await h.c.next();
      await h.c.afterSignIn(const AppUser(id: 'u1', name: 'Ana'));
      final card = h.cards.created.single;
      expect(card.baseRatePercent, Decimal.zero);
      expect(card.rules.map((r) => r.categoryId), ['new-Supermercados']);
      expect(card.rules.single.ratePercent, Decimal.fromInt(7));
      // Only the ticked one gets a rule; the unticked is never created.
      expect(h.categories.items.map((e) => e.name), contains('Supermercados'));
    });

    test('a failed sync keeps the draft and retry never duplicates', () async {
      final h = Harness();
      await h.fillSetup();
      await h.c.next();
      h.cards.error = const AppException(kind: AppErrorKind.network);
      await h.c.afterSignIn(const AppUser(id: 'u1'));
      expect(h.c.syncError.value, isNotNull);
      expect(h.c.step.value, OnboardingStep.account);
      expect(h.cards.created, isEmpty);
      expect((await h.drafts.read())?.bank, 'BAC Credomatic');

      h.cards.error = null;
      await h.c.retrySync();
      await h.c.retrySync(); // already synced: no second card
      expect(h.cards.created, hasLength(1));
      expect(h.c.syncError.value, isNull);
      expect(h.c.step.value, OnboardingStep.pdf);
    });

    test('a signed-in user reopening the setup syncs without login', () async {
      final h = Harness(signedIn: true);
      await h.c.load();
      expect(h.c.step.value, OnboardingStep.bank); // no demo
      h.c.selectBank('Banco Ficohsa');
      await h.c.next();
      h.c.setLast4('3618');
      await h.c.next();
      await h.c.next(); // categories -> sync -> pdf
      expect(h.cards.created, hasLength(1));
      expect(h.c.step.value, OnboardingStep.pdf);
    });

    test('no credit left finishes at Home instead of the PDF step', () async {
      final h = Harness(signedIn: true, freeCheck: false);
      await h.c.load();
      h.c.selectBank('Banpaís');
      await h.c.next();
      h.c.setLast4('1111');
      await h.c.next();
      await h.c.next();
      expect(h.nav.routes, ['/home']);
      expect(await h.drafts.read(), isNull);
    });
  });

  group('first PDF', () {
    Future<Harness> atPdf() async {
      final h = Harness();
      await h.fillSetup();
      await h.c.next();
      await h.c.afterSignIn(const AppUser(id: 'u1'));
      return h;
    }

    test('upload, poll, confirm rates and reveal the verdict', () {
      fakeAsync((async) {
        late Harness h;
        atPdf().then((v) => h = v);
        async.flushMicrotasks();
        h.verifications.getResults.addAll([
          {...verificationJson(), 'status': 'PROCESSING'},
          awaitingVerificationJson(),
        ]);
        h.nav.nextResult = VerificationMapper.detail(verificationJson());
        h.c.pickPdf();
        async.flushMicrotasks();
        expect(h.c.canAnalyze, isTrue);
        h.c.startAnalysis();
        async.flushMicrotasks();
        expect(h.c.pdfPhase.value, FirstPdfPhase.processing);
        expect(h.nav.pushedForResult, isEmpty);
        async.elapse(const Duration(seconds: 4));
        async.elapse(const Duration(seconds: 4));
        async.flushMicrotasks();
        expect(h.nav.pushedForResult, ['/confirm-rates']);
        final args = h.nav.pushedForResultArgs.single as ConfirmRatesArgs;
        expect(args.returnToResult, isTrue);
        expect(h.c.step.value, OnboardingStep.verdict);
        expect(h.c.verification.value?.isCompleted, isTrue);
      });
    });

    test('leaving while processing stops polling and goes Home', () {
      fakeAsync((async) {
        late Harness h;
        atPdf().then((v) => h = v);
        async.flushMicrotasks();
        h.verifications.getResults.add({
          ...verificationJson(),
          'status': 'PROCESSING',
        });
        h.c.pickPdf();
        async.flushMicrotasks();
        h.c.startAnalysis();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 9));
        final calls = h.verifications.getCalls;
        expect(calls, greaterThan(0));
        h.c.leaveToHome();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 60));
        expect(h.verifications.getCalls, calls);
        expect(h.nav.routes.last, '/home');
      });
    });

    test('a failed analysis offers another PDF (credit refunded)', () {
      fakeAsync((async) {
        late Harness h;
        atPdf().then((v) => h = v);
        async.flushMicrotasks();
        h.verifications.getResults.add({
          ...verificationJson(),
          'status': 'FAILED',
          'failureCode': 'NOT_A_STATEMENT',
        });
        h.c.pickPdf();
        async.flushMicrotasks();
        h.c.startAnalysis();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 4));
        expect(h.c.pdfPhase.value, FirstPdfPhase.failed);
        expect(h.c.failure.value, FailureCode.notAStatement);
        h.c.retryPdf();
        expect(h.c.pdfPhase.value, FirstPdfPhase.pick);
        expect(h.c.file.value, isNull);
      });
    });

    test('rejects files that are not PDFs', () async {
      final h = await atPdf();
      h.picker.result = const PickedPdf(
        name: 'a.png',
        path: '/a',
        sizeBytes: 3,
      );
      await h.c.pickPdf();
      expect(h.c.file.value, isNull);
      expect(h.c.pdfError.value, 'type');
    });
  });

  test('the poller default interval is 4 seconds', () {
    expect(
      VerificationPoller(repository: FakeVerificationRepository()).interval,
      const Duration(seconds: 4),
    );
  });
}
