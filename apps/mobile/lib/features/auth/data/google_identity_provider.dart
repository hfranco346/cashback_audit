import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/auth_entities.dart';
import '../domain/auth_repository.dart';

/// google_sign_in 7.x: a singleton that must be `initialize`d once and
/// `authenticate()`s interactively. The ID token lives on
/// `account.authentication.idToken`.
class GoogleSignInIdentityProvider implements GoogleIdentityProvider {
  bool _initialized = false;

  String? _orNull(String value) => value.isEmpty ? null : value;

  @override
  Future<String> fetchIdToken() async {
    final google = GoogleSignIn.instance;
    if (!_initialized) {
      await google.initialize(
        clientId: _orNull(AppConfig.googleIosClientId),
        serverClientId: _orNull(AppConfig.googleServerClientId),
      );
      _initialized = true;
    }
    try {
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AppException(
          kind: AppErrorKind.unknown,
          code: 'IDENTITY_TOKEN_MISSING',
        );
      }
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const SignInCancelled();
      }
      throw AppException(
        kind: AppErrorKind.unknown,
        code: 'IDENTITY_FAILED',
        serverMessage: e.description,
      );
    }
  }
}
