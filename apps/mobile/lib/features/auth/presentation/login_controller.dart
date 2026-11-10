import 'package:get/get.dart';

import '../../../core/errors/error_messages.dart';
import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/app_routes.dart';
import '../domain/auth_entities.dart';
import '../domain/auth_repository.dart';
import 'session_controller.dart';

enum LoginProvider { email, google, apple, dev }

class LoginController extends GetxController {
  LoginController({
    required this._repository,
    required this._session,
    required this._navigator,
    required bool showApple,
    this._devSignIn,
  }) : _appleSupported = showApple;

  final AuthRepository _repository;
  final SessionController _session;
  final AppNavigator _navigator;
  final bool _appleSupported;
  final Future<AppUser> Function()? _devSignIn;

  /// Runs after a successful sign-in instead of opening Home (the guided
  /// setup uses it to push its draft to the backend).
  Future<void> Function(AppUser user)? onAuthenticated;

  /// Debug-only shortcut that signs in with a pre-issued token.
  bool get showDevSignIn => _devSignIn != null;

  /// Sign-in methods the backend has configured. Email until it answers.
  final providers = AuthProviders.emailOnly.obs;

  /// Google needs its client ids on the backend, so it is shown only then.
  bool get showGoogle => providers.value.google;

  /// Apple needs both a supporting device and the backend configuration.
  bool get showApple => _appleSupported && providers.value.apple;

  final loading = Rxn<LoginProvider>();
  final errorMessage = RxnString();

  bool get isBusy => loading.value != null;

  @override
  void onInit() {
    super.onInit();
    loadProviders();
  }

  /// Asks the backend which sign-in methods to offer; keeps the email-only
  /// default when it cannot be reached.
  Future<void> loadProviders() async {
    try {
      providers.value = await _repository.fetchProviders();
    } catch (_) {
      // Email sign-in needs no provider configuration.
    }
  }

  Future<void> signInWithGoogle() async {
    await _run(LoginProvider.google, _repository.signInWithGoogle);
  }

  Future<void> signInWithApple() async {
    await _run(LoginProvider.apple, _repository.signInWithApple);
  }

  /// Signs in with the emailed [code]. Returns the failure (instead of
  /// showing it here) so the code screen can explain what went wrong, or null
  /// once the session started.
  Future<Object?> signInWithEmailCode(String email, String code) => _run(
    LoginProvider.email,
    () => _repository.verifyEmailCode(email: email, code: code),
    reportErrors: false,
  );

  Future<void> signInForDevelopment() async {
    final devSignIn = _devSignIn;
    if (devSignIn == null) return;
    await _run(LoginProvider.dev, devSignIn);
  }

  /// Runs one sign-in. Returns the failure, or null on success/cancellation.
  Future<Object?> _run(
    LoginProvider provider,
    Future<AppUser> Function() action, {
    bool reportErrors = true,
  }) async {
    if (isBusy) return null;
    loading.value = provider;
    errorMessage.value = null;
    try {
      final user = await action();
      await _session.onSignedIn(user);
      final afterSignIn = onAuthenticated;
      if (afterSignIn != null) {
        await afterSignIn(user);
      } else {
        _navigator.offAll(Routes.home);
      }
    } on SignInCancelled {
      // User dismissed the sheet: nothing to show.
    } catch (e) {
      if (reportErrors) errorMessage.value = userMessageFor(e);
      return e;
    } finally {
      loading.value = null;
    }
    return null;
  }
}
