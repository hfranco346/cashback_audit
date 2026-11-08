import 'package:get/get.dart';

import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/presentation/login_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/cards/domain/card_entities.dart';
import '../../features/cards/domain/card_repository.dart';
import '../../features/cards/presentation/card_form_controller.dart';
import '../../features/cards/presentation/card_form_page.dart';
import '../../features/cards/presentation/cards_controller.dart';
import '../../features/categories/presentation/catalog_controller.dart';
import '../../features/categories/presentation/catalog_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/verifications/domain/pdf_picker.dart';
import '../../features/verifications/domain/verification_entities.dart';
import '../../features/verifications/domain/verification_repository.dart';
import '../../features/verifications/presentation/confirm_rates_controller.dart';
import '../../features/verifications/presentation/confirm_rates_page.dart';
import '../../features/verifications/presentation/history_controller.dart';
import '../../features/verifications/presentation/history_page.dart';
import '../../features/verifications/presentation/result_controller.dart';
import '../../features/verifications/presentation/result_page.dart';
import '../../features/verifications/presentation/upload_controller.dart';
import '../../features/verifications/presentation/upload_page.dart';
import '../../features/credits/domain/credits_repository.dart';
import '../../features/credits/presentation/credit_history_controller.dart';
import '../../features/credits/presentation/credit_history_page.dart';
import '../../features/credits/presentation/credits_controller.dart';
import '../../features/subscription/domain/subscription_repository.dart';
import '../../features/subscription/presentation/paywall_controller.dart';
import '../../features/subscription/presentation/paywall_page.dart';
import '../../features/subscription/presentation/subscription_controller.dart';
import '../../features/home/presentation/home_controller.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/onboarding/presentation/onboarding_controller.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/splash/presentation/splash_controller.dart';
import '../../features/splash/presentation/splash_page.dart';
import '../../features/onboarding/domain/onboarding_repository.dart';
import '../storage/token_storage.dart';
import 'app_navigator.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static final pages = <GetPage<dynamic>>[
    GetPage(
      name: Routes.splash,
      page: () => const SplashPage(),
      binding: BindingsBuilder(() {
        // Eager: SplashPage never reads its controller, and the controller's
        // onReady is what navigates away from the splash.
        Get.put(
          SplashController(
            onboarding: Get.find<OnboardingRepository>(),
            tokens: Get.find<TokenStorage>(),
            navigator: Get.find<AppNavigator>(),
          ),
        );
      }),
    ),
    GetPage(
      name: Routes.onboarding,
      page: () => const OnboardingPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(
          () => OnboardingController(
            repository: Get.find<OnboardingRepository>(),
            navigator: Get.find<AppNavigator>(),
          ),
        );
      }),
    ),
    GetPage(
      name: Routes.login,
      page: () => const LoginPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(
          () => LoginController(
            repository: Get.find<AuthRepository>(),
            session: Get.find<SessionController>(),
            navigator: Get.find<AppNavigator>(),
            showApple: Get.find<AppleIdentityProvider>().isSupported,
          ),
        );
      }),
    ),
    GetPage(
      name: Routes.home,
      page: () => const HomePage(),
      transition: Transition.fadeIn,
      binding: BindingsBuilder(() {
        Get.put(
          HomeController(
            session: Get.find<SessionController>(),
            subscription: Get.find<SubscriptionController>(),
            credits: Get.find<CreditsController>(),
          ),
        );
      }),
    ),
    GetPage(
      name: Routes.cardForm,
      page: () => const CardFormPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(
          () => CardFormController(
            repository: Get.find<CardRepository>(),
            cards: Get.find<CardsController>(),
            catalog: Get.find<CatalogController>(),
            editing: Get.arguments is CreditCard
                ? Get.arguments as CreditCard
                : null,
          ),
        );
      }),
    ),
    GetPage(
      name: Routes.upload,
      page: () => const UploadPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(
          () => UploadController(
            repository: Get.find<VerificationRepository>(),
            picker: Get.find<PdfPicker>(),
            cards: Get.find<CardsController>(),
            credits: Get.find<CreditsController>(),
            navigator: Get.find<AppNavigator>(),
            onVerified: () => Get.find<LatestVerificationsController>().load(),
            initialCardId: Get.arguments is String
                ? Get.arguments as String
                : null,
          ),
        );
      }),
    ),
    GetPage(
      name: Routes.confirmRates,
      page: () => const ConfirmRatesPage(),
      transition: Transition.rightToLeftWithFade,
      binding: BindingsBuilder(() {
        final args = Get.arguments;
        Get.lazyPut(
          () => ConfirmRatesController(
            repository: Get.find<VerificationRepository>(),
            cards: Get.find<CardsController>(),
            navigator: Get.find<AppNavigator>(),
            catalog: Get.find<CatalogController>(),
            args: args is ConfirmRatesArgs
                ? args
                : ConfirmRatesArgs.byId(args as String),
          ),
        );
      }),
    ),
    GetPage(
      name: Routes.result,
      page: () => const ResultPage(),
      transition: Transition.fadeIn,
      binding: BindingsBuilder(() {
        final args = Get.arguments;
        Get.lazyPut(
          () => ResultController(
            repository: Get.find<VerificationRepository>(),
            catalog: Get.find<CatalogController>(),
            navigator: Get.find<AppNavigator>(),
            initial: args is Verification ? args : null,
            verificationId: args is String ? args : null,
          ),
        );
      }),
    ),
    GetPage(
      name: Routes.history,
      page: () => const HistoryPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(
          () => HistoryController(
            repository: Get.find<VerificationRepository>(),
            navigator: Get.find<AppNavigator>(),
            initialCardId: Get.arguments is String
                ? Get.arguments as String
                : null,
          ),
        );
      }),
    ),
    GetPage(
      name: Routes.paywall,
      page: () => const PaywallPage(),
      fullscreenDialog: true,
      binding: BindingsBuilder(() {
        Get.lazyPut(
          () => PaywallController(
            billing: Get.find<BillingService>(),
            credits: Get.find<CreditsController>(),
            subscription: Get.find<SubscriptionController>(),
            navigator: Get.find<AppNavigator>(),
          ),
        );
      }),
    ),
    GetPage(
      name: Routes.creditHistory,
      page: () => const CreditHistoryPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(
          () => CreditHistoryController(
            repository: Get.find<CreditsRepository>(),
          ),
        );
      }),
    ),
    GetPage(name: Routes.catalog, page: () => const CatalogPage()),
    GetPage(name: Routes.settings, page: () => const SettingsPage()),
  ];
}
