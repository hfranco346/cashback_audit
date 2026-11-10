import 'package:cashback_audit/core/network/session_events.dart';
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';
import 'package:cashback_audit/core/l10n/active_locale.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/routing/app_navigator.dart';
import 'package:cashback_audit/core/routing/app_pages.dart';
import 'package:cashback_audit/core/routing/app_routes.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/core/utils/cached.dart';
import 'package:cashback_audit/features/auth/domain/auth_repository.dart';
import 'package:cashback_audit/features/auth/presentation/session_controller.dart';
import 'package:cashback_audit/features/cards/data/card_mapper.dart';
import 'package:cashback_audit/features/cards/domain/card_entities.dart';
import 'package:cashback_audit/features/cards/domain/card_repository.dart';
import 'package:cashback_audit/features/cards/presentation/cards_controller.dart';
import 'package:cashback_audit/features/categories/presentation/catalog_controller.dart';
import 'package:cashback_audit/features/credits/presentation/credits_controller.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/domain/pdf_picker.dart';
import 'package:cashback_audit/features/verifications/domain/verification_repository.dart';
import 'package:cashback_audit/features/verifications/presentation/attention_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/confirm_rates_page.dart';
import 'package:cashback_audit/features/verifications/presentation/result_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/result_page.dart';
import 'package:cashback_audit/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../features/categories/fake_catalog.dart';
import '../support/fake_credits_repository.dart';
import '../support/fake_verification_repository.dart';
import '../support/fixtures.dart';

class _CardRepo implements CardRepository {
  @override
  Future<Cached<List<CreditCard>>> getCards() async =>
      Cached([CardMapper.fromJson(cardJson())]);
  @override
  Future<CreditCard> createCard(CardDraft draft) => throw UnimplementedError();
  @override
  Future<CreditCard> updateCard(String id, CardDraft draft) =>
      throw UnimplementedError();
  @override
  Future<void> deleteCard(String id) async {}
}

class _AuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Routing-level regression for the Result screen's "recalculate with other
/// rates" controls, using the real [GetMaterialApp], the app's [GetPage]s and
/// the real [GetAppNavigator].
class _NoPicker implements PdfPicker {
  @override
  Future<PickedPdf?> pick() async => null;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    await initializeDateFormatting('en_US');
  });
  tearDown(Get.reset);

  late FakeVerificationRepository repo;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ActiveLocale.set(const Locale('es'));
    S.current = ActiveLocale.strings;
    repo = FakeVerificationRepository()..detailJson = ficohsaCompletedJson();
    final navigator = GetAppNavigator();
    Get.put<AppNavigator>(navigator);
    Get.put<VerificationRepository>(repo);
    Get.put<PdfPicker>(_NoPicker());
    Get.put(CardsController(_CardRepo()));
    Get.put(CreditsController(repository: FakeCreditsRepository([balance()])));
    Get.put(
      CatalogController(
        categories: FakeCategoryRepository(const []),
        merchants: FakeMerchantRepository(),
      ),
    );
    Get.put(AttentionController(repository: repo, navigator: navigator));
    Get.put(
      SessionController(
        repository: _AuthRepo(),
        events: SessionEvents(),
        clearLocalData: () async {},
        navigator: navigator,
      ),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        locale: const Locale('es'),
        getPages: AppPages.pages
            .where(
              (p) => [
                Routes.result,
                Routes.confirmRates,
                Routes.verificationProgress,
              ].contains(p.name),
            )
            .toList(),
        home: const Scaffold(body: Text('home')),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Verification completed() => VerificationMapper.detail(ficohsaCompletedJson());

  Future<void> expectRecalcFlow(WidgetTester tester, Finder control) async {
    expect(find.byType(ResultPage), findsOneWidget);
    await tester.tap(control);
    await settle(tester);
    expect(find.byType(ConfirmRatesPage), findsOneWidget);
    repo.detailJson = ficohsaCompletedJson(id: 'recalculated');
    await tester.tap(find.byKey(const Key('confirm-button')));
    await settle(tester);
    expect(find.byType(ConfirmRatesPage), findsNothing);
    expect(Get.find<ResultController>().verification.value?.id, 'recalculated');
    expect(find.byType(ResultPage), findsOneWidget);
    expect(repo.confirmedIds, isNotEmpty);
  }

  final entries = <String, Future<void> Function(WidgetTester)>{
    'pushed from Home/History': (tester) async {
      Get.toNamed<void>(Routes.result, arguments: 'fico');
      await settle(tester);
    },
    'replaced from Confirm after a first confirmation': (tester) async {
      Get.toNamed<void>(Routes.confirmRates, arguments: 'fico');
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirm-button')));
      await settle(tester);
    },
    'replaced from the progress page': (tester) async {
      Get.toNamed<void>(Routes.verificationProgress, arguments: 'fico');
      await settle(tester);
      Get.offNamed<void>(Routes.result, arguments: completed());
      await settle(tester);
    },
  };

  for (final entry in entries.entries) {
    for (final control in <String, Finder Function()>{
      'AppBar %': () => find.byKey(const Key('result-recalculate')),
      'summary button': () => find.byKey(const Key('recalculate-button')),
    }.entries) {
      testWidgets('${entry.key}: ${control.key} opens Confirm and returns', (
        tester,
      ) async {
        await pumpApp(tester);
        await entry.value(tester);
        await expectRecalcFlow(tester, control.value());
      });
    }
  }
}
