import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/apple_identity_provider.dart';
import '../../features/auth/data/auth_repository_impl.dart';
import '../../features/auth/data/google_identity_provider.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/onboarding/data/onboarding_repository_impl.dart';
import '../../features/onboarding/domain/onboarding_repository.dart';
import '../config/app_config.dart';
import '../db/app_database.dart';
import '../network/dio_factory.dart';
import '../routing/app_navigator.dart';
import '../network/session_events.dart';
import '../storage/token_storage.dart';

/// App-wide singletons. Feature bindings register their own controllers.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<AppNavigator>(GetAppNavigator(), permanent: true);
    Get.put<SessionEvents>(SessionEvents(), permanent: true);
    Get.put<TokenStorage>(SecureTokenStorage(), permanent: true);
    Get.put<Dio>(
      buildDio(
        baseUrl: AppConfig.apiBaseUrl,
        tokens: Get.find<TokenStorage>(),
        events: Get.find<SessionEvents>(),
      ),
      permanent: true,
    );
    Get.put<AppDatabase>(AppDatabase(), permanent: true);
    final prefs = SharedPreferencesAsync();
    Get.put<OnboardingRepository>(
      OnboardingRepositoryImpl(prefs),
      permanent: true,
    );
    Get.put<AppleIdentityProvider>(
      SignInWithAppleIdentityProvider(),
      permanent: true,
    );
    Get.put<AuthRepository>(
      AuthRepositoryImpl(
        dio: Get.find<Dio>(),
        tokens: Get.find<TokenStorage>(),
        prefs: prefs,
        google: GoogleSignInIdentityProvider(),
        apple: Get.find<AppleIdentityProvider>(),
      ),
      permanent: true,
    );
    Get.put<SessionController>(
      SessionController(
        repository: Get.find<AuthRepository>(),
        events: Get.find<SessionEvents>(),
        clearLocalData: Get.find<AppDatabase>().clearAll,
        navigator: Get.find<AppNavigator>(),
      ),
      permanent: true,
    );
  }
}
