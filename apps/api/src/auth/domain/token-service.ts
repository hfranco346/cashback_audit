export interface IssuedAccessToken {
  token: string;
  expiresInSeconds: number;
}

export interface IssuedRefreshToken {
  token: string;
  expiresAt: Date;
}

export interface RefreshClaims {
  userId: string;
  tokenId: string;
  familyId: string;
}

/** Port: signs and verifies our own access/refresh tokens. */
export abstract class TokenService {
  abstract signAccessToken(userId: string): Promise<IssuedAccessToken>;
  /** Throws InvalidAccessTokenError. */
  abstract verifyAccessToken(token: string): Promise<{ userId: string }>;
  abstract signRefreshToken(claims: RefreshClaims): Promise<IssuedRefreshToken>;
  /** Throws InvalidRefreshTokenError. */
  abstract verifyRefreshToken(token: string): Promise<RefreshClaims>;
}
