import { Injectable } from '@nestjs/common';
import { UserRepository } from '../../users/domain/user.repository.js';
import type { User } from '../../users/domain/user.js';
import {
  AppleIdTokenVerifier,
  GoogleIdTokenVerifier,
} from '../domain/identity-token-verifier.js';
import { AuthSessionService, type AuthTokens } from './auth-session.service.js';

export interface SignInResult {
  tokens: AuthTokens;
  user: User;
}

@Injectable()
export class SignInWithGoogleUseCase {
  constructor(
    private readonly verifier: GoogleIdTokenVerifier,
    private readonly users: UserRepository,
    private readonly sessions: AuthSessionService,
  ) {}

  async execute(idToken: string): Promise<SignInResult> {
    const identity = await this.verifier.verify(idToken);
    const user = await this.users.upsertFromIdentity(identity);
    return { user, tokens: await this.sessions.startSession(user.id) };
  }
}

@Injectable()
export class SignInWithAppleUseCase {
  constructor(
    private readonly verifier: AppleIdTokenVerifier,
    private readonly users: UserRepository,
    private readonly sessions: AuthSessionService,
  ) {}

  async execute(
    identityToken: string,
    fullName?: string,
  ): Promise<SignInResult> {
    const identity = await this.verifier.verify(identityToken, fullName);
    const user = await this.users.upsertFromIdentity(identity);
    return { user, tokens: await this.sessions.startSession(user.id) };
  }
}
