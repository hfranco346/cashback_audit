import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/l10n/active_locale.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/core/utils/cached.dart';
import 'package:cashback_audit/features/cards/domain/card_entities.dart';
import 'package:cashback_audit/features/cards/domain/card_repository.dart';
import 'package:cashback_audit/features/cards/presentation/cards_controller.dart';
import 'package:cashback_audit/features/categories/presentation/catalog_controller.dart';
import 'package:cashback_audit/features/credits/presentation/credits_controller.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/presentation/confirm_rates_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/confirm_rates_page.dart';
import 'package:cashback_audit/features/verifications/presentation/history_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/history_page.dart';
import 'package:cashback_audit/features/verifications/presentation/result_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/result_page.dart';
import 'package:cashback_audit/features/verifications/presentation/verification_progress_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/verification_progress_page.dart';
import 'package:cashback_audit/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/fake_credits_repository.dart';
import '../../support/fake_verification_repository.dart';
import '../../support/fakes.dart';
import '../../support/fixtures.dart';
import '../categories/fake_catalog.dart';

class _CardRepo implements CardRepository {
  @override
  Future<Cached<List<CreditCard>>> getCards() async => const Cached([]);
  @override
  Future<CreditCard> createCard(CardDraft draft) => throw UnimplementedError();
  @override
  Future<CreditCard> updateCard(String id, CardDraft draft) =>
      throw UnimplementedError();
  @override
  Future<void> deleteCard(String id) async {}
}

AppException _notFound() => const AppException(
  kind: AppErrorKind.notFound,
  statusCode: 404,
  code: 'VERIFICATION_NOT_FOUND',
);

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  String lang = 'es',
}) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  ActiveLocale.set(Locale(lang));
  S.current = ActiveLocale.strings;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      locale: Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: home),
    ),
  );
  await tester.pump(const Duration(seconds: 2));
}

CreditsController _credits({bool unlimited = false}) {
  final c = CreditsController(
    repository: FakeCreditsRepository([balance(free: 2, unlimited: unlimited)]),
  );
  c.balance.value = balance(free: 2, unlimited: unlimited);
  return c;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    await initializeDateFormatting('en_US');
  });
  tearDown(Get.reset);

  late FakeVerificationRepository repo;
  late FakeNavigator nav;

  setUp(() {
    repo = FakeVerificationRepository();
    nav = FakeNavigator();
  });

  group('Result screen', () {
    Future<ResultController> pumpResult(
      WidgetTester tester, {
      CreditsController? credits,
      String lang = 'es',
    }) async {
      final c = ResultController(
        repository: repo,
        catalog: CatalogController(
          categories: FakeCategoryRepository(const []),
          merchants: FakeMerchantRepository(),
        ),
        navigator: nav,
        credits: credits ?? _credits(),
        initial: VerificationMapper.detail(verificationJson()),
      )..onInit();
      Get.put<ResultController>(c);
      await _pump(tester, const ResultPage(), lang: lang);
      return c;
    }

    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('verification-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('verification-menu-delete')));
      await tester.pumpAndSettle();
    }

    testWidgets('menu sits next to the % button and explains the credit', (
      tester,
    ) async {
      await pumpResult(tester);
      expect(find.byKey(const Key('result-recalculate')), findsOneWidget);
      await openDialog(tester);
      expect(find.text('Eliminar verificación'), findsWidgets);
      expect(find.textContaining('de forma permanente'), findsOneWidget);
      expect(find.textContaining('no se devuelve'), findsOneWidget);
    });

    testWidgets('cancel keeps the check', (tester) async {
      await pumpResult(tester);
      await openDialog(tester);
      await tester.tap(find.byKey(const Key('delete-verification-cancel')));
      await tester.pumpAndSettle();
      expect(repo.deleted, isEmpty);
      expect(nav.pops, 0);
    });

    testWidgets('confirm deletes, goes back and announces it', (tester) async {
      await pumpResult(tester);
      await openDialog(tester);
      await tester.tap(find.byKey(const Key('delete-verification-confirm')));
      await tester.pumpAndSettle();
      expect(repo.deleted, ['v1']);
      expect(nav.pops, 1);
      expect(nav.notices, ['Verificación eliminada']);
    });

    testWidgets('unlimited accounts do not get the credit sentence (EN)', (
      tester,
    ) async {
      await pumpResult(tester, credits: _credits(unlimited: true), lang: 'en');
      await openDialog(tester);
      expect(find.text('Delete check'), findsWidgets);
      expect(find.textContaining('permanently'), findsOneWidget);
      expect(find.textContaining('not returned'), findsNothing);
    });

    testWidgets('404 counts as already deleted', (tester) async {
      repo.deleteError = _notFound();
      await pumpResult(tester);
      await openDialog(tester);
      await tester.tap(find.byKey(const Key('delete-verification-confirm')));
      await tester.pumpAndSettle();
      expect(nav.pops, 1);
      expect(nav.notices, ['Verificación eliminada']);
    });

    testWidgets('other errors stay on screen with a message', (tester) async {
      repo.deleteError = const AppException(kind: AppErrorKind.network);
      await pumpResult(tester);
      await openDialog(tester);
      await tester.tap(find.byKey(const Key('delete-verification-confirm')));
      await tester.pumpAndSettle();
      expect(nav.pops, 0);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('History', () {
    Future<HistoryController> pumpHistory(
      WidgetTester tester, {
      CreditsController? credits,
    }) async {
      repo.items = [
        VerificationMapper.summary(summaryJson('v1')),
        VerificationMapper.summary(summaryJson('v2')),
      ];
      Get.put(CardsController(_CardRepo()));
      final c = HistoryController(
        repository: repo,
        navigator: nav,
        credits: credits ?? _credits(),
      )..onInit();
      await c.load();
      Get.put<HistoryController>(c);
      await _pump(tester, const HistoryPage());
      return c;
    }

    testWidgets('swipe asks first; confirming removes the row', (tester) async {
      final c = await pumpHistory(tester);
      await tester.drag(
        find.byKey(const Key('history-row-v1')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('delete-verification-dialog')), findsOne);
      await tester.tap(find.byKey(const Key('delete-verification-confirm')));
      await tester.pumpAndSettle();
      expect(repo.deleted, ['v1']);
      expect(c.items.map((i) => i.id), ['v2']);
      expect(find.text('Verificación eliminada'), findsOneWidget);
    });

    testWidgets('swipe + cancel keeps the row', (tester) async {
      final c = await pumpHistory(tester);
      await tester.drag(
        find.byKey(const Key('history-row-v1')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-verification-cancel')));
      await tester.pumpAndSettle();
      expect(repo.deleted, isEmpty);
      expect(c.items, hasLength(2));
      expect(find.byKey(const Key('history-row-v1')), findsOneWidget);
    });

    testWidgets('long press opens the same confirmation (unlimited: short)', (
      tester,
    ) async {
      final c = await pumpHistory(tester, credits: _credits(unlimited: true));
      await tester.longPress(find.byKey(const Key('history-row-v2')));
      await tester.pumpAndSettle();
      expect(find.textContaining('de forma permanente'), findsOneWidget);
      expect(find.textContaining('no se devuelve'), findsNothing);
      await tester.tap(find.byKey(const Key('delete-verification-confirm')));
      await tester.pumpAndSettle();
      expect(repo.deleted, ['v2']);
      expect(c.items.map((i) => i.id), ['v1']);
    });

    test('a 404 removes the row as well; other errors keep it', () async {
      repo.items = [VerificationMapper.summary(summaryJson('v1'))];
      final c = HistoryController(repository: repo, navigator: nav)..onInit();
      await c.load();
      repo.deleteError = const AppException(kind: AppErrorKind.network);
      expect(await c.delete(c.items.first), isNotNull);
      expect(c.items, hasLength(1));
      repo.deleteError = _notFound();
      expect(await c.delete(c.items.first), isNull);
      expect(c.items, isEmpty);
    });
  });

  group('non-completed checks', () {
    testWidgets('a failed analysis can be deleted (no credit sentence)', (
      tester,
    ) async {
      repo.getResults.add({
        ...verificationJson(),
        'status': 'FAILED',
        'failureCode': 'NOT_A_STATEMENT',
      });
      final c = VerificationProgressController(
        verificationId: 'v1',
        repository: repo,
        navigator: nav,
        credits: _credits(),
      );
      Get.put<VerificationProgressController>(c);
      await _pump(tester, const VerificationProgressPage());
      await tester.tap(find.byKey(const Key('verification-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('verification-menu-delete')));
      await tester.pumpAndSettle();
      expect(find.textContaining('no se devuelve'), findsNothing);
      await tester.tap(find.byKey(const Key('delete-verification-confirm')));
      await tester.pumpAndSettle();
      expect(repo.deleted, ['v1']);
      expect(nav.pops, 1);
      expect(nav.notices, ['Verificación eliminada']);
    });

    test('a running analysis is discarded and polling stops', () async {
      repo.getResults.add(processingVerificationJson());
      final c = VerificationProgressController(
        verificationId: 'v1',
        repository: repo,
        navigator: nav,
        credits: _credits(),
      );
      expect(c.deleteLosesCreditNote, isTrue);
      expect(await c.deleteVerification(), isNull);
      expect(repo.deleted, ['v1']);
      expect(nav.pops, 1);
      c.onClose();
    });

    testWidgets('the confirm screen (awaiting rates) can be abandoned', (
      tester,
    ) async {
      final v = VerificationMapper.detail(awaitingVerificationJson());
      Get.put(CardsController(_CardRepo()));
      final c = ConfirmRatesController(
        repository: repo,
        cards: Get.find<CardsController>(),
        navigator: nav,
        credits: _credits(),
        args: ConfirmRatesArgs.verification(v),
      );
      Get.put<ConfirmRatesController>(c);
      await _pump(tester, const ConfirmRatesPage());
      expect(c.canDelete, isTrue);
      await tester.tap(find.byKey(const Key('verification-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('verification-menu-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-verification-confirm')));
      await tester.pumpAndSettle();
      expect(repo.deleted, [v.id]);
      expect(nav.pops, 1);
    });
  });
}
