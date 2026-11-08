import { Injectable } from '@nestjs/common';
import { createHash, randomUUID } from 'node:crypto';
import { InvalidRefreshTokenError } from '../domain/auth-errors.js';
import { RefreshTokenRepository } from '../domain/refresh-token.repository.js';
import { TokenService } from '../domain/token-service.js';

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  tokenType: 'Bearer';
  /** Access token lifetime in seconds. */
  expiresIn: number;
}

export function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

/** Issues, rotates and revokes token pairs. */
@Injectable()
export class AuthSessionService {
  constructor(
    private readonly tokens: TokenService,
    private readonly refreshTokens: RefreshTokenRepository,
  ) {}

  /** Starts a new refresh-token family (a fresh sign-in). */
  async startSession(userId: string): Promise<AuthTokens> {
    const tokenId = randomUUID();
    const familyId = randomUUID();
    const refresh = await this.tokens.signRefreshToken({
      userId,
      tokenId,
      familyId,
    });
    await this.refreshTokens.create({
      id: tokenId,
      userId,
      familyId,
      tokenHash: hashToken(refresh.token),
      expiresAt: refresh.expiresAt,
    });
    return this.buildTokens(userId, refresh.token);
  }

  /** Rotates a refresh token; replaying a used one revokes the whole family. */
  async rotate(presentedToken: string): Promise<AuthTokens> {
    const claims = await this.tokens.verifyRefreshToken(presentedToken);
    const record = await this.refreshTokens.findByHash(
      hashToken(presentedToken),
    );
    if (!record || record.userId !== claims.userId) {
      throw new InvalidRefreshTokenError();
    }
    if (record.revokedAt) {
      await this.refreshTokens.revokeFamily(record.familyId);
      throw new InvalidRefreshTokenError();
    }
    if (record.expiresAt.getTime() <= Date.now()) {
      throw new InvalidRefreshTokenError();
    }

    const tokenId = randomUUID();
    const refresh = await this.tokens.signRefreshToken({
      userId: record.userId,
      tokenId,
      familyId: record.familyId,
    });
    const rotated = await this.refreshTokens.rotate(record.id, {
      id: tokenId,
      userId: record.userId,
      familyId: record.familyId,
      tokenHash: hashToken(refresh.token),
      expiresAt: refresh.expiresAt,
    });
    if (!rotated) {
      await this.refreshTokens.revokeFamily(record.familyId);
      throw new InvalidRefreshTokenError();
    }
    return this.buildTokens(record.userId, refresh.token);
  }

  /** Idempotent: unknown or invalid tokens are ignored. */
  async revoke(presentedToken: string): Promise<void> {
    const record = await this.refreshTokens.findByHash(
      hashToken(presentedToken),
    );
    if (record) {
      await this.refreshTokens.revokeFamily(record.familyId);
    }
  }

  private async buildTokens(
    userId: string,
    refreshToken: string,
  ): Promise<AuthTokens> {
    const access = await this.tokens.signAccessToken(userId);
    return {
      accessToken: access.token,
      refreshToken,
      tokenType: 'Bearer',
      expiresIn: access.expiresInSeconds,
    };
  }
}
