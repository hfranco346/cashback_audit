import request from 'supertest';
import {
  AppleIdTokenVerifier,
  GoogleIdTokenVerifier,
} from '../src/auth/domain/identity-token-verifier.js';
import { appleStub, googleStub } from './stubs.js';
import { createTestApp, resetDatabase, type TestApp } from './test-app.js';

describe('Auth (e2e)', () => {
  let ctx: TestApp;
  const http = () => request(ctx.app.getHttpServer());

  beforeAll(async () => {
    ctx = await createTestApp([
      { token: GoogleIdTokenVerifier, useValue: googleStub },
      { token: AppleIdTokenVerifier, useValue: appleStub },
    ]);
  });
  afterAll(() => ctx.close());
  beforeEach(() => resetDatabase(ctx.prisma));

  it('google sign-in -> /me -> refresh -> logout', async () => {
    const login = await http()
      .post('/api/v1/auth/google')
      .send({ idToken: 'google-ok:g-1' })
      .expect(200);
    expect(login.body).toMatchObject({
      tokenType: 'Bearer',
      expiresIn: 900,
      user: { email: 'ana@example.com', name: 'Ana Google' },
    });

    const me = await http()
      .get('/api/v1/me')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .expect(200);
    expect(me.body).toMatchObject({
      id: login.body.user.id,
      provider: 'GOOGLE',
    });

    const refreshed = await http()
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: login.body.refreshToken })
      .expect(200);
    expect(refreshed.body.refreshToken).not.toBe(login.body.refreshToken);

    await http()
      .post('/api/v1/auth/logout')
      .send({ refreshToken: refreshed.body.refreshToken })
      .expect(204);
    await http()
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: refreshed.body.refreshToken })
      .expect(401);
  });

  it('upserts by (provider, subject): second login reuses the user', async () => {
    const a = await http()
      .post('/api/v1/auth/google')
      .send({ idToken: 'google-ok:g-2' });
    const b = await http()
      .post('/api/v1/auth/google')
      .send({ idToken: 'google-ok:g-2' });
    expect(a.body.user.id).toBe(b.body.user.id);
    expect(await ctx.prisma.user.count()).toBe(1);
  });

  it('stores the Apple name on first sign-in and never erases it afterwards', async () => {
    const first = await http()
      .post('/api/v1/auth/apple')
      .send({ identityToken: 'apple-ok:ap-1', fullName: 'Beto Gomez' })
      .expect(200);
    expect(first.body.user.name).toBe('Beto Gomez');
    const second = await http()
      .post('/api/v1/auth/apple')
      .send({ identityToken: 'apple-ok:ap-1' })
      .expect(200);
    expect(second.body.user).toMatchObject({
      id: first.body.user.id,
      name: 'Beto Gomez',
    });
  });

  it('rejects invalid identity tokens with a stable error body', async () => {
    const res = await http()
      .post('/api/v1/auth/google')
      .send({ idToken: 'forged' })
      .expect(401);
    expect(res.body).toMatchObject({
      statusCode: 401,
      code: 'INVALID_IDENTITY_TOKEN',
    });
  });

  it('revokes the whole family when a rotated refresh token is replayed', async () => {
    const login = await http()
      .post('/api/v1/auth/google')
      .send({ idToken: 'google-ok:g-3' });
    const rotated = await http()
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: login.body.refreshToken })
      .expect(200);
    await http()
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: login.body.refreshToken })
      .expect(401);
    await http()
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: rotated.body.refreshToken })
      .expect(401);
  });

  it('protects routes by default', async () => {
    await http().get('/api/v1/me').expect(401);
    await http()
      .get('/api/v1/me')
      .set('Authorization', 'Bearer nope')
      .expect(401);
  });

  it('keeps health public', async () => {
    await http().get('/api/v1/health').expect(200);
  });

  it('validates bodies (whitelist + forbidNonWhitelisted)', async () => {
    const res = await http()
      .post('/api/v1/auth/google')
      .send({ idToken: 'x', extra: 1 })
      .expect(400);
    expect(res.body.code).toBe('VALIDATION_ERROR');
    await http().post('/api/v1/auth/google').send({}).expect(400);
  });

  it('stores refresh tokens hashed', async () => {
    const login = await http()
      .post('/api/v1/auth/google')
      .send({ idToken: 'google-ok:g-4' });
    const rows = await ctx.prisma.refreshToken.findMany();
    expect(rows).toHaveLength(1);
    expect(rows[0]!.tokenHash).not.toBe(login.body.refreshToken);
  });
});
