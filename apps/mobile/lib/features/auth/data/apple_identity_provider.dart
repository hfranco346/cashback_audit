import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/auth_entities.dart';
import '../domain/auth_repository.dart';

class SignInWithAppleIdentityProvider implements AppleIdentityProvider {
  /// Offered on iOS only (Android would need a web flow, out of scope).
  @override
  bool get isSupported => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<AppleCredential> fetchCredential() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final token = credential.identityToken;
      if (token == null) {
        throw const AppException(
          kind: AppErrorKind.unknown,
          code: 'IDENTITY_TOKEN_MISSING',
        );
      }
      final fullName = [
        credential.givenName,
        credential.familyName,
      ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
      return AppleCredential(
        identityToken: token,
        fullName: fullName.isEmpty ? null : fullName,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const SignInCancelled();
      }
      throw AppException(
        kind: AppErrorKind.unknown,
        code: 'IDENTITY_FAILED',
        serverMessage: e.message,
      );
    }
  }
}
