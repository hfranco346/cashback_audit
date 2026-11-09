import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/apple_identity_provider.dart';
import '../../features/auth/data/auth_repository_impl.dart';
import '../../features/auth/data/google_identity_provider.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/cards/data/card_repository_impl.dart';
import '../../features/cards/domain/card_repository.dart';
import '../../features/cards/presentation/cards_controller.dart';
import '../../features/categories/data/catalog_repositories_impl.dart';
import '../../features/categories/domain/catalog_repositories.dart';
import '../../features/categories/presentation/catalog_controller.dart';
import '../../features/verifications/data/file_picker_pdf_picker.dart';
import '../../features/verifications/data/verification_repository_impl.dart';
import '../../features/verifications/domain/pdf_picker.dart';
import '../../features/verifications/domain/verification_repository.dart';
import '../../features/verifications/presentation/attention_controller.dart';
import '../../features/verifications/presentation/history_controller.dart';
import '../../features/credits/data/credits_repository_impl.dart';
import '../../features/credits/domain/credits_repository.dart';
import '../../features/credits/presentation/credits_controller.dart';
import '../../features/subscription/data/revenuecat_billing_service.dart';
import '../../features/subscription/data/subscription_repository_impl.dart';
import '../../features/subscription/domain/subscription_repository.dart';
import '../../features/subscription/presentation/subscription_controller.dart';
import '../../features/settings/data/user_preferences_repository_impl.dart';
import '../../features/settings/domain/locale_preference.dart';
import '../../features/settings/domain/user_preferences.dart';
import '../../features/settings/presentation/locale_controller.dart';
import '../../features/settings/presentation/preferences_controller.dart';
import '../../features/onboarding/data/onboarding_repository_impl.dart';
import '../../features/onboarding/data/onboarding_draft_repository_impl.dart';
import '../../features/onboarding/domain/onboarding_draft.dart';
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
    Get.put<OnboardingDraftRepository>(
      OnboardingDraftRepositoryImpl(prefs),
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
        clearLocalData: _clearUserScopedState,
        navigator: Get.find<AppNavigator>(),
      ),
      permanent: true,
    );
    final dio = Get.find<Dio>();
    final db = Get.find<AppDatabase>();
    Get.put<CardRepository>(CardRepositoryImpl(dio, db), permanent: true);
    Get.put<CategoryRepository>(
      CategoryRepositoryImpl(dio, db),
      permanent: true,
    );
    Get.put<MerchantRepository>(
      MerchantRepositoryImpl(dio, db),
      permanent: true,
    );
    Get.put<VerificationRepository>(
      VerificationRepositoryImpl(dio, db),
      permanent: true,
    );
    Get.lazyPut<AttentionController>(
      () => AttentionController(
        repository: Get.find<VerificationRepository>(),
        navigator: Get.find<AppNavigator>(),
      ),
      fenix: true,
    );
    Get.put<PdfPicker>(FilePickerPdfPicker(), permanent: true);
    Get.lazyPut<LatestVerificationsController>(
      () => LatestVerificationsController(Get.find<VerificationRepository>()),
      fenix: true,
    );
    Get.put<BillingService>(RevenueCatBillingService(), permanent: true);
    Get.put<SubscriptionRepository>(
      SubscriptionRepositoryImpl(dio),
      permanent: true,
    );
    Get.put<SubscriptionController>(
      SubscriptionController(
        repository: Get.find<SubscriptionRepository>(),
        billing: Get.find<BillingService>(),
      ),
      permanent: true,
    );
    Get.put<CreditsRepository>(CreditsRepositoryImpl(dio), permanent: true);
    Get.put<CreditsController>(
      CreditsController(repository: Get.find<CreditsRepository>()),
      permanent: true,
    );
    Get.put<UserPreferencesRepository>(
      UserPreferencesRepositoryImpl(dio),
      permanent: true,
    );
    Get.put<PreferencesController>(
      PreferencesController(
        repository: Get.find<UserPreferencesRepository>(),
        session: Get.find<SessionController>(),
        locale: Get.find<LocaleController>(),
        localeStore: Get.find<LocalePreferenceRepository>(),
      ),
      permanent: true,
    );
    // RevenueCat customer must carry our user id before any purchase.
    final session = Get.find<SessionController>();
    session
      ..addSignedInHook((user) => Get.find<BillingService>().logIn(user.id))
      ..addSignedInHook(Get.find<PreferencesController>().syncLocale)
      ..addSignedInHook((_) async {
        await Get.find<SubscriptionController>().fetchStatus();
        await Get.find<CreditsController>().fetch();
      })
      ..addSignedOutHook(Get.find<BillingService>().logOut)
      ..addSignedOutHook(() async => Get.find<SubscriptionController>().reset())
      ..addSignedOutHook(() async => Get.find<CreditsController>().reset());
    // Shared stores; recreated lazily after logout.
    Get.lazyPut<CardsController>(
      () => CardsController(Get.find<CardRepository>()),
      fenix: true,
    );
    Get.lazyPut<CatalogController>(
      () => CatalogController(
        categories: Get.find<CategoryRepository>(),
        merchants: Get.find<MerchantRepository>(),
      ),
      fenix: true,
    );
  }

  /// Wipes cached rows and drops controllers holding the previous user's data.
  Future<void> _clearUserScopedState() async {
    await Get.find<AppDatabase>().clearAll();
    Get.delete<CardsController>(force: true);
    Get.delete<CatalogController>(force: true);
    Get.delete<LatestVerificationsController>(force: true);
    Get.delete<AttentionController>(force: true);
  }
}
