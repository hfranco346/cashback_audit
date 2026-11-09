import 'package:cashback_audit/core/db/app_database.dart';
import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/network/dio_factory.dart';
import 'package:cashback_audit/core/network/session_events.dart';
import 'package:cashback_audit/core/storage/token_storage.dart';
import 'package:cashback_audit/core/utils/cached.dart';
import 'package:cashback_audit/features/cards/data/card_mapper.dart';
import 'package:cashback_audit/features/cards/domain/card_entities.dart';
import 'package:cashback_audit/features/cards/domain/card_repository.dart';
import 'package:cashback_audit/features/cards/presentation/cards_controller.dart';
import 'package:cashback_audit/features/categories/data/catalog_repositories_impl.dart';
import 'package:cashback_audit/features/categories/domain/catalog_entities.dart';
import 'package:cashback_audit/features/categories/presentation/catalog_controller.dart';
import 'package:cashback_audit/features/categories/presentation/catalog_page.dart';
import 'package:cashback_audit/features/categories/presentation/widgets/catalog_view.dart';
import 'package:cashback_audit/features/categories/presentation/widgets/category_form_sheet.dart';
import 'package:cashback_audit/features/categories/presentation/widgets/merchant_form_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../core/ui/ui_harness.dart';
import '../../support/fake_adapter.dart';
import '../../support/fixtures.dart';
import 'fake_catalog.dart';

void main() {
  group('repositories', () {
    late AppDatabase db;
    late FakeAdapter adapter;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    dioFor(FakeAdapter a) => buildDio(
      baseUrl: 'http://test/api/v1',
      tokens: InMemoryTokenStorage(),
      events: SessionEvents(),
      adapter: a,
    );

    test('lists categories and merchants and caches them', () async {
      adapter = FakeAdapter((o) {
        if (o.path == '/categories') {
          return FakeResponse(200, [categoryJson('c1', 'Super', merchants: 1)]);
        }
        return FakeResponse(200, [
          merchantJson('m1', 'Walmart', 'c1', keywords: ['WAL MART']),
        ]);
      });
      final dio = dioFor(adapter);
      final cats = await CategoryRepositoryImpl(dio, db).getCategories();
      final merch = await MerchantRepositoryImpl(dio, db).getMerchants();
      expect(cats.data.single.merchantCount, 1);
      expect(merch.data.single.keywords, ['WAL MART']);
      expect(await db.readCategories(), hasLength(1));
      expect(await db.readMerchants(), hasLength(1));
    });

    test('delete passes reassignTo as a query param', () async {
      adapter = FakeAdapter((o) => const FakeResponse(204));
      await CategoryRepositoryImpl(
        dioFor(adapter),
        db,
      ).deleteCategory('c1', reassignTo: 'c2');
      expect(adapter.requests.single.queryParameters, {'reassignTo': 'c2'});
    });

    test('merchant update sends only provided fields', () async {
      adapter = FakeAdapter(
        (o) => FakeResponse(200, merchantJson('m1', 'W', 'c2')),
      );
      await MerchantRepositoryImpl(
        dioFor(adapter),
        db,
      ).updateMerchant('m1', categoryId: 'c2');
      expect(adapter.requests.single.data, {'categoryId': 'c2'});
      expect(adapter.requests.single.method, 'PATCH');
    });

    test('merchant create sends keywords and maps 409', () async {
      adapter = FakeAdapter(
        (o) => const FakeResponse(409, {
          'statusCode': 409,
          'code': 'MERCHANT_NAME_TAKEN',
          'message': 'x',
        }),
      );
      await expectLater(
        MerchantRepositoryImpl(
          dioFor(adapter),
          db,
        ).createMerchant(name: 'W', categoryId: 'c1', keywords: ['A']),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            'MERCHANT_NAME_TAKEN',
          ),
        ),
      );
      expect(adapter.requests.single.data, {
        'name': 'W',
        'categoryId': 'c1',
        'keywords': ['A'],
      });
    });
  });

  group('CatalogController', () {
    late FakeCategoryRepository cats;
    late FakeMerchantRepository merchants;
    late CatalogController controller;

    setUp(() {
      cats = FakeCategoryRepository(const [
        Category(id: 'c1', name: 'Super'),
        Category(id: 'c2', name: 'Gasolina'),
      ]);
      merchants = FakeMerchantRepository([
        const Merchant(id: 'm1', name: 'Walmart', categoryId: 'c1'),
      ]);
      controller = CatalogController(categories: cats, merchants: merchants);
    });

    test('loads and groups merchants by category', () async {
      await controller.load();
      expect(controller.merchantsOf('c1').single.name, 'Walmart');
      expect(controller.merchantsOf('c2'), isEmpty);
      expect(controller.categoryById('c2')?.name, 'Gasolina');
    });

    test('reassigns a merchant to another category', () async {
      await controller.load();
      expect(await controller.updateMerchant('m1', categoryId: 'c2'), isNull);
      expect(controller.merchantsOf('c2').single.id, 'm1');
    });

    test(
      'delete reports CATEGORY_IN_USE details, then succeeds with reassign',
      () async {
        cats.deleteError = const AppException(
          kind: AppErrorKind.conflict,
          statusCode: 409,
          code: 'CATEGORY_IN_USE',
          details: {'merchants': 2, 'cardRules': 1},
        );
        await controller.load();
        final first = await controller.deleteCategory('c1');
        expect(first, isA<CategoryInUse>());
        expect((first as CategoryInUse).merchants, 2);
        expect(first.cardRules, 1);
        final second = await controller.deleteCategory('c1', reassignTo: 'c2');
        expect(second, isA<CategoryDeleted>());
        expect(cats.lastReassign, 'c2');
        expect(controller.categories.map((c) => c.id), ['c2']);
      },
    );

    test('mutations return mapped error messages', () async {
      merchants.createError = const AppException(
        kind: AppErrorKind.conflict,
        code: 'MERCHANT_NAME_TAKEN',
      );
      final msg = await controller.createMerchant(name: 'W', categoryId: 'c1');
      expect(msg, S.errMerchantNameTaken);
    });

    test('parseKeywords splits and trims', () {
      expect(parseKeywords(' WAL MART, ,WALMART SUC\nSORIANA'), [
        'WAL MART',
        'WALMART SUC',
        'SORIANA',
      ]);
    });
  });

  group('widgets', () {
    const cat = Category(id: 'c1', name: 'Super');
    const cat2 = Category(id: 'c2', name: 'Farmacia');
    const m = Merchant(
      id: 'm1',
      name: 'Walmart',
      categoryId: 'c1',
      keywords: ['WAL MART'],
    );

    CatalogView view({
      List<Category> categories = const [cat, cat2],
      bool offline = false,
      bool loading = false,
      ValueChanged<Category>? onAddMerchant,
      ValueChanged<Merchant>? onEditMerchant,
      ValueChanged<String>? onQuickAdd,
      VoidCallback? onAddCategory,
    }) => CatalogView(
      categories: categories,
      merchantsOf: (id) => id == 'c1' ? const [m] : const [],
      ruleTagsOf: (id) => id == 'c1' ? const ['BAC Cash 7%'] : const [],
      loading: loading,
      offline: offline,
      onRefresh: () async {},
      onAddCategory: onAddCategory ?? () {},
      onQuickAddCategory: onQuickAdd,
      onEditCategory: (_) {},
      onDeleteCategory: (_) {},
      onAddMerchant: onAddMerchant ?? (_) {},
      onEditMerchant: onEditMerchant ?? (_) {},
    );

    testWidgets('populated: tags, aliases and expandable categories', (
      tester,
    ) async {
      Category? added;
      Merchant? edited;
      await pumpUi(
        tester,
        view(
          offline: true,
          onAddMerchant: (c) => added = c,
          onEditMerchant: (x) => edited = x,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Super'), findsOneWidget);
      expect(find.text('BAC Cash 7%'), findsOneWidget);
      expect(find.text(S.offlineBanner), findsOneWidget);
      expect(find.text('1 comercio'), findsOneWidget);
      // The first category starts open: merchant and bank text visible.
      expect(find.text('Walmart'), findsOneWidget);
      expect(find.text('WAL MART'), findsOneWidget);
      // The one without merchants says the AI classifies it.
      expect(find.text(S.current.catalogByAi), findsOneWidget);
      expect(find.byKey(const Key('add-category')), findsOneWidget);
      await tester.tap(find.byKey(const Key('merchant-m1')));
      expect(edited, m);
      await tester.tap(find.byKey(const Key('add-merchant-c1')));
      expect(added, cat);
      // Collapse and expand the first card.
      await tester.tap(find.byKey(const Key('category-c1')));
      await tester.pumpAndSettle();
      expect(find.text('Walmart'), findsNothing);
      await tester.tap(find.byKey(const Key('category-c2')));
      await tester.pumpAndSettle();
      expect(find.text(S.noMerchants), findsOneWidget);
    });

    testWidgets('guided empty state offers one-tap categories', (tester) async {
      String? quick;
      var created = 0;
      await pumpUi(
        tester,
        view(
          categories: const [],
          onQuickAdd: (n) => quick = n,
          onAddCategory: () => created++,
        ),
        size: const Size(390, 1000),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('catalog-guide')), findsOneWidget);
      expect(find.text(S.current.catalogIntroTitle), findsOneWidget);
      expect(find.byKey(const Key('add-category')), findsNothing);
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(Key('suggest-$i')), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('suggest-0')));
      expect(quick, 'Supermercados');
      await tester.tap(find.byKey(const Key('add-category-empty')));
      expect(created, 1);
    });

    testWidgets('shows a spinner while the first load runs', (tester) async {
      await pumpUi(tester, view(categories: const [], loading: true));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('catalog-guide')), findsNothing);
    });

    for (final dark in [false, true]) {
      for (final lang in ['es', 'en']) {
        testWidgets('smoke (dark=$dark, $lang)', (tester) async {
          await pumpUi(
            tester,
            view(categories: const []),
            dark: dark,
            lang: lang,
            size: const Size(390, 1000),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.text(lang == 'es' ? 'Supermercados' : 'Supermarkets'),
            findsOneWidget,
          );
          await pumpUi(tester, view(), dark: dark, lang: lang);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.text(lang == 'es' ? '+ Nuevo rubro' : '+ New category'),
            findsOneWidget,
          );
        });
      }
    }

    testWidgets('MerchantFormSheet validates and submits parsed keywords', (
      tester,
    ) async {
      String? submitted;
      await pumpUi(
        tester,
        MerchantFormSheet(
          categories: const [
            cat,
            Category(id: 'c2', name: 'Gasolina'),
          ],
          initialName: 'Walmart',
          initialKeywords: const ['WAL MART'],
          onSubmit: (n, k, c) async {
            submitted = '$n|${k.join(',')}|$c';
            return null;
          },
        ),
      );
      await tester.tap(find.byKey(const Key('merchant-submit')));
      await tester.pump();
      expect(submitted, isNull); // category missing
      expect(find.text(S.fieldRequired), findsOneWidget);
      await tester.tap(find.byKey(const Key('merchant-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gasolina').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('merchant-keywords')),
        'WAL MART, WALMART SUC',
      );
      await tester.tap(find.byKey(const Key('merchant-submit')));
      await tester.pump();
      expect(submitted, 'Walmart|WAL MART,WALMART SUC|c2');
    });

    testWidgets('MerchantFormSheet deletes after confirming', (tester) async {
      var deleted = 0;
      await pumpUi(
        tester,
        MerchantFormSheet(
          categories: const [cat],
          initialName: 'Walmart',
          initialCategoryId: 'c1',
          onSubmit: (_, _, _) async => null,
          onDelete: () async {
            deleted++;
            return null;
          },
        ),
      );
      await tester.tap(find.byKey(const Key('merchant-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('merchant-delete-cancel')));
      await tester.pumpAndSettle();
      expect(deleted, 0);
      await tester.tap(find.byKey(const Key('merchant-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('merchant-delete-confirm')));
      await tester.pumpAndSettle();
      expect(deleted, 1);
    });

    testWidgets('MerchantFormSheet without onDelete hides the action', (
      tester,
    ) async {
      await pumpUi(
        tester,
        MerchantFormSheet(
          categories: const [cat],
          onSubmit: (_, _, _) async => null,
        ),
      );
      expect(find.byKey(const Key('merchant-delete')), findsNothing);
    });

    testWidgets('CategoryFormSheet validates the name and shows API errors', (
      tester,
    ) async {
      var calls = 0;
      await pumpUi(
        tester,
        CategoryFormSheet(
          onSubmit: (n, d) async {
            calls++;
            return S.errCategoryNameTaken;
          },
        ),
      );
      await tester.tap(find.byKey(const Key('category-submit')));
      await tester.pump();
      expect(calls, 0);
      expect(find.text(S.fieldRequired), findsOneWidget);
      await tester.enterText(find.byKey(const Key('category-name')), 'Super');
      await tester.tap(find.byKey(const Key('category-submit')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text(S.errCategoryNameTaken), findsOneWidget);
    });
  });

  group('CatalogPage', () {
    late FakeCategoryRepository cats;
    late CatalogController controller;

    tearDown(Get.reset);

    Future<void> pumpPage(WidgetTester tester) async {
      cats = FakeCategoryRepository(const [
        Category(id: 'c1', name: 'Super'),
        Category(id: 'c2', name: 'Farmacia'),
      ]);
      controller = CatalogController(
        categories: cats,
        merchants: FakeMerchantRepository([
          const Merchant(id: 'm1', name: 'Walmart', categoryId: 'c1'),
        ]),
      );
      await controller.load();
      final cards = CardsController(_CardsRepo());
      await cards.load();
      Get.put(controller);
      await pumpUi(tester, CatalogPage(cards: cards));
      await tester.pumpAndSettle();
    }

    testWidgets('labels each category with the cards that pay it', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(find.text('Daily 5%'), findsOneWidget);
    });

    testWidgets('CATEGORY_IN_USE asks where to move before deleting', (
      tester,
    ) async {
      await pumpPage(tester);
      cats.deleteError = const AppException(
        kind: AppErrorKind.conflict,
        statusCode: 409,
        code: 'CATEGORY_IN_USE',
        details: {'merchants': 1, 'cardRules': 1},
      );
      await tester.tap(find.byKey(const Key('category-menu-c1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.delete).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-delete')));
      await tester.pumpAndSettle();
      // The reassign dialog explains what is attached and offers targets.
      expect(find.byKey(const Key('reassign-target')), findsOneWidget);
      expect(
        find.textContaining('Este rubro tiene 1 comercio y 1 regla'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('reassign-confirm')));
      await tester.pumpAndSettle();
      expect(cats.lastReassign, 'c2');
      expect(controller.categories.map((c) => c.id), ['c2']);
    });

    testWidgets('cancelling the reassign dialog keeps the category', (
      tester,
    ) async {
      await pumpPage(tester);
      cats.deleteError = const AppException(
        kind: AppErrorKind.conflict,
        statusCode: 409,
        code: 'CATEGORY_IN_USE',
        details: {'merchants': 1, 'cardRules': 0},
      );
      await tester.tap(find.byKey(const Key('category-menu-c1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.delete).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reassign-cancel')));
      await tester.pumpAndSettle();
      expect(cats.deleted, isEmpty);
      expect(controller.categories, hasLength(2));
    });

    testWidgets('quick-adding from the empty state creates the category', (
      tester,
    ) async {
      cats = FakeCategoryRepository(const []);
      controller = CatalogController(
        categories: cats,
        merchants: FakeMerchantRepository(),
      );
      await controller.load();
      Get.put(controller);
      await pumpUi(
        tester,
        CatalogPage(cards: CardsController(_CardsRepo())),
        size: const Size(390, 1000),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('suggest-1')));
      await tester.pumpAndSettle();
      expect(controller.categories.single.name, 'Farmacia');
      // Now populated: the guide is gone and the header action appears.
      expect(find.byKey(const Key('catalog-guide')), findsNothing);
      expect(find.byKey(const Key('add-category')), findsOneWidget);
    });
  });
}

class _CardsRepo implements CardRepository {
  @override
  Future<Cached<List<CreditCard>>> getCards() async => Cached([
    CardMapper.fromJson(
      cardJson(
        rules: [
          {'categoryId': 'c1', 'ratePercent': '5', 'monthlyCap': null},
        ],
      ),
    ),
  ]);
  @override
  Future<CreditCard> createCard(CardDraft draft) => throw UnimplementedError();
  @override
  Future<CreditCard> updateCard(String id, CardDraft draft) =>
      throw UnimplementedError();
  @override
  Future<void> deleteCard(String id) => throw UnimplementedError();
}
