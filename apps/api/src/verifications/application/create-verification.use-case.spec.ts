import { Decimal } from 'decimal.js';
import type { Card } from '../../cards/domain/card.js';
import { CardRepository } from '../../cards/domain/card.repository.js';
import { CategoryRepository } from '../../categories/domain/category.repository.js';
import type { Merchant } from '../../merchants/domain/merchant.js';
import { MerchantRepository } from '../../merchants/domain/merchant.repository.js';
import type {
  ExtractedStatement,
  ExtractedTransaction,
  LoyaltyProgram,
  MerchantGuess,
} from '../domain/statement.js';
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
  bank: 'BAC',
  last4: '4321',
  network: null,
  rewardUnit: 'CASHBACK_CURRENCY',
  pointsPerCurrencyUnit: d(1),
  baseRatePercent: d(1),
  currency: 'HNL',
  rewardProgramName: null,
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

const program = (
  name: string,
  accumulated: string | null,
  over: Partial<LoyaltyProgram> = {},
): LoyaltyProgram => ({
  name,
  accumulated: accumulated === null ? null : d(accumulated),
  available: null,
  redeemedInPeriod: null,
  expiring: null,
  forfeited: null,
  unit: 'CURRENCY',
  ...over,
});

const line = (
  merchantText: string,
  amount: number,
  over: Partial<ExtractedTransaction> = {},
): ExtractedTransaction => ({
  date: '2026-01-02',
  reference: null,
  merchant: merchantText,
  amount: d(amount),
  currency: 'HNL',
  isCredit: false,
  kind: 'PURCHASE',
  ...over,
});

const statement = (
  over: Partial<ExtractedStatement> = {},
): ExtractedStatement => ({
  bank: 'BAC',
  cardLast4: '4321',
  periodStart: '2026-01-01',
  periodEnd: '2026-01-31',
  currency: 'HNL',
  summaries: [],
  exchangeRate: null,
  loyaltyPrograms: [program('CASH BAC CREDOMATIC', '60')],
  transactions: [
    line('WALMART SUC 123', 1000),
    line('SORIANA HIPER', 200),
    line('WM SUPERCENTER 9', 100),
    line('UBER TRIP', 100),
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
      statement: statement({ transactions: [line('WALMART', 100)] }),
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

  describe('reported reward and loyalty programs', () => {
    it('uses the accumulated value of the only program', async () => {
      const v = await setup({}).useCase.execute({
        userId: USER,
        cardId: 'card-1',
        pdf,
      });
      expect(v).toMatchObject({
        reportedSource: 'STATEMENT',
        reportedLabel: 'CASH BAC CREDOMATIC',
      });
      expect(v.reportedAmount.toString()).toBe('60');
      expect(v.loyalty.selectedBy).toBe('ONLY_PROGRAM');
      expect(v.loyalty.programs).toHaveLength(1);
    });

    const two = [
      program('PUNTOS BAC CREDOMATIC', '999', { unit: 'POINTS' }),
      program('CASH BAC CREDOMATIC', '60'),
    ];

    it('fails with REWARD_PROGRAM_AMBIGUOUS listing the names', async () => {
      const error = await setup({
        statement: statement({ loyaltyPrograms: two }),
      })
        .useCase.execute({ userId: USER, cardId: 'card-1', pdf })
        .catch((e) => e);
      expect(error).toMatchObject({
        kind: 'UNPROCESSABLE',
        code: 'REWARD_PROGRAM_AMBIGUOUS',
        details: {
          programs: ['PUNTOS BAC CREDOMATIC', 'CASH BAC CREDOMATIC'],
        },
      });
    });

    it('picks the program from the card setting or the request name', async () => {
      const fromCard = await setup({
        statement: statement({ loyaltyPrograms: two }),
        card: { ...card, rewardProgramName: 'cash bac' },
      }).useCase.execute({ userId: USER, cardId: 'card-1', pdf });
      expect(fromCard.loyalty).toMatchObject({ selectedBy: 'CARD' });
      expect(fromCard.reportedAmount.toString()).toBe('60');

      const fromRequest = await setup({
        statement: statement({ loyaltyPrograms: two }),
        card: { ...card, rewardProgramName: 'cash bac' },
      }).useCase.execute({
        userId: USER,
        cardId: 'card-1',
        pdf,
        rewardProgramName: 'PUNTOS',
      });
      expect(fromRequest.loyalty).toMatchObject({ selectedBy: 'REQUEST' });
      expect(fromRequest.reportedAmount.toString()).toBe('999');
      expect(fromRequest.warnings.map((w) => w.code)).toContain(
        'REPORTED_UNIT_DIFFERS_FROM_CARD',
      );
    });

    it('does not block on ambiguity when an override is given, and lists all programs', async () => {
      const v = await setup({
        statement: statement({ loyaltyPrograms: two }),
      }).useCase.execute({
        userId: USER,
        cardId: 'card-1',
        pdf,
        reportedRewardOverride: '61',
      });
      expect(v).toMatchObject({ reportedSource: 'OVERRIDE', verdict: 'MATCH' });
      expect(v.loyalty.selected).toBeNull();
      expect(v.loyalty.programs).toHaveLength(2);
    });

    it('prefers the override over the statement figure', async () => {
      const v = await setup({}).useCase.execute({
        userId: USER,
        cardId: 'card-1',
        pdf,
        reportedRewardOverride: '61',
      });
      expect(v).toMatchObject({ reportedSource: 'OVERRIDE', verdict: 'MATCH' });
      expect(v.reportedAmount.toString()).toBe('61');
    });

    it('fails with REPORTED_REWARD_NOT_FOUND without programs, or with an empty accumulated cell', async () => {
      for (const loyaltyPrograms of [[], [program('CASH', null)]]) {
        await expect(
          setup({ statement: statement({ loyaltyPrograms }) }).useCase.execute({
            userId: USER,
            cardId: 'card-1',
            pdf,
          }),
        ).rejects.toMatchObject({ code: 'REPORTED_REWARD_NOT_FOUND' });
      }
      const ok = await setup({
        statement: statement({ loyaltyPrograms: [] }),
      }).useCase.execute({
        userId: USER,
        cardId: 'card-1',
        pdf,
        reportedRewardOverride: '10',
      });
      expect(ok.reportedSource).toBe('OVERRIDE');
    });

    it('warns when the accumulated column looks like a running balance', async () => {
      const running = program('CASH BAC CREDOMATIC', '5000', {
        available: d(4900),
        redeemedInPeriod: d(60),
        forfeited: d(40),
      });
      const v = await setup({
        statement: statement({ loyaltyPrograms: [running] }),
      }).useCase.execute({ userId: USER, cardId: 'card-1', pdf });
      expect(v.warnings.map((w) => w.code)).toContain(
        'REPORTED_VALUE_MAY_BE_CUMULATIVE',
      );
      expect(v.reportedAmount.toString()).toBe('5000'); // still the default value

      const overridden = await setup({
        statement: statement({ loyaltyPrograms: [running] }),
      }).useCase.execute({
        userId: USER,
        cardId: 'card-1',
        pdf,
        reportedRewardOverride: '62',
      });
      expect(overridden.warnings.map((w) => w.code)).not.toContain(
        'REPORTED_VALUE_MAY_BE_CUMULATIVE',
      );
    });
  });

  describe('multi-currency', () => {
    const mixed = (rate: ExtractedStatement['exchangeRate'] = null) =>
      statement({
        exchangeRate: rate,
        transactions: [
          line('WALMART SUC 123', 1000),
          line('AMAZON WALMART', 10, { currency: 'USD' }),
          line('UBER TRIP', 4, { currency: 'USD', kind: 'PURCHASE' }),
        ],
      });

    it('excludes foreign lines with a warning when no rate is available', async () => {
      const v = await setup({ statement: mixed() }).useCase.execute({
        userId: USER,
        cardId: 'card-1',
        pdf,
      });
      expect(v.expectedAmount.toString()).toBe('50');
      expect(v.transactions.map((t) => t.excludedReason)).toEqual([
        null,
        'NO_EXCHANGE_RATE',
        'NO_EXCHANGE_RATE',
      ]);
      expect(v.warnings.map((w) => w.code)).toContain('NO_EXCHANGE_RATE');
      expect(v.conversion.currencies.map((c) => c.currency)).toEqual([
        'HNL',
        'USD',
      ]);
    });

    it('uses the statement rate and then the request rate over it', async () => {
      const printed = {
        from: 'USD',
        to: 'HNL',
        rate: d(25),
        source: 'STATEMENT' as const,
      };
      const fromStatement = await setup({
        statement: mixed(printed),
      }).useCase.execute({ userId: USER, cardId: 'card-1', pdf });
      // 1000 + 10*25 = 1250 at 5% (Walmart keyword) ; 4*25 = 100 at 1%
      expect(fromStatement.expectedAmount.toString()).toBe('63.5');
      expect(fromStatement.transactions[1]).toMatchObject({
        rateSource: 'STATEMENT',
        convertedAmount: d(250),
      });
      expect(fromStatement.warnings.map((w) => w.code)).not.toContain(
        'NO_EXCHANGE_RATE',
      );

      const fromRequest = await setup({
        statement: mixed(printed),
      }).useCase.execute({
        userId: USER,
        cardId: 'card-1',
        pdf,
        exchangeRate: '26',
      });
      expect(fromRequest.transactions[1]!.rateSource).toBe('REQUEST');
      expect(fromRequest.conversion.requestedRate!.toString()).toBe('26');
      // 1000 + 260 = 1260 at 5% = 63 ; 104 at 1% = 1.04
      expect(fromRequest.expectedAmount.toString()).toBe('64.04');
    });

    it('inverts a statement rate printed in the opposite direction', async () => {
      const v = await setup({
        statement: mixed({
          from: 'HNL',
          to: 'USD',
          rate: d('0.04'),
          source: 'STATEMENT',
        }),
      }).useCase.execute({ userId: USER, cardId: 'card-1', pdf });
      expect(v.transactions[1]!.exchangeRate!.toString()).toBe('25');
    });

    it('excludes non-purchase kinds and never sends them to the classifier', async () => {
      const { useCase, classifierCalls } = setup({
        statement: statement({
          transactions: [
            line('WALMART', 100),
            line('SEGURO DE SALDO DE DEUDA', 50, { kind: 'INSURANCE' }),
            line('INTERESES', 30, { kind: 'INTEREST' }),
            line('PAGO RECIBIDO', 500, { kind: 'PAYMENT', isCredit: true }),
          ],
        }),
      });
      const v = await useCase.execute({ userId: USER, cardId: 'card-1', pdf });
      expect(classifierCalls).toHaveLength(0);
      expect(v.expectedAmount.toString()).toBe('5');
      expect(v.transactions.map((t) => t.excludedReason)).toEqual([
        null,
        'NON_PURCHASE_KIND',
        'NON_PURCHASE_KIND',
        'NON_PURCHASE_KIND',
      ]);
      expect(v.transactions[1]).toMatchObject({
        matchSource: 'NONE',
        categoryId: null,
      });
    });

    it('stores primary-currency totals and per-currency summaries', async () => {
      const v = await setup({
        statement: statement({
          summaries: [
            {
              currency: 'HNL',
              previousBalance: d(0),
              purchasesAndCharges: d(1400),
              totalBalance: d(1400),
            },
            {
              currency: 'USD',
              previousBalance: null,
              purchasesAndCharges: d(0),
              totalBalance: d(0),
            },
          ],
        }),
      }).useCase.execute({ userId: USER, cardId: 'card-1', pdf });
      expect(v.primaryCurrency).toBe('HNL');
      expect(v.totalSpent!.toString()).toBe('1400');
      expect(v.summaries).toHaveLength(2);
      expect(v.warnings.map((w) => w.code)).not.toContain(
        'TOTAL_SPENT_MISMATCH',
      );
    });
  });

  it('warns about last4, currency and unit mismatches, and total gaps', async () => {
    const { useCase } = setup({
      statement: statement({
        cardLast4: '9999',
        currency: 'USD',
        summaries: [
          {
            currency: 'USD',
            previousBalance: null,
            purchasesAndCharges: d(5000),
            totalBalance: null,
          },
        ],
        loyaltyPrograms: [program('PUNTOS', '10', { unit: 'POINTS' })],
        transactions: [line('WALMART', 100, { currency: 'USD' })],
      }),
    });
    const v = await useCase.execute({
      userId: USER,
      cardId: 'card-1',
      pdf,
      exchangeRate: '25',
    });
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
        loyaltyPrograms: [program('CASH', '0')],
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
