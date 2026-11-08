import 'package:get/get.dart';

import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/presentation/login_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/session_controller.dart';
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
        Get.lazyPut(
          () => SplashController(
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
    GetPage(name: Routes.home, page: () => const HomePage()),
  ];
}
