import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from 'jose';
import type { Env } from '../../config/env.js';
import type { VerifiedIdentity } from '../../users/domain/user.js';
import {
  IdentityProviderUnavailableError,
  InvalidIdentityTokenError,
} from '../domain/auth-errors.js';
import { AppleIdTokenVerifier } from '../domain/identity-token-verifier.js';

export const APPLE_ISSUER = 'https://appleid.apple.com';
export const APPLE_JWKS_URL = 'https://appleid.apple.com/auth/keys';

@Injectable()
export class JoseAppleIdTokenVerifier extends AppleIdTokenVerifier {
  private readonly audience: string;
  private keys: JWTVerifyGetKey = createRemoteJWKSet(new URL(APPLE_JWKS_URL));

  constructor(config: ConfigService<Env, true>) {
    super();
    this.audience = config.get('APPLE_BUNDLE_ID', { infer: true });
  }

  /** Test seam: swap Apple's remote JWKS for a local key set. */
  useKeys(keys: JWTVerifyGetKey): this {
    this.keys = keys;
    return this;
  }

  async verify(
    identityToken: string,
    fullName?: string,
  ): Promise<VerifiedIdentity> {
    if (!this.audience) {
      throw new IdentityProviderUnavailableError('Apple');
    }
    try {
      const { payload } = await jwtVerify(identityToken, this.keys, {
        issuer: APPLE_ISSUER,
        audience: this.audience,
        algorithms: ['RS256'],
      });
      if (!payload.sub) throw new InvalidIdentityTokenError();
      return {
        provider: 'APPLE',
        subject: payload.sub,
        email: typeof payload.email === 'string' ? payload.email : null,
        name: fullName?.trim() || null,
      };
    } catch (error) {
      if (error instanceof InvalidIdentityTokenError) throw error;
      throw new InvalidIdentityTokenError();
    }
  }
}
