export interface RefreshTokenRecord {
  id: string;
  userId: string;
  familyId: string;
  tokenHash: string;
  expiresAt: Date;
  revokedAt: Date | null;
}

export type NewRefreshToken = Omit<RefreshTokenRecord, 'revokedAt'>;

export abstract class RefreshTokenRepository {
  abstract create(record: NewRefreshToken): Promise<void>;
  abstract findByHash(tokenHash: string): Promise<RefreshTokenRecord | null>;
  /**
   * Atomically revokes `oldId` (only if still active) and stores `next`.
   * Returns false when `oldId` was already revoked (concurrent reuse).
   */
  abstract rotate(oldId: string, next: NewRefreshToken): Promise<boolean>;
  abstract revokeFamily(familyId: string): Promise<void>;
}
