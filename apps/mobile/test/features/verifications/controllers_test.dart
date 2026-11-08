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
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';
import 'package:cashback_audit/features/verifications/domain/verification_repository.dart';
import 'package:cashback_audit/features/verifications/presentation/history_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/result_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/upload_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/fixtures.dart';
import '../categories/fake_catalog.dart';

class _VerRepo implements VerificationRepository {
  Object? verifyError;
  String? lastOverride;
  final deleted = <String>[];
  List<VerificationSummary> items = [];
  int pageSizeSeen = 0;

  @override
  Future<Verification> verify({
    required String cardId,
    required String filePath,
    String? reportedRewardOverride,
    UploadProgress? onProgress,
  }) async {
    lastOverride = reportedRewardOverride;
    onProgress?.call(5, 10);
    onProgress?.call(10, 10);
    if (verifyError != null) throw verifyError!;
    return VerificationMapper.detail(verificationJson());
  }

  @override
  Future<Cached<VerificationPage>> history({
    String? cardId,
    int page = 1,
    int pageSize = 20,
  }) async {
    pageSizeSeen = pageSize;
    final start = (page - 1) * pageSize;
    final slice = items.skip(start).take(pageSize).toList();
    return Cached(
      VerificationPage(
        items: slice,
        page: page,
        pageSize: pageSize,
        total: items.length,
      ),
    );
  }

  @override
  Future<Cached<Verification>> detail(String id) async =>
      Cached(VerificationMapper.detail(verificationJson(id: id)));

  @override
  Future<void> delete(String id) async => deleted.add(id);
}

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
    late _VerRepo repo;
    late _Picker picker;
    late FakeNavigator nav;
    late UploadController c;
    var verified = 0;

    setUp(() {
      repo = _VerRepo();
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
      expect(nav.replaced, ['/result']);
      expect(nav.replacedArgs.single, isA<Verification>());
      expect(verified, 1);
      expect(c.phase.value, UploadPhase.idle);
    });

    test('402 routes to the paywall', () async {
      repo.verifyError = const AppException(
        kind: AppErrorKind.subscriptionRequired,
        statusCode: 402,
        code: 'SUBSCRIPTION_REQUIRED',
      );
      await c.pickFile();
      await c.submit();
      expect(nav.pushed, ['/paywall']);
      expect(c.errorMessage.value, S.errSubscription);
    });

    test('missing reward asks for an override and retries with it', () async {
      repo.verifyError = const AppException(
        kind: AppErrorKind.unprocessable,
        statusCode: 422,
        code: 'REPORTED_REWARD_NOT_FOUND',
      );
      await c.pickFile();
      await c.submit();
      expect(c.needsOverride.value, isTrue);
      expect(c.errorMessage.value, S.errRewardNotFound);

      c.overrideText.text = 'abc';
      await c.submit();
      expect(c.overrideError.value, S.overrideInvalid);

      repo.verifyError = null;
      c.overrideText.text = '125,40';
      await c.submit();
      expect(repo.lastOverride, '125,40');
      expect(nav.replaced, ['/result']);
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

    setUp(() async {
      merchants = FakeMerchantRepository();
      catalog = CatalogController(
        categories: FakeCategoryRepository(const [
          Category(id: 'cat1', name: 'Super'),
        ]),
        merchants: merchants,
      );
      await catalog.load();
      c = ResultController(
        repository: _VerRepo(),
        catalog: catalog,
        initial: VerificationMapper.detail(verificationJson()),
      )..onInit();
    });

    test('filters transactions', () {
      expect(c.visibleTransactions, hasLength(2));
      c.setFilter(TransactionFilter.counted);
      expect(c.visibleTransactions.single.index, 0);
      c.setFilter(TransactionFilter.uncounted);
      expect(c.visibleTransactions.single.index, 1);
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
        repository: _VerRepo(),
        catalog: catalog,
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
      final repo = _VerRepo()
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
      expect(await c.delete(c.items.first), isNull);
      expect(repo.deleted, ['v0']);
      expect(c.items, hasLength(2));
    });

    test('latest controller loads three', () async {
      final repo = _VerRepo()
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
