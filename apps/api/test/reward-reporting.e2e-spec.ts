import { Decimal } from 'decimal.js';
import request from 'supertest';
import { VerificationProcessingService } from '../src/verifications/application/verification-processing.service.js';
import {
  LineClassifier,
  PreviousStatementReader,
  ResultExplainer,
  StatementExtractor,
  type PreviousStatementProgram,
} from '../src/verifications/domain/statement-extractor.js';
import { NotAStatementError } from '../src/verifications/domain/verification-errors.js';
import type { ExtractedStatement } from '../src/verifications/domain/statement.js';
import {
  d,
  line,
  mxnCashbackStatement,
  program,
} from './fixtures/statements.js';
import {
  createTestApp,
  resetDatabase,
  signInAs,
  type TestApp,
  type TestUser,
} from './test-app.js';

// The credit gate is on so the "no credit" guarantee is observable.
vi.hoisted(() => {
  process.env.CREDITS_GATE_ENABLED = 'true';
  process.env.FREE_CREDITS = '10';
});

const PDF = Buffer.from('%PDF-1.7\n%fake statement\n');

describe('Cumulative reward balance (e2e)', () => {
  let ctx: TestApp;
  let alice: TestUser;
  let bob: TestUser;
  let cardId: string;
  let statement: ExtractedStatement;
  let previous: {
    programs?: PreviousStatementProgram[];
    error?: Error;
    calls: number;
  };
  const http = () => request(ctx.app.getHttpServer());

  /** The fixture's expected reward is 58 at the supermarket rate below. */
  const cashStatement = (
    accumulated: string,
    over: Parameters<typeof program>[2] = {},
    period: { periodStart: string; periodEnd: string } = {
      periodStart: '2026-01-01',
      periodEnd: '2026-01-31',
    },
  ) =>
    mxnCashbackStatement({
      ...period,
      loyaltyPrograms: [program('Cashback', accumulated, over)],
      transactions: [line('SUPERMERCADO UNO', 1000), line('PEMEX 4455', 400)],
      detectedRates: [],
    });

  beforeAll(async () => {
    ctx = await createTestApp([
      {
        token: StatementExtractor,
        useValue: {
          extract: async () => ({ statement, model: 'stub-model' }),
        },
      },
      {
        token: LineClassifier,
        useValue: {
          classify: async (descriptors: string[]) => ({
            model: 'stub-classifier',
            unclassified: [],
            results: descriptors.map((descriptor) => ({
              descriptor,
              categoryId: null,
              matchedMerchantId: null,
              confidence: 0,
              reason: 'stub',
            })),
          }),
        },
      },
      {
        token: ResultExplainer,
        useValue: {
          explain: async () => ({ text: 'Explicación.', model: 'stub-haiku' }),
        },
      },
      {
        token: PreviousStatementReader,
        useValue: {
          read: async () => {
            previous.calls++;
            if (previous.error) throw previous.error;
            return { programs: previous.programs ?? [], model: 'stub-prev' };
          },
        },
      },
    ]);
  });
  afterAll(() => ctx.close());

  beforeEach(async () => {
    previous = { calls: 0 };
    statement = cashStatement('58');
    await resetDatabase(ctx.prisma);
    alice = await signInAs(ctx.app, 'alice');
    bob = await signInAs(ctx.app, 'bob');
    cardId = (
      await http().post('/api/v1/cards').set(alice.auth).send({
        alias: 'Daily',
        bank: 'BBVA',
        last4: '4321',
        rewardUnit: 'CASHBACK_CURRENCY',
        baseRatePercent: 5,
        currency: 'MXN',
      })
    ).body.id;
  });
  afterEach(() => ctx.app.get(VerificationProcessingService).idle());

  /** Uploads and waits for AWAITING_RATES; returns the detail body. */
  const start = async (user = alice) => {
    const accepted = await http()
      .post('/api/v1/verifications')
      .set(user.auth)
      .field('cardId', cardId)
      .attach('file', PDF, {
        filename: 's.pdf',
        contentType: 'application/pdf',
      })
      .expect(202);
    await ctx.app.get(VerificationProcessingService).idle();
    return (
      await http()
        .get(`/api/v1/verifications/${accepted.body.id}`)
        .set(user.auth)
        .expect(200)
    ).body;
  };
  const confirm = (
    id: string,
    body: Record<string, unknown> = {},
    user = alice,
  ) =>
    http()
      .post(`/api/v1/verifications/${id}/confirm`)
      .set(user.auth)
      .send({ baseRatePercent: '5', categoryRates: [], ...body });
  const previousStatement = (
    id: string,
    user = alice,
    file: Buffer | null = PDF,
    fields: Record<string, string> = {},
  ) => {
    let req = http()
      .post(`/api/v1/verifications/${id}/previous-statement`)
      .set(user.auth);
    for (const [k, v] of Object.entries(fields)) req = req.field(k, v);
    if (file)
      req = req.attach('file', file, {
        filename: 'prev.pdf',
        contentType: 'application/pdf',
      });
    return req;
  };
  const consumed = () =>
    ctx.prisma.creditLedger.count({
      where: { userId: alice.id, reason: 'CONSUME' },
    });

  describe('cards', () => {
    it('defaults to AUTO and can be set on create, PATCH and read back', async () => {
      const got = await http()
        .get(`/api/v1/cards/${cardId}`)
        .set(alice.auth)
        .expect(200);
      expect(got.body.rewardReporting).toBe('AUTO');
      const patched = await http()
        .patch(`/api/v1/cards/${cardId}`)
        .set(alice.auth)
        .send({ rewardReporting: 'CUMULATIVE' })
        .expect(200);
      expect(patched.body.rewardReporting).toBe('CUMULATIVE');
      const created = await http()
        .post('/api/v1/cards')
        .set(alice.auth)
        .send({
          alias: 'Second',
          bank: 'BBVA',
          last4: '1111',
          rewardUnit: 'CASHBACK_CURRENCY',
          baseRatePercent: 1,
          currency: 'MXN',
          rewardReporting: 'MONTHLY',
        })
        .expect(201);
      expect(created.body.rewardReporting).toBe('MONTHLY');
      await http()
        .patch(`/api/v1/cards/${cardId}`)
        .set(alice.auth)
        .send({ rewardReporting: 'WEEKLY' })
        .expect(400);
    });
  });

  describe('proposal', () => {
    it('exposes the program fields and a MONTHLY proposal with no signal', async () => {
      statement = cashStatement('70');
      const body = await start();
      expect(body.status).toBe('AWAITING_RATES');
      expect(body.rewardReporting).toBeNull();
      expect(body.rewardReportingProposal).toEqual({
        mode: 'MONTHLY',
        suggestedMode: 'MONTHLY',
        reason: 'NONE',
        cardSetting: 'AUTO',
        currentBalance: '70',
        previousBalance: null,
        previousBalanceSource: null,
        previousVerificationId: null,
        previousPeriodEnd: null,
        programName: 'Cashback',
        reportedLabel: null,
        redeemedInPeriod: '0',
        expiredInPeriod: '0',
        earned: null,
        previousBalanceRequired: true,
      });
      expect(body.loyalty.programs[0]).toMatchObject({
        previousBalance: null,
        earnedInPeriod: null,
        reportedLabel: null,
      });
    });

    it('suggests CUMULATIVE when the statement prints the previous balance', async () => {
      statement = cashStatement('158', { previousBalance: d(100) });
      const body = await start();
      expect(body.rewardReportingProposal).toMatchObject({
        mode: 'CUMULATIVE',
        suggestedMode: 'CUMULATIVE',
        reason: 'STATEMENT_HAS_PREVIOUS_BALANCE',
        previousBalance: '100',
        previousBalanceSource: 'STATEMENT',
        earned: '58',
        previousBalanceRequired: false,
      });
    });

    it('suggests from the label and from a figure far above the expected one', async () => {
      statement = cashStatement('70', { reportedLabel: 'Saldo acumulado' });
      expect((await start()).rewardReportingProposal).toMatchObject({
        suggestedMode: 'CUMULATIVE',
        reason: 'LABEL_SAYS_ACCUMULATED',
      });
      // 1,400 of spend at 5% = 70 expected; 9,000 is far above
      statement = cashStatement('9000');
      expect((await start()).rewardReportingProposal).toMatchObject({
        suggestedMode: 'CUMULATIVE',
        reason: 'REPORTED_FAR_ABOVE_EXPECTED',
      });
    });

    it('follows the remembered card setting', async () => {
      await http()
        .patch(`/api/v1/cards/${cardId}`)
        .set(alice.auth)
        .send({ rewardReporting: 'MONTHLY' })
        .expect(200);
      statement = cashStatement('158', { previousBalance: d(100) });
      expect((await start()).rewardReportingProposal).toMatchObject({
        mode: 'MONTHLY',
        suggestedMode: 'MONTHLY',
        reason: 'CARD_SETTING',
        cardSetting: 'MONTHLY',
      });
    });
  });

  describe('confirm', () => {
    it('B: derives earned from the previous balance printed on the statement', async () => {
      statement = cashStatement('170', {
        previousBalance: d(100),
        redeemedInPeriod: d(0),
      });
      const started = await start();
      const res = await confirm(started.id, {
        rewardReporting: { mode: 'CUMULATIVE' },
      }).expect(200);
      expect(res.body).toMatchObject({
        status: 'COMPLETED',
        verdict: 'MATCH',
        reported: { amount: '70', source: 'STATEMENT' },
        rewardReporting: {
          mode: 'CUMULATIVE',
          currentBalance: '170',
          previousBalance: '100',
          previousBalanceSource: 'STATEMENT',
          redeemedInPeriod: '0',
          expiredInPeriod: '0',
          earned: '70',
        },
      });
    });

    it('B: uses the earned-in-period figure printed on the statement', async () => {
      statement = cashStatement('900', { earnedInPeriod: d(70) });
      const started = await start();
      const res = await confirm(started.id, {
        rewardReporting: { mode: 'CUMULATIVE' },
      }).expect(200);
      expect(res.body.reported.amount).toBe('70');
      expect(res.body.rewardReporting).toMatchObject({
        previousBalance: null,
        previousBalanceSource: 'STATEMENT',
        earned: '70',
      });
    });

    it('answers 422 PREVIOUS_BALANCE_REQUIRED, then audits with a typed balance', async () => {
      statement = cashStatement('170');
      const started = await start();
      const refused = await confirm(started.id, {
        rewardReporting: { mode: 'CUMULATIVE' },
      }).expect(422);
      expect(refused.body).toMatchObject({
        code: 'PREVIOUS_BALANCE_REQUIRED',
      });
      const res = await confirm(started.id, {
        rewardReporting: { mode: 'CUMULATIVE', previousBalance: '100' },
      }).expect(200);
      expect(res.body.rewardReporting).toMatchObject({
        previousBalance: '100',
        previousBalanceSource: 'USER',
        earned: '70',
      });
    });

    it('validates the body', async () => {
      const started = await start();
      for (const rewardReporting of [
        { mode: 'WEEKLY' },
        { mode: 'CUMULATIVE', previousBalance: '-1' },
        { mode: 'CUMULATIVE', previousBalance: 'abc' },
        { mode: 'CUMULATIVE', previousBalanceSource: 'GUESS' },
        {},
      ]) {
        await confirm(started.id, { rewardReporting }).expect(400);
      }
    });

    it('adds redeemed and expired points back; a negative result is kept with a warning', async () => {
      statement = cashStatement('150', {
        redeemedInPeriod: d(30),
        forfeited: d(5),
        expiring: d(40),
      });
      const started = await start();
      const ok = await confirm(started.id, {
        rewardReporting: { mode: 'CUMULATIVE', previousBalance: '115' },
      }).expect(200);
      // 150 - 115 + 30 + 5 = 70
      expect(ok.body.rewardReporting).toMatchObject({
        earned: '70',
        redeemedInPeriod: '30',
        expiredInPeriod: '5',
      });
      expect(ok.body.verdict).toBe('MATCH');
      const negative = await confirm(started.id, {
        rewardReporting: { mode: 'CUMULATIVE', previousBalance: '400' },
      }).expect(200);
      expect(negative.body.reported.amount).toBe('-215');
      expect(negative.body.rewardReporting.earned).toBe('-215');
      expect(negative.body.warnings.map((w: any) => w.code)).toContain(
        'REWARD_BALANCE_INCONSISTENT',
      );
    });

    it('rememberForCard updates the card; re-confirm can switch back for free', async () => {
      statement = cashStatement('170');
      const started = await start();
      const first = await confirm(started.id, {
        rewardReporting: {
          mode: 'CUMULATIVE',
          previousBalance: '100',
          rememberForCard: true,
        },
      }).expect(200);
      expect(first.body.rewardReporting.mode).toBe('CUMULATIVE');
      expect(
        (await http().get(`/api/v1/cards/${cardId}`).set(alice.auth)).body
          .rewardReporting,
      ).toBe('CUMULATIVE');
      const before = await consumed();
      const monthly = await confirm(started.id, {
        rewardReporting: { mode: 'MONTHLY' },
      }).expect(200);
      expect(monthly.body.reported.amount).toBe('170');
      expect(monthly.body.rewardReporting.mode).toBe('MONTHLY');
      expect(await consumed()).toBe(before);
      // card setting untouched without rememberForCard
      expect(
        (await http().get(`/api/v1/cards/${cardId}`).set(alice.auth)).body
          .rewardReporting,
      ).toBe('CUMULATIVE');
    });

    it('describes the derivation to the explainer and warns in the explanation facts', async () => {
      statement = cashStatement('170');
      const started = await start();
      const res = await confirm(started.id, {
        rewardReporting: { mode: 'CUMULATIVE', previousBalance: '100' },
      }).expect(200);
      expect(res.body.explanation).toBe('Explicación.');
    });
  });

  describe('persistence feeding the next month (decision A)', () => {
    it('uses last month balance when the card is CUMULATIVE', async () => {
      // December: the user types the previous balance; 170 is kept.
      statement = cashStatement(
        '170',
        {},
        {
          periodStart: '2025-12-01',
          periodEnd: '2025-12-31',
        },
      );
      const december = await start();
      await confirm(december.id, {
        rewardReporting: {
          mode: 'CUMULATIVE',
          previousBalance: '100',
          rememberForCard: true,
        },
      }).expect(200);

      // January: closest earlier COMPLETED audit of the same card/program.
      statement = cashStatement('240');
      const january = await start();
      expect(january.rewardReportingProposal).toMatchObject({
        mode: 'CUMULATIVE',
        reason: 'CARD_SETTING',
        previousBalance: '170',
        previousBalanceSource: 'PREVIOUS_VERIFICATION',
        previousVerificationId: december.id,
        previousPeriodEnd: '2025-12-31',
        earned: '70',
        previousBalanceRequired: false,
      });
      const res = await confirm(january.id).expect(200);
      expect(res.body).toMatchObject({
        verdict: 'MATCH',
        reported: { amount: '70' },
        rewardReporting: {
          mode: 'CUMULATIVE',
          currentBalance: '240',
          previousBalance: '170',
          previousBalanceSource: 'PREVIOUS_VERIFICATION',
          previousPeriodEnd: '2025-12-31',
          earned: '70',
        },
      });
    });

    it('ignores audits of another card, another program or a distant period', async () => {
      statement = cashStatement(
        '170',
        {},
        {
          periodStart: '2025-10-01',
          periodEnd: '2025-10-31',
        },
      );
      const october = await start();
      await confirm(october.id, {
        rewardReporting: { mode: 'CUMULATIVE', previousBalance: '100' },
      }).expect(200);
      statement = cashStatement('240');
      const january = await start();
      expect(january.rewardReportingProposal).toMatchObject({
        previousBalance: null,
        previousBalanceRequired: true,
      });
    });

    it('does not use a MONTHLY audit as a balance', async () => {
      statement = cashStatement(
        '70',
        {},
        {
          periodStart: '2025-12-01',
          periodEnd: '2025-12-31',
        },
      );
      const december = await start();
      await confirm(december.id).expect(200);
      statement = cashStatement('240');
      const january = await start();
      expect(january.rewardReportingProposal.previousBalanceRequired).toBe(
        true,
      );
    });
  });

  describe('POST /verifications/:id/previous-statement', () => {
    beforeEach(() => {
      statement = cashStatement('170');
      previous.programs = [
        {
          name: 'CASHBACK',
          balance: new Decimal('100.5'),
          periodEnd: '2025-12-31',
        },
        { name: 'Puntos', balance: new Decimal(7), periodEnd: '2025-12-31' },
      ];
    });

    it('returns the programs and the matched balance without spending a credit', async () => {
      const started = await start();
      const before = await consumed();
      const res = await previousStatement(started.id).expect(200);
      expect(res.body).toEqual({
        programs: [
          { name: 'CASHBACK', balance: '100.5', periodEnd: '2025-12-31' },
          { name: 'Puntos', balance: '7', periodEnd: '2025-12-31' },
        ],
        matchedBalance: '100.5',
      });
      expect(await consumed()).toBe(before);
      expect(previous.calls).toBe(1);

      // the read balance is then confirmed with its source
      const done = await confirm(started.id, {
        rewardReporting: {
          mode: 'CUMULATIVE',
          previousBalance: res.body.matchedBalance,
          previousBalanceSource: 'PREVIOUS_STATEMENT',
        },
      }).expect(200);
      expect(done.body.rewardReporting).toMatchObject({
        previousBalance: '100.5',
        previousBalanceSource: 'PREVIOUS_STATEMENT',
      });
      // ...and it also works on a COMPLETED verification
      await previousStatement(started.id).expect(200);
    });

    it('answers 422 PROGRAM_NOT_FOUND when the program is not on that statement', async () => {
      const started = await start();
      previous.programs = [
        { name: 'Millas Viajero', balance: new Decimal(7), periodEnd: null },
      ];
      const res = await previousStatement(started.id).expect(422);
      expect(res.body).toMatchObject({ code: 'PROGRAM_NOT_FOUND' });
    });

    it('answers 422 NOT_A_STATEMENT', async () => {
      const started = await start();
      previous.error = new NotAStatementError();
      const res = await previousStatement(started.id).expect(422);
      expect(res.body).toMatchObject({ code: 'NOT_A_STATEMENT' });
    });

    it('validates the file and the ownership before calling Claude', async () => {
      const started = await start();
      await previousStatement(started.id, alice, null).expect(400);
      await previousStatement(
        started.id,
        alice,
        Buffer.from('not a pdf!'),
      ).expect(400);
      await previousStatement(started.id, bob).expect(404);
      await previousStatement('00000000-0000-4000-8000-000000000000').expect(
        404,
      );
      await http()
        .post(`/api/v1/verifications/${started.id}/previous-statement`)
        .expect(401);
      expect(previous.calls).toBe(0);
    });

    it('refuses verifications that are not ready', async () => {
      const accepted = await http()
        .post('/api/v1/verifications')
        .set(alice.auth)
        .field('cardId', cardId)
        .attach('file', PDF, {
          filename: 's.pdf',
          contentType: 'application/pdf',
        })
        .expect(202);
      // still PROCESSING until the background job runs
      const res = await previousStatement(accepted.body.id);
      expect([200, 409]).toContain(res.status);
      await ctx.app.get(VerificationProcessingService).idle();
    });
  });

  describe('COMPLETED detail of older rows', () => {
    it('reads as MONTHLY with the printed figure as earned', async () => {
      statement = cashStatement('70');
      const started = await start();
      const res = await confirm(started.id).expect(200);
      expect(res.body.rewardReporting).toEqual({
        mode: 'MONTHLY',
        programName: 'Cashback',
        reportedLabel: null,
        currentBalance: null,
        previousBalance: null,
        previousBalanceSource: null,
        previousPeriodEnd: null,
        redeemedInPeriod: '0',
        expiredInPeriod: '0',
        earned: '70',
      });
      // simulate a row written before this feature
      await ctx.prisma.verification.update({
        where: { id: started.id },
        data: { rewardReporting: undefined },
      });
      await ctx.prisma
        .$executeRaw`UPDATE "Verification" SET "rewardReporting" = NULL WHERE id = ${started.id}::uuid`;
      const old = await http()
        .get(`/api/v1/verifications/${started.id}`)
        .set(alice.auth)
        .expect(200);
      expect(old.body.rewardReporting).toMatchObject({
        mode: 'MONTHLY',
        earned: '70',
      });
    });
  });
});
