import 'auth_entities.dart';

/// Ports to the native identity SDKs.
abstract class GoogleIdentityProvider {
  /// Returns a Google **ID token**. Throws [SignInCancelled] on dismissal.
  Future<String> fetchIdToken();
}

abstract class AppleIdentityProvider {
  /// Whether Sign in with Apple can be offered on this device.
  bool get isSupported;

  /// Throws [SignInCancelled] on dismissal.
  Future<AppleCredential> fetchCredential();
}

abstract class AuthRepository {
  Future<AppUser> signInWithGoogle();
  Future<AppUser> signInWithApple();

  /// Emails a 6-digit code to [email]. [locale] (`es` | `en`) picks the
  /// language of the message.
  Future<EmailChallenge> startEmailSignIn({
    required String email,
    required String locale,
  });

  /// Exchanges the emailed [code] for a session, like the other providers.
  Future<AppUser> verifyEmailCode({
    required String email,
    required String code,
  });

  /// Which sign-in methods the backend offers.
  Future<AuthProviders> fetchProviders();

  /// The user stored on the device, if any (works offline).
  Future<AppUser?> cachedUser();

  /// Refreshes the user from `GET /me`, falling back to the stored one when
  /// the network is unavailable.
  Future<AppUser?> loadUser();

  /// Revokes the session on the server (best effort) and clears local tokens.
  Future<void> signOut();
}
