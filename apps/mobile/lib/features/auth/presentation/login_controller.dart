import 'package:get/get.dart';

import '../../../core/errors/error_messages.dart';
import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/app_routes.dart';
import '../domain/auth_entities.dart';
import '../domain/auth_repository.dart';
import 'session_controller.dart';

enum LoginProvider { google, apple, dev }

class LoginController extends GetxController {
  LoginController({
    required this._repository,
    required this._session,
    required this._navigator,
    required this.showApple,
    this._devSignIn,
  });

  final AuthRepository _repository;
  final SessionController _session;
  final AppNavigator _navigator;
  final bool showApple;
  final Future<AppUser> Function()? _devSignIn;

  /// Runs after a successful sign-in instead of opening Home (the guided
  /// setup uses it to push its draft to the backend).
  Future<void> Function(AppUser user)? onAuthenticated;

  /// Debug-only shortcut that signs in with a pre-issued token.
  bool get showDevSignIn => _devSignIn != null;

  final loading = Rxn<LoginProvider>();
  final errorMessage = RxnString();

  bool get isBusy => loading.value != null;

  Future<void> signInWithGoogle() =>
      _run(LoginProvider.google, _repository.signInWithGoogle);

  Future<void> signInWithApple() =>
      _run(LoginProvider.apple, _repository.signInWithApple);

  Future<void> signInForDevelopment() {
    final devSignIn = _devSignIn;
    if (devSignIn == null) return Future.value();
    return _run(LoginProvider.dev, devSignIn);
  }

  Future<void> _run(
    LoginProvider provider,
    Future<AppUser> Function() action,
  ) async {
    if (isBusy) return;
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
      errorMessage.value = userMessageFor(e);
    } finally {
      loading.value = null;
    }
  }
}
