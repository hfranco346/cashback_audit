import { Decimal } from 'decimal.js';
import type { Card } from '../../cards/domain/card.js';
import { CardRepository } from '../../cards/domain/card.repository.js';
import { CategoryRepository } from '../../categories/domain/category.repository.js';
import type { Merchant } from '../../merchants/domain/merchant.js';
import { MerchantRepository } from '../../merchants/domain/merchant.repository.js';
import type { ExtractedStatement, MerchantGuess } from '../domain/statement.js';
import {
  MerchantClassifier,
  StatementExtractor,
} from '../domain/statement-extractor.js';
import type { NewVerification, Verification } from '../domain/verification.js';
import { VerificationRepository } from '../domain/verification.repository.js';
import { CreateVerificationUseCase } from './create-verification.use-case.js';

const d = (v: string | number) => new Decimal(v);
const USER = 'user-1';
const pdf = Buffer.from('%PDF-1.4 fake');

const card: Card = {
  id: 'card-1',
  userId: USER,
  alias: 'Daily',
  bank: 'BBVA',
  last4: '4321',
  network: null,
  rewardUnit: 'CASHBACK_CURRENCY',
  pointsPerCurrencyUnit: d(1),
  baseRatePercent: d(1),
  currency: 'MXN',
  rules: [{ categoryId: 'cat-super', ratePercent: d(5), monthlyCap: null }],
  createdAt: new Date(),
  updatedAt: new Date(),
};
const merchant = (
  id: string,
  name: string,
  keywords: string[],
  categoryId = 'cat-super',
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

const statement = (
  over: Partial<ExtractedStatement> = {},
): ExtractedStatement => ({
  bank: 'BBVA',
  cardLast4: '4321',
  periodStart: '2026-01-01',
  periodEnd: '2026-01-31',
  currency: 'MXN',
  totalSpent: null,
  totalToPay: null,
  reportedReward: { amount: d('60'), unit: 'CURRENCY', label: 'Bonificación' },
  transactions: [
    {
      date: '2026-01-02',
      merchant: 'WALMART SUC 123',
      amount: d(1000),
      isCredit: false,
    },
    {
      date: '2026-01-03',
      merchant: 'SORIANA HIPER',
      amount: d(200),
      isCredit: false,
    },
    {
      date: '2026-01-04',
      merchant: 'WM SUPERCENTER 9',
      amount: d(100),
      isCredit: false,
    },
    {
      date: '2026-01-05',
      merchant: 'UBER TRIP',
      amount: d(100),
      isCredit: false,
    },
  ],
  ...over,
});

function setup(opts: {
  statement?: ExtractedStatement;
  merchants?: Merchant[];
  guesses?: MerchantGuess[] | Error;
  card?: Card | null;
}) {
  const saved: NewVerification[] = [];
  const classifierCalls: string[][] = [];
  const useCase = new CreateVerificationUseCase(
    {
      findById: async () => (opts.card === undefined ? card : opts.card),
    } as unknown as CardRepository,
    {
      findManyByIds: async () => [
        {
          id: 'cat-super',
          userId: USER,
          name: 'Supermarkets',
          description: null,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ],
    } as unknown as CategoryRepository,
    {
      list: async () => opts.merchants ?? merchants,
    } as unknown as MerchantRepository,
    {
      extract: async () => ({
        statement: opts.statement ?? statement(),
        model: 'test-model',
      }),
    } as unknown as StatementExtractor,
    {
      classify: async (descriptors: string[]) => {
        classifierCalls.push(descriptors);
        if (opts.guesses instanceof Error) throw opts.guesses;
        return opts.guesses ?? [];
      },
    } as unknown as MerchantClassifier,
    {
      create: async (input: NewVerification) => {
        saved.push(input);
        return { ...input, id: 'v-1', createdAt: new Date() } as Verification;
      },
    } as unknown as VerificationRepository,
  );
  return { useCase, saved, classifierCalls };
}

describe('CreateVerificationUseCase', () => {
  it('matches by keyword first and sends only unmatched descriptors to the AI', async () => {
    const { useCase, classifierCalls } = setup({});
    await useCase.execute({ userId: USER, cardId: 'card-1', pdf });
    expect(classifierCalls).toEqual([['WM SUPERCENTER 9', 'UBER TRIP']]);
  });

  it('applies AI guesses above the confidence threshold and ignores weak ones', async () => {
    const { useCase } = setup({
      guesses: [
        {
          descriptor: 'WM SUPERCENTER 9',
          merchantId: 'm-wal',
          confidence: 0.9,
        },
        { descriptor: 'UBER TRIP', merchantId: 'm-sor', confidence: 0.3 },
      ],
    });
    const v = await useCase.execute({ userId: USER, cardId: 'card-1', pdf });
    const bySource = v.transactions.map((t) => [
      t.merchant,
      t.matchSource,
      t.matchedMerchantId,
    ]);
    expect(bySource).toEqual([
      ['WALMART SUC 123', 'KEYWORD', 'm-wal'],
      ['SORIANA HIPER', 'KEYWORD', 'm-sor'],
      ['WM SUPERCENTER 9', 'AI', 'm-wal'],
      ['UBER TRIP', 'NONE', null],
    ]);
    expect(v.transactions[2]).toMatchObject({
      matchConfidence: 0.9,
      categoryId: 'cat-super',
      categoryName: 'Supermarkets',
      ruleApplied: true,
    });
    // 1300 at 5% + 100 at 1%
    expect(v.expectedAmount.toString()).toBe('66');
    expect(v.verdict).toBe('UNDERPAID'); // reported 60, tolerance 1% of 66 -> 1
    expect(v.difference.toString()).toBe('-6');
  });

  it('keeps going with a warning when the AI is unavailable', async () => {
    const { useCase } = setup({ guesses: new Error('boom') });
    const v = await useCase.execute({ userId: USER, cardId: 'card-1', pdf });
    expect(v.warnings.map((w) => w.code)).toContain('AI_MATCHING_UNAVAILABLE');
    expect(v.transactions[2]!.matchSource).toBe('NONE');
    expect(v.expectedAmount.toString()).toBe('62'); // 1200 at 5% + 200 at 1%
  });

  it('skips the AI when everything matched or the user has no merchants', async () => {
    const all = setup({
      statement: statement({
        transactions: [
          {
            date: '2026-01-02',
            merchant: 'WALMART',
            amount: d(100),
            isCredit: false,
          },
        ],
      }),
    });
    await all.useCase.execute({ userId: USER, cardId: 'card-1', pdf });
    expect(all.classifierCalls).toHaveLength(0);

    const none = setup({ merchants: [] });
    const v = await none.useCase.execute({
      userId: USER,
      cardId: 'card-1',
      pdf,
    });
    expect(none.classifierCalls).toHaveLength(0);
    expect(v.expectedAmount.toString()).toBe('14'); // all at base 1%
  });

  it('prefers the override over the statement figure', async () => {
    const { useCase } = setup({});
    const v = await useCase.execute({
      userId: USER,
      cardId: 'card-1',
      pdf,
      reportedRewardOverride: '61',
    });
    expect(v).toMatchObject({ reportedSource: 'OVERRIDE', verdict: 'MATCH' });
    expect(v.reportedAmount.toString()).toBe('61');
  });

  it('fails with REPORTED_REWARD_NOT_FOUND when neither source has a figure', async () => {
    const { useCase } = setup({
      statement: statement({ reportedReward: null }),
    });
    await expect(
      useCase.execute({ userId: USER, cardId: 'card-1', pdf }),
    ).rejects.toMatchObject({
      code: 'REPORTED_REWARD_NOT_FOUND',
    });
    const ok = await setup({
      statement: statement({ reportedReward: null }),
    }).useCase.execute({
      userId: USER,
      cardId: 'card-1',
      pdf,
      reportedRewardOverride: '10',
    });
    expect(ok.reportedSource).toBe('OVERRIDE');
  });

  it('warns about last4, currency and unit mismatches, and total spent gaps', async () => {
    const { useCase } = setup({
      statement: statement({
        cardLast4: '9999',
        currency: 'USD',
        totalSpent: d(5000),
        reportedReward: { amount: d(10), unit: 'POINTS', label: 'Puntos' },
      }),
    });
    const v = await useCase.execute({ userId: USER, cardId: 'card-1', pdf });
    expect(v.warnings.map((w) => w.code).sort()).toEqual([
      'CARD_LAST4_MISMATCH',
      'CURRENCY_MISMATCH',
      'REPORTED_UNIT_DIFFERS_FROM_CARD',
      'TOTAL_SPENT_MISMATCH',
    ]);
  });

  it('handles an empty statement', async () => {
    const { useCase } = setup({
      statement: statement({
        transactions: [],
        reportedReward: { amount: d(0), unit: 'CURRENCY', label: 'x' },
      }),
    });
    const v = await useCase.execute({ userId: USER, cardId: 'card-1', pdf });
    expect(v).toMatchObject({ verdict: 'MATCH' });
    expect(v.expectedAmount.toString()).toBe('0');
    expect(v.warnings.map((w) => w.code)).toContain('NO_TRANSACTIONS');
  });

  it('rejects non-PDF bytes and unknown cards before calling Claude', async () => {
    await expect(
      setup({}).useCase.execute({
        userId: USER,
        cardId: 'card-1',
        pdf: Buffer.from('GIF89a'),
      }),
    ).rejects.toMatchObject({ code: 'INVALID_PDF' });
    await expect(
      setup({ card: null }).useCase.execute({
        userId: USER,
        cardId: 'nope',
        pdf,
      }),
    ).rejects.toMatchObject({ code: 'CARD_NOT_FOUND' });
  });
});
