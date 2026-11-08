import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { OAuth2Client } from 'google-auth-library';
import type { Env } from '../../config/env.js';
import type { VerifiedIdentity } from '../../users/domain/user.js';
import {
  IdentityProviderUnavailableError,
  InvalidIdentityTokenError,
} from '../domain/auth-errors.js';
import { GoogleIdTokenVerifier } from '../domain/identity-token-verifier.js';

@Injectable()
export class GoogleOAuthIdTokenVerifier extends GoogleIdTokenVerifier {
  private readonly client = new OAuth2Client();
  private readonly audiences: string[];

  constructor(config: ConfigService<Env, true>) {
    super();
    this.audiences = config
      .get('GOOGLE_CLIENT_IDS', { infer: true })
      .split(',')
      .map((id) => id.trim())
      .filter(Boolean);
  }

  async verify(idToken: string): Promise<VerifiedIdentity> {
    if (this.audiences.length === 0) {
      throw new IdentityProviderUnavailableError('Google');
    }
    try {
      const ticket = await this.client.verifyIdToken({
        idToken,
        audience: this.audiences,
      });
      const payload = ticket.getPayload();
      if (!payload?.sub) throw new InvalidIdentityTokenError();
      return {
        provider: 'GOOGLE',
        subject: payload.sub,
        email: payload.email ?? null,
        name: payload.name ?? null,
      };
    } catch (error) {
      if (error instanceof InvalidIdentityTokenError) throw error;
      throw new InvalidIdentityTokenError();
    }
  }
}
