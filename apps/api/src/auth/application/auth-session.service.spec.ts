import {
  RefreshTokenRepository,
  type NewRefreshToken,
  type RefreshTokenRecord,
} from '../domain/refresh-token.repository.js';
import type { RefreshClaims, TokenService } from '../domain/token-service.js';
import { AuthSessionService } from './auth-session.service.js';

class InMemoryRefreshTokens extends RefreshTokenRepository {
  rows = new Map<string, RefreshTokenRecord>();
  async create(record: NewRefreshToken) {
    this.rows.set(record.id, { ...record, revokedAt: null });
  }
  async findByHash(hash: string) {
    return [...this.rows.values()].find((r) => r.tokenHash === hash) ?? null;
  }
  async rotate(oldId: string, next: NewRefreshToken) {
    const old = this.rows.get(oldId);
    if (!old || old.revokedAt) return false;
    old.revokedAt = new Date();
    await this.create(next);
    return true;
  }
  async revokeFamily(familyId: string) {
    for (const r of this.rows.values()) {
      if (r.familyId === familyId && !r.revokedAt) r.revokedAt = new Date();
    }
  }
}

/** Opaque, claim-carrying fake: "refresh|user|id|family". */
const fakeTokens = {
  signAccessToken: async (userId: string) => ({
    token: `access|${userId}`,
    expiresInSeconds: 900,
  }),
  verifyAccessToken: async (t: string) => ({ userId: t.split('|')[1]! }),
  signRefreshToken: async (c: RefreshClaims) => ({
    token: `refresh|${c.userId}|${c.tokenId}|${c.familyId}`,
    expiresAt: new Date(Date.now() + 60_000),
  }),
  verifyRefreshToken: async (t: string): Promise<RefreshClaims> => {
    const [kind, userId, tokenId, familyId] = t.split('|');
    if (kind !== 'refresh') throw new Error('bad');
    return { userId: userId!, tokenId: tokenId!, familyId: familyId! };
  },
} as unknown as TokenService;

describe('AuthSessionService', () => {
  let repo: InMemoryRefreshTokens;
  let service: AuthSessionService;

  beforeEach(() => {
    repo = new InMemoryRefreshTokens();
    service = new AuthSessionService(fakeTokens, repo);
  });

  it('stores only a hash of the refresh token', async () => {
    const tokens = await service.startSession('u1');
    const [row] = [...repo.rows.values()];
    expect(row!.tokenHash).not.toContain(tokens.refreshToken);
    expect(row!.tokenHash).toMatch(/^[0-9a-f]{64}$/);
    expect(tokens).toMatchObject({ tokenType: 'Bearer', expiresIn: 900 });
  });

  it('rotates: the old token is revoked and the new one works', async () => {
    const first = await service.startSession('u1');
    const second = await service.rotate(first.refreshToken);
    expect(second.refreshToken).not.toBe(first.refreshToken);
    await expect(service.rotate(second.refreshToken)).resolves.toBeDefined();
  });

  it('detects reuse of a rotated token and revokes the whole family', async () => {
    const first = await service.startSession('u1');
    const second = await service.rotate(first.refreshToken);
    await expect(service.rotate(first.refreshToken)).rejects.toMatchObject({
      code: 'INVALID_REFRESH_TOKEN',
    });
    await expect(service.rotate(second.refreshToken)).rejects.toMatchObject({
      code: 'INVALID_REFRESH_TOKEN',
    });
  });

  it('rejects unknown and expired tokens', async () => {
    await expect(service.rotate('refresh|u1|nope|fam')).rejects.toBeDefined();
    const tokens = await service.startSession('u1');
    [...repo.rows.values()][0]!.expiresAt = new Date(Date.now() - 1);
    await expect(service.rotate(tokens.refreshToken)).rejects.toBeDefined();
  });

  it('logout revokes the family and is idempotent', async () => {
    const tokens = await service.startSession('u1');
    await service.revoke(tokens.refreshToken);
    await service.revoke(tokens.refreshToken);
    await service.revoke('garbage');
    await expect(service.rotate(tokens.refreshToken)).rejects.toBeDefined();
  });
});
