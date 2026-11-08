import request from 'supertest';
import { Decimal } from 'decimal.js';
import { ExtractionUnavailableError } from '../src/verifications/domain/verification-errors.js';
import {
  MerchantClassifier,
  StatementExtractor,
} from '../src/verifications/domain/statement-extractor.js';
import type { ExtractedStatement } from '../src/verifications/domain/statement.js';
import {
  createTestApp,
  resetDatabase,
  signInAs,
  type TestApp,
  type TestUser,
} from './test-app.js';

const d = (v: string | number) => new Decimal(v);
const PDF = Buffer.from('%PDF-1.7\n%fake statement\n');

const sampleStatement = (
  over: Partial<ExtractedStatement> = {},
): ExtractedStatement => ({
  bank: 'BBVA',
  cardLast4: '4321',
  periodStart: '2026-01-01',
  periodEnd: '2026-01-31',
  currency: 'MXN',
  totalSpent: d(1400),
  totalToPay: d(1400),
  reportedReward: {
    amount: d(58),
    unit: 'CURRENCY',
    label: 'Bonificación del periodo',
  },
  transactions: [
    {
      date: '2026-01-02',
      merchant: 'WAL MART SUC 123',
      amount: d(1000),
      isCredit: false,
    },
    {
      date: '2026-01-03',
      merchant: 'WM SUPERCENTER',
      amount: d(200),
      isCredit: false,
    },
    {
      date: '2026-01-04',
      merchant: 'PEMEX 4455',
      amount: d(300),
      isCredit: false,
    },
    {
      date: '2026-01-06',
      merchant: 'WAL MART SUC 123',
      amount: d(100),
      isCredit: true,
    },
  ],
  ...over,
});

describe('Verifications (e2e)', () => {
  let ctx: TestApp;
  let alice: TestUser;
  let bob: TestUser;
  let extraction: {
    statement?: ExtractedStatement;
    error?: Error;
    calls: number;
  };
  const http = () => request(ctx.app.getHttpServer());

  const extractorStub = {
    extract: async () => {
      extraction.calls++;
      if (extraction.error) throw extraction.error;
      return {
        statement: extraction.statement ?? sampleStatement(),
        model: 'stub-model',
      };
    },
  };
  const classifierStub = {
    classify: async (descriptors: string[]) =>
      descriptors.map((descriptor) => ({
        descriptor,
        merchantId: descriptor === 'WM SUPERCENTER' ? aiMerchantId : null,
        confidence: 0.85,
      })),
  };
  let aiMerchantId: string;

  beforeAll(async () => {
    ctx = await createTestApp([
      { token: StatementExtractor, useValue: extractorStub },
      { token: MerchantClassifier, useValue: classifierStub },
    ]);
  });
  afterAll(() => ctx.close());

  let cardId: string;
  beforeEach(async () => {
    extraction = { calls: 0 };
    await resetDatabase(ctx.prisma);
    alice = await signInAs(ctx.app, 'alice');
    bob = await signInAs(ctx.app, 'bob');

    const cat = (
      await http()
        .post('/api/v1/categories')
        .set(alice.auth)
        .send({ name: 'Supermarkets' })
    ).body;
    const merchant = (
      await http()
        .post('/api/v1/merchants')
        .set(alice.auth)
        .send({ name: 'Walmart', keywords: ['WAL MART'], categoryId: cat.id })
    ).body;
    aiMerchantId = merchant.id;
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

  it('requires authentication', async () => {
    await http().post('/api/v1/verifications').expect(401);
    await http().get('/api/v1/verifications').expect(401);
  });

  it('happy path: extracts, matches (keyword + AI), computes and stores the verdict', async () => {
    const res = await upload(alice).expect(201);

    // super: 1000 + 200 - 100 = 1100 * 5% = 55 ; base: 300 * 1% = 3 ; expected 58
    expect(res.body).toMatchObject({
      cardId,
      statement: {
        bank: 'BBVA',
        cardLast4: '4321',
        periodStart: '2026-01-01',
        periodEnd: '2026-01-31',
        currency: 'MXN',
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
      model: 'stub-model',
      warnings: [],
    });
    expect(
      res.body.transactions.map((t: any) => [
        t.merchant,
        t.matchSource,
        t.ruleApplied,
        t.appliedRatePercent,
        t.expectedReward,
      ]),
    ).toEqual([
      ['WAL MART SUC 123', 'KEYWORD', true, '5', '50'],
      ['WM SUPERCENTER', 'AI', true, '5', '10'],
      ['PEMEX 4455', 'NONE', false, '1', '3'],
      ['WAL MART SUC 123', 'KEYWORD', true, '5', '-5'],
    ]);
    expect(res.body.transactions[1]).toMatchObject({
      matchConfidence: 0.85,
      categoryName: 'Supermarkets',
      matchedMerchantName: 'Walmart',
    });
    expect(res.body.breakdown[0]).toMatchObject({
      categoryName: 'Supermarkets',
      spend: '1100',
      expectedReward: '55',
      capped: false,
    });
    expect(res.body.breakdown[1]).toMatchObject({
      categoryId: null,
      expectedReward: '3',
    });

    const stored = await http()
      .get(`/api/v1/verifications/${res.body.id}`)
      .set(alice.auth)
      .expect(200);
    expect(stored.body).toEqual(res.body);
  });

  it('flags an underpaid statement', async () => {
    extraction.statement = sampleStatement({
      reportedReward: { amount: d(30), unit: 'CURRENCY', label: 'x' },
    });
    const res = await upload(alice).expect(201);
    expect(res.body).toMatchObject({ verdict: 'UNDERPAID', difference: '-28' });
  });

  it('accepts reportedRewardOverride and uses it', async () => {
    extraction.statement = sampleStatement({ reportedReward: null });
    await upload(alice)
      .expect(422)
      .expect((r) => expect(r.body.code).toBe('REPORTED_REWARD_NOT_FOUND'));
    const res = await upload(alice, { reportedRewardOverride: '70.5' }).expect(
      201,
    );
    expect(res.body).toMatchObject({
      verdict: 'OVERPAID',
      reported: { amount: '70.5', source: 'OVERRIDE' },
      difference: '12.5',
    });
  });

  it('warns when the statement belongs to another card', async () => {
    extraction.statement = sampleStatement({ cardLast4: '9999' });
    const res = await upload(alice).expect(201);
    expect(res.body.warnings.map((w: any) => w.code)).toContain(
      'CARD_LAST4_MISMATCH',
    );
  });

  it('never persists the PDF: only extracted data is stored', async () => {
    const res = await upload(alice).expect(201);
    const row = await ctx.prisma.verification.findUniqueOrThrow({
      where: { id: res.body.id },
    });
    expect(JSON.stringify(row)).not.toContain(PDF.toString('base64'));
    expect(JSON.stringify(row)).not.toContain('%PDF');
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
      await upload(alice, { reportedRewardOverride: '-3' }).expect(400);
      await upload(alice, { reportedRewardOverride: 'abc' }).expect(400);
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
      for (let i = 0; i < 3; i++) await upload(alice).expect(201);
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
