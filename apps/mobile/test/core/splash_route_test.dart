import 'package:cashback_audit/core/routing/app_navigator.dart';
import 'package:cashback_audit/core/routing/app_pages.dart';
import 'package:cashback_audit/core/routing/app_routes.dart';
import 'package:cashback_audit/core/storage/token_storage.dart';
import 'package:cashback_audit/features/onboarding/domain/onboarding_repository.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/fakes.dart';

class _FakeOnboarding implements OnboardingRepository {
  @override
  Future<bool> hasSeenOnboarding() async => false;
  @override
  Future<void> markOnboardingSeen() async {}
}

void main() {
  tearDown(Get.reset);

  // Regression: the splash view never reads its controller, so a lazily
  // registered controller was never created and the app stayed on the splash.
  testWidgets('the splash route leaves the splash on its own', (tester) async {
    final navigator = FakeNavigator();
    Get.put<OnboardingRepository>(_FakeOnboarding());
    Get.put<TokenStorage>(InMemoryTokenStorage());
    Get.put<AppNavigator>(navigator);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        initialRoute: Routes.splash,
        getPages: AppPages.pages
            .where((page) => page.name == Routes.splash)
            .toList(),
        home: const SizedBox.shrink(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(navigator.routes, [Routes.onboarding]);
  });
}
