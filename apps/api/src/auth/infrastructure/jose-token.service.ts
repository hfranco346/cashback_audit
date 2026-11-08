import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SignJWT, jwtVerify } from 'jose';
import { parseDurationSeconds, type Env } from '../../config/env.js';
import {
  InvalidAccessTokenError,
  InvalidRefreshTokenError,
} from '../domain/auth-errors.js';
import {
  TokenService,
  type IssuedAccessToken,
  type IssuedRefreshToken,
  type RefreshClaims,
} from '../domain/token-service.js';

const ISSUER = 'cashback-audit-api';
const encode = (secret: string) => new TextEncoder().encode(secret);

@Injectable()
export class JoseTokenService extends TokenService {
  private readonly accessSecret: Uint8Array;
  private readonly refreshSecret: Uint8Array;
  private readonly accessTtl: number;
  private readonly refreshTtl: number;

  constructor(config: ConfigService<Env, true>) {
    super();
    this.accessSecret = encode(
      config.get('JWT_ACCESS_SECRET', { infer: true }),
    );
    this.refreshSecret = encode(
      config.get('JWT_REFRESH_SECRET', { infer: true }),
    );
    this.accessTtl = parseDurationSeconds(
      config.get('JWT_ACCESS_TTL', { infer: true }),
    );
    this.refreshTtl = parseDurationSeconds(
      config.get('JWT_REFRESH_TTL', { infer: true }),
    );
  }

  async signAccessToken(userId: string): Promise<IssuedAccessToken> {
    const token = await new SignJWT({ typ: 'access' })
      .setProtectedHeader({ alg: 'HS256' })
      .setSubject(userId)
      .setIssuer(ISSUER)
      .setIssuedAt()
      .setExpirationTime(`${this.accessTtl}s`)
      .sign(this.accessSecret);
    return { token, expiresInSeconds: this.accessTtl };
  }

  async verifyAccessToken(token: string): Promise<{ userId: string }> {
    try {
      const { payload } = await jwtVerify(token, this.accessSecret, {
        issuer: ISSUER,
        algorithms: ['HS256'],
      });
      if (payload.typ !== 'access' || !payload.sub) {
        throw new InvalidAccessTokenError();
      }
      return { userId: payload.sub };
    } catch {
      throw new InvalidAccessTokenError();
    }
  }

  async signRefreshToken(claims: RefreshClaims): Promise<IssuedRefreshToken> {
    const expiresAt = new Date(Date.now() + this.refreshTtl * 1000);
    const token = await new SignJWT({ typ: 'refresh', fam: claims.familyId })
      .setProtectedHeader({ alg: 'HS256' })
      .setSubject(claims.userId)
      .setJti(claims.tokenId)
      .setIssuer(ISSUER)
      .setIssuedAt()
      .setExpirationTime(Math.floor(expiresAt.getTime() / 1000))
      .sign(this.refreshSecret);
    return { token, expiresAt };
  }

  async verifyRefreshToken(token: string): Promise<RefreshClaims> {
    try {
      const { payload } = await jwtVerify(token, this.refreshSecret, {
        issuer: ISSUER,
        algorithms: ['HS256'],
      });
      if (
        payload.typ !== 'refresh' ||
        !payload.sub ||
        !payload.jti ||
        typeof payload.fam !== 'string'
      ) {
        throw new InvalidRefreshTokenError();
      }
      return {
        userId: payload.sub,
        tokenId: payload.jti,
        familyId: payload.fam,
      };
    } catch {
      throw new InvalidRefreshTokenError();
    }
  }
}
