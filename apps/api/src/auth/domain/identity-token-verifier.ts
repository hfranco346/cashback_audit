import type { VerifiedIdentity } from '../../users/domain/user.js';

/** Port: verifies a provider-issued ID token and extracts the identity. */
export abstract class GoogleIdTokenVerifier {
  abstract verify(idToken: string): Promise<VerifiedIdentity>;
}

export abstract class AppleIdTokenVerifier {
  /** `fullName` comes from the client: Apple omits it from the token. */
  abstract verify(
    identityToken: string,
    fullName?: string,
  ): Promise<VerifiedIdentity>;
}
