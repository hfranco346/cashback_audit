import '../../features/auth/domain/auth_entities.dart';
import '../config/app_config.dart';

import 'package:get/get.dart';

import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/presentation/email_sign_in_controller.dart';
import '../../features/auth/presentation/login_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/cards/domain/card_entities.dart';
import '../../features/cards/domain/card_repository.dart';
import '../../features/cards/presentation/card_form_controller.dart';
import '../../features/cards/presentation/card_form_page.dart';
import '../../features/cards/presentation/cards_controller.dart';
import '../../features/categories/domain/catalog_repositories.dart';
import '../../features/claim/data/url_launcher_mail_launcher.dart';
import '../../features/claim/domain/claim_email.dart';
import '../../features/claim/presentation/claim_controller.dart';
import '../../features/claim/presentation/claim_page.dart';
import '../l10n/active_locale.dart';
import '../../features/categories/presentation/catalog_controller.dart';
import '../../features/categories/presentation/catalog_page.dart';
import '../../features/settings/presentation/language_currencies_page.dart';
import '../../features/settings/presentation/locale_controller.dart';
import '../../features/verifications/domain/pdf_picker.dart';
import '../../features/verifications/domain/verification_entities.dart';
import '../../features/verifications/domain/verification_events.dart';
import '../../features/verifications/domain/verification_repository.dart';
import '../../features/verifications/presentation/attention_controller.dart';
import '../../features/verifications/presentation/confirm_rates_controller.dart';
import '../../features/verifications/presentation/verification_progress_controller.dart';
import '../../features/verifications/presentation/verification_progress_page.dart';
import '../../features/verifications/presentation/confirm_rates_page.dart';
import '../../features/verifications/presentation/history_controller.dart';
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
import '../../features/navigation/presentation/home_shell_page.dart';
import '../../features/navigation/presentation/shell_controller.dart';
import '../../features/onboarding/data/onboarding_sync.dart';
import '../../features/onboarding/domain/onboarding_draft.dart';
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
        final login = _buildLoginController();
        Get.put(login);
        Get.put(_buildEmailController(login));
        final session = Get.find<SessionController>();
        final drafts = Get.find<OnboardingDraftRepository>();
        final controller = OnboardingController(
          drafts: drafts,
          onboarding: Get.find<OnboardingRepository>(),
          navigator: Get.find<AppNavigator>(),
          sync: OnboardingSync(
            cards: Get.find<CardRepository>(),
            categories: Get.find<CategoryRepository>(),
            drafts: drafts,
          ),
          verifications: Get.find<VerificationRepository>(),
          picker: Get.find<PdfPicker>(),
          isSignedIn: () => session.user.value != null,
          userName: () => session.user.value?.firstName,
          onDataChanged: () async {
            await Get.find<CardsController>().load();
            await Get.find<CatalogController>().load();
            await Get.find<CreditsController>().fetch();
          },
          hasFreeCheck: () =>
              Get.find<CreditsController>().balance.value?.hasCredits ?? true,
        );
        login.onAuthenticated = controller.afterSignIn;
        Get.put(controller);
      }),
    ),
    GetPage(
      name: Routes.login,
      page: () => const LoginPage(),
      binding: BindingsBuilder(() {
        Get.put(_buildLoginController());
        Get.put(_buildEmailController(Get.find<LoginController>()));
      }),
    ),
    GetPage(
      name: Routes.home,
      page: () => const HomeShellPage(),
      transition: Transition.fadeIn,
      binding: BindingsBuilder(() {
        final session = Get.find<SessionController>();
        final drafts = Get.find<OnboardingDraftRepository>();
        final shell = Get.put(ShellController());
        final events = Get.find<VerificationEvents>();
        bool homeOnTop() => Get.currentRoute == Routes.home;
        // Tabs reuse the screens' controllers; the shell registers them
        // because no route binding runs for a tab.
        Get.lazyPut(
          () => HistoryController(
            repository: Get.find<VerificationRepository>(),
            navigator: Get.find<AppNavigator>(),
            credits: Get.find<CreditsController>(),
            events: events,
            shell: shell.tab,
            isRouteOnTop: homeOnTop,
          ),
        );
        Get.put(
          HomeController(
            attention: Get.find<AttentionController>(),
            cards: Get.find<CardsController>(),
            catalog: Get.find<CatalogController>(),
            latest: Get.find<LatestVerificationsController>(),
            credits: Get.find<CreditsController>(),
            drafts: drafts,
            verifications: Get.find<VerificationRepository>(),
            sync: OnboardingSync(
              cards: Get.find<CardRepository>(),
              categories: Get.find<CategoryRepository>(),
              drafts: drafts,
            ),
            isSignedIn: () => session.user.value != null,
            events: events,
            shell: shell.tab,
            isRouteOnTop: homeOnTop,
            startup: () async {
              await session.restore();
              await Get.find<SubscriptionController>().fetchStatus();
              await Get.find<CreditsController>().fetch();
            },
          ),
        );
      }),
    ),
    GetPage(
      name: Routes.cardForm,
      page: () => const CardFormPage(),
      binding: BindingsBuilder(() {
        // Eager: onInit fills the form from the edited card and must not run
        // inside the page's first build.
        Get.put(
          CardFormController(
            repository: Get.find<CardRepository>(),
            cards: Get.find<CardsController>(),
            catalog: Get.find<CatalogController>(),
            editing: Get.arguments is CreditCard
                ? Get.arguments as CreditCard
                : null,
            userCurrencies:
                Get.find<SessionController>().user.value?.currencies ??
                const [],
            defaultCurrency:
                Get.find<SessionController>().user.value?.primaryCurrency,
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
      name: Routes.verificationProgress,
      page: () => const VerificationProgressPage(),
      binding: BindingsBuilder(() {
        final progress = VerificationProgressArgs.from(Get.arguments);
        Get.lazyPut(
          () => VerificationProgressController(
            verificationId: progress.verificationId,
            fileName: progress.fileName,
            cards: Get.find<CardsController>(),
            repository: Get.find<VerificationRepository>(),
            navigator: Get.find<AppNavigator>(),
            attention: Get.find<AttentionController>(),
            credits: Get.find<CreditsController>(),
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
            credits: Get.find<CreditsController>(),
            savedRates:
                Get.find<SessionController>().user.value?.currencyRates ??
                const {},
            savedRatesPrimary:
                Get.find<SessionController>().user.value?.primaryCurrency,
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
            cards: Get.find<CardsController>(),
            attention: Get.find<AttentionController>(),
            credits: Get.find<CreditsController>(),
            initial: args is Verification ? args : null,
            verificationId: args is String ? args : null,
          ),
        );
      }),
    ),
    GetPage(
      name: Routes.claim,
      page: () => const ClaimPage(),
      binding: BindingsBuilder(() {
        final verification = Get.arguments as Verification;
        final cards = Get.find<CardsController>();
        Get.lazyPut(
          () => ClaimController(
            verification: verification,
            launcher: const UrlLauncherMailLauncher(),
            initialLanguage: ClaimLanguage.fromCode(
              ActiveLocale.locale.languageCode,
            ),
            card: cards.byId(verification.cardId),
            userName: Get.find<SessionController>().user.value?.name,
            repository: Get.find<ClaimEmailRepository>(),
            cards: cards,
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
    GetPage(
      name: Routes.languageCurrencies,
      page: () => const LanguageCurrenciesPage(),
    ),
  ];
}

EmailSignInController _buildEmailController(LoginController login) =>
    EmailSignInController(
      repository: Get.find<AuthRepository>(),
      login: login,
      localeCode: () => Get.find<LocaleController>().locale.languageCode,
    );

LoginController _buildLoginController() => LoginController(
  repository: Get.find<AuthRepository>(),
  session: Get.find<SessionController>(),
  navigator: Get.find<AppNavigator>(),
  showApple: Get.find<AppleIdentityProvider>().isSupported,
  devSignIn: AppConfig.devLoginEnabled ? _devSignIn : null,
);

/// Debug-only: stores the build-time dev token and loads the user it belongs
/// to from `/me`. Never reachable in release builds (see AppConfig).
Future<AppUser> _devSignIn() async {
  await Get.find<TokenStorage>().save(
    const AuthTokens(
      accessToken: AppConfig.devAccessToken,
      refreshToken: 'dev-session',
    ),
  );
  final user = await Get.find<AuthRepository>().loadUser();
  if (user == null) {
    throw StateError('The development token was rejected by the backend.');
  }
  return user;
}
