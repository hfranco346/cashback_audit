import request from 'supertest';
import { Decimal } from 'decimal.js';
import {
  MerchantClassifier,
  StatementExtractor,
} from '../src/verifications/domain/statement-extractor.js';
import {
  createTestApp,
  resetDatabase,
  signInAs,
  type TestApp,
  type TestUser,
} from './test-app.js';

// ConfigModule.forRoot reads the environment when AppModule is first imported,
// so the flag must be set before the imports below are evaluated.
vi.hoisted(() => {
  process.env.SUBSCRIPTION_GATE_ENABLED = 'true';
});

const AUTH = 'test-webhook-secret';
const PDF = Buffer.from('%PDF-1.7\n');
const DAY = 86_400_000;

describe('Subscriptions (e2e, gate enabled)', () => {
  let ctx: TestApp;
  let alice: TestUser;
  let cardId: string;
  let eventCounter = 0;
  const http = () => request(ctx.app.getHttpServer());

  beforeAll(async () => {
    ctx = await createTestApp([
      {
        token: StatementExtractor,
        useValue: {
          extract: async () => ({
            statement: {
              bank: 'BBVA',
              cardLast4: '4321',
              periodStart: null,
              periodEnd: null,
              currency: 'MXN',
              totalSpent: null,
              totalToPay: null,
              reportedReward: {
                amount: new Decimal(1),
                unit: 'CURRENCY',
                label: 'x',
              },
              transactions: [],
            },
            model: 'stub',
          }),
        },
      },
      { token: MerchantClassifier, useValue: { classify: async () => [] } },
    ]);
  });
  afterAll(async () => {
    await ctx.close();
  });
  beforeEach(async () => {
    await resetDatabase(ctx.prisma);
    alice = await signInAs(ctx.app, 'alice');
    cardId = (
      await http().post('/api/v1/cards').set(alice.auth).send({
        alias: 'c',
        bank: 'b',
        last4: '4321',
        rewardUnit: 'CASHBACK_CURRENCY',
        baseRatePercent: 1,
        currency: 'MXN',
      })
    ).body.id;
  });

  const rcEvent = (type: string, over: Record<string, unknown> = {}) => ({
    api_version: '1.0',
    event: {
      id: `evt-${++eventCounter}`,
      type,
      app_user_id: alice.id,
      original_app_user_id: alice.id,
      aliases: [alice.id],
      entitlement_ids: ['pro'],
      product_id: 'pro_monthly',
      store: 'APP_STORE',
      expiration_at_ms: Date.now() + 30 * DAY,
      event_timestamp_ms: Date.now(),
      environment: 'SANDBOX',
      ...over,
    },
  });
  const send = (body: unknown, auth: string | null = AUTH) => {
    let req = http().post('/api/v1/webhooks/revenuecat');
    if (auth !== null) req = req.set('Authorization', auth);
    return req.send(body as object);
  };
  const verify = () =>
    http()
      .post('/api/v1/verifications')
      .set(alice.auth)
      .field('cardId', cardId)
      .attach('file', PDF, {
        filename: 's.pdf',
        contentType: 'application/pdf',
      });
  const mySubscription = async () =>
    (await http().get('/api/v1/subscriptions/me').set(alice.auth).expect(200))
      .body;

  describe('webhook authentication', () => {
    it('rejects a missing Authorization header', async () => {
      const res = await send(rcEvent('INITIAL_PURCHASE'), null).expect(401);
      expect(res.body.code).toBe('INVALID_WEBHOOK_AUTH');
    });

    it('rejects a wrong secret (also a same-length one and a prefix)', async () => {
      await send(rcEvent('INITIAL_PURCHASE'), 'wrong').expect(401);
      await send(rcEvent('INITIAL_PURCHASE'), 'test-webhook-secreT').expect(
        401,
      );
      await send(rcEvent('INITIAL_PURCHASE'), 'test-webhook').expect(401);
      expect((await mySubscription()).status).toBe('NONE');
    });

    it('accepts the configured secret without a user token (public route)', async () => {
      await send(rcEvent('INITIAL_PURCHASE')).expect(200);
    });

    it('rejects malformed payloads with 400', async () => {
      await send({ nope: true }).expect(400);
    });
  });

  describe('gate on POST /verifications', () => {
    it('returns 402 SUBSCRIPTION_REQUIRED without a subscription', async () => {
      const res = await verify().expect(402);
      expect(res.body).toMatchObject({
        statusCode: 402,
        code: 'SUBSCRIPTION_REQUIRED',
        details: { entitlementId: 'pro' },
      });
    });

    it('allows verification after INITIAL_PURCHASE', async () => {
      await send(rcEvent('INITIAL_PURCHASE'))
        .expect(200)
        .expect({ status: 'applied' });
      await verify().expect(201);
      expect(await mySubscription()).toMatchObject({
        entitlementId: 'pro',
        active: true,
        status: 'ACTIVE',
        willRenew: true,
        store: 'APP_STORE',
        productId: 'pro_monthly',
      });
    });

    it('keeps access after CANCELLATION until expiration, then blocks on EXPIRATION', async () => {
      const expiration = Date.now() + 10 * DAY;
      await send(
        rcEvent('INITIAL_PURCHASE', { expiration_at_ms: expiration }),
      ).expect(200);
      await send(
        rcEvent('CANCELLATION', { expiration_at_ms: expiration }),
      ).expect(200);
      expect(await mySubscription()).toMatchObject({
        active: true,
        status: 'CANCELLED',
        willRenew: false,
      });
      await verify().expect(201);

      await send(
        rcEvent('EXPIRATION', { expiration_at_ms: Date.now() }),
      ).expect(200);
      expect(await mySubscription()).toMatchObject({
        active: false,
        status: 'EXPIRED',
      });
      await verify().expect(402);
    });

    it('UNCANCELLATION and RENEWAL restore / extend access', async () => {
      await send(rcEvent('INITIAL_PURCHASE')).expect(200);
      await send(rcEvent('CANCELLATION')).expect(200);
      await send(rcEvent('UNCANCELLATION')).expect(200);
      expect(await mySubscription()).toMatchObject({
        status: 'ACTIVE',
        willRenew: true,
      });
      const later = Date.now() + 60 * DAY;
      await send(rcEvent('RENEWAL', { expiration_at_ms: later })).expect(200);
      expect(new Date((await mySubscription()).expiresAt).getTime()).toBe(
        later,
      );
    });

    it('treats a subscription past its expiration date as inactive even without an EXPIRATION event', async () => {
      await send(
        rcEvent('INITIAL_PURCHASE', { expiration_at_ms: Date.now() - 1000 }),
      ).expect(200);
      expect((await mySubscription()).active).toBe(false);
      await verify().expect(402);
    });

    it('keeps access during a BILLING_ISSUE grace period', async () => {
      await send(rcEvent('INITIAL_PURCHASE')).expect(200);
      await send(rcEvent('BILLING_ISSUE')).expect(200);
      expect(await mySubscription()).toMatchObject({
        active: true,
        status: 'BILLING_ISSUE',
      });
      await verify().expect(201);
    });

    it('PRODUCT_CHANGE updates the product', async () => {
      await send(rcEvent('INITIAL_PURCHASE')).expect(200);
      await send(
        rcEvent('PRODUCT_CHANGE', { product_id: 'pro_yearly' }),
      ).expect(200);
      expect((await mySubscription()).productId).toBe('pro_yearly');
    });
  });

  describe('event handling rules', () => {
    it('is idempotent by event id', async () => {
      const body = rcEvent('INITIAL_PURCHASE');
      await send(body).expect(200).expect({ status: 'applied' });
      await send(body).expect(200).expect({ status: 'duplicate' });
      expect(await ctx.prisma.revenueCatEvent.count()).toBe(1);
      expect(await ctx.prisma.subscription.count()).toBe(1);
    });

    it('ignores events older than the last applied one', async () => {
      const now = Date.now();
      await send(
        rcEvent('EXPIRATION', {
          event_timestamp_ms: now,
          expiration_at_ms: now,
        }),
      ).expect(200);
      await send(
        rcEvent('INITIAL_PURCHASE', { event_timestamp_ms: now - 5 * DAY }),
      )
        .expect(200)
        .expect({ status: 'stale' });
      expect((await mySubscription()).status).toBe('EXPIRED');
    });

    it('ignores other entitlements, unhandled types and unknown users (still 200)', async () => {
      await send(rcEvent('INITIAL_PURCHASE', { entitlement_ids: ['other'] }))
        .expect(200)
        .expect({ status: 'ignored' });
      await send(rcEvent('TEST')).expect(200).expect({ status: 'ignored' });
      await send(
        rcEvent('INITIAL_PURCHASE', {
          app_user_id: '$RCAnonymousID:abc',
          original_app_user_id: '$RCAnonymousID:abc',
          aliases: ['$RCAnonymousID:abc'],
        }),
      )
        .expect(200)
        .expect({ status: 'ignored' });
      await send(
        rcEvent('INITIAL_PURCHASE', {
          app_user_id: '11111111-1111-4111-8111-111111111111',
          aliases: [],
          original_app_user_id: null,
        }),
      )
        .expect(200)
        .expect({ status: 'ignored' });
      expect(await ctx.prisma.subscription.count()).toBe(0);
    });

    it('resolves our user id from aliases when app_user_id is anonymous', async () => {
      await send(
        rcEvent('INITIAL_PURCHASE', {
          app_user_id: '$RCAnonymousID:abc',
          aliases: ['$RCAnonymousID:abc', alice.id],
        }),
      )
        .expect(200)
        .expect({ status: 'applied' });
      expect((await mySubscription()).active).toBe(true);
    });

    it('does not leak subscriptions between users', async () => {
      await send(rcEvent('INITIAL_PURCHASE')).expect(200);
      const bob = await signInAs(ctx.app, 'bob');
      const res = await http()
        .get('/api/v1/subscriptions/me')
        .set(bob.auth)
        .expect(200);
      expect(res.body).toMatchObject({
        active: false,
        status: 'NONE',
        expiresAt: null,
      });
    });
  });

  it('requires authentication for GET /subscriptions/me', async () => {
    await http().get('/api/v1/subscriptions/me').expect(401);
  });
});
