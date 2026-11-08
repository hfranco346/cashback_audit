import { ConfigService } from '@nestjs/config';
import { SignJWT } from 'jose';
import { validateEnv } from '../../config/env.js';
import { JoseTokenService } from './jose-token.service.js';

const env = validateEnv({
  DATABASE_URL: 'postgresql://x',
  JWT_ACCESS_SECRET: 'a'.repeat(40),
  JWT_REFRESH_SECRET: 'r'.repeat(40),
  JWT_ACCESS_TTL: '15m',
  JWT_REFRESH_TTL: '30d',
});
const service = new JoseTokenService(new ConfigService(env) as never);

describe('JoseTokenService', () => {
  it('round-trips an access token', async () => {
    const { token, expiresInSeconds } = await service.signAccessToken('user-1');
    expect(expiresInSeconds).toBe(900);
    await expect(service.verifyAccessToken(token)).resolves.toEqual({
      userId: 'user-1',
    });
  });

  it('rejects a tampered access token', async () => {
    const { token } = await service.signAccessToken('user-1');
    await expect(service.verifyAccessToken(token + 'x')).rejects.toMatchObject({
      code: 'INVALID_ACCESS_TOKEN',
    });
  });

  it('does not accept a refresh token as an access token (and vice versa)', async () => {
    const refresh = await service.signRefreshToken({
      userId: 'u',
      tokenId: 't',
      familyId: 'f',
    });
    const access = await service.signAccessToken('u');
    await expect(
      service.verifyAccessToken(refresh.token),
    ).rejects.toBeDefined();
    await expect(
      service.verifyRefreshToken(access.token),
    ).rejects.toBeDefined();
  });

  it('round-trips refresh claims', async () => {
    const { token, expiresAt } = await service.signRefreshToken({
      userId: 'u',
      tokenId: 't',
      familyId: 'f',
    });
    expect(expiresAt.getTime()).toBeGreaterThan(Date.now() + 29 * 86400_000);
    await expect(service.verifyRefreshToken(token)).resolves.toEqual({
      userId: 'u',
      tokenId: 't',
      familyId: 'f',
    });
  });

  it('rejects expired tokens', async () => {
    const expired = await new SignJWT({ typ: 'access' })
      .setProtectedHeader({ alg: 'HS256' })
      .setSubject('u')
      .setIssuer('cashback-audit-api')
      .setExpirationTime(Math.floor(Date.now() / 1000) - 10)
      .sign(new TextEncoder().encode('a'.repeat(40)));
    await expect(service.verifyAccessToken(expired)).rejects.toBeDefined();
  });

  it('rejects tokens signed with the wrong secret', async () => {
    const forged = await new SignJWT({ typ: 'access' })
      .setProtectedHeader({ alg: 'HS256' })
      .setSubject('u')
      .setIssuer('cashback-audit-api')
      .setExpirationTime('5m')
      .sign(new TextEncoder().encode('z'.repeat(40)));
    await expect(service.verifyAccessToken(forged)).rejects.toBeDefined();
  });
});
