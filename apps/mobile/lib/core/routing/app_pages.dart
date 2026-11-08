import 'package:get/get.dart';

import '../../features/splash/presentation/splash_controller.dart';
import '../../features/splash/presentation/splash_page.dart';
import '../../features/onboarding/domain/onboarding_repository.dart';
import '../storage/token_storage.dart';
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
          ),
        );
      }),
    ),
  ];
}
