import 'package:cashback_audit/core/db/app_database.dart';
import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/network/dio_factory.dart';
import 'package:cashback_audit/core/network/session_events.dart';
import 'package:cashback_audit/core/storage/token_storage.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/features/categories/data/catalog_repositories_impl.dart';
import 'package:cashback_audit/features/categories/domain/catalog_entities.dart';
import 'package:cashback_audit/features/categories/presentation/catalog_controller.dart';
import 'package:cashback_audit/features/categories/presentation/widgets/catalog_view.dart';
import 'package:cashback_audit/features/categories/presentation/widgets/merchant_form_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    Widget wrap(Widget c) => MaterialApp(theme: AppTheme.light, home: c);

    testWidgets('CatalogView lists merchants and exposes actions', (
      tester,
    ) async {
      Category? added;
      Merchant? edited;
      const cat = Category(id: 'c1', name: 'Super');
      const m = Merchant(
        id: 'm1',
        name: 'Walmart',
        categoryId: 'c1',
        keywords: ['WAL MART'],
      );
      await tester.pumpWidget(
        wrap(
          CatalogView(
            categories: const [cat],
            merchantsOf: (_) => const [m],
            loading: false,
            offline: true,
            onRefresh: () async {},
            onAddCategory: () {},
            onEditCategory: (_) {},
            onDeleteCategory: (_) {},
            onAddMerchant: (c) => added = c,
            onEditMerchant: (x) => edited = x,
            onDeleteMerchant: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Super'), findsOneWidget);
      expect(find.text(S.offlineBanner), findsOneWidget);
      await tester.tap(find.text('Super'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('merchant-m1')));
      expect(edited, m);
      await tester.tap(find.byKey(const Key('add-merchant-c1')));
      expect(added, cat);
    });

    testWidgets('CatalogView empty state', (tester) async {
      await tester.pumpWidget(
        wrap(
          CatalogView(
            categories: const [],
            merchantsOf: (_) => const [],
            loading: false,
            offline: false,
            onRefresh: () async {},
            onAddCategory: () {},
            onEditCategory: (_) {},
            onDeleteCategory: (_) {},
            onAddMerchant: (_) {},
            onEditMerchant: (_) {},
            onDeleteMerchant: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(S.catalogEmptyTitle), findsOneWidget);
    });

    testWidgets('MerchantFormSheet validates and submits parsed keywords', (
      tester,
    ) async {
      String? submitted;
      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: MerchantFormSheet(
              categories: const [
                Category(id: 'c1', name: 'Super'),
                Category(id: 'c2', name: 'Gasolina'),
              ],
              initialName: 'Walmart',
              initialKeywords: const ['WAL MART'],
              onSubmit: (n, k, c) async {
                submitted = '$n|${k.join(',')}|$c';
                return null;
              },
            ),
          ),
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
  });
}
