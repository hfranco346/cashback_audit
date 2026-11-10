import request from 'supertest';
import { VerificationProcessingService } from '../src/verifications/application/verification-processing.service.js';
import {
  LineClassifier,
  ResultExplainer,
  StatementExtractor,
} from '../src/verifications/domain/statement-extractor.js';
import type { ExtractedStatement } from '../src/verifications/domain/statement.js';
import {
  hnlUsdTwoProgramsStatement,
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

const PDF = Buffer.from('%PDF-1.7\n%fake statement\n');
const CASH = 'CASH BAC CREDOMATIC';
const PUNTOS = 'PUNTOS BAC CREDOMATIC';

describe('Card reward cap and program choice (e2e)', () => {
  let ctx: TestApp;
  let alice: TestUser;
  let statement: ExtractedStatement;
  const http = () => request(ctx.app.getHttpServer());

  /** 1400 at the 5% base rate = 70 expected. */
  const cashStatement = (accumulated = '70') =>
    mxnCashbackStatement({
      loyaltyPrograms: [program('Cashback', accumulated)],
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
          classify: async () => ({
            model: 'stub-classifier',
            unclassified: [],
            results: [],
          }),
        },
      },
      {
        token: ResultExplainer,
        useValue: {
          explain: async () => ({ text: 'Explicación.', model: 'stub' }),
        },
      },
    ]);
  });
  afterAll(() => ctx.close());
  beforeEach(async () => {
    statement = cashStatement();
    await resetDatabase(ctx.prisma);
    alice = await signInAs(ctx.app, 'alice');
  });
  afterEach(() => ctx.app.get(VerificationProcessingService).idle());

  const createCard = async (extra: Record<string, unknown> = {}) =>
    (
      await http()
        .post('/api/v1/cards')
        .set(alice.auth)
        .send({
          alias: 'Daily',
          bank: 'BBVA',
          last4: '4321',
          rewardUnit: 'CASHBACK_CURRENCY',
          baseRatePercent: 5,
          currency: 'MXN',
          ...extra,
        })
        .expect(201)
    ).body;
  const start = async (cardId: string) => {
    const accepted = await http()
      .post('/api/v1/verifications')
      .set(alice.auth)
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
        .set(alice.auth)
        .expect(200)
    ).body;
  };
  const confirm = (id: string, body: Record<string, unknown> = {}) =>
    http()
      .post(`/api/v1/verifications/${id}/confirm`)
      .set(alice.auth)
      .send({ baseRatePercent: '5', categoryRates: [], ...body });

  describe('card rewardCap', () => {
    it('is null by default; set on create, PATCH and cleared', async () => {
      const card = await createCard();
      expect(card.rewardCap).toBeNull();
      const capped = await createCard({ last4: '1111', rewardCap: '1500.5' });
      expect(capped.rewardCap).toBe('1500.5');
      const patched = await http()
        .patch(`/api/v1/cards/${card.id}`)
        .set(alice.auth)
        .send({ rewardCap: 200 })
        .expect(200);
      expect(patched.body.rewardCap).toBe('200');
      const read = await http()
        .get(`/api/v1/cards/${card.id}`)
        .set(alice.auth)
        .expect(200);
      expect(read.body.rewardCap).toBe('200');
      const cleared = await http()
        .patch(`/api/v1/cards/${card.id}`)
        .set(alice.auth)
        .send({ rewardCap: null })
        .expect(200);
      expect(cleared.body.rewardCap).toBeNull();
    });

    it.each(['0', '-5', 'abc', '10.123'])('rejects %s', async (rewardCap) => {
      const card = await createCard();
      await http()
        .patch(`/api/v1/cards/${card.id}`)
        .set(alice.auth)
        .send({ rewardCap })
        .expect(400);
    });
  });

  describe('rewardCapApplied in the completed detail', () => {
    it('reports cap, uncapped and capped when the cap is hit', async () => {
      const card = await createCard({ rewardCap: '40' });
      const started = await start(card.id);
      expect(started.rewardCapApplied).toBeNull();
      const res = await confirm(started.id).expect(200);
      expect(res.body).toMatchObject({
        status: 'COMPLETED',
        verdict: 'OVERPAID',
        reported: { amount: '70' },
        expected: { amount: '40' },
        difference: '30',
        rewardCapApplied: { cap: '40', uncapped: '70', capped: '40' },
      });
      // Per-line rewards stay uncapped.
      expect(
        res.body.transactions.map(
          (t: { expectedReward: string }) => t.expectedReward,
        ),
      ).toEqual(['50', '20']);
    });

    it('is null when the cap is not reached or the card has none', async () => {
      for (const rewardCap of ['500', undefined]) {
        const card = await createCard({
          last4: rewardCap ? '2222' : '3333',
          rewardCap,
        });
        const started = await start(card.id);
        const res = await confirm(started.id).expect(200);
        expect(res.body).toMatchObject({
          verdict: 'MATCH',
          expected: { amount: '70' },
          rewardCapApplied: null,
        });
      }
    });

    it('cumulative reporting compares the earned figure with the capped expected', async () => {
      statement = mxnCashbackStatement({
        loyaltyPrograms: [
          program('Cashback', '170', { previousBalance: undefined }),
        ],
        transactions: [line('SUPERMERCADO UNO', 1000), line('PEMEX 4455', 400)],
        detectedRates: [],
      });
      const card = await createCard({ rewardCap: '40' });
      const started = await start(card.id);
      const res = await confirm(started.id, {
        rewardReporting: { mode: 'CUMULATIVE', previousBalance: '100' },
      }).expect(200);
      expect(res.body).toMatchObject({
        reported: { amount: '70' },
        expected: { amount: '40' },
        verdict: 'OVERPAID',
        rewardCapApplied: { cap: '40', uncapped: '70', capped: '40' },
      });
    });
  });

  describe('rewardProgramChoice', () => {
    beforeEach(() => {
      statement = hnlUsdTwoProgramsStatement();
    });
    const hnlCard = (extra: Record<string, unknown> = {}) =>
      createCard({ currency: 'HNL', ...extra });

    it('is required while several programs are listed and none resolves', async () => {
      const card = await hnlCard();
      const started = await start(card.id);
      expect(started.status).toBe('AWAITING_RATES');
      expect(started.rewardProgramChoice.required).toBe(true);
      expect(
        started.rewardProgramChoice.options.map(
          (o: { name: string }) => o.name,
        ),
      ).toEqual([PUNTOS, CASH]);
      expect(
        Object.keys(started.rewardProgramChoice.options[0]).sort(),
      ).toEqual(['currency', 'name', 'reportedLabel', 'unit']);
      expect(started.rewardProgramChoice.options[0].unit).toBe('POINTS');
    });

    it('is null when the card program resolves it, and with a single program', async () => {
      const card = await hnlCard({ rewardProgramName: 'cash' });
      expect((await start(card.id)).rewardProgramChoice).toBeNull();
      statement = cashStatement();
      const other = await createCard({ last4: '9999' });
      const started = await start(other.id);
      expect(started.rewardProgramChoice).toBeNull();
      const res = await confirm(started.id).expect(200);
      expect(res.body.loyalty.selectedBy).toBe('ONLY_PROGRAM');
    });

    it('422 REWARD_PROGRAM_AMBIGUOUS without a choice, then audits with it', async () => {
      const card = await hnlCard();
      const started = await start(card.id);
      const ambiguous = await confirm(started.id).expect(422);
      expect(ambiguous.body.error?.code ?? ambiguous.body.code).toBe(
        'REWARD_PROGRAM_AMBIGUOUS',
      );
      const res = await confirm(started.id, {
        rewardProgramName: CASH,
      }).expect(200);
      expect(res.body).toMatchObject({
        status: 'COMPLETED',
        rewardProgramChoice: null,
        reported: { amount: '134.5' },
      });
      const stored = await http()
        .get(`/api/v1/cards/${card.id}`)
        .set(alice.auth);
      expect(stored.body.rewardProgramName).toBeNull();
    });

    it('400 INVALID_REWARD_PROGRAM for a name that is not an option', async () => {
      const card = await hnlCard();
      const started = await start(card.id);
      const res = await confirm(started.id, {
        rewardProgramName: 'Visa Signature',
        rememberProgramForCard: true,
      }).expect(400);
      expect(res.body.error?.code ?? res.body.code).toBe(
        'INVALID_REWARD_PROGRAM',
      );
      const stored = await http()
        .get(`/api/v1/cards/${card.id}`)
        .set(alice.auth);
      expect(stored.body.rewardProgramName).toBeNull();
    });

    it('rememberProgramForCard saves the program on the card for the next statement', async () => {
      const card = await hnlCard();
      const started = await start(card.id);
      await confirm(started.id, {
        rewardProgramName: 'cash',
        rememberProgramForCard: true,
      }).expect(200);
      const stored = await http()
        .get(`/api/v1/cards/${card.id}`)
        .set(alice.auth);
      expect(stored.body.rewardProgramName).toBe(CASH);
      expect((await start(card.id)).rewardProgramChoice).toBeNull();
    });

    it('re-confirm can change the program for free', async () => {
      const card = await hnlCard();
      const started = await start(card.id);
      const first = await confirm(started.id, {
        rewardProgramName: CASH,
      }).expect(200);
      expect(first.body.reported.label).toBe(CASH);
      const second = await confirm(started.id, {
        rewardProgramName: PUNTOS,
      }).expect(200);
      expect(second.body.reported.label).toBe(PUNTOS);
      expect(second.body.loyalty.selectedBy).toBe('REQUEST');
    });
  });
});
