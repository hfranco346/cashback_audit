import { ConfigService } from '@nestjs/config';
import { SignJWT, createLocalJWKSet, exportJWK, generateKeyPair } from 'jose';
import { validateEnv } from '../../config/env.js';
import {
  APPLE_ISSUER,
  JoseAppleIdTokenVerifier,
} from './apple-id-token.verifier.js';

const AUDIENCE = 'com.example.app';

async function setup(audience = AUDIENCE) {
  const { publicKey, privateKey } = await generateKeyPair('RS256');
  const jwk = {
    ...(await exportJWK(publicKey)),
    kid: 'k1',
    alg: 'RS256',
    use: 'sig',
  };
  const config = new ConfigService(
    validateEnv({
      DATABASE_URL: 'x',
      JWT_ACCESS_SECRET: 'a'.repeat(32),
      JWT_REFRESH_SECRET: 'b'.repeat(32),
      APPLE_BUNDLE_ID: audience,
    }),
  );
  const verifier = new JoseAppleIdTokenVerifier(config as never).useKeys(
    createLocalJWKSet({ keys: [jwk] }),
  );
  const sign = (
    claims: Record<string, unknown>,
    opts: { iss?: string; aud?: string; exp?: string } = {},
  ) =>
    new SignJWT(claims)
      .setProtectedHeader({ alg: 'RS256', kid: 'k1' })
      .setIssuer(opts.iss ?? APPLE_ISSUER)
      .setAudience(opts.aud ?? AUDIENCE)
      .setExpirationTime(opts.exp ?? '5m')
      .sign(privateKey);
  return { verifier, sign };
}

describe('JoseAppleIdTokenVerifier', () => {
  it('accepts a valid token and uses the client supplied name', async () => {
    const { verifier, sign } = await setup();
    const token = await sign({
      sub: 'apple-1',
      email: 'a@privaterelay.appleid.com',
    });
    await expect(verifier.verify(token, ' Ana Perez ')).resolves.toEqual({
      provider: 'APPLE',
      subject: 'apple-1',
      email: 'a@privaterelay.appleid.com',
      name: 'Ana Perez',
    });
  });

  it('returns a null name when the client sends none', async () => {
    const { verifier, sign } = await setup();
    const result = await verifier.verify(await sign({ sub: 'apple-1' }));
    expect(result.name).toBeNull();
    expect(result.email).toBeNull();
  });

  it.each([
    ['wrong audience', { aud: 'other.app' }],
    ['wrong issuer', { iss: 'https://evil.example.com' }],
    ['expired', { exp: '-1m' }],
  ])('rejects a token with %s', async (_label, opts) => {
    const { verifier, sign } = await setup();
    await expect(
      verifier.verify(await sign({ sub: 'x' }, opts)),
    ).rejects.toMatchObject({
      code: 'INVALID_IDENTITY_TOKEN',
    });
  });

  it('rejects a token signed by an unknown key', async () => {
    const { verifier } = await setup();
    const other = await setup();
    await expect(
      verifier.verify(await other.sign({ sub: 'x' })),
    ).rejects.toBeDefined();
  });

  it('reports the provider as unavailable when the audience is not configured', async () => {
    const { verifier, sign } = await setup('');
    await expect(
      verifier.verify(await sign({ sub: 'x' })),
    ).rejects.toMatchObject({
      code: 'IDENTITY_PROVIDER_UNAVAILABLE',
    });
  });
});
