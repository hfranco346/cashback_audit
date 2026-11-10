import request from 'supertest';
import {
  EmailSender,
  type OutgoingEmail,
} from '../src/auth/domain/email-sender.js';
import { createTestApp, resetDatabase, type TestApp } from './test-app.js';

// Hoisted: AppModule reads the environment when it is first imported.
vi.hoisted(() => {
  process.env.REVIEW_LOGIN_EMAIL = 'review@example.com';
  process.env.REVIEW_LOGIN_CODE = '424242';
});

describe('Email sign-in (e2e)', () => {
  let ctx: TestApp;
  const sent: OutgoingEmail[] = [];
  const fakeSender = { send: async (m: OutgoingEmail) => void sent.push(m) };
  const http = () => request(ctx.app.getHttpServer());
  const lastCode = () => sent.at(-1)!.code!;
  const wrong = () => (lastCode() === '000000' ? '000001' : '000000');
  const start = (email = 'ana@example.com', extra: object = {}) =>
    http()
      .post('/api/v1/auth/email/start')
      .send({ email, ...extra });
  const verify = (email: string, code: string) =>
    http().post('/api/v1/auth/email/verify').send({ email, code });
  /** Moves every stored code back in time to skip the waits. */
  const ageCodes = (seconds: number) =>
    ctx.prisma.$executeRawUnsafe(
      `UPDATE "EmailLoginCode" SET "createdAt" = "createdAt" - interval '${seconds} seconds', "expiresAt" = "expiresAt" - interval '${seconds} seconds'`,
    );

  beforeAll(async () => {
    ctx = await createTestApp([{ token: EmailSender, useValue: fakeSender }]);
  });
  afterAll(async () => {
    delete process.env.REVIEW_LOGIN_EMAIL;
    delete process.env.REVIEW_LOGIN_CODE;
    await ctx.close();
  });
  beforeEach(async () => {
    sent.length = 0;
    await resetDatabase(ctx.prisma);
  });

  it('start -> 202, mail with the code; verify -> tokens + EMAIL user', async () => {
    const res = await start('  Ana@Example.com ').expect(202);
    expect(res.body).toEqual({ expiresInSeconds: 600, resendAfterSeconds: 60 });
    expect(sent).toHaveLength(1);
    expect(sent[0]).toMatchObject({ to: 'ana@example.com' });
    expect(sent[0]!.subject).toBe(`Tu código de Cashback Audit: ${lastCode()}`);

    const login = await verify('ANA@example.com', lastCode()).expect(200);
    expect(login.body).toMatchObject({
      tokenType: 'Bearer',
      expiresIn: 900,
      user: { email: 'ana@example.com', name: null },
    });
    const me = await http()
      .get('/api/v1/me')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .expect(200);
    expect(me.body).toMatchObject({
      provider: 'EMAIL',
      email: 'ana@example.com',
    });
    await http()
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: login.body.refreshToken })
      .expect(200);
  });

  it('sends English when asked and rejects unknown locales', async () => {
    await start('ana@example.com', { locale: 'en' }).expect(202);
    expect(sent[0]!.subject).toBe(`Your Cashback Audit code: ${lastCode()}`);
    await start('b@example.com', { locale: 'fr' }).expect(400);
  });

  it('the same email signs in again as the same user', async () => {
    await start().expect(202);
    const a = await verify('ana@example.com', lastCode()).expect(200);
    await ageCodes(120);
    await start().expect(202);
    const b = await verify('ana@example.com', lastCode()).expect(200);
    expect(b.body.user.id).toBe(a.body.user.id);
    expect(await ctx.prisma.user.count()).toBe(1);
    expect(await ctx.prisma.user.findFirst()).toMatchObject({
      provider: 'EMAIL',
      providerSubject: 'ana@example.com',
    });
  });

  it('stores only a hash and the requester ip', async () => {
    await start().expect(202);
    const row = await ctx.prisma.emailLoginCode.findFirstOrThrow();
    expect(row.codeHash).not.toContain(lastCode());
    expect(row.codeHash).toMatch(/^[0-9a-f]{64}$/);
    expect(row.ip).toBeTruthy();
  });

  it('wrong code -> 400 INVALID_CODE with attemptsLeft', async () => {
    await start().expect(202);
    const res = await verify('ana@example.com', wrong()).expect(400);
    expect(res.body).toMatchObject({
      statusCode: 400,
      code: 'INVALID_CODE',
      details: { attemptsLeft: 4 },
    });
  });

  it('5 failures -> 429 TOO_MANY_ATTEMPTS and the code is burned', async () => {
    await start().expect(202);
    const good = lastCode();
    for (let left = 4; left >= 1; left--) {
      const r = await verify('ana@example.com', wrong()).expect(400);
      expect(r.body.details.attemptsLeft).toBe(left);
    }
    const burned = await verify('ana@example.com', wrong()).expect(429);
    expect(burned.body).toMatchObject({ code: 'TOO_MANY_ATTEMPTS' });
    const after = await verify('ana@example.com', good).expect(410);
    expect(after.body.code).toBe('CODE_EXPIRED');
  });

  it('expired code -> 410 CODE_EXPIRED; no code at all -> 410 too', async () => {
    await start().expect(202);
    await ageCodes(601);
    const res = await verify('ana@example.com', lastCode()).expect(410);
    expect(res.body).toMatchObject({ statusCode: 410, code: 'CODE_EXPIRED' });
    await verify('nobody@example.com', '123456').expect(410);
  });

  it('code is single use', async () => {
    await start().expect(202);
    const code = lastCode();
    await verify('ana@example.com', code).expect(200);
    await verify('ana@example.com', code).expect(410);
  });

  it('parallel guesses cannot exceed the attempt limit', async () => {
    await start().expect(202);
    const bad = wrong();
    const results = await Promise.all(
      Array.from({ length: 12 }, () => verify('ana@example.com', bad)),
    );
    const invalid = results.filter((r) => r.status === 400).length;
    expect(invalid).toBeLessThanOrEqual(4);
    expect(
      (await ctx.prisma.emailLoginCode.findFirstOrThrow()).attempts,
    ).toBeLessThanOrEqual(5);
  });

  it('resend before 60 s -> 429 with retryAfterSeconds and Retry-After', async () => {
    await start().expect(202);
    const res = await start().expect(429);
    expect(res.body).toMatchObject({
      statusCode: 429,
      code: 'TOO_MANY_REQUESTS',
      details: { retryAfterSeconds: expect.any(Number) },
    });
    expect(res.body.details.retryAfterSeconds).toBeLessThanOrEqual(60);
    expect(Number(res.headers['retry-after'])).toBe(
      res.body.details.retryAfterSeconds,
    );
    expect(sent).toHaveLength(1);
  });

  it('a resend replaces the previous code', async () => {
    await start().expect(202);
    const first = lastCode();
    await ageCodes(61);
    await start().expect(202);
    const second = lastCode();
    expect(sent).toHaveLength(2);
    if (first !== second) {
      await verify('ana@example.com', first).expect(400);
    }
    await verify('ana@example.com', second).expect(200);
  });

  it('caps sends at 5 per email per hour', async () => {
    for (let i = 0; i < 5; i++) {
      await start().expect(202);
      await ageCodes(61);
    }
    const res = await start().expect(429);
    expect(res.body.details.retryAfterSeconds).toBeGreaterThan(60);
    expect(sent).toHaveLength(5);
    // another address is unaffected
    await start('other@example.com').expect(202);
  });

  it('validates input', async () => {
    await start('not-an-email').expect(400);
    await verify('ana@example.com', '12345').expect(400);
    await verify('ana@example.com', 'abcdef').expect(400);
    await http()
      .post('/api/v1/auth/email/start')
      .send({ email: 'a@b.co', extra: 1 })
      .expect(400);
  });

  it('review account: no email, fixed code', async () => {
    await start('Review@Example.com').expect(202);
    expect(sent).toHaveLength(0);
    expect(await ctx.prisma.emailLoginCode.count()).toBe(0);
    const login = await verify('review@example.com', '424242').expect(200);
    expect(login.body.user.email).toBe('review@example.com');
    await verify('review@example.com', '111111').expect(400);
    await verify('other@example.com', '424242').expect(410);
  });

  it('GET /auth/providers reflects the configured client ids', async () => {
    const res = await http().get('/api/v1/auth/providers').expect(200);
    expect(res.body).toEqual({ email: true, google: true, apple: true });
  });
});
