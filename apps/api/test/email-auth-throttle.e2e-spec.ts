import request from 'supertest';
import { EmailSender } from '../src/auth/domain/email-sender.js';
import { createTestApp, resetDatabase, type TestApp } from './test-app.js';

// Hoisted: AppModule reads the environment when it is first imported.
vi.hoisted(() => {
  process.env.OTP_THROTTLE_LIMIT = '3';
  process.env.GOOGLE_CLIENT_IDS = '';
  process.env.APPLE_BUNDLE_ID = '';
});

describe('Email sign-in per-IP throttle and providers (e2e)', () => {
  let ctx: TestApp;
  beforeAll(async () => {
    ctx = await createTestApp([
      { token: EmailSender, useValue: { send: async () => undefined } },
    ]);
  });
  afterAll(async () => {
    await ctx.close();
  });
  beforeEach(() => resetDatabase(ctx.prisma));

  it('limits email start requests per IP', async () => {
    const http = () => request(ctx.app.getHttpServer());
    for (let i = 0; i < 3; i++) {
      await http()
        .post('/api/v1/auth/email/start')
        .send({ email: `u${i}@example.com` })
        .expect(202);
    }
    const res = await http()
      .post('/api/v1/auth/email/start')
      .send({ email: 'u9@example.com' })
      .expect(429);
    expect(res.body.code).toBe('TOO_MANY_REQUESTS');
  });

  it('providers: google/apple off when not configured', async () => {
    const res = await request(ctx.app.getHttpServer())
      .get('/api/v1/auth/providers')
      .expect(200);
    expect(res.body).toEqual({ email: true, google: false, apple: false });
  });
});
