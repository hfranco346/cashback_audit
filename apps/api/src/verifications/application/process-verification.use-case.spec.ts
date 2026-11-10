import { Decimal } from 'decimal.js';
import type { Card } from '../../cards/domain/card.js';
import { CategoryRepository } from '../../categories/domain/category.repository.js';
import type { Merchant } from '../../merchants/domain/merchant.js';
import { MerchantRepository } from '../../merchants/domain/merchant.repository.js';
import {
  CAT_PHARMACY,
  CAT_SUPER,
  d,
  detected,
  hnlUsdTwoProgramsStatement,
  line,
  mxnCashbackStatement,
  program,
  usdMilesStatement,
} from '../../../test/fixtures/statements.js';
import type {
  ExtractedStatement,
  LineClassification,
} from '../domain/statement.js';
import {
  LineClassifier,
  StatementExtractor,
} from '../domain/statement-extractor.js';
import type {
  Verification,
  VerificationUpdate,
} from '../domain/verification.js';
import { VerificationRepository } from '../domain/verification.repository.js';
import { ProcessVerificationUseCase } from './process-verification.use-case.js';

const USER = 'user-1';
const pdf = Buffer.from('%PDF-1.4 fake');

export const card: Card = {
  id: 'card-1',
  userId: USER,
  alias: 'Daily',
  bank: 'Example',
  last4: '4321',
  network: null,
  rewardUnit: 'CASHBACK_CURRENCY',
  pointsPerCurrencyUnit: d(1),
  baseRatePercent: d(1),
  currency: 'MXN',
  rewardProgramName: null,
  rewardCurrency: null,
  claimEmail: null,
  rewardReporting: 'AUTO',
  rewardCap: null,
  rules: [{ categoryId: CAT_SUPER, ratePercent: d(5), monthlyCap: null }],
  createdAt: new Date(),
  updatedAt: new Date(),
};
const merchant = (
  id: string,
  name: string,
  keywords: string[],
  categoryId = CAT_SUPER,
): Merchant => ({
  id,
  userId: USER,
  name,
  keywords,
  categoryId,
  createdAt: new Date(),
  updatedAt: new Date(),
});
const merchants = [
  merchant('m-wal', 'Walmart', ['WAL MART']),
  merchant('m-sor', 'Soriana', []),
];

const defaultCategories = [
  { id: CAT_SUPER, name: 'Supermarkets', description: null },
  {
    id: CAT_PHARMACY,
    name: 'Pharmacies',
    description: 'pharmacies, drugstores',
  },
];

function setup(opts: {
  statement?: ExtractedStatement;
  merchants?: Merchant[];
  guesses?: LineClassification[] | Error;
  unclassified?: string[];
  categories?: { id: string; name: string; description: string | null }[];
  card?: Card;
  extractError?: Error;
}) {
  const saved: VerificationUpdate[] = [];
  const classifierCalls: string[][] = [];
  const categoryCalls: unknown[][] = [];
  const extractorContexts: unknown[] = [];
  const useCase = new ProcessVerificationUseCase(
    {
      listWithCounts: async () =>
        (opts.categories ?? defaultCategories).map((c) => ({
          ...c,
          userId: USER,
          merchantCount: 0,
          createdAt: new Date(),
          updatedAt: new Date(),
        })),
    } as unknown as CategoryRepository,
    {
      list: async () => opts.merchants ?? merchants,
    } as unknown as MerchantRepository,
    {
      extract: async (_pdf: Buffer, context: unknown) => {
        extractorContexts.push(context);
        if (opts.extractError) throw opts.extractError;
        return {
          statement: opts.statement ?? mxnCashbackStatement(),
          model: 'test-model',
        };
      },
    } as unknown as StatementExtractor,
    {
      classify: async (descriptors: string[], categories: unknown[]) => {
        classifierCalls.push(descriptors);
        categoryCalls.push(categories);
        if (opts.guesses instanceof Error) throw opts.guesses;
        return {
          results: opts.guesses ?? [],
          unclassified: opts.unclassified ?? [],
          model: 'test-classifier',
        };
      },
    } as unknown as LineClassifier,
    {
      update: async (_user: string, id: string, patch: VerificationUpdate) => {
        saved.push(patch);
        return { ...patch, id, createdAt: new Date() } as Verification;
      },
    } as unknown as VerificationRepository,
    0.7,
  );
  return {
    useCase,
    card: opts.card ?? card,
    saved,
    classifierCalls,
    categoryCalls,
    extractorContexts,
  };
}

/** Runs the job and returns what the processor stored on the verification. */
const run = async (
  s: ReturnType<typeof setup>,
  extra: { exchangeRate?: string; rewardProgramName?: string } = {},
  cardOverride?: Card,
) => {
  await s.useCase.execute({
    verificationId: 'v-1',
    userId: USER,
    card: cardOverride ?? s.card,
    pdf,
    ...extra,
  });
  return s.saved.at(-1) as Verification;
};

const verdict = (
  descriptor: string,
  over: Partial<LineClassification> = {},
): LineClassification => ({
  descriptor,
  categoryId: CAT_SUPER,
  matchedMerchantId: null,
  confidence: 0.9,
  reason: 'looks like a supermarket',
  ...over,
});

describe('ProcessVerificationUseCase (step 1)', () => {
  it('stores the extraction on the verification and ends AWAITING_RATES', async () => {
    const s = setup({});
    await run(s);
    expect(s.saved).toHaveLength(1);
    expect(s.saved[0]).toMatchObject({
      status: 'AWAITING_RATES',
      failureCode: null,
    });
    expect(s.saved[0]!.processedAt).toBeInstanceOf(Date);
  });

  it('persists AWAITING_RATES with no reward figures', async () => {
    const s = setup({});
    const v = await run(s);
    expect(v.status).toBe('AWAITING_RATES');
    expect(v).toMatchObject({
      reportedAmount: null,
      expectedAmount: null,
      difference: null,
      tolerance: null,
      verdict: null,
      appliedRates: null,
      explanation: null,
      breakdown: [],
    });
    expect(v.transactions.every((t) => t.expectedReward === null)).toBe(true);
    expect(v.transactions.every((t) => t.appliedRatePercent === null)).toBe(
      true,
    );
    expect(v.detectedRates).toHaveLength(2);
    expect(v.models).toEqual({
      extraction: 'test-model',
      classification: 'test-classifier',
      explanation: null,
    });
  });

  it('gives the extractor the user categories as context', async () => {
    const s = setup({});
    await run(s);
    expect(s.extractorContexts[0]).toEqual({ categories: defaultCategories });
  });

  it('matches by keyword first and sends only unmatched purchase lines to the classifier', async () => {
    const s = setup({
      statement: mxnCashbackStatement({
        transactions: [
          line('WALMART SUC 123', 1000),
          line('SORIANA HIPER', 200),
          line('WM SUPERCENTER 9', 100),
          line('UBER TRIP', 100),
          line('INTERESES', 30, { kind: 'INTEREST' }),
        ],
      }),
    });
    await run(s);
    expect(s.classifierCalls).toEqual([['WM SUPERCENTER 9', 'UBER TRIP']]);
  });

  it('maps classifier results to AI_MERCHANT / AI_CATEGORY and applies the threshold', async () => {
    const s = setup({
      statement: mxnCashbackStatement({
        transactions: [
          line('WALMART SUC 123', 1000),
          line('WM SUPERCENTER 9', 100),
          line('FARMACIA X', 50),
          line('UBER TRIP', 100),
        ],
      }),
      guesses: [
        verdict('WM SUPERCENTER 9', { matchedMerchantId: 'm-wal' }),
        verdict('FARMACIA X', { categoryId: CAT_PHARMACY, confidence: 0.7 }),
        verdict('UBER TRIP', { confidence: 0.69 }),
      ],
    });
    const v = await run(s);
    expect(
      v.transactions.map((t) => [
        t.matchSource,
        t.matchedMerchantId,
        t.categoryId,
      ]),
    ).toEqual([
      ['KEYWORD', 'm-wal', CAT_SUPER],
      ['AI_MERCHANT', 'm-wal', CAT_SUPER],
      ['AI_CATEGORY', null, CAT_PHARMACY],
      ['NONE', null, null],
    ]);
    expect(v.transactions[1]).toMatchObject({
      matchConfidence: 0.9,
      matchReason: 'looks like a supermarket',
      categoryName: 'Supermarkets',
    });
  });

  it('rejects classifier ids that are not the user categories', async () => {
    const v = await run(
      setup({
        statement: mxnCashbackStatement({ transactions: [line('X', 10)] }),
        guesses: [verdict('X', { categoryId: 'cat-unknown' })],
      }),
    );
    expect(v.transactions[0]!.matchSource).toBe('NONE');
  });

  it('offers every category (merchants as examples) to the classifier', async () => {
    const s = setup({});
    await run(s);
    const sent = s.categoryCalls[0] as {
      id: string;
      description: string | null;
      merchants: { id: string }[];
    }[];
    expect(sent.map((c) => c.id)).toEqual([CAT_SUPER, CAT_PHARMACY]);
    expect(sent[0]!.merchants.map((m) => m.id)).toEqual(['m-wal', 'm-sor']);
    expect(sent[1]).toMatchObject({
      description: 'pharmacies, drugstores',
      merchants: [],
    });
  });

  it('classifies into categories that have no merchants at all', async () => {
    const s = setup({
      merchants: [],
      statement: mxnCashbackStatement({
        transactions: [line('FARMACIA SIMAN', 100)],
      }),
      guesses: [verdict('FARMACIA SIMAN', { categoryId: CAT_PHARMACY })],
    });
    const v = await run(s);
    expect(v.transactions[0]).toMatchObject({
      matchSource: 'AI_CATEGORY',
      categoryName: 'Pharmacies',
    });
  });

  it('records the classification model only when the classifier ran', async () => {
    const skipped = await run(
      setup({
        statement: mxnCashbackStatement({
          transactions: [line('WALMART', 100)],
        }),
      }),
    );
    expect(skipped.models.classification).toBeNull();
    const none = await run(setup({ categories: [], merchants: [] }));
    expect(none.models.classification).toBeNull();
  });

  it('keeps going with a warning when the classifier fails or skips lines', async () => {
    const failed = await run(setup({ guesses: new Error('boom') }));
    expect(failed.warnings.map((w) => w.code)).toContain(
      'AI_MATCHING_UNAVAILABLE',
    );
    expect(failed.models.classification).toBeNull();
    const partial = await run(
      setup({ guesses: [], unclassified: ['PEMEX 4455'] }),
    );
    expect(partial.warnings.map((w) => w.code)).toContain(
      'AI_MATCHING_UNAVAILABLE',
    );
  });

  it('flags non-purchase kinds as excluded and never classifies them', async () => {
    const s = setup({
      statement: hnlUsdTwoProgramsStatement(),
      card: { ...card, currency: 'HNL' },
    });
    const v = await run(s);
    expect(s.classifierCalls[0]).not.toContain('SEGURO DE SALDO DE DEUDA');
    expect(s.classifierCalls[0]).not.toContain('PAGO RECIBIDO');
    expect(v.transactions.map((t) => t.excludedReason)).toEqual([
      null,
      null,
      null,
      'NON_PURCHASE_KIND',
      'NON_PURCHASE_KIND',
    ]);
  });

  it('proposes (never throws) the loyalty program and stores every program', async () => {
    const ambiguous = await run(
      setup({
        statement: hnlUsdTwoProgramsStatement(),
        card: { ...card, currency: 'HNL' },
      }),
    );
    expect(ambiguous.loyalty.selected).toBeNull();
    expect(ambiguous.loyalty.programs).toHaveLength(2);

    const chosen = await run(
      setup({
        statement: hnlUsdTwoProgramsStatement(),
        card: { ...card, currency: 'HNL' },
      }),
      { rewardProgramName: 'cash bac' },
    );
    expect(chosen.loyalty).toMatchObject({
      selectedBy: 'REQUEST',
      requestedProgramName: 'cash bac',
    });
    expect(chosen.loyalty.selected!.name).toBe('CASH BAC CREDOMATIC');

    const miles = await run(setup({ statement: usdMilesStatement() }));
    expect(miles.loyalty.selectedBy).toBe('ONLY_PROGRAM');
  });

  it('stores the requested exchange rate, summaries and primary totals', async () => {
    const v = await run(
      setup({
        statement: hnlUsdTwoProgramsStatement(),
        card: { ...card, currency: 'HNL' },
      }),
      { exchangeRate: '26.35' },
    );
    expect(v.primaryCurrency).toBe('HNL');
    expect(v.conversion.requestedRate!.toString()).toBe('26.35');
    expect(v.totalSpent!.toString()).toBe('2670');
    expect(v.totalToPay!.toString()).toBe('3170');
    expect(v.summaries).toHaveLength(2);
  });

  it('warns about last4, currencies and total gaps', async () => {
    const v = await run(
      setup({
        statement: mxnCashbackStatement({
          cardLast4: '9999',
          summaries: [
            {
              currency: 'USD',
              previousBalance: null,
              purchasesAndCharges: d(5000),
              purchases: null,
              chargesAndInterest: null,
              totalBalance: null,
            },
          ],
          transactions: [line('WALMART', 100, { currency: 'USD' })],
        }),
      }),
    );
    expect(v.warnings.map((w) => w.code).sort()).toEqual([
      'CARD_LAST4_MISMATCH',
      'CURRENCY_MISMATCH',
      'TOTAL_SPENT_MISMATCH',
    ]);
  });

  it('stores an empty statement with a warning', async () => {
    const v = await run(
      setup({ statement: mxnCashbackStatement({ transactions: [] }) }),
    );
    expect(v.warnings.map((w) => w.code)).toContain('NO_TRANSACTIONS');
  });

  it('keeps Decimal amounts exact', async () => {
    const v = await run(setup({}));
    expect(v.transactions[0]!.amount).toBeInstanceOf(Decimal);
    expect(program('x', '1').accumulated).toBeInstanceOf(Decimal);
  });
});

describe('ProcessVerificationUseCase: statement category hints', () => {
  const ficohsa = (over: Partial<ExtractedStatement> = {}) =>
    mxnCashbackStatement({
      detectedRates: [
        detected({
          categoryHint: 'Farmacias y Hospitales',
          suggestedCategoryId: CAT_PHARMACY,
          ratePercent: d(7),
          evidence: '7% Farmacias y Hospitales',
        }),
        detected({
          categoryHint: 'Restaurantes y Comida rápida',
          ratePercent: d(7),
          evidence: '7% Restaurantes y Comida rápida',
        }),
      ],
      transactions: [
        line('HOSPITAL MEDICO', 900),
        line('POLLO CAMPERO 12', 120),
        line('POLLO CAMPERO 13', 130),
        line('PEMEX', 50),
      ],
      ...over,
    });

  it('broadens a category with the wider statement wording', async () => {
    const s = setup({ statement: ficohsa() });
    await run(s);
    const candidates = s.categoryCalls[0] as {
      id: string;
      description: string | null;
    }[];
    const pharmacy = candidates.find((c) => c.id === CAT_PHARMACY)!;
    expect(pharmacy.description).toContain('pharmacies, drugstores');
    expect(pharmacy.description).toContain('"Farmacias y Hospitales"');
    // a wording equal to the category name adds nothing
    expect(candidates.find((c) => c.id === CAT_SUPER)!.description).toBeNull();
  });

  it('offers the missing categories as hint:<n> and tags the lines they fit', async () => {
    const s = setup({
      statement: ficohsa(),
      guesses: [
        verdict('HOSPITAL MEDICO', {
          categoryId: CAT_PHARMACY,
          reason: 'Hospital: cae en Farmacias y Hospitales',
        }),
        verdict('POLLO CAMPERO 12', {
          categoryId: 'hint:0',
          reason: 'Comida rápida del estado de cuenta',
        }),
        verdict('POLLO CAMPERO 13', { categoryId: 'hint:0' }),
        verdict('PEMEX', { categoryId: 'hint:0', confidence: 0.3 }),
      ],
    });
    const v = await run(s);
    const candidates = s.categoryCalls[0] as { id: string; name: string }[];
    expect(candidates.find((c) => c.id === 'hint:0')).toMatchObject({
      name: 'Restaurantes y Comida rápida',
    });
    expect(candidates.find((c) => c.id === 'hint:1')).toBeUndefined();
    expect(v.transactions[0]).toMatchObject({
      categoryId: CAT_PHARMACY,
      matchSource: 'AI_CATEGORY',
    });
    expect(v.transactions[1]).toMatchObject({
      categoryId: null,
      matchSource: 'NONE',
      suggestedHint: 'Restaurantes y Comida rápida',
      matchReason: 'Comida rápida del estado de cuenta',
    });
    expect(v.transactions[2]!.suggestedHint).toBe(
      'Restaurantes y Comida rápida',
    );
    // below the confidence threshold: left alone
    expect(v.transactions[3]).toMatchObject({
      suggestedHint: null,
      matchSource: 'NONE',
    });
  });

  it('still classifies when the user has no categories but the statement has hints', async () => {
    const s = setup({ statement: ficohsa(), categories: [] });
    await run(s);
    expect(s.classifierCalls).toHaveLength(1);
  });
});
