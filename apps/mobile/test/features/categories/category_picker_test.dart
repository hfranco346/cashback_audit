import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/features/categories/domain/catalog_entities.dart';
import 'package:cashback_audit/features/categories/presentation/widgets/category_picker_sheet.dart';
import 'package:cashback_audit/features/categories/presentation/widgets/category_reassign_dialog.dart';
import 'package:cashback_audit/features/categories/presentation/widgets/merchant_form_sheet.dart';
import 'package:cashback_audit/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _long =
    'Restaurantes, cafeterías y servicios de comida rápida a domicilio en toda la ciudad';

List<Category> _many(int n) => [
  for (var i = 0; i < n; i++) Category(id: 'c$i', name: 'Rubro $i'),
];

void main() {
  /// Mounts a button that opens the picker and records its result.
  Future<void> pumpHost(
    WidgetTester tester, {
    required List<Category> categories,
    String? selectedId,
    Set<String> excluded = const {},
    CreateCategory? onCreate,
    void Function(String?)? onResult,
    bool dark = false,
    String lang = 'es',
  }) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        locale: Locale(lang),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('open'),
                onPressed: () async {
                  final id = await showCategoryPicker(
                    context: context,
                    categories: categories,
                    selectedId: selectedId,
                    excludedIds: excluded,
                    onCreate: onCreate,
                  );
                  onResult?.call(id);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  group('CategoryPickerSheet', () {
    testWidgets('shows full long names, the check and returns the tap', (
      tester,
    ) async {
      String? result;
      await pumpHost(
        tester,
        categories: const [
          Category(id: 'a', name: _long),
          Category(id: 'b', name: 'Super'),
        ],
        selectedId: 'a',
        onResult: (id) => result = id,
      );
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text(_long));
      expect(text.overflow, isNull);
      expect(text.maxLines, isNull);
      // Wraps onto several lines: taller than a single line of text.
      expect(tester.getSize(find.text(_long)).height, greaterThan(30));
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byKey(const Key('category-search')), findsNothing);
      await tester.tap(find.text('Super'));
      await tester.pumpAndSettle();
      expect(result, 'b');
    });

    testWidgets('search appears only with more than 8 categories', (
      tester,
    ) async {
      await pumpHost(tester, categories: _many(8));
      expect(find.byKey(const Key('category-search')), findsNothing);
    });

    testWidgets('filters by name and explains an empty result', (tester) async {
      await pumpHost(
        tester,
        categories: [
          ..._many(9),
          const Category(id: 'g', name: 'Gasolina'),
        ],
      );
      expect(find.byKey(const Key('category-search')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('category-search')), 'gaso');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('category-option-g')), findsOneWidget);
      expect(find.byKey(const Key('category-option-c1')), findsNothing);
      await tester.enterText(find.byKey(const Key('category-search')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('category-picker-empty')), findsOneWidget);
    });

    testWidgets('hides excluded categories', (tester) async {
      await pumpHost(
        tester,
        categories: const [
          Category(id: 'a', name: 'Uno'),
          Category(id: 'b', name: 'Dos'),
        ],
        excluded: const {'a'},
      );
      expect(find.byKey(const Key('category-option-a')), findsNothing);
      expect(find.byKey(const Key('category-option-b')), findsOneWidget);
    });

    testWidgets('creates a category inline and returns it selected', (
      tester,
    ) async {
      String? result;
      final created = <String>[];
      await pumpHost(
        tester,
        categories: _many(2),
        onCreate: (name) async {
          created.add(name);
          return Category(id: 'new', name: name);
        },
        onResult: (id) => result = id,
      );
      await tester.tap(find.byKey(const Key('category-create')));
      await tester.pumpAndSettle();
      // Empty name is rejected before calling the API.
      await tester.tap(find.byKey(const Key('category-create-confirm')));
      await tester.pumpAndSettle();
      expect(created, isEmpty);
      await tester.enterText(
        find.byKey(const Key('category-new-name')),
        '  Mascotas ',
      );
      await tester.tap(find.byKey(const Key('category-create-confirm')));
      await tester.pumpAndSettle();
      expect(created, ['Mascotas']);
      expect(result, 'new');
    });

    testWidgets('a failed creation stays open with the mapped error', (
      tester,
    ) async {
      String? result = 'unset';
      await pumpHost(
        tester,
        categories: _many(1),
        onCreate: (_) async => throw const AppException(
          kind: AppErrorKind.conflict,
          code: 'CATEGORY_NAME_TAKEN',
        ),
        onResult: (id) => result = id,
      );
      await tester.tap(find.byKey(const Key('category-create')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('category-new-name')), 'X');
      await tester.tap(find.byKey(const Key('category-create-confirm')));
      await tester.pumpAndSettle();
      expect(result, 'unset');
      expect(find.byKey(const Key('category-new-name')), findsOneWidget);
      expect(find.text(S.errCategoryNameTaken), findsOneWidget);
    });

    testWidgets('no create action without onCreate', (tester) async {
      await pumpHost(tester, categories: _many(2));
      expect(find.byKey(const Key('category-create')), findsNothing);
    });

    for (final dark in [false, true]) {
      for (final lang in ['es', 'en']) {
        testWidgets('renders (dark=$dark, $lang)', (tester) async {
          await pumpHost(
            tester,
            categories: [
              ..._many(10),
              const Category(id: 'l', name: _long),
            ],
            selectedId: 'c3',
            onCreate: (n) async => Category(id: 'n', name: n),
            dark: dark,
            lang: lang,
          );
          expect(tester.takeException(), isNull);
          expect(
            find.text(lang == 'es' ? 'Crear rubro' : 'Create category'),
            findsOneWidget,
          );
        });
      }
    }
  });

  group('callers', () {
    Future<void> pumpUi(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('es'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );
    }

    testWidgets('merchant sheet picks a category created inline', (
      tester,
    ) async {
      String? submitted;
      await pumpUi(
        tester,
        MerchantFormSheet(
          categories: const [Category(id: 'c1', name: 'Super')],
          initialName: 'Tienda',
          onCreateCategory: (n) async => Category(id: 'made', name: n),
          onSubmit: (n, k, c) async {
            submitted = '$n|$c';
            return null;
          },
        ),
      );
      await tester.tap(find.byKey(const Key('merchant-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('category-create')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('category-new-name')),
        'Mascotas',
      );
      await tester.tap(find.byKey(const Key('category-create-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Mascotas'), findsOneWidget);
      await tester.tap(find.byKey(const Key('merchant-submit')));
      await tester.pump();
      expect(submitted, 'Tienda|made');
    });

    testWidgets('reassign dialog shows the target and lets you change it', (
      tester,
    ) async {
      await pumpUi(
        tester,
        const CategoryReassignDialog(
          others: [
            Category(id: 'a', name: 'Uno'),
            Category(id: 'b', name: _long),
          ],
          message: 'm',
        ),
      );
      expect(find.text('Uno'), findsOneWidget);
      await tester.tap(find.byKey(const Key('reassign-target')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_long));
      await tester.pumpAndSettle();
      expect(find.text(_long), findsOneWidget);
      expect(find.text('Uno'), findsNothing);
    });
  });
}
