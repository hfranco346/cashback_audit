import request from 'supertest';
import { CleanupAwaitingRatesService } from '../src/verifications/application/cleanup-awaiting-rates.service.js';
import { ExtractionUnavailableError } from '../src/verifications/domain/verification-errors.js';
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
        categoryId: descriptor.includes('FARMACIA')
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
      const res = await upload(alice).expect(201);
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
      const res = await upload(alice).expect(201);
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
      const stated = await upload(alice).expect(201);
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
      const res = await upload(alice).expect(201);
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
      await upload(alice, { rewardProgramName: '' }).expect(201);
    });

    it('never persists the PDF: only extracted data is stored', async () => {
      const res = await upload(alice).expect(201);
      const row = await ctx.prisma.verification.findUniqueOrThrow({
        where: { id: res.body.id },
      });
      expect(JSON.stringify(row)).not.toContain(PDF.toString('base64'));
      expect(JSON.stringify(row)).not.toContain('%PDF');
    });

    it('warns when the statement belongs to another card', async () => {
      extraction.statement = mxn({ cardLast4: '9999' });
      const res = await upload(alice).expect(201);
      expect(res.body.warnings.map((w: any) => w.code)).toContain(
        'CARD_LAST4_MISMATCH',
      );
    });
  });

  describe('step 2: confirm', () => {
    it('audits with the confirmed rates, stores appliedRates and completes', async () => {
      const started = (await upload(alice).expect(201)).body;
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
      const started = (await upload(alice).expect(201)).body;
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
      const started = (await upload(alice).expect(201)).body;
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
      const started = (await upload(alice).expect(201)).body;
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
      const started = (await upload(alice).expect(201)).body;
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
      const started = (await upload(alice).expect(201)).body;
      const under = await confirm(alice, started.id).expect(200);
      expect(under.body).toMatchObject({
        verdict: 'UNDERPAID',
        difference: '-28',
      });

      extraction.statement = mxn({ loyaltyPrograms: [] });
      const none = (await upload(alice).expect(201)).body;
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
      const started = (await upload(alice).expect(201)).body;
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
      const started = (await upload(alice).expect(201)).body;
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
      const started = (await upload(alice).expect(201)).body;
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
      const started = (await upload(alice).expect(201)).body;
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
      const started = (await upload(alice).expect(201)).body;
      const res = await patch(alice, started.id, 0, {
        categoryId: superCategoryId,
      }).expect(422);
      expect(res.body.code).toBe('TRANSACTION_NOT_CLASSIFIABLE');
    });
  });

  describe('cleanup of abandoned verifications', () => {
    it('deletes AWAITING_RATES older than the TTL and keeps everything else', async () => {
      const old = (await upload(alice).expect(201)).body;
      const fresh = (await upload(alice).expect(201)).body;
      const doneOld = (await upload(alice).expect(201)).body;
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
      const started = (await upload(alice).expect(201)).body;
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
      const started = (
        await upload(alice, { rewardProgramName: 'CASH' }).expect(201)
      ).body;
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
      const started = (await upload(alice, { exchangeRate: '20' }).expect(201))
        .body;
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
      const started = (await upload(alice).expect(201)).body;
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
      const started = (await upload(alice).expect(201)).body;
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
      const started = (await upload(alice).expect(201)).body;
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
      const second = (await upload(alice).expect(201)).body;
      expect(second.rewardConversion).toMatchObject({ toCurrency: 'EUR' });
    });

    it('validates rates and rewardCurrency', async () => {
      const started = (await upload(alice).expect(201)).body;
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

  describe('status and history', () => {
    it('lists both statuses and filters by status', async () => {
      const done = (await upload(alice).expect(201)).body;
      await confirm(alice, done.id).expect(200);
      const waiting = (await upload(alice).expect(201)).body;

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
      const waiting = (await upload(alice).expect(201)).body;
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

  describe('upstream failures', () => {
    it('maps an unavailable analysis service to 503', async () => {
      extraction.error = new ExtractionUnavailableError();
      const res = await upload(alice).expect(503);
      expect(res.body).toMatchObject({
        statusCode: 503,
        code: 'EXTRACTION_UNAVAILABLE',
      });
    });

    it('maps unexpected extractor crashes to a generic 500 without leaking details', async () => {
      extraction.error = new Error('sk-ant-secret exploded');
      const res = await upload(alice).expect(500);
      expect(JSON.stringify(res.body)).not.toContain('sk-ant');
    });
  });

  describe('history', () => {
    it('lists newest first with pagination, filtered by card, scoped to the user', async () => {
      for (let i = 0; i < 3; i++) {
        const v = (await upload(alice).expect(201)).body;
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
      const created = (await upload(alice).expect(201)).body;
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
      const created = (await upload(alice).expect(201)).body;
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
