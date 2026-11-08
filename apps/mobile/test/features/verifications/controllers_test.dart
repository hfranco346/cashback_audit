import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/utils/cached.dart';
import 'package:cashback_audit/features/cards/domain/card_entities.dart';
import 'package:cashback_audit/features/cards/domain/card_repository.dart';
import 'package:cashback_audit/features/cards/presentation/cards_controller.dart';
import 'package:cashback_audit/features/categories/domain/catalog_entities.dart';
import 'package:cashback_audit/features/categories/presentation/catalog_controller.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/domain/pdf_picker.dart';
import 'package:cashback_audit/features/verifications/presentation/confirm_rates_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/history_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/result_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/upload_controller.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';

import '../../support/fake_verification_repository.dart';
import '../../support/fakes.dart';
import '../../support/fixtures.dart';
import '../categories/fake_catalog.dart';

class _Picker implements PdfPicker {
  _Picker(this.result);
  PickedPdf? result;
  @override
  Future<PickedPdf?> pick() async => result;
}

class _CardRepo implements CardRepository {
  _CardRepo(this.cards);
  final List<CreditCard> cards;
  @override
  Future<Cached<List<CreditCard>>> getCards() async => Cached(cards);
  @override
  Future<CreditCard> createCard(CardDraft draft) => throw UnimplementedError();
  @override
  Future<CreditCard> updateCard(String id, CardDraft draft) =>
      throw UnimplementedError();
  @override
  Future<void> deleteCard(String id) async {}
}

const _pdf = PickedPdf(name: 'edo.pdf', path: '/tmp/edo.pdf', sizeBytes: 1000);

void main() {
  group('UploadController', () {
    late FakeVerificationRepository repo;
    late _Picker picker;
    late FakeNavigator nav;
    late UploadController c;
    var verified = 0;

    setUp(() {
      repo = FakeVerificationRepository();
      picker = _Picker(_pdf);
      nav = FakeNavigator();
      verified = 0;
      final cards = CardsController(_CardRepo([]));
      c = UploadController(
        repository: repo,
        picker: picker,
        cards: cards,
        navigator: nav,
        onVerified: () => verified++,
        initialCardId: 'c1',
      )..onInit();
    });
    tearDown(() => c.onClose());

    test('cannot submit without a file', () async {
      expect(c.canSubmit, isFalse);
      await c.submit();
      expect(nav.replaced, isEmpty);
    });

    test('rejects non-PDF and oversized files', () async {
      picker.result = const PickedPdf(name: 'a.png', path: '/a', sizeBytes: 5);
      await c.pickFile();
      expect(c.errorMessage.value, S.fileNotPdf);
      picker.result = const PickedPdf(
        name: 'big.pdf',
        path: '/b',
        sizeBytes: 11 * 1024 * 1024,
      );
      await c.pickFile();
      expect(c.errorMessage.value, S.fileTooLarge);
      expect(c.file.value, isNull);
    });

    test('success opens the result and refreshes the home list', () async {
      await c.pickFile();
      expect(c.canSubmit, isTrue);
      await c.submit();
      // Step 1 only produced the rate proposal: the user confirms it next.
      expect(nav.replaced, ['/confirm-rates']);
      final args = nav.replacedArgs.single as ConfirmRatesArgs;
      expect(args.verification?.isAwaitingRates, isTrue);
      expect(verified, 1);
      expect(c.phase.value, UploadPhase.idle);
    });

    test('402 routes to the paywall', () async {
      repo.verifyError = const AppException(
        kind: AppErrorKind.noCredits,
        statusCode: 402,
        code: 'NO_CREDITS',
      );
      await c.pickFile();
      await c.submit();
      expect(nav.pushed, ['/paywall']);
      expect(c.errorMessage.value, S.errNoCredits);
    });

    test('timeouts tell the user to check history before retrying', () async {
      repo.verifyError = const AppException(kind: AppErrorKind.timeout);
      await c.pickFile();
      await c.submit();
      expect(c.errorMessage.value, S.uploadTimeout);
      expect(nav.replaced, isEmpty);
    });
  });

  group('ResultController', () {
    late CatalogController catalog;
    late ResultController c;
    late FakeMerchantRepository merchants;
    late FakeVerificationRepository repo;
    late FakeNavigator nav;

    setUp(() async {
      merchants = FakeMerchantRepository();
      catalog = CatalogController(
        categories: FakeCategoryRepository(const [
          Category(id: 'cat1', name: 'Super'),
        ]),
        merchants: merchants,
      );
      await catalog.load();
      repo = FakeVerificationRepository();
      nav = FakeNavigator();
      c = ResultController(
        repository: repo,
        catalog: catalog,
        navigator: nav,
        initial: VerificationMapper.detail(verificationJson()),
      )..onInit();
    });

    test('filters transactions', () {
      expect(c.visibleTransactions, hasLength(2));
      c.setFilter(TransactionFilter.counted);
      expect(c.visibleTransactions.single.index, 0);
      c.setFilter(TransactionFilter.uncounted);
      expect(c.visibleTransactions.single.index, 1);
      c.setFilter(TransactionFilter.excluded);
      expect(c.visibleTransactions, isEmpty);
    });

    test('excluded lines are neither counted nor uncounted', () {
      final withExcluded = ResultController(
        repository: repo,
        catalog: catalog,
        navigator: nav,
        initial: VerificationMapper.detail(
          verificationJson(
            transactions: [
              txJson(0, 'SUPER', '100', source: 'KEYWORD'),
              txJson(1, 'OXXO', '100', source: 'NONE'),
              txJson(2, 'PAGO', '100', source: 'NONE', kind: 'PAYMENT'),
            ],
          ),
        ),
      )..onInit();
      withExcluded.setFilter(TransactionFilter.excluded);
      expect(withExcluded.visibleTransactions.single.index, 2);
      withExcluded.setFilter(TransactionFilter.uncounted);
      expect(withExcluded.visibleTransactions.single.index, 1);
    });

    group('line correction', () {
      VerificationTransaction line(int i) =>
          c.verification.value!.transactions[i];

      test('PATCHes the line then re-confirms with the same rates', () async {
        final message = await c.correctCategory(line(1), 'cat1');
        expect(repo.corrections.single.id, 'v1');
        expect(repo.corrections.single.index, 1);
        expect(repo.corrections.single.categoryId, 'cat1');
        // Free recalculation with exactly the applied rates (base 1, cat1 5).
        final req = repo.confirmRequests.single;
        expect(req.baseRatePercent, Decimal.parse('1'));
        expect(req.categoryRates.single.categoryId, 'cat1');
        expect(req.categoryRates.single.ratePercent, Decimal.parse('5'));
        expect(req.saveToCard, isFalse);
        expect(req.exchangeRate, isNull);
        expect(req.rewardProgramName, isNull);
        expect(message, S.categoryChanged);
        expect(c.stale.value, isFalse);
        expect(c.recalculating.value, isFalse);
      });

      test('clearing a category sends null', () async {
        await c.correctCategory(line(0), null);
        expect(repo.corrections.single.categoryId, isNull);
        expect(repo.confirmRequests, hasLength(1));
      });

      test('same category is a no-op', () async {
        await c.correctCategory(line(0), 'cat1');
        expect(repo.corrections, isEmpty);
      });

      test(
        'a failed PATCH shows the message and does not recalculate',
        () async {
          repo.correctError = const AppException(
            kind: AppErrorKind.unprocessable,
            statusCode: 422,
            code: 'TRANSACTION_NOT_CLASSIFIABLE',
          );
          final message = await c.correctCategory(line(1), 'cat1');
          expect(message, S.errTransactionNotClassifiable);
          expect(repo.confirmRequests, isEmpty);
        },
      );

      test(
        'a failed recalculation marks the result stale and can retry',
        () async {
          repo.confirmErrors.add(
            const AppException(kind: AppErrorKind.network),
          );
          final message = await c.correctCategory(line(1), 'cat1');
          expect(message, S.recalcFailedAfterChange);
          expect(c.stale.value, isTrue);
          expect(await c.retryRecalculation(), S.categoryChanged);
          expect(c.stale.value, isFalse);
          expect(repo.confirmRequests, hasLength(2));
        },
      );

      test('a new category needing a rate reopens the confirmation', () async {
        repo.confirmErrors.add(
          const AppException(
            kind: AppErrorKind.unprocessable,
            statusCode: 422,
            code: 'RATES_REQUIRED',
          ),
        );
        final message = await c.correctCategory(line(1), 'cat1');
        expect(message, S.recalcNeedsRate);
        expect(nav.pushedForResult, ['/confirm-rates']);
        final args = nav.pushedForResultArgs.single as ConfirmRatesArgs;
        expect(args.returnToResult, isTrue);
        expect(args.verification?.id, 'v1');
      });
    });

    test(
      '"Recalcular con otros %" opens the confirmation and takes its result',
      () async {
        final fresh = VerificationMapper.detail(
          verificationJson(verdict: 'MATCH'),
        );
        nav.nextResult = fresh;
        await c.recalculateWithOtherRates();
        expect(nav.pushedForResult, ['/confirm-rates']);
        final args = nav.pushedForResultArgs.single as ConfirmRatesArgs;
        expect(args.returnToResult, isTrue);
        expect(args.verification?.appliedRates, isNotNull);
        expect(c.verification.value?.verdict, Verdict.match);
      },
    );

    test('cancelling the confirmation keeps the current result', () async {
      nav.nextResult = null;
      await c.recalculateWithOtherRates();
      expect(c.verification.value?.verdict, Verdict.underpaid);
    });

    test(
      'assigning creates a merchant with the descriptor as keyword',
      () async {
        final tx = c.verification.value!.transactions.last;
        final err = await c.assignMerchant(
          tx,
          name: 'Oxxo',
          keywords: ['OXXO REFORMA'],
          categoryId: 'cat1',
        );
        expect(err, isNull);
        expect(merchants.calls.single, 'create:Oxxo:cat1:OXXO REFORMA');
        expect(c.assigned[1], 'Super');
      },
    );

    test('loads by id when opened from history', () async {
      final byId = ResultController(
        repository: repo,
        catalog: catalog,
        navigator: nav,
        verificationId: 'v9',
      )..onInit();
      await Future<void>.delayed(Duration.zero);
      expect(byId.verification.value?.id, 'v9');
    });

    test('cleanDescriptor strips branch numbers', () {
      expect(cleanDescriptor('WAL MART SUC 123'), 'WAL MART');
      expect(cleanDescriptor('OXXO #4455'), 'OXXO');
      expect(cleanDescriptor('SORIANA'), 'SORIANA');
    });
  });

  group('HistoryController', () {
    test('paginates, filters by card and deletes', () async {
      final repo = FakeVerificationRepository()
        ..items = [
          for (var i = 0; i < 3; i++)
            VerificationMapper.summary(summaryJson('v$i')),
        ];
      final nav = FakeNavigator();
      final c = HistoryController(repository: repo, navigator: nav, pageSize: 2)
        ..onInit();
      await c.load();
      expect(c.items, hasLength(2));
      expect(c.hasMore.value, isTrue);
      await c.loadMore();
      expect(c.items, hasLength(3));
      expect(c.hasMore.value, isFalse);
      c.open(c.items.first);
      expect(nav.pushed, ['/result']);
      expect(nav.pushedArgs.single, 'v0');
      // A statement still waiting for its rates resumes in the confirmation.
      c.open(
        VerificationMapper.summary({
          ...summaryJson('pending'),
          'status': 'AWAITING_RATES',
          'verdict': null,
        }),
      );
      expect(nav.pushed.last, '/confirm-rates');
      expect(
        (nav.pushedArgs.last as ConfirmRatesArgs).verificationId,
        'pending',
      );
      expect(await c.delete(c.items.first), isNull);
      expect(repo.deleted, ['v0']);
      expect(c.items, hasLength(2));
    });

    test('latest controller loads three', () async {
      final repo = FakeVerificationRepository()
        ..items = [
          for (var i = 0; i < 5; i++)
            VerificationMapper.summary(summaryJson('v$i')),
        ];
      final c = LatestVerificationsController(repo);
      await c.load();
      expect(repo.pageSizeSeen, 3);
      expect(c.items, hasLength(3));
    });
  });
}
