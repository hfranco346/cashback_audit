import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/onboarding/data/onboarding_repository_impl.dart';
import '../../features/onboarding/domain/onboarding_repository.dart';
import '../config/app_config.dart';
import '../db/app_database.dart';
import '../network/dio_factory.dart';
import '../network/session_events.dart';
import '../storage/token_storage.dart';

/// App-wide singletons. Feature bindings register their own controllers.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
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
    Get.put<OnboardingRepository>(
      OnboardingRepositoryImpl(SharedPreferencesAsync()),
      permanent: true,
    );
  }
}
