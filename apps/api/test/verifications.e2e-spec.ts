import request from 'supertest';
import { CleanupAwaitingRatesService } from '../src/verifications/application/cleanup-awaiting-rates.service.js';
import { VerificationProcessingService } from '../src/verifications/application/verification-processing.service.js';
import {
  ExtractionUnavailableError,
  UnreadableStatementError,
} from '../src/verifications/domain/verification-errors.js';
import {
  LineClassifier,
  ResultExplainer,
  StatementExtractor,
} from '../src/verifications/domain/statement-extractor.js';
import type { ExtractedStatement } from '../src/verifications/domain/statement.js';
import {
  crcUsdEurStatement,
  d,
  detected,
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

describe('Verifications (e2e)', () => {
  let ctx: TestApp;
  let alice: TestUser;
  let bob: TestUser;
  let extraction: {
    statement?: ExtractedStatement;
    error?: Error;
    /** While set, extraction waits for it (keeps a verification PROCESSING). */
    gate?: Promise<void>;
    calls: number;
    contexts: unknown[];
  };
  const http = () => request(ctx.app.getHttpServer());

  let superCategoryId: string;
  let pharmacyCategoryId: string;
  let aiMerchantId: string;
  let cardId: string;

  /** Fixture statement whose stated category rate points at the real id. */
  const mxn = (over: Partial<ExtractedStatement> = {}) =>
    mxnCashbackStatement({
      detectedRates: [
        detected({ scope: 'BASE', ratePercent: d(1), evidence: '1% base' }),
        detected({
          suggestedCategoryId: superCategoryId,
          ratePercent: d(5),
          evidence: '5% at supermarkets',
        }),
      ],
      ...over,
    });

  const extractorStub = {
    extract: async (_pdf: Buffer, context: unknown) => {
      extraction.calls++;
      extraction.contexts.push(context);
      if (extraction.gate) await extraction.gate;
      if (extraction.error) throw extraction.error;
      return {
        statement: extraction.statement ?? mxn(),
        model: 'stub-model',
      };
    },
  };
  const classifierStub = {
    classify: async (descriptors: string[]) => ({
      model: 'stub-classifier',
      unclassified: [] as string[],
      results: descriptors.map((descriptor) => ({
        descriptor,
        categoryId: descriptor.includes('POLLO')
          ? 'hint:0'
          : descriptor.includes('FARMACIA')
            ? pharmacyCategoryId
            : descriptor.includes('SUPERMERCADO') ||
                descriptor === 'WM SUPERCENTER'
              ? superCategoryId
              : null,
        matchedMerchantId:
          descriptor === 'WM SUPERCENTER' ? aiMerchantId : null,
        confidence: 0.85,
        reason: 'stub',
      })),
    }),
  };

  let explainFacts: unknown[] = [];
  let explainFails = false;
  const explainerStub = {
    explain: async (facts: unknown) => {
      explainFacts.push(facts);
      if (explainFails) throw new Error('down');
      return { text: 'Explicación breve.', model: 'stub-haiku' };
    },
  };

  beforeAll(async () => {
    ctx = await createTestApp([
      { token: StatementExtractor, useValue: extractorStub },
      { token: LineClassifier, useValue: classifierStub },
      { token: ResultExplainer, useValue: explainerStub },
    ]);
  });
  afterAll(() => ctx.close());

  beforeEach(async () => {
    extraction = { calls: 0, contexts: [] };
    explainFacts = [];
    explainFails = false;
    await resetDatabase(ctx.prisma);
    alice = await signInAs(ctx.app, 'alice');
    bob = await signInAs(ctx.app, 'bob');

    const cat = (
      await http()
        .post('/api/v1/categories')
        .set(alice.auth)
        .send({ name: 'Supermarkets' })
    ).body;
    superCategoryId = cat.id;
    pharmacyCategoryId = (
      await http()
        .post('/api/v1/categories')
        .set(alice.auth)
        .send({ name: 'Pharmacies', description: 'pharmacies and drugstores' })
    ).body.id;
    aiMerchantId = (
      await http()
        .post('/api/v1/merchants')
        .set(alice.auth)
        .send({ name: 'Walmart', keywords: ['WAL MART'], categoryId: cat.id })
    ).body.id;
    cardId = (
      await http()
        .post('/api/v1/cards')
        .set(alice.auth)
        .send({
          alias: 'Daily',
          bank: 'BBVA',
          last4: '4321',
          rewardUnit: 'CASHBACK_CURRENCY',
          baseRatePercent: 1,
          currency: 'MXN',
          rules: [{ categoryId: cat.id, ratePercent: 5 }],
        })
    ).body.id;
  });

  const upload = (
    user: TestUser,
    fields: Record<string, string> = {},
    file: Buffer | null = PDF,
    mime = 'application/pdf',
  ) => {
    let req = http().post('/api/v1/verifications').set(user.auth);
    for (const [k, v] of Object.entries({ cardId, ...fields }))
      req = req.field(k, v);
    if (file)
      req = req.attach('file', file, {
        filename: 'statement.pdf',
        contentType: mime,
      });
    return req;
  };
  const processing = () => ctx.app.get(VerificationProcessingService);
  /**
   * Uploads (expects 202 + PROCESSING), waits for the background processor and
   * returns the finished verification as GET /verifications/:id shows it.
   */
  const start = async (user: TestUser, fields: Record<string, string> = {}) => {
    const accepted = await upload(user, fields).expect(202);
    expect(accepted.body.status).toBe('PROCESSING');
    await processing().idle();
    return http()
      .get(`/api/v1/verifications/${accepted.body.id}`)
      .set(user.auth)
      .expect(200);
  };
  let releaseGate: (() => void) | undefined;
  /** Keeps extraction pending (verifications stay PROCESSING) until released. */
  const holdExtraction = () => {
    extraction.gate = new Promise<void>((resolve) => (releaseGate = resolve));
    return () => releaseGate?.();
  };
  afterEach(async () => {
    releaseGate?.();
    releaseGate = undefined;
    await processing().idle();
  });
  const attention = async (user: TestUser) =>
    (
      await http()
        .get('/api/v1/verifications/attention')
        .set(user.auth)
        .expect(200)
    ).body.items as { id: string; status: string }[];
  const confirm = (
    user: TestUser,
    id: string,
    body: Record<string, unknown> = {},
  ) =>
    http()
      .post(`/api/v1/verifications/${id}/confirm`)
      .set(user.auth)
      .send({
        baseRatePercent: '1',
        categoryRates: [{ categoryId: superCategoryId, ratePercent: '5' }],
        ...body,
      });

  it('requires authentication', async () => {
    await http().post('/api/v1/verifications').expect(401);
    await http().get('/api/v1/verifications').expect(401);
    await http()
      .post(
        '/api/v1/verifications/00000000-0000-4000-8000-000000000000/confirm',
      )
      .expect(401);
  });

  describe('step 1: upload', () => {
    it('extracts and classifies but computes nothing (AWAITING_RATES)', async () => {
      const res = await start(alice);
      expect(res.body).toMatchObject({
        cardId,
        status: 'AWAITING_RATES',
        primaryCurrency: 'MXN',
        statement: {
          bank: 'Example Bank',
          cardLast4: '4321',
          totalSpent: '1400',
        },
        reported: null,
        expected: null,
        difference: null,
        tolerance: null,
        verdict: null,
        appliedRates: null,
        explanation: null,
        breakdown: [],
        currencies: [],
        model: 'stub-model',
        models: { extraction: 'stub-model', classification: 'stub-classifier' },
        warnings: [],
      });
      expect(res.body.detectedRates).toHaveLength(2);
      expect(res.body.detectedRates[1]).toMatchObject({
        scope: 'CATEGORY',
        suggestedCategoryId: superCategoryId,
        ratePercent: '5',
        evidence: '5% at supermarkets',
      });
      expect(
        res.body.transactions.map((t: any) => [
          t.merchant,
          t.matchSource,
          t.categoryName,
          t.expectedReward,
          t.appliedRatePercent,
        ]),
      ).toEqual([
        ['WAL MART SUC 123', 'KEYWORD', 'Supermarkets', null, null],
        ['WM SUPERCENTER', 'AI_MERCHANT', 'Supermarkets', null, null],
        ['PEMEX 4455', 'NONE', null, null, null],
        ['WAL MART SUC 123', 'KEYWORD', 'Supermarkets', null, null],
      ]);
      expect(res.body.transactions[1]).toMatchObject({
        matchConfidence: 0.85,
        matchReason: 'stub',
        matchedMerchantName: 'Walmart',
      });
      expect(extraction.contexts[0]).toMatchObject({
        categories: expect.arrayContaining([
          expect.objectContaining({ name: 'Supermarkets' }),
          expect.objectContaining({
            name: 'Pharmacies',
            description: 'pharmacies and drugstores',
          }),
        ]),
      });
    });

    it('proposes rates: STATEMENT > CARD_RULE > NONE, required only for NONE', async () => {
      extraction.statement = mxn({
        detectedRates: [],
        transactions: [
          line('WAL MART SUC 123', 1000),
          line('FARMACIA SIMAN', 100),
        ],
      });
      const res = await start(alice);
      expect(res.body.rateProposal).toEqual([
        {
          categoryId: null,
          categoryName: null,
          ratePercent: '1',
          monthlyCap: null,
          source: 'CARD_RULE',
          evidence: null,
          unitNote: null,
          required: false,
        },
        {
          categoryId: pharmacyCategoryId,
          categoryName: 'Pharmacies',
          ratePercent: null,
          monthlyCap: null,
          source: 'NONE',
          evidence: null,
          unitNote: null,
          required: true,
        },
        {
          categoryId: superCategoryId,
          categoryName: 'Supermarkets',
          ratePercent: '5',
          monthlyCap: null,
          source: 'CARD_RULE',
          evidence: null,
          unitNote: null,
          required: false,
        },
      ]);

      extraction.statement = mxn();
      const stated = await start(alice);
      const superEntry = stated.body.rateProposal.find(
        (e: any) => e.categoryId === superCategoryId,
      );
      expect(superEntry).toMatchObject({
        source: 'STATEMENT',
        ratePercent: '5',
        evidence: '5% at supermarkets',
        required: false,
      });
    });

    it('never fails on an ambiguous program: it lists them and waits', async () => {
      extraction.statement = hnlUsdTwoProgramsStatement();
      await http()
        .patch(`/api/v1/cards/${cardId}`)
        .set(alice.auth)
        .send({ currency: 'HNL' })
        .expect(200);
      const res = await start(alice);
      expect(res.body.loyalty.selectedProgram).toBeNull();
      expect(res.body.loyalty.programs.map((p: any) => p.name)).toEqual([
        'PUNTOS BAC CREDOMATIC',
        'CASH BAC CREDOMATIC',
      ]);
      expect(res.body.currencies).toEqual([]);
    });

    it('validates exchangeRate and rewardProgramName and rejects the removed override', async () => {
      await upload(alice, { exchangeRate: '0' }).expect(400);
      await upload(alice, { exchangeRate: 'abc' }).expect(400);
      await upload(alice, { rewardProgramName: 'x'.repeat(81) }).expect(400);
      await upload(alice, { reportedRewardOverride: '5' }).expect(400);
      await start(alice, { rewardProgramName: '' });
    });

    it('never persists the PDF: only extracted data is stored', async () => {
      const res = await start(alice);
      const row = await ctx.prisma.verification.findUniqueOrThrow({
        where: { id: res.body.id },
      });
      expect(JSON.stringify(row)).not.toContain(PDF.toString('base64'));
      expect(JSON.stringify(row)).not.toContain('%PDF');
    });

    it('warns when the statement belongs to another card', async () => {
      extraction.statement = mxn({ cardLast4: '9999' });
      const res = await start(alice);
      expect(res.body.warnings.map((w: any) => w.code)).toContain(
        'CARD_LAST4_MISMATCH',
      );
    });
  });

  describe('step 2: confirm', () => {
    it('audits with the confirmed rates, stores appliedRates and completes', async () => {
      const started = (await start(alice)).body;
      const res = await confirm(alice, started.id).expect(200);

      // super: 1000 + 200 - 100 = 1100 * 5% = 55 ; base: 300 * 1% = 3
      expect(res.body).toMatchObject({
        id: started.id,
        status: 'COMPLETED',
        explanation: 'Explicación breve.',
        models: {
          extraction: 'stub-model',
          classification: 'stub-classifier',
          explanation: 'stub-haiku',
        },
        reported: {
          amount: '58',
          unit: 'CASHBACK_CURRENCY',
          source: 'STATEMENT',
          label: 'Bonificación del periodo',
        },
        expected: { amount: '58', unit: 'CASHBACK_CURRENCY' },
        difference: '0',
        tolerance: '1',
        verdict: 'MATCH',
        appliedRates: {
          baseRatePercent: '1',
          baseSource: 'STATEMENT_CONFIRMED',
          savedToCard: false,
          categoryRates: [
            {
              categoryId: superCategoryId,
              categoryName: 'Supermarkets',
              ratePercent: '5',
              monthlyCap: null,
              source: 'STATEMENT_CONFIRMED',
            },
          ],
        },
        currencies: [
          {
            currency: 'MXN',
            isPrimary: true,
            spent: '1400',
            eligibleSpent: '1400',
            expectedReward: '58',
          },
        ],
        loyalty: { selectedBy: 'ONLY_PROGRAM' },
      });
      expect(
        res.body.transactions.map((t: any) => [
          t.matchSource,
          t.ruleApplied,
          t.appliedRatePercent,
          t.expectedReward,
        ]),
      ).toEqual([
        ['KEYWORD', true, '5', '50'],
        ['AI_MERCHANT', true, '5', '10'],
        ['NONE', false, '1', '3'],
        ['KEYWORD', true, '5', '-5'],
      ]);
      expect(res.body.breakdown[0]).toMatchObject({
        categoryName: 'Supermarkets',
        spend: '1100',
        expectedReward: '55',
        capped: false,
      });
      expect(extraction.calls).toBe(1);

      const stored = await http()
        .get(`/api/v1/verifications/${started.id}`)
        .set(alice.auth)
        .expect(200);
      expect(stored.body).toEqual(res.body);
    });

    it('answers 422 RATES_REQUIRED listing the missing categories', async () => {
      extraction.statement = mxn({
        transactions: [line('FARMACIA SIMAN', 100), line('WAL MART X', 100)],
      });
      const started = (await start(alice)).body;
      const res = await confirm(alice, started.id).expect(422);
      expect(res.body).toMatchObject({
        code: 'RATES_REQUIRED',
        details: {
          missing: [
            { categoryId: pharmacyCategoryId, categoryName: 'Pharmacies' },
          ],
        },
      });
      const ok = await confirm(alice, started.id, {
        categoryRates: [
          { categoryId: superCategoryId, ratePercent: '5' },
          { categoryId: pharmacyCategoryId, ratePercent: '3', monthlyCap: '1' },
        ],
      }).expect(200);
      // super 100 * 5% = 5 ; pharmacy 100 * 3% = 3 capped at 1
      expect(ok.body.expected.amount).toBe('6');
      expect(
        ok.body.appliedRates.categoryRates.find(
          (c: any) => c.categoryId === pharmacyCategoryId,
        ),
      ).toMatchObject({ source: 'USER_ENTERED', monthlyCap: '1' });
    });

    it('recalculates a COMPLETED verification with other rates and no new Claude call', async () => {
      const started = (await start(alice)).body;
      const first = (await confirm(alice, started.id).expect(200)).body;
      const second = (
        await confirm(alice, started.id, {
          baseRatePercent: '2',
          categoryRates: [{ categoryId: superCategoryId, ratePercent: '10' }],
        }).expect(200)
      ).body;
      // super 1100 * 10% = 110 ; base 300 * 2% = 6
      expect(second.expected.amount).toBe('116');
      expect(second.verdict).toBe('UNDERPAID');
      expect(second.appliedRates.categoryRates[0]).toMatchObject({
        ratePercent: '10',
        source: 'USER_ENTERED',
      });
      expect(first.expected.amount).toBe('58');
      expect(extraction.calls).toBe(1);
    });

    it('saveToCard persists the rates as the card rates', async () => {
      const started = (await start(alice)).body;
      const res = await confirm(alice, started.id, {
        baseRatePercent: '2',
        saveToCard: true,
        categoryRates: [
          { categoryId: superCategoryId, ratePercent: '8', monthlyCap: '500' },
        ],
      }).expect(200);
      expect(res.body.appliedRates.savedToCard).toBe(true);
      const card = (
        await http().get(`/api/v1/cards/${cardId}`).set(alice.auth).expect(200)
      ).body;
      expect(card.baseRatePercent).toBe('2');
      expect(card.rules).toEqual([
        { categoryId: superCategoryId, ratePercent: '8', monthlyCap: '500' },
      ]);
    });

    it('validates the body and ownership', async () => {
      const started = (await start(alice)).body;
      await confirm(alice, started.id, { baseRatePercent: '101' }).expect(400);
      await confirm(alice, started.id, { baseRatePercent: '-1' }).expect(400);
      await confirm(alice, started.id, { baseRatePercent: undefined }).expect(
        400,
      );
      await confirm(alice, started.id, {
        categoryRates: [{ categoryId: superCategoryId, ratePercent: '101' }],
      }).expect(400);
      await confirm(alice, started.id, { unknown: 1 }).expect(400);
      await confirm(alice, started.id, {
        categoryRates: [
          {
            categoryId: '00000000-0000-4000-8000-000000000000',
            ratePercent: '5',
          },
        ],
      }).expect(404);
      await confirm(alice, started.id, {
        categoryRates: [
          { categoryId: superCategoryId, ratePercent: '5' },
          { categoryId: superCategoryId, ratePercent: '6' },
        ],
      }).expect(400);
      await confirm(bob, started.id).expect(404);
    });

    it('flags an underpaid statement and accepts reportedRewardOverride', async () => {
      extraction.statement = mxn({ loyaltyPrograms: [program('x', '30')] });
      const started = (await start(alice)).body;
      const under = await confirm(alice, started.id).expect(200);
      expect(under.body).toMatchObject({
        verdict: 'UNDERPAID',
        difference: '-28',
      });

      extraction.statement = mxn({ loyaltyPrograms: [] });
      const none = (await start(alice)).body;
      await confirm(alice, none.id)
        .expect(422)
        .expect((r) => expect(r.body.code).toBe('REPORTED_REWARD_NOT_FOUND'));
      const res = await confirm(alice, none.id, {
        reportedRewardOverride: '70.5',
      }).expect(200);
      expect(res.body).toMatchObject({
        verdict: 'OVERPAID',
        reported: { amount: '70.5', source: 'OVERRIDE' },
        difference: '12.5',
      });
      await confirm(alice, none.id, { reportedRewardOverride: '-3' }).expect(
        400,
      );
    });
  });

  describe('explanation', () => {
    it('is generated from the computed numbers and refreshed on recalculation', async () => {
      const started = (await start(alice)).body;
      await confirm(alice, started.id).expect(200);
      expect(explainFacts[0]).toMatchObject({
        verdict: 'MATCH',
        reported: '58',
        expected: '58',
      });
      await confirm(alice, started.id, { baseRatePercent: '2' }).expect(200);
      expect(explainFacts).toHaveLength(2);
    });

    it('degrades to a warning when it fails', async () => {
      explainFails = true;
      const started = (await start(alice)).body;
      const res = await confirm(alice, started.id).expect(200);
      expect(res.body.status).toBe('COMPLETED');
      expect(res.body.explanation).toBeNull();
      expect(res.body.models.explanation).toBeNull();
      expect(res.body.warnings.map((w: any) => w.code)).toContain(
        'EXPLANATION_UNAVAILABLE',
      );
    });
  });

  describe('PATCH /verifications/:id/transactions/:index', () => {
    const patch = (
      user: TestUser,
      id: string,
      index: number | string,
      body: unknown,
    ) =>
      http()
        .patch(`/api/v1/verifications/${id}/transactions/${index}`)
        .set(user.auth)
        .send(body as object);

    it('corrects a category, then a new confirm applies it (and requires its rate)', async () => {
      const started = (await start(alice)).body;
      const fixed = await patch(alice, started.id, 2, {
        categoryId: pharmacyCategoryId,
      }).expect(200);
      expect(fixed.body.transactions[2]).toMatchObject({
        categoryName: 'Pharmacies',
        matchSource: 'USER',
        matchConfidence: null,
      });
      expect(
        fixed.body.rateProposal.find(
          (e: any) => e.categoryId === pharmacyCategoryId,
        ),
      ).toMatchObject({ source: 'NONE', required: true });
      await confirm(alice, started.id).expect(422);
      const done = await confirm(alice, started.id, {
        categoryRates: [
          { categoryId: superCategoryId, ratePercent: '5' },
          { categoryId: pharmacyCategoryId, ratePercent: '10' },
        ],
      }).expect(200);
      // pharmacy 300 * 10% = 30 ; super 55 ; base 0
      expect(done.body.expected.amount).toBe('85');
      expect(done.body.transactions[2]).toMatchObject({
        matchSource: 'USER',
        appliedRatePercent: '10',
      });
      expect(extraction.calls).toBe(1);
    });

    it('clears a category and validates input and ownership', async () => {
      const started = (await start(alice)).body;
      const cleared = await patch(alice, started.id, 0, {
        categoryId: null,
      }).expect(200);
      expect(cleared.body.transactions[0]).toMatchObject({
        categoryId: null,
        matchSource: 'NONE',
      });
      await patch(alice, started.id, 0, { categoryId: 'nope' }).expect(400);
      await patch(alice, started.id, 0, {}).expect(400);
      await patch(alice, started.id, 99, { categoryId: null }).expect(404);
      await patch(alice, started.id, -1, { categoryId: null }).expect(400);
      await patch(alice, started.id, 0, {
        categoryId: '00000000-0000-4000-8000-000000000000',
      }).expect(404);
      await patch(bob, started.id, 0, { categoryId: null }).expect(404);
    });

    it('refuses to categorize non-purchase lines', async () => {
      extraction.statement = mxn({
        transactions: [line('SEGURO', 10, { kind: 'INSURANCE' })],
      });
      const started = (await start(alice)).body;
      const res = await patch(alice, started.id, 0, {
        categoryId: superCategoryId,
      }).expect(422);
      expect(res.body.code).toBe('TRANSACTION_NOT_CLASSIFIABLE');
    });
  });

  describe('cleanup of abandoned verifications', () => {
    it('deletes AWAITING_RATES older than the TTL and keeps everything else', async () => {
      const old = (await start(alice)).body;
      const fresh = (await start(alice)).body;
      const doneOld = (await start(alice)).body;
      await confirm(alice, doneOld.id).expect(200);
      const longAgo = new Date(Date.now() - 8 * 24 * 60 * 60 * 1000);
      await ctx.prisma.verification.updateMany({
        where: { id: { in: [old.id, doneOld.id] } },
        data: { createdAt: longAgo },
      });
      const deleted = await ctx.app.get(CleanupAwaitingRatesService).run();
      expect(deleted).toBe(1);
      await http()
        .get(`/api/v1/verifications/${old.id}`)
        .set(alice.auth)
        .expect(404);
      await http()
        .get(`/api/v1/verifications/${fresh.id}`)
        .set(alice.auth)
        .expect(200);
      await http()
        .get(`/api/v1/verifications/${doneOld.id}`)
        .set(alice.auth)
        .expect(200);
    });
  });

  describe('multi-currency and loyalty programs', () => {
    beforeEach(async () => {
      await http()
        .patch(`/api/v1/cards/${cardId}`)
        .set(alice.auth)
        .send({ currency: 'HNL' })
        .expect(200);
    });
    const hnl = (over: Partial<ExtractedStatement> = {}) =>
      hnlUsdTwoProgramsStatement({
        detectedRates: [
          detected({
            suggestedCategoryId: superCategoryId,
            ratePercent: d(7),
            evidence: '7% cashback en supermercados',
          }),
        ],
        ...over,
      });

    it('answers 422 REWARD_PROGRAM_AMBIGUOUS at confirm and resolves it by name', async () => {
      extraction.statement = hnl();
      const started = (await start(alice)).body;
      const amb = await confirm(alice, started.id, {
        categoryRates: [
          { categoryId: superCategoryId, ratePercent: '7' },
          { categoryId: pharmacyCategoryId, ratePercent: '0' },
        ],
      }).expect(422);
      expect(amb.body).toMatchObject({
        code: 'REWARD_PROGRAM_AMBIGUOUS',
        details: { programs: ['PUNTOS BAC CREDOMATIC', 'CASH BAC CREDOMATIC'] },
      });
      const res = await confirm(alice, started.id, {
        rewardProgramName: 'cash bac',
        categoryRates: [
          { categoryId: superCategoryId, ratePercent: '7' },
          { categoryId: pharmacyCategoryId, ratePercent: '0' },
        ],
      }).expect(200);
      expect(res.body).toMatchObject({
        reported: { amount: '134.5', label: 'CASH BAC CREDOMATIC' },
        loyalty: { selectedBy: 'REQUEST' },
      });
      expect(res.body.loyalty.programs[0]).toMatchObject({
        name: 'PUNTOS BAC CREDOMATIC',
        accumulated: '1500',
        available: '1400',
        redeemedInPeriod: '100',
        expiring: null,
      });
    });

    it('uses the program asked at upload, then USD lines need a rate', async () => {
      extraction.statement = hnl();
      const started = (await start(alice, { rewardProgramName: 'CASH' })).body;
      const rates = {
        baseRatePercent: '1',
        categoryRates: [
          { categoryId: superCategoryId, ratePercent: '7' },
          { categoryId: pharmacyCategoryId, ratePercent: '2' },
        ],
      };
      const without = (await confirm(alice, started.id, rates).expect(200))
        .body;
      // super 2000 * 7% = 140 ; pharmacy 500 * 2% = 10 ; USD excluded
      expect(without.expected.amount).toBe('150');
      expect(without.transactions[2]).toMatchObject({
        currency: 'USD',
        excludedReason: 'NO_EXCHANGE_RATE',
        convertedAmount: null,
        expectedReward: '0',
      });
      expect(without.warnings.map((w: any) => w.code)).toContain(
        'NO_EXCHANGE_RATE',
      );
      expect(without.currencies[1]).toMatchObject({
        currency: 'USD',
        eligibleSpent: '0',
        excludedCount: 1,
      });

      const withRate = (
        await confirm(alice, started.id, {
          ...rates,
          exchangeRate: '25',
        }).expect(200)
      ).body;
      // + USD 40 * 25 = 1000 at base 1% = 10
      expect(withRate.expected.amount).toBe('160');
      expect(withRate.conversion.requestedRate).toBe('25');
      expect(withRate.transactions[2]).toMatchObject({
        convertedAmount: '1000',
        exchangeRate: '25',
        exchangeRateSource: 'REQUEST',
        excludedReason: null,
      });
      expect(withRate.currencies[1]).toMatchObject({
        convertedEligibleSpent: '1000',
        expectedReward: '10',
      });
      expect(
        withRate.transactions
          .slice(3)
          .map((t: any) => [t.kind, t.excludedReason, t.expectedReward]),
      ).toEqual([
        ['INSURANCE', 'NON_PURCHASE_KIND', '0'],
        ['PAYMENT', 'NON_PURCHASE_KIND', '0'],
      ]);
    });

    it('uses the exchangeRate sent with the upload and the card rewardProgramName', async () => {
      extraction.statement = hnl();
      await http()
        .patch(`/api/v1/cards/${cardId}`)
        .set(alice.auth)
        .send({ rewardProgramName: 'PUNTOS' })
        .expect(200);
      const started = (await start(alice, { exchangeRate: '20' })).body;
      expect(started.conversion.requestedRate).toBe('20');
      const res = (
        await confirm(alice, started.id, {
          categoryRates: [
            { categoryId: superCategoryId, ratePercent: '7' },
            { categoryId: pharmacyCategoryId, ratePercent: '2' },
          ],
        }).expect(200)
      ).body;
      expect(res.loyalty.selectedBy).toBe('CARD');
      expect(res.reported.label).toBe('PUNTOS BAC CREDOMATIC');
      expect(res.transactions[2].convertedAmount).toBe('800');
    });
  });

  describe('reward currency and several exchange rates', () => {
    beforeEach(async () => {
      await http()
        .patch(`/api/v1/cards/${cardId}`)
        .set(alice.auth)
        .send({ currency: 'CRC', rules: [] })
        .expect(200);
      extraction.statement = crcUsdEurStatement();
    });
    const none = { baseRatePercent: '1', categoryRates: [] };

    it('exposes the conversions to collect and then audits in the reward currency', async () => {
      const started = (await start(alice)).body;
      expect(started.rewardConversion).toMatchObject({
        fromCurrency: 'CRC',
        toCurrency: 'USD',
        rate: null,
        source: 'NONE',
        required: true,
      });
      expect(started.exchangeRateProposal).toEqual([
        { currency: 'EUR', rate: null, source: 'NONE', required: false },
        { currency: 'USD', rate: null, source: 'NONE', required: false },
      ]);

      const missing = await confirm(alice, started.id, none).expect(422);
      expect(missing.body).toMatchObject({
        code: 'REWARD_EXCHANGE_RATE_REQUIRED',
        details: { fromCurrency: 'CRC', toCurrency: 'USD' },
      });

      const res = (
        await confirm(alice, started.id, {
          ...none,
          exchangeRates: { USD: '520', EUR: '560' },
          rewardExchangeRate: '520',
        }).expect(200)
      ).body;
      expect(res).toMatchObject({
        status: 'COMPLETED',
        rewardCurrency: 'USD',
        reported: { amount: '2.6', currency: 'USD' },
        expected: { amount: '2.62', currency: 'USD' },
        expectedInPrimaryCurrency: '1360',
        difference: '-0.02',
        tolerance: '1',
        verdict: 'MATCH',
        appliedRates: {
          rewardExchangeRate: {
            fromCurrency: 'CRC',
            toCurrency: 'USD',
            rate: '520',
            source: 'USER_ENTERED',
          },
        },
      });
      expect(res.transactions[1]).toMatchObject({
        convertedAmount: '52000',
        exchangeRate: '520',
        exchangeRateSource: 'REQUEST',
      });
      expect(res.conversion.requestedRates).toEqual({
        USD: '520',
        EUR: '560',
      });

      // Re-confirm changes the rate without a new Claude call.
      const calls = extraction.calls;
      const again = (
        await confirm(alice, started.id, {
          ...none,
          rewardExchangeRate: '500',
        }).expect(200)
      ).body;
      expect(again.expected.amount).toBe('2.72');
      expect(extraction.calls).toBe(calls);
    });

    it('leaves out only the foreign currency without a rate', async () => {
      const started = (await start(alice)).body;
      const res = (
        await confirm(alice, started.id, {
          ...none,
          exchangeRates: { USD: '520' },
        }).expect(200)
      ).body;
      expect(res.transactions.map((t: any) => t.excludedReason)).toEqual([
        null,
        null,
        'NO_EXCHANGE_RATE',
      ]);
      expect(
        res.currencies.map((c: any) => [c.currency, c.excludedCount]),
      ).toEqual([
        ['CRC', 0],
        ['USD', 0],
        ['EUR', 1],
      ]);
    });

    it('prefills from statement-printed rates and the card override wins', async () => {
      extraction.statement = crcUsdEurStatement({
        exchangeRates: [
          { from: 'USD', to: 'CRC', rate: d(520), source: 'STATEMENT' },
        ],
      });
      const started = (await start(alice)).body;
      expect(started.rewardConversion).toMatchObject({
        rate: '520',
        source: 'STATEMENT',
        required: false,
      });
      expect(started.exchangeRateProposal[1]).toMatchObject({
        currency: 'USD',
        rate: '520',
        source: 'STATEMENT',
      });
      const ok = (await confirm(alice, started.id, none).expect(200)).body;
      expect(ok.appliedRates.rewardExchangeRate.source).toBe(
        'STATEMENT_CONFIRMED',
      );

      await http()
        .patch(`/api/v1/cards/${cardId}`)
        .set(alice.auth)
        .send({ rewardCurrency: 'EUR' })
        .expect(200);
      const second = (await start(alice)).body;
      expect(second.rewardConversion).toMatchObject({ toCurrency: 'EUR' });
    });

    it('validates rates and rewardCurrency', async () => {
      const started = (await start(alice)).body;
      for (const body of [
        { exchangeRates: { USD: '0' } },
        { exchangeRates: { CRC: '1' } },
        { exchangeRates: 'x' },
        { rewardExchangeRate: 'abc' },
      ]) {
        await confirm(alice, started.id, { ...none, ...body }).expect(400);
      }
      await http()
        .patch(`/api/v1/cards/${cardId}`)
        .set(alice.auth)
        .send({ rewardCurrency: 'XX' })
        .expect(400);
      const cleared = await http()
        .patch(`/api/v1/cards/${cardId}`)
        .set(alice.auth)
        .send({ rewardCurrency: null })
        .expect(200);
      expect(cleared.body.rewardCurrency).toBeNull();
    });
  });

  describe('statement categories the user lacks', () => {
    const RESTAURANTS = 'Restaurantes y Comida rápida';
    const withHints = () =>
      mxn({
        detectedRates: [
          detected({ scope: 'BASE', ratePercent: d(1), evidence: '1% base' }),
          detected({
            categoryHint: RESTAURANTS,
            ratePercent: d(7),
            evidence: '7% Restaurantes y Comida rápida',
          }),
        ],
        transactions: [
          line('WAL MART SUC 123', 1000),
          line('POLLO CAMPERO 1', 120),
          line('POLLO CAMPERO 2', 130),
          line('PEMEX 4455', 300),
        ],
      });
    const fromSuggestions = (user: TestUser, id: string, names: string[]) =>
      http()
        .post(`/api/v1/verifications/${id}/categories-from-suggestions`)
        .set(user.auth)
        .send({ names });

    it('suggests the missing category and creates it, reassigning the lines', async () => {
      extraction.statement = withHints();
      const started = (await start(alice)).body;
      expect(started.suggestedCategories).toEqual([
        {
          name: RESTAURANTS,
          ratePercent: '7',
          evidence: '7% Restaurantes y Comida rápida',
          matchingTransactionCount: 2,
        },
      ]);
      expect(started.transactions[1]).toMatchObject({
        categoryId: null,
        matchSource: 'NONE',
        suggestedHint: RESTAURANTS,
      });
      const calls = extraction.calls;

      const res = (
        await fromSuggestions(alice, started.id, [RESTAURANTS]).expect(200)
      ).body;
      expect(extraction.calls).toBe(calls);
      expect(res.categoriesResult.created).toHaveLength(1);
      expect(res.categoriesResult.reused).toEqual([]);
      const newId = res.categoriesResult.created[0].id;
      expect(res.transactions.slice(1, 3)).toEqual([
        expect.objectContaining({
          categoryId: newId,
          categoryName: RESTAURANTS,
          matchSource: 'AI_CATEGORY',
          suggestedHint: null,
        }),
        expect.objectContaining({ categoryId: newId }),
      ]);
      expect(res.suggestedCategories).toEqual([]);
      expect(res.rateProposal).toContainEqual(
        expect.objectContaining({
          categoryId: newId,
          ratePercent: '7',
          source: 'STATEMENT',
          required: false,
        }),
      );

      const category = (
        await http()
          .get(`/api/v1/categories/${newId}`)
          .set(alice.auth)
          .expect(200)
      ).body;
      expect(category).toMatchObject({
        name: RESTAURANTS,
        description: RESTAURANTS,
      });

      // Calling again reuses the category and changes nothing else.
      const again = (
        await fromSuggestions(alice, started.id, [RESTAURANTS]).expect(200)
      ).body;
      expect(again.categoriesResult).toEqual({
        created: [],
        reused: [{ id: newId, name: RESTAURANTS }],
      });

      // The audit then counts the lines at the statement rate.
      const done = (
        await confirm(alice, started.id, {
          categoryRates: [
            { categoryId: superCategoryId, ratePercent: '5' },
            { categoryId: newId, ratePercent: '7' },
          ],
        }).expect(200)
      ).body;
      expect(
        done.breakdown.find((b: any) => b.categoryId === newId),
      ).toMatchObject({ spend: '250', expectedReward: '17.5' });
    });

    it('works on a completed verification, validates names and is per user', async () => {
      extraction.statement = withHints();
      const started = (await start(alice)).body;
      await confirm(alice, started.id).expect(200);
      await fromSuggestions(alice, started.id, [RESTAURANTS]).expect(200);
      await fromSuggestions(alice, started.id, []).expect(400);
      await http()
        .post(`/api/v1/verifications/${started.id}/categories-from-suggestions`)
        .set(alice.auth)
        .send({ names: [''] })
        .expect(400);
      await fromSuggestions(bob, started.id, [RESTAURANTS]).expect(404);
    });
  });

  describe('credit labeling', () => {
    it('exposes creditType: payments are never refunds, bonuses are other credits', async () => {
      extraction.statement = mxn({
        transactions: [
          line('WAL MART SUC 123', 1000),
          line('WAL MART SUC 123', 100, { isCredit: true, kind: 'REFUND' }),
          line('PAGO RECIBIDO', 500, { isCredit: true, kind: 'PAYMENT' }),
          line('BONO POR MEMBRESIA', 50, { isCredit: true, kind: 'OTHER' }),
        ],
      });
      const started = (await start(alice)).body;
      expect(
        started.transactions.map((t: any) => [t.kind, t.creditType]),
      ).toEqual([
        ['PURCHASE', null],
        ['REFUND', 'REFUND'],
        ['PAYMENT', 'PAYMENT'],
        ['OTHER', 'OTHER_CREDIT'],
      ]);
      const done = (await confirm(alice, started.id).expect(200)).body;
      expect(done.transactions[3]).toMatchObject({
        creditType: 'OTHER_CREDIT',
        excludedReason: 'NON_PURCHASE_KIND',
        expectedReward: '0',
      });
      expect(done.transactions[2].creditType).toBe('PAYMENT');
    });
  });

  describe('status and history', () => {
    it('lists both statuses and filters by status', async () => {
      const done = (await start(alice)).body;
      await confirm(alice, done.id).expect(200);
      const waiting = (await start(alice)).body;

      const all = await http()
        .get('/api/v1/verifications')
        .set(alice.auth)
        .expect(200);
      expect(all.body.total).toBe(2);
      const byId = Object.fromEntries(
        all.body.items.map((i: any) => [i.id, i]),
      );
      expect(byId[waiting.id]).toMatchObject({
        status: 'AWAITING_RATES',
        reportedAmount: null,
        expectedAmount: null,
        verdict: null,
        primaryCurrency: 'MXN',
      });
      expect(byId[done.id]).toMatchObject({
        status: 'COMPLETED',
        reportedAmount: '58',
        expectedAmount: '58',
        difference: '0',
        verdict: 'MATCH',
        rewardUnit: 'CASHBACK_CURRENCY',
      });
      const pending = await http()
        .get('/api/v1/verifications?status=AWAITING_RATES')
        .set(alice.auth)
        .expect(200);
      expect(pending.body.items.map((i: any) => i.id)).toEqual([waiting.id]);
      const completed = await http()
        .get('/api/v1/verifications?status=COMPLETED')
        .set(alice.auth)
        .expect(200);
      expect(completed.body.total).toBe(1);
      await http()
        .get('/api/v1/verifications?status=NOPE')
        .set(alice.auth)
        .expect(400);
    });

    it('returns the proposal for an awaiting verification on GET', async () => {
      const waiting = (await start(alice)).body;
      const got = await http()
        .get(`/api/v1/verifications/${waiting.id}`)
        .set(alice.auth)
        .expect(200);
      expect(got.body.rateProposal).toEqual(waiting.rateProposal);
      expect(got.body.status).toBe('AWAITING_RATES');
    });
  });

  describe('upload validation', () => {
    it('requires a file', async () => {
      const res = await upload(alice, {}, null).expect(400);
      expect(res.body.code).toBe('FILE_REQUIRED');
    });

    it('rejects non-PDF content types with 415', async () => {
      const res = await upload(alice, {}, PDF, 'image/png').expect(415);
      expect(res.body.code).toBe('UNSUPPORTED_MEDIA_TYPE');
    });

    it('rejects files that claim to be PDFs but are not (magic bytes)', async () => {
      const res = await upload(
        alice,
        {},
        Buffer.from('GIF89a not a pdf'),
      ).expect(400);
      expect(res.body.code).toBe('INVALID_PDF');
      expect(extraction.calls).toBe(0);
    });

    it('rejects files over 10 MB with 413', async () => {
      const big = Buffer.concat([
        Buffer.from('%PDF-1.7\n'),
        Buffer.alloc(10 * 1024 * 1024 + 1),
      ]);
      const res = await upload(alice, {}, big).expect(413);
      expect(res.body.code).toBe('PAYLOAD_TOO_LARGE');
      expect(extraction.calls).toBe(0);
    });

    it('validates cardId and the override', async () => {
      await upload(alice, { cardId: 'nope' }).expect(400);
    });
  });

  it("returns 404 for another user's card without calling Claude", async () => {
    const res = await upload(bob).expect(404);
    expect(res.body.code).toBe('CARD_NOT_FOUND');
    expect(extraction.calls).toBe(0);
  });

  describe('async lifecycle', () => {
    it('answers 202 PROCESSING at once and finishes in the background', async () => {
      const release = holdExtraction();
      const res = await upload(alice).expect(202);
      expect(res.body).toMatchObject({
        cardId,
        status: 'PROCESSING',
        failureCode: null,
        seenAt: null,
        primaryCurrency: 'MXN',
        transactions: [],
        detectedRates: [],
        verdict: null,
      });
      const id = res.body.id;
      // readable while processing
      const got = await http()
        .get(`/api/v1/verifications/${id}`)
        .set(alice.auth)
        .expect(200);
      expect(got.body.status).toBe('PROCESSING');
      // nothing can be done with it yet
      await confirm(alice, id).expect(409);
      await http()
        .patch(`/api/v1/verifications/${id}/transactions/0`)
        .set(alice.auth)
        .send({ categoryId: null })
        .expect(409);
      release();
      await processing().idle();
      const done = await http()
        .get(`/api/v1/verifications/${id}`)
        .set(alice.auth)
        .expect(200);
      expect(done.body.status).toBe('AWAITING_RATES');
      expect(done.body.transactions.length).toBeGreaterThan(0);
      expect(done.body.failureCode).toBeNull();
    });

    it('fails NOT_A_STATEMENT, refunds the credit and keeps it unseen', async () => {
      extraction.error = new UnreadableStatementError();
      const failed = (await start(alice)).body;
      expect(failed).toMatchObject({
        status: 'FAILED',
        failureCode: 'NOT_A_STATEMENT',
        seenAt: null,
        transactions: [],
      });
      expect(await attention(alice)).toEqual([
        expect.objectContaining({
          id: failed.id,
          status: 'FAILED',
          failureCode: 'NOT_A_STATEMENT',
        }),
      ]);
      await confirm(alice, failed.id).expect(409);
    });

    it('fails EXTRACTION_FAILED on any other error without leaking details', async () => {
      extraction.error = new ExtractionUnavailableError();
      const unavailable = (await start(alice)).body;
      expect(unavailable).toMatchObject({
        status: 'FAILED',
        failureCode: 'EXTRACTION_FAILED',
      });
      extraction.error = new Error('sk-ant-secret exploded');
      const crashed = (await start(alice)).body;
      expect(crashed).toMatchObject({
        status: 'FAILED',
        failureCode: 'EXTRACTION_FAILED',
      });
      expect(JSON.stringify(crashed)).not.toContain('sk-ant');
    });

    it('boot recovery turns orphaned PROCESSING rows into FAILED/INTERRUPTED with a refund', async () => {
      const id = '7d2f8c1e-5b1a-4c55-9d63-1a2b3c4d5e6f';
      await ctx.prisma.verification.create({
        data: {
          id,
          userId: alice.id,
          cardId,
          status: 'PROCESSING',
          processingStartedAt: new Date(),
          primaryCurrency: 'MXN',
          reportedUnit: 'CASHBACK_CURRENCY',
          breakdown: [],
          transactions: [],
          warnings: [],
          model: '',
        },
      });
      expect(await processing().recoverInterrupted()).toBe(1);
      const got = await http()
        .get(`/api/v1/verifications/${id}`)
        .set(alice.auth)
        .expect(200);
      expect(got.body).toMatchObject({
        status: 'FAILED',
        failureCode: 'INTERRUPTED',
        seenAt: null,
      });
      // running it again finds nothing
      expect(await processing().recoverInterrupted()).toBe(0);
    });

    it('the AWAITING_RATES cleanup never touches PROCESSING rows', async () => {
      const release = holdExtraction();
      const res = await upload(alice).expect(202);
      await ctx.prisma.verification.update({
        where: { id: res.body.id },
        data: { createdAt: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) },
      });
      expect(await ctx.app.get(CleanupAwaitingRatesService).run()).toBe(0);
      release();
      await processing().idle();
    });
  });

  describe('last-used currency rates', () => {
    const profile = async () =>
      (await http().get('/api/v1/me').set(alice.auth).expect(200)).body;

    it('confirming with exchange rates remembers them in the user currencies', async () => {
      const v = (await start(alice)).body;
      await confirm(alice, v.id, { exchangeRates: { USD: '24.5' } }).expect(
        200,
      );
      expect((await profile()).currencies).toEqual([
        expect.objectContaining({ code: 'USD', lastRateToPrimary: '24.5' }),
      ]);
      // a newer confirmation updates the last rate
      await confirm(alice, v.id, { exchangeRates: { USD: '25' } }).expect(200);
      expect((await profile()).currencies).toEqual([
        expect.objectContaining({ code: 'USD', lastRateToPrimary: '25' }),
      ]);
      // confirming without rates changes nothing
      await confirm(alice, v.id).expect(200);
      expect((await profile()).currencies).toHaveLength(1);
    });

    it('skips them when the user primary currency differs from the card currency', async () => {
      await http()
        .patch('/api/v1/me/preferences')
        .set(alice.auth)
        .send({ primaryCurrency: 'HNL' })
        .expect(200);
      const v = (await start(alice)).body; // the card is MXN
      await confirm(alice, v.id, { exchangeRates: { USD: '24.5' } }).expect(
        200,
      );
      expect((await profile()).currencies).toEqual([]);
    });
  });

  describe('attention and seen', () => {
    it('lists in-flight, awaiting and unseen results, newest first, per user', async () => {
      const completed = (await start(alice)).body;
      await confirm(alice, completed.id).expect(200);
      extraction.error = new UnreadableStatementError();
      const failed = (await start(alice)).body;
      extraction.error = undefined;
      const awaiting = (await start(alice)).body;
      const release = holdExtraction();
      const inFlight = (await upload(alice).expect(202)).body;

      expect((await attention(alice)).map((i) => [i.id, i.status])).toEqual([
        [inFlight.id, 'PROCESSING'],
        [awaiting.id, 'AWAITING_RATES'],
        [failed.id, 'FAILED'],
        [completed.id, 'COMPLETED'],
      ]);
      expect(await attention(bob)).toEqual([]);

      // once seen, FAILED and COMPLETED leave; the others stay until resolved
      await http()
        .post(`/api/v1/verifications/${failed.id}/seen`)
        .set(alice.auth)
        .expect(204);
      await http()
        .post(`/api/v1/verifications/${completed.id}/seen`)
        .set(alice.auth)
        .expect(204);
      await http()
        .post(`/api/v1/verifications/${awaiting.id}/seen`)
        .set(alice.auth)
        .expect(204);
      expect((await attention(alice)).map((i) => i.status)).toEqual([
        'PROCESSING',
        'AWAITING_RATES',
      ]);
      release();
      await processing().idle();
    });

    it('seen is idempotent, keeps the first timestamp and shows in list/get', async () => {
      const v = (await start(alice)).body;
      await confirm(alice, v.id).expect(200);
      const seen = () =>
        http().post(`/api/v1/verifications/${v.id}/seen`).set(alice.auth);
      await seen().expect(204);
      const first = (
        await http().get(`/api/v1/verifications/${v.id}`).set(alice.auth)
      ).body.seenAt;
      expect(first).toEqual(expect.any(String));
      await seen().expect(204);
      const again = (
        await http().get(`/api/v1/verifications/${v.id}`).set(alice.auth)
      ).body.seenAt;
      expect(again).toBe(first);
      const list = await http()
        .get('/api/v1/verifications')
        .set(alice.auth)
        .expect(200);
      expect(list.body.items[0]).toMatchObject({
        id: v.id,
        status: 'COMPLETED',
        failureCode: null,
        seenAt: first,
      });
    });

    it('enforces ownership and validates the id', async () => {
      const v = (await start(alice)).body;
      const res = await http()
        .post(`/api/v1/verifications/${v.id}/seen`)
        .set(bob.auth)
        .expect(404);
      expect(res.body.code).toBe('VERIFICATION_NOT_FOUND');
      await http()
        .post('/api/v1/verifications/nope/seen')
        .set(alice.auth)
        .expect(400);
      await http()
        .post('/api/v1/verifications/00000000-0000-4000-8000-000000000000/seen')
        .set(alice.auth)
        .expect(404);
      await http().get('/api/v1/verifications/attention').expect(401);
      await http().post(`/api/v1/verifications/${v.id}/seen`).expect(401);
      // alice's row was not marked by bob's attempt
      expect(
        (await http().get(`/api/v1/verifications/${v.id}`).set(alice.auth)).body
          .seenAt,
      ).toBeNull();
    });

    it('filters the list by the new statuses', async () => {
      extraction.error = new Error('x');
      const failed = (await start(alice)).body;
      const res = await http()
        .get('/api/v1/verifications?status=FAILED')
        .set(alice.auth)
        .expect(200);
      expect(res.body.items.map((i: any) => i.id)).toEqual([failed.id]);
      await http()
        .get('/api/v1/verifications?status=PROCESSING')
        .set(alice.auth)
        .expect(200);
    });
  });

  describe('history', () => {
    it('lists newest first with pagination, filtered by card, scoped to the user', async () => {
      for (let i = 0; i < 3; i++) {
        const v = (await start(alice)).body;
        await confirm(alice, v.id).expect(200);
      }
      const all = await http()
        .get('/api/v1/verifications')
        .set(alice.auth)
        .expect(200);
      expect(all.body).toMatchObject({ page: 1, pageSize: 20, total: 3 });
      expect(all.body.items).toHaveLength(3);
      expect(all.body.items[0]).toMatchObject({
        cardId,
        verdict: 'MATCH',
        reportedAmount: '58',
        expectedAmount: '58',
        rewardUnit: 'CASHBACK_CURRENCY',
      });
      expect(all.body.items[0].transactions).toBeUndefined();
      const times = all.body.items.map((i: any) => i.createdAt);
      expect([...times].sort((a, b) => b.localeCompare(a))).toEqual(times);

      const page2 = await http()
        .get('/api/v1/verifications?pageSize=2&page=2')
        .set(alice.auth)
        .expect(200);
      expect(page2.body.items).toHaveLength(1);
      expect(page2.body.total).toBe(3);

      const byCard = await http()
        .get(`/api/v1/verifications?cardId=${cardId}`)
        .set(alice.auth)
        .expect(200);
      expect(byCard.body.total).toBe(3);

      expect(
        (await http().get('/api/v1/verifications').set(bob.auth)).body.total,
      ).toBe(0);
      await http()
        .get(`/api/v1/verifications?cardId=${cardId}`)
        .set(bob.auth)
        .expect(404);
      await http()
        .get('/api/v1/verifications?pageSize=101')
        .set(alice.auth)
        .expect(400);
    });

    it('isolates get/delete between users and deletes', async () => {
      const created = (await start(alice)).body;
      await http()
        .get(`/api/v1/verifications/${created.id}`)
        .set(bob.auth)
        .expect(404);
      await http()
        .delete(`/api/v1/verifications/${created.id}`)
        .set(bob.auth)
        .expect(404);
      await http()
        .delete(`/api/v1/verifications/${created.id}`)
        .set(alice.auth)
        .expect(204);
      await http()
        .get(`/api/v1/verifications/${created.id}`)
        .set(alice.auth)
        .expect(404);
    });

    it('removes history when its card is deleted', async () => {
      const created = (await start(alice)).body;
      await http()
        .delete(`/api/v1/cards/${cardId}`)
        .set(alice.auth)
        .expect(204);
      await http()
        .get(`/api/v1/verifications/${created.id}`)
        .set(alice.auth)
        .expect(404);
    });
  });
});
