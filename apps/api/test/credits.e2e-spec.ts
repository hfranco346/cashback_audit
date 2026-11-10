import request from 'supertest';
import { CreditsService } from '../src/credits/application/credits.service.js';
import {
  LineClassifier,
  ResultExplainer,
  StatementExtractor,
} from '../src/verifications/domain/statement-extractor.js';
import {
  ExtractionUnavailableError,
  UnreadableStatementError,
} from '../src/verifications/domain/verification-errors.js';
import { VerificationProcessingService } from '../src/verifications/application/verification-processing.service.js';
import { mxnCashbackStatement } from './fixtures/statements.js';
import {
  createTestApp,
  resetDatabase,
  signInAs,
  type TestApp,
  type TestUser,
} from './test-app.js';

// ConfigModule.forRoot reads the environment when AppModule is first imported,
// so the flags must be set before the imports below are evaluated.
vi.hoisted(() => {
  process.env.CREDITS_GATE_ENABLED = 'true';
  process.env.CREDIT_PACKS = 'credits_3:3,credits_10:10';
  process.env.PLAN_CREDITS_PER_PERIOD = '5';
  process.env.FREE_CREDITS = '1';
});

const AUTH = 'test-webhook-secret';
const PDF = Buffer.from('%PDF-1.7\n');
const DAY = 86_400_000;

describe('Credits (e2e)', () => {
  let ctx: TestApp;
  let alice: TestUser;
  let cardId: string;
  let counter = 0;
  let extractorError: Error | null = null;
  let extractCalls = 0;
  let extractorGate: Promise<void> | null = null;
  const http = () => request(ctx.app.getHttpServer());

  beforeAll(async () => {
    ctx = await createTestApp([
      {
        token: StatementExtractor,
        useValue: {
          extract: async () => {
            extractCalls++;
            if (extractorGate) await extractorGate;
            if (extractorError) throw extractorError;
            return { statement: mxnCashbackStatement(), model: 'stub' };
          },
        },
      },
      {
        token: LineClassifier,
        useValue: {
          classify: async () => ({
            results: [],
            unclassified: [],
            model: null,
          }),
        },
      },
      {
        token: ResultExplainer,
        useValue: { explain: async () => ({ text: 'ok', model: 'stub' }) },
      },
    ]);
  });
  afterEach(async () => {
    await ctx.app.get(VerificationProcessingService).idle();
  });
  afterAll(() => ctx.close());

  beforeEach(async () => {
    extractorError = null;
    extractorGate = null;
    extractCalls = 0;
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

  const verify = (user: TestUser = alice) =>
    http()
      .post('/api/v1/verifications')
      .set(user.auth)
      .field('cardId', cardId)
      .attach('file', PDF, {
        filename: 's.pdf',
        contentType: 'application/pdf',
      });
  /** Waits for the background processor to finish every accepted upload. */
  const settle = () => ctx.app.get(VerificationProcessingService).idle();
  const credits = async (user: TestUser = alice) =>
    (await http().get('/api/v1/credits/me').set(user.auth).expect(200)).body;
  const rc = (type: string, over: Record<string, unknown> = {}) => ({
    api_version: '1.0',
    event: {
      id: `evt-${++counter}`,
      type,
      app_user_id: alice.id,
      original_app_user_id: alice.id,
      aliases: [alice.id],
      entitlement_ids: ['pro'],
      product_id: 'pro_monthly',
      store: 'APP_STORE',
      transaction_id: `tx-${counter}`,
      expiration_at_ms: Date.now() + 30 * DAY,
      event_timestamp_ms: Date.now(),
      ...over,
    },
  });
  const send = (body: unknown) =>
    http()
      .post('/api/v1/webhooks/revenuecat')
      .set('Authorization', AUTH)
      .send(body as object);
  const pack = (productId = 'credits_3', over: Record<string, unknown> = {}) =>
    rc('NON_RENEWING_PURCHASE', {
      product_id: productId,
      entitlement_ids: null,
      expiration_at_ms: null,
      ...over,
    });
  const history = async () =>
    (
      await http()
        .get('/api/v1/credits/me/history?pageSize=100')
        .set(alice.auth)
        .expect(200)
    ).body;

  it('requires authentication', async () => {
    await http().get('/api/v1/credits/me').expect(401);
    await http().get('/api/v1/credits/me/history').expect(401);
  });

  describe('free credit', () => {
    it('every new user starts with exactly one lifetime free credit', async () => {
      expect(await credits()).toEqual({
        free: 1,
        plan: 0,
        planPeriodEnd: null,
        purchased: 0,
        total: 1,
        subscriptionActive: false,
        unlimited: false,
      });
      // Signing in again never grants another one.
      await signInAs(ctx.app, 'alice');
      await signInAs(ctx.app, 'alice');
      expect((await credits()).free).toBe(1);
      expect(
        await ctx.prisma.creditLedger.count({
          where: { userId: alice.id, reason: 'GRANT_FREE' },
        }),
      ).toBe(1);
    });

    it('uses the free credit, then answers 402 NO_CREDITS with the balance', async () => {
      const first = await verify().expect(202);
      expect(first.body.status).toBe('PROCESSING');
      // the credit is spent on acceptance, before the evaluation finishes
      expect((await credits()).total).toBe(0);

      const res = await verify().expect(402);
      expect(res.body).toMatchObject({
        statusCode: 402,
        code: 'NO_CREDITS',
        details: {
          free: 0,
          plan: 0,
          planPeriodEnd: null,
          purchased: 0,
          total: 0,
          subscriptionActive: false,
        },
      });
      await settle();
      expect(extractCalls).toBe(1);
    });

    it('does not re-grant it after it was spent (even from the balance endpoint)', async () => {
      await verify().expect(202);
      await credits();
      await credits();
      expect((await credits()).free).toBe(0);
    });
  });

  describe('credit packs', () => {
    it('grants PURCHASED credits that never expire, idempotently per transaction', async () => {
      const body = pack('credits_3', { transaction_id: 'tx-A' });
      await send(body)
        .expect(200)
        .expect((r) => expect(r.body.credits).toBe('granted'));
      expect((await credits()).purchased).toBe(3);
      // same transaction under a new event id (redelivery) and the same event
      await send(pack('credits_3', { transaction_id: 'tx-A' }))
        .expect(200)
        .expect((r) => expect(r.body.credits).toBe('duplicate'));
      await send(body)
        .expect(200)
        .expect((r) => expect(r.body.credits).toBe('duplicate'));
      expect((await credits()).purchased).toBe(3);
      // a different transaction grants again; other packs use their own size
      await send(pack('credits_10', { transaction_id: 'tx-B' })).expect(200);
      expect((await credits()).purchased).toBe(13);
    });

    it('ignores unknown products and unknown users', async () => {
      await send(pack('credits_999'))
        .expect(200)
        .expect((r) => expect(r.body.credits).toBe('ignored'));
      await send(
        pack('credits_3', {
          app_user_id: '$RCAnonymousID:x',
          original_app_user_id: '$RCAnonymousID:x',
          aliases: ['$RCAnonymousID:x'],
        }),
      )
        .expect(200)
        .expect((r) => expect(r.body.credits).toBe('ignored'));
      expect((await credits()).purchased).toBe(0);
    });

    it('maps the store to the ledger source (web payments need no extra code)', async () => {
      await send(pack('credits_3', { store: 'STRIPE' })).expect(200);
      await send(pack('credits_3', { store: 'PLAY_STORE' })).expect(200);
      await send(pack('credits_3', { store: 'APP_STORE' })).expect(200);
      await send(pack('credits_3', { store: 'PADDLE' })).expect(200);
      await send(pack('credits_3', { store: 'RC_BILLING' })).expect(200);
      await send(pack('credits_3', { store: 'PROMOTIONAL' })).expect(200);
      const sources = (await history()).items
        .filter((i: any) => i.reason === 'GRANT_PACK')
        .map((i: any) => i.source)
        .reverse();
      expect(sources).toEqual([
        'WEB',
        'GOOGLE',
        'APPLE',
        'WEB',
        'WEB',
        'SYSTEM',
      ]);
    });

    it('a refund debits the pack but never below zero', async () => {
      await send(pack('credits_3', { transaction_id: 'tx-R' })).expect(200);
      // spend the free credit first, then 2 of the 3 purchased credits
      await verify().expect(202);
      await verify().expect(202);
      await verify().expect(202);
      expect((await credits()).purchased).toBe(1);
      const refund = rc('CANCELLATION', {
        product_id: 'credits_3',
        entitlement_ids: null,
        transaction_id: 'tx-R',
        cancel_reason: 'CUSTOMER_SUPPORT',
      });
      await send(refund)
        .expect(200)
        .expect((r) => expect(r.body.credits).toBe('debited'));
      expect((await credits()).purchased).toBe(0);
      // redelivery does nothing; the next debit never goes negative
      await send(refund)
        .expect(200)
        .expect((r) => expect(r.body.credits).toBe('duplicate'));
      await send(
        rc('CANCELLATION', {
          product_id: 'credits_3',
          entitlement_ids: null,
          transaction_id: 'tx-other',
          cancel_reason: 'CUSTOMER_SUPPORT',
        }),
      ).expect(200);
      expect((await credits()).total).toBe(0);
      // an ordinary (non refund) cancellation of a pack changes nothing
      await send(pack('credits_3', { transaction_id: 'tx-N' })).expect(200);
      await send(
        rc('CANCELLATION', {
          product_id: 'credits_3',
          entitlement_ids: null,
          transaction_id: 'tx-N',
          cancel_reason: 'UNSUBSCRIBE',
        }),
      ).expect(200);
      expect((await credits()).purchased).toBe(3);
    });
  });

  describe('subscription plan credits', () => {
    it('grants 5 credits for the period and reports subscriptionActive', async () => {
      const end = Date.now() + 30 * DAY;
      await send(rc('INITIAL_PURCHASE', { expiration_at_ms: end }))
        .expect(200)
        .expect((r) =>
          expect(r.body).toEqual({ status: 'applied', credits: 'granted' }),
        );
      const b = await credits();
      expect(b).toMatchObject({
        free: 1,
        plan: 5,
        purchased: 0,
        total: 6,
        subscriptionActive: true,
      });
      expect(new Date(b.planPeriodEnd).getTime()).toBe(end);
    });

    it('spends FREE, then PLAN, then PURCHASED', async () => {
      await send(rc('INITIAL_PURCHASE')).expect(200);
      await send(pack('credits_3')).expect(200);
      for (let i = 0; i < 9; i++) await verify().expect(202);
      const consumed = (await history()).items
        .filter((i: any) => i.reason === 'CONSUME')
        .map((i: any) => i.bucket)
        .reverse();
      expect(consumed).toEqual([
        'FREE',
        ...Array(5).fill('PLAN'),
        ...Array(3).fill('PURCHASED'),
      ]);
      expect((await credits()).total).toBe(0);
      await verify().expect(402);
    });

    it('a renewal expires what is left (no roll over) and grants 5 more', async () => {
      const first = Date.now() + 30 * DAY;
      await send(rc('INITIAL_PURCHASE', { expiration_at_ms: first })).expect(
        200,
      );
      await verify().expect(202); // free
      await verify().expect(202); // plan -> 4 left
      expect((await credits()).plan).toBe(4);

      const second = first + 30 * DAY;
      await send(rc('RENEWAL', { expiration_at_ms: second }))
        .expect(200)
        .expect((r) => expect(r.body.credits).toBe('granted'));
      const b = await credits();
      expect(b.plan).toBe(5); // not 9
      expect(new Date(b.planPeriodEnd).getTime()).toBe(second);
      const reasons = (await history()).items.map((i: any) => i.reason);
      expect(reasons).toContain('EXPIRE_PLAN');
    });

    it('does not grant twice for the same period, nor for duplicate events', async () => {
      const end = Date.now() + 30 * DAY;
      const evt = rc('INITIAL_PURCHASE', { expiration_at_ms: end });
      await send(evt).expect(200);
      await send(evt).expect(200);
      await send(rc('RENEWAL', { expiration_at_ms: end })).expect(200); // other event id, same period
      expect((await credits()).plan).toBe(5);
    });

    it('plan credits stop counting when their period is over', async () => {
      await send(
        rc('INITIAL_PURCHASE', { expiration_at_ms: Date.now() + 30 * DAY }),
      ).expect(200);
      await ctx.prisma.creditLedger.updateMany({
        where: { userId: alice.id, bucket: 'PLAN' },
        data: { periodEnd: new Date(Date.now() - 1000) },
      });
      expect(await credits()).toMatchObject({ plan: 0, planPeriodEnd: null });
    });

    it('ignores plan events without a future expiration', async () => {
      await send(
        rc('INITIAL_PURCHASE', { expiration_at_ms: Date.now() - 1000 }),
      )
        .expect(200)
        .expect((r) => expect(r.body.credits).toBe('ignored'));
      expect((await credits()).plan).toBe(0);
    });
  });

  describe('consumption', () => {
    it('is concurrency safe: two parallel uploads with one credit -> one 402', async () => {
      const [a, b] = await Promise.all([verify(), verify()]);
      expect([a.status, b.status].sort((x, y) => x - y)).toEqual([202, 402]);
      expect((await credits()).total).toBe(0);
      expect(
        await ctx.prisma.creditLedger.count({
          where: { userId: alice.id, reason: 'CONSUME' },
        }),
      ).toBe(1);
      await settle();
      expect(extractCalls).toBe(1);
    });

    it('many parallel uploads never spend more than the balance', async () => {
      await send(pack('credits_3')).expect(200); // 1 free + 3 purchased
      const results = await Promise.all(
        Array.from({ length: 8 }, () => verify()),
      );
      const statuses = results.map((r) => r.status);
      expect(statuses.filter((s) => s === 202)).toHaveLength(4);
      expect(statuses.filter((s) => s === 402)).toHaveLength(4);
      expect((await credits()).total).toBe(0);
    });

    it('refunds the credit to the same bucket when the evaluation fails', async () => {
      await send(pack('credits_3')).expect(200);
      await verify().expect(202); // free spent
      extractorError = new ExtractionUnavailableError();
      const a = (await verify().expect(202)).body;
      const b = (await verify().expect(202)).body;
      await settle();
      expect(await credits()).toMatchObject({ free: 0, purchased: 3 });
      for (const id of [a.id, b.id]) {
        const got = await http()
          .get(`/api/v1/verifications/${id}`)
          .set(alice.auth)
          .expect(200);
        expect(got.body).toMatchObject({
          status: 'FAILED',
          failureCode: 'EXTRACTION_FAILED',
        });
      }
      const entries = (await history()).items.filter(
        (i: any) => i.reason === 'CONSUME' || i.reason === 'REFUND',
      );
      expect(entries.filter((e: any) => e.reason === 'REFUND')).toHaveLength(2);
      expect(
        entries
          .filter((e: any) => e.reason === 'REFUND')
          .every((e: any) => e.bucket === 'PURCHASED' && e.delta === 1),
      ).toBe(true);
    });

    it('refunds an unreadable statement as NOT_A_STATEMENT, tied to the verification', async () => {
      extractorError = new UnreadableStatementError();
      const v = (await verify().expect(202)).body;
      await settle();
      expect((await credits()).free).toBe(1);
      const got = await http()
        .get(`/api/v1/verifications/${v.id}`)
        .set(alice.auth)
        .expect(200);
      expect(got.body).toMatchObject({
        status: 'FAILED',
        failureCode: 'NOT_A_STATEMENT',
      });
      expect((await history()).items[0]).toMatchObject({
        delta: 1,
        bucket: 'FREE',
        reason: 'REFUND',
        source: 'SYSTEM',
        verificationId: v.id,
      });
    });

    it('refunds on unexpected crashes too, and not for invalid requests', async () => {
      extractorError = new Error('boom');
      await verify().expect(202);
      await settle();
      expect((await credits()).free).toBe(1);
      extractorError = null;
      // invalid PDFs / unknown cards never reserve anything
      await http()
        .post('/api/v1/verifications')
        .set(alice.auth)
        .field('cardId', cardId)
        .attach('file', Buffer.from('GIF89a'), {
          filename: 's.pdf',
          contentType: 'application/pdf',
        })
        .expect(400);
      expect((await credits()).free).toBe(1);
      // only the crashed attempt reserved a credit, and it was given back
      expect(
        await ctx.prisma.creditLedger.count({ where: { reason: 'CONSUME' } }),
      ).toBe(1);
      expect(
        await ctx.prisma.creditLedger.count({ where: { reason: 'REFUND' } }),
      ).toBe(1);
    });

    it('refunds exactly once, however many times it is asked', async () => {
      extractorError = new Error('boom');
      const v = (await verify().expect(202)).body;
      await settle();
      const service = ctx.app.get(CreditsService);
      await service.refundVerification(alice.id, v.id);
      await service.refundVerification(alice.id, v.id);
      expect(
        await ctx.prisma.creditLedger.count({
          where: { reason: 'REFUND', verificationId: v.id },
        }),
      ).toBe(1);
      expect((await credits()).free).toBe(1);
    });

    it('boot recovery fails orphaned PROCESSING rows as INTERRUPTED and refunds them', async () => {
      let release!: () => void;
      extractorGate = new Promise<void>((resolve) => (release = resolve));
      const v = (await verify().expect(202)).body;
      expect((await credits()).free).toBe(0);
      // simulate a restart: this process no longer owns the job
      expect(
        await ctx.app.get(VerificationProcessingService).recoverInterrupted(),
      ).toBe(1);
      const got = await http()
        .get(`/api/v1/verifications/${v.id}`)
        .set(alice.auth)
        .expect(200);
      expect(got.body).toMatchObject({
        status: 'FAILED',
        failureCode: 'INTERRUPTED',
      });
      expect((await credits()).free).toBe(1);
      expect(
        await ctx.app.get(VerificationProcessingService).recoverInterrupted(),
      ).toBe(0);
      expect((await credits()).free).toBe(1);
      // the lost job ends later: it must not resurrect the failed verification
      release();
      await settle();
      const after = await http()
        .get(`/api/v1/verifications/${v.id}`)
        .set(alice.auth)
        .expect(200);
      expect(after.body.status).toBe('FAILED');
    });

    it('the consume entry references the verification it paid for', async () => {
      const v = (await verify().expect(202)).body;
      const consume = (await history()).items.find(
        (i: any) => i.reason === 'CONSUME',
      );
      expect(consume.verificationId).toBe(v.id);
    });

    it('confirming, recalculating, reading and deleting cost nothing and are not gated', async () => {
      const v = (await verify().expect(202)).body;
      expect((await credits()).total).toBe(0);
      const confirm = () =>
        http()
          .post(`/api/v1/verifications/${v.id}/confirm`)
          .set(alice.auth)
          .send({ baseRatePercent: '1', categoryRates: [] });
      await confirm().expect(200);
      await confirm().expect(200);
      await http()
        .get(`/api/v1/verifications/${v.id}`)
        .set(alice.auth)
        .expect(200);
      expect((await credits()).total).toBe(0);
      await http()
        .delete(`/api/v1/verifications/${v.id}`)
        .set(alice.auth)
        .expect(204);
    });

    it('rejects with 402 before looking at the upload when there is nothing to spend', async () => {
      await verify().expect(202);
      // not even a valid PDF: the credit pre-check answers first
      const res = await http()
        .post('/api/v1/verifications')
        .set(alice.auth)
        .field('cardId', cardId)
        .attach('file', Buffer.from('x'), {
          filename: 's.txt',
          contentType: 'text/plain',
        })
        .expect(402);
      expect(res.body.code).toBe('NO_CREDITS');
    });
  });

  describe('unlimited accounts', () => {
    const setUnlimited = (user: TestUser, value = true) =>
      ctx.prisma.user.update({
        where: { id: user.id },
        data: { unlimitedCredits: value },
      });

    it('exposes the flag in /credits/me and /me, false by default', async () => {
      expect((await credits()).unlimited).toBe(false);
      const me = await http().get('/api/v1/me').set(alice.auth).expect(200);
      expect(me.body.unlimitedCredits).toBe(false);
      await setUnlimited(alice);
      expect((await credits()).unlimited).toBe(true);
      const after = await http().get('/api/v1/me').set(alice.auth).expect(200);
      expect(after.body.unlimitedCredits).toBe(true);
    });

    it('never answers 402 and writes no ledger rows for the uploads', async () => {
      await setUnlimited(alice);
      await ctx.prisma.creditLedger.deleteMany({ where: { userId: alice.id } });
      // zero balance, yet uploads keep being accepted
      for (let i = 0; i < 3; i++) await verify().expect(202);
      await settle();
      expect(
        await ctx.prisma.creditLedger.count({ where: { userId: alice.id } }),
      ).toBe(0);
      expect(extractCalls).toBe(3);
    });

    it('refunds nothing when the evaluation fails', async () => {
      await setUnlimited(alice);
      await credits();
      const before = await ctx.prisma.creditLedger.count({
        where: { userId: alice.id },
      });
      extractorError = new UnreadableStatementError();
      const v = (await verify().expect(202)).body;
      await settle();
      const got = await http()
        .get(`/api/v1/verifications/${v.id}`)
        .set(alice.auth)
        .expect(200);
      expect(got.body.status).toBe('FAILED');
      expect(
        await ctx.prisma.creditLedger.count({ where: { userId: alice.id } }),
      ).toBe(before);
      expect(
        await ctx.prisma.creditLedger.count({
          where: { verificationId: v.id },
        }),
      ).toBe(0);
    });

    it('keeps gating everybody else, and cannot be set through the API', async () => {
      const bob = await signInAs(ctx.app, 'bob');
      await setUnlimited(alice);
      const bobCard = (
        await http().post('/api/v1/cards').set(bob.auth).send({
          alias: 'c',
          bank: 'b',
          last4: '1111',
          rewardUnit: 'CASHBACK_CURRENCY',
          baseRatePercent: 1,
          currency: 'MXN',
        })
      ).body.id;
      const upload = () =>
        http()
          .post('/api/v1/verifications')
          .set(bob.auth)
          .field('cardId', bobCard)
          .attach('file', PDF, {
            filename: 's.pdf',
            contentType: 'application/pdf',
          });
      await upload().expect(202);
      await upload().expect(402);
      await settle();
      for (const [method, path] of [
        ['patch', '/api/v1/me/preferences'],
        ['patch', '/api/v1/me'],
      ] as const) {
        await http()
          [method](path)
          .set(bob.auth)
          .send({ unlimitedCredits: true })
          .expect((res) => expect([400, 404]).toContain(res.status));
      }
      expect(
        (await ctx.prisma.user.findUnique({ where: { id: bob.id } }))
          ?.unlimitedCredits,
      ).toBe(false);
    });
  });

  describe('history', () => {
    it('is paginated, newest first and scoped to the user', async () => {
      await send(pack('credits_3')).expect(200);
      await verify().expect(202);
      const res = await http()
        .get('/api/v1/credits/me/history?pageSize=2')
        .set(alice.auth)
        .expect(200);
      expect(res.body).toMatchObject({ page: 1, pageSize: 2, total: 3 });
      expect(res.body.items).toHaveLength(2);
      expect(res.body.items[0]).toMatchObject({
        delta: -1,
        bucket: 'FREE',
        reason: 'CONSUME',
        source: 'SYSTEM',
      });
      expect(res.body.items[0].externalRef).toBeUndefined();
      const bob = await signInAs(ctx.app, 'bob');
      const other = await http()
        .get('/api/v1/credits/me/history')
        .set(bob.auth)
        .expect(200);
      expect(other.body.total).toBe(1);
      await http()
        .get('/api/v1/credits/me/history?pageSize=101')
        .set(alice.auth)
        .expect(400);
    });
  });
});
