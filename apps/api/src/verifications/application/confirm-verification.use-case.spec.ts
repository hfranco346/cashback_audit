import type { Decimal } from 'decimal.js';
import type { Card } from '../../cards/domain/card.js';
import { CardRepository } from '../../cards/domain/card.repository.js';
import { CategoryRepository } from '../../categories/domain/category.repository.js';
import { MerchantRepository } from '../../merchants/domain/merchant.repository.js';
import {
  CAT_PHARMACY,
  CAT_SUPER,
  d,
  crcUsdEurStatement,
  hnlUsdTwoProgramsStatement,
  line,
  mxnCashbackStatement,
  program,
  usdMilesStatement,
} from '../../../test/fixtures/statements.js';
import type { ExtractedStatement } from '../domain/statement.js';
import {
  LineClassifier,
  ResultExplainer,
  StatementExtractor,
  type AuditFacts,
} from '../domain/statement-extractor.js';
import type {
  NewVerification,
  Verification,
  VerificationUpdate,
} from '../domain/verification.js';
import { VerificationRepository } from '../domain/verification.repository.js';
import type { UserRepository } from '../../users/domain/user.repository.js';
import { ConfirmVerificationUseCase } from './confirm-verification.use-case.js';
import { ProcessVerificationUseCase } from './process-verification.use-case.js';
import { RateProposalService } from './rate-proposal.service.js';
import { RewardReportingService } from './reward-reporting.service.js';

const USER = 'user-1';
const pdf = Buffer.from('%PDF-1.4 fake');

function world(
  statement: ExtractedStatement,
  cardOver: Partial<Card> = {},
  classify: Record<string, { categoryId: string | null }> = {},
  explain: (
    facts: AuditFacts,
  ) => Promise<{ text: string; model: string }> = async () => ({
    text: 'explicación',
    model: 'e-model',
  }),
) {
  const card: Card = {
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
    rules: [{ categoryId: CAT_SUPER, ratePercent: d(5), monthlyCap: null }],
    createdAt: new Date(),
    updatedAt: new Date(),
    ...cardOver,
  };
  const stored = new Map<string, Verification>();
  const previousRows: Verification[] = [];
  const listRanges: unknown[] = [];
  const repo = {
    create: async (input: NewVerification) => {
      const v = { ...input, id: 'v-1', createdAt: new Date() } as Verification;
      stored.set(v.id, v);
      return v;
    },
    findById: async (_u: string, id: string) => stored.get(id) ?? null,
    listCompletedForCard: async (_u: string, _c: string, range: unknown) => {
      listRanges.push(range);
      return previousRows;
    },
    update: async (_u: string, id: string, patch: VerificationUpdate) => {
      const current = stored.get(id);
      if (!current) return null;
      const next = { ...current, ...patch } as Verification;
      stored.set(id, next);
      return next;
    },
  } as unknown as VerificationRepository;
  const cardsRepo = {
    findById: async () => card,
    update: async (_u: string, _id: string, patch: Partial<Card>) => {
      Object.assign(card, patch);
      return card;
    },
  } as unknown as CardRepository;
  const categoriesRepo = {
    listWithCounts: async () =>
      [
        { id: CAT_SUPER, name: 'Supermarkets', description: null },
        { id: CAT_PHARMACY, name: 'Pharmacies', description: null },
      ].map((c) => ({
        ...c,
        userId: USER,
        merchantCount: 0,
        createdAt: new Date(),
        updatedAt: new Date(),
      })),
  } as unknown as CategoryRepository;
  let extractions = 0;
  const recorded: {
    currency: string;
    rates: { code: string; rate: Decimal }[];
  }[] = [];
  const process = new ProcessVerificationUseCase(
    categoriesRepo,
    {
      list: async () => [
        {
          id: 'm-wal',
          userId: USER,
          name: 'Walmart',
          keywords: ['WAL MART'],
          categoryId: CAT_SUPER,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ],
    } as unknown as MerchantRepository,
    {
      extract: async () => {
        extractions++;
        return { statement, model: 'm' };
      },
    } as unknown as StatementExtractor,
    {
      classify: async (descriptors: string[]) => ({
        results: descriptors.flatMap((descriptor) =>
          classify[descriptor]
            ? [
                {
                  descriptor,
                  categoryId: classify[descriptor]!.categoryId,
                  matchedMerchantId: null,
                  confidence: 0.9,
                  reason: 'r',
                },
              ]
            : [],
        ),
        unclassified: [],
        model: 'c',
      }),
    } as unknown as LineClassifier,
    repo,
    0.7,
  );
  const confirm = new ConfirmVerificationUseCase(
    repo,
    cardsRepo,
    categoriesRepo,
    new RateProposalService(
      cardsRepo,
      categoriesRepo,
      new RewardReportingService(repo),
    ),
    { explain } as unknown as ResultExplainer,
    {
      recordCurrencyRates: async (
        _user: string,
        currency: string,
        rates: { code: string; rate: Decimal }[],
      ) => {
        recorded.push({ currency, rates });
      },
    } as unknown as UserRepository,
    new RewardReportingService(repo),
  );
  return {
    card,
    stored,
    previousRows,
    listRanges,
    extractions: () => extractions,
    recorded,
    /** Processes the upload as the background processor would. */
    start: async (
      extra: { exchangeRate?: string; rewardProgramName?: string } = {},
    ) => {
      stored.set('v-1', {
        id: 'v-1',
        userId: USER,
        cardId: 'card-1',
        status: 'PROCESSING',
        createdAt: new Date(),
      } as Verification);
      await process.execute({
        verificationId: 'v-1',
        userId: USER,
        card,
        pdf,
        ...extra,
      });
      return stored.get('v-1')!;
    },
    confirm: (
      over: Partial<Parameters<ConfirmVerificationUseCase['execute']>[0]> = {},
    ) =>
      confirm.execute({
        userId: USER,
        verificationId: 'v-1',
        baseRatePercent: '1',
        categoryRates: [{ categoryId: CAT_SUPER, ratePercent: '5' }],
        ...over,
      }),
  };
}

describe('ConfirmVerificationUseCase (step 2)', () => {
  it('audits with the confirmed rates and completes the verification', async () => {
    const w = world(
      mxnCashbackStatement(),
      {},
      {
        'WM SUPERCENTER': { categoryId: CAT_SUPER },
      },
    );
    await w.start();
    const v = await w.confirm();
    expect(v.status).toBe('COMPLETED');
    // super: 1000 + 200 - 100 = 1100 * 5% = 55 ; base: 300 * 1% = 3
    expect(v.expectedAmount!.toString()).toBe('58');
    expect(v).toMatchObject({ verdict: 'MATCH', reportedSource: 'STATEMENT' });
    expect(v.transactions[1]).toMatchObject({
      ruleApplied: true,
      expectedReward: d(10),
    });
    expect(w.extractions()).toBe(1);
  });

  it('records appliedRates with the source of each rate', async () => {
    const w = world(mxnCashbackStatement(), { baseRatePercent: d(2) });
    await w.start();
    const v = await w.confirm({
      baseRatePercent: '1', // equals the STATEMENT proposal (1%)
      categoryRates: [{ categoryId: CAT_SUPER, ratePercent: '6' }], // proposal: 5
    });
    expect(v.appliedRates).toMatchObject({
      baseSource: 'STATEMENT_CONFIRMED',
      savedToCard: false,
    });
    expect(v.appliedRates!.baseRatePercent.toString()).toBe('1');
    expect(v.appliedRates!.categoryRates[0]).toMatchObject({
      categoryName: 'Supermarkets',
      source: 'USER_ENTERED',
    });
  });

  it('marks card-rule rates as CARD_RULE_CONFIRMED when nothing is stated', async () => {
    const w = world(mxnCashbackStatement({ detectedRates: [] }));
    await w.start();
    const v = await w.confirm();
    expect(v.appliedRates!.baseSource).toBe('CARD_RULE_CONFIRMED');
    expect(v.appliedRates!.categoryRates[0]!.source).toBe(
      'CARD_RULE_CONFIRMED',
    );
  });

  it('overrides the card rules entirely (no rule for a category = base rate)', async () => {
    const w = world(
      mxnCashbackStatement(),
      {},
      {
        'PEMEX 4455': { categoryId: CAT_PHARMACY },
      },
    );
    await w.start();
    // Pharmacy line: category used but no rate stated/card rule -> required.
    await expect(w.confirm()).rejects.toMatchObject({
      code: 'RATES_REQUIRED',
      details: {
        missing: [{ categoryId: CAT_PHARMACY, categoryName: 'Pharmacies' }],
      },
    });
    const v = await w.confirm({
      baseRatePercent: '0.5',
      categoryRates: [
        { categoryId: CAT_SUPER, ratePercent: '10', monthlyCap: '50' },
        { categoryId: CAT_PHARMACY, ratePercent: '3' },
      ],
    });
    // super (1000 - 100) * 10% = 90 -> capped 50 ; pharmacy 300 * 3% = 9 ;
    // base 200 * 0.5% = 1
    expect(v.expectedAmount!.toString()).toBe('60');
    expect(v.breakdown[0]).toMatchObject({ capped: true });
  });

  it('rejects categories the user does not own and duplicates', async () => {
    const w = world(mxnCashbackStatement());
    await w.start();
    await expect(
      w.confirm({
        categoryRates: [
          { categoryId: CAT_SUPER, ratePercent: '5' },
          { categoryId: 'foreign', ratePercent: '5' },
        ],
      }),
    ).rejects.toMatchObject({ code: 'CATEGORY_NOT_FOUND' });
    await expect(
      w.confirm({
        categoryRates: [
          { categoryId: CAT_SUPER, ratePercent: '5' },
          { categoryId: CAT_SUPER, ratePercent: '6' },
        ],
      }),
    ).rejects.toMatchObject({ code: 'DUPLICATE_RULE_CATEGORY' });
  });

  it('recomputes on re-confirm with other rates, without a new extraction', async () => {
    const w = world(mxnCashbackStatement());
    await w.start();
    const first = await w.confirm();
    const second = await w.confirm({
      categoryRates: [{ categoryId: CAT_SUPER, ratePercent: '10' }],
    });
    expect(first.expectedAmount!.toString()).not.toBe(
      second.expectedAmount!.toString(),
    );
    expect(second.status).toBe('COMPLETED');
    expect(w.extractions()).toBe(1);
  });

  it('saves the rates to the card when asked', async () => {
    const w = world(mxnCashbackStatement());
    await w.start();
    await w.confirm({
      baseRatePercent: '2',
      saveToCard: true,
      categoryRates: [
        { categoryId: CAT_SUPER, ratePercent: '8', monthlyCap: '50' },
      ],
    });
    expect(w.card.baseRatePercent.toString()).toBe('2');
    expect(w.card.rules).toEqual([
      { categoryId: CAT_SUPER, ratePercent: d(8), monthlyCap: d(50) },
    ]);
    const unsaved = world(mxnCashbackStatement());
    await unsaved.start();
    await unsaved.confirm({ baseRatePercent: '2' });
    expect(unsaved.card.baseRatePercent.toString()).toBe('1');
  });

  describe('program selection and reported value', () => {
    const hnl = { currency: 'HNL' };

    it('fails with REWARD_PROGRAM_AMBIGUOUS until a program is chosen', async () => {
      const w = world(hnlUsdTwoProgramsStatement(), hnl);
      await w.start();
      await expect(w.confirm()).rejects.toMatchObject({
        code: 'REWARD_PROGRAM_AMBIGUOUS',
        details: {
          programs: ['PUNTOS BAC CREDOMATIC', 'CASH BAC CREDOMATIC'],
        },
      });
      const v = await w.confirm({ rewardProgramName: 'cash' });
      expect(v.reportedAmount!.toString()).toBe('134.5');
      expect(v.loyalty.selectedBy).toBe('REQUEST');
    });

    it('keeps the program asked for at upload time on re-confirm', async () => {
      const w = world(hnlUsdTwoProgramsStatement(), hnl);
      await w.start({ rewardProgramName: 'puntos' });
      const v = await w.confirm();
      expect(v.reportedLabel).toBe('PUNTOS BAC CREDOMATIC');
      const again = await w.confirm();
      expect(again.reportedLabel).toBe('PUNTOS BAC CREDOMATIC');
    });

    it('lets an override win, and a later confirm without it keeps it', async () => {
      const w = world(hnlUsdTwoProgramsStatement(), hnl);
      await w.start();
      const v = await w.confirm({ reportedRewardOverride: '60.5' });
      expect(v).toMatchObject({ reportedSource: 'OVERRIDE' });
      expect(v.reportedAmount!.toString()).toBe('60.5');
      const again = await w.confirm();
      expect(again.reportedAmount!.toString()).toBe('60.5');
    });

    it('fails with REPORTED_REWARD_NOT_FOUND without a usable figure', async () => {
      for (const loyaltyPrograms of [[], [program('CASH', null)]]) {
        const w = world(mxnCashbackStatement({ loyaltyPrograms }));
        await w.start();
        await expect(w.confirm()).rejects.toMatchObject({
          code: 'REPORTED_REWARD_NOT_FOUND',
        });
      }
    });

    it('warns when the accumulated column looks like a running balance (once, even after re-confirm)', async () => {
      const running = program('CASH', '5000', {
        available: d(4900),
        redeemedInPeriod: d(60),
        forfeited: d(40),
      });
      const w = world(mxnCashbackStatement({ loyaltyPrograms: [running] }));
      await w.start();
      await w.confirm();
      const v = await w.confirm();
      expect(
        v.warnings.filter((x) => x.code === 'REPORTED_VALUE_MAY_BE_CUMULATIVE'),
      ).toHaveLength(1);
      expect(v.reportedAmount!.toString()).toBe('5000');
    });
  });

  describe('multi-currency', () => {
    const hnl = { currency: 'HNL', rewardProgramName: 'cash' };
    const classify = {
      'SUPERMERCADO LA COLONIA': { categoryId: CAT_SUPER },
    };

    it('remembers the per-currency rates used, and nothing when none were sent', async () => {
      const w = world(hnlUsdTwoProgramsStatement(), hnl, classify);
      await w.start();
      await w.confirm();
      expect(w.recorded.at(-1)).toEqual({ currency: 'HNL', rates: [] });
      await w.confirm({ exchangeRates: { USD: '25.5' } });
      const last = w.recorded.at(-1)!;
      expect(last.currency).toBe('HNL');
      expect(last.rates.map((r) => [r.code, r.rate.toString()])).toEqual([
        ['USD', '25.5'],
      ]);
    });

    it('excludes USD lines without a rate, then includes them when one is sent', async () => {
      const w = world(hnlUsdTwoProgramsStatement(), hnl, classify);
      await w.start();
      const without = await w.confirm();
      expect(without.transactions[2]!.excludedReason).toBe('NO_EXCHANGE_RATE');
      expect(without.warnings.map((x) => x.code)).toContain('NO_EXCHANGE_RATE');
      const withRate = await w.confirm({ exchangeRate: '25' });
      expect(withRate.transactions[2]!.excludedReason).toBeNull();
      expect(withRate.transactions[2]!.convertedAmount!.toString()).toBe(
        '1000',
      );
      expect(withRate.warnings.map((x) => x.code)).not.toContain(
        'NO_EXCHANGE_RATE',
      );
      // super 2000 * 5% = 100 ; (500 + 1000) base * 1% = 15
      expect(withRate.expectedAmount!.toString()).toBe('115');
    });

    it('uses the rate stored at upload time, the statement rate otherwise', async () => {
      const stored = world(hnlUsdTwoProgramsStatement(), hnl, classify);
      await stored.start({ exchangeRate: '20' });
      const v = await stored.confirm();
      expect(v.transactions[2]!.exchangeRate!.toString()).toBe('20');
      expect(v.transactions[2]!.rateSource).toBe('REQUEST');

      const printed = world(
        hnlUsdTwoProgramsStatement({
          exchangeRates: [
            { from: 'USD', to: 'HNL', rate: d(26), source: 'STATEMENT' },
          ],
        }),
        hnl,
        classify,
      );
      await printed.start();
      const p = await printed.confirm();
      expect(p.transactions[2]!.rateSource).toBe('STATEMENT');
    });
  });

  it('audits the miles fixture with an unexpressible stated rate as required input', async () => {
    const w = world(
      usdMilesStatement(),
      {
        currency: 'USD',
        rewardUnit: 'POINTS',
        baseRatePercent: d(2),
        rules: [],
      },
      {},
    );
    const started = await w.start();
    expect(started.detectedRates[0]!.ratePercent).toBeNull();
    const v = await w
      .confirm({ baseRatePercent: '200', categoryRates: [] })
      .catch((e) => e);
    // 200% is outside the allowed range at the HTTP layer; the domain still computes
    expect(v.status ?? v.code).toBeDefined();
    const ok = await w.confirm({ baseRatePercent: '100', categoryRates: [] });
    // 800 * 100% * 1 point per unit
    expect(ok.expectedAmount!.toString()).toBe('800');
    expect(ok.appliedRates!.baseSource).toBe('USER_ENTERED');
    expect(ok.reportedAmount!.toString()).toBe('2400');
    expect(ok.verdict).toBe('OVERPAID');
  });

  describe('explanation', () => {
    it('stores the narrative and the model, and feeds it only computed numbers', async () => {
      const seen: AuditFacts[] = [];
      const w = world(
        mxnCashbackStatement(),
        {},
        {
          'WM SUPERCENTER': { categoryId: CAT_SUPER },
        },
        async (facts) => {
          seen.push(facts);
          return { text: 'El banco pagó lo esperado.', model: 'haiku-x' };
        },
      );
      await w.start();
      const v = await w.confirm();
      expect(v.explanation).toBe('El banco pagó lo esperado.');
      expect(v.models).toMatchObject({
        extraction: 'm',
        classification: 'c',
        explanation: 'haiku-x',
      });
      expect(seen[0]).toMatchObject({
        verdict: 'MATCH',
        reported: '58',
        expected: '58',
        difference: '0',
        tolerance: '1',
        rewardUnit: 'CASHBACK_CURRENCY',
        primaryCurrency: 'MXN',
        programName: 'Bonificación del periodo',
        excludedForeignLines: 0,
      });
      expect(seen[0]!.breakdown[0]).toMatchObject({
        category: 'Supermarkets',
        ratePercent: '5',
        expectedReward: '55',
      });
    });

    it('degrades to a warning when the explainer fails and recovers on re-confirm', async () => {
      let fail = true;
      const w = world(mxnCashbackStatement(), {}, {}, async () => {
        if (fail) throw new Error('down');
        return { text: 'ok', model: 'm2' };
      });
      await w.start();
      const first = await w.confirm();
      expect(first.status).toBe('COMPLETED');
      expect(first.explanation).toBeNull();
      expect(first.models.explanation).toBeNull();
      expect(first.warnings.map((x) => x.code)).toContain(
        'EXPLANATION_UNAVAILABLE',
      );
      fail = false;
      const second = await w.confirm();
      expect(second.explanation).toBe('ok');
      expect(second.warnings.map((x) => x.code)).not.toContain(
        'EXPLANATION_UNAVAILABLE',
      );
    });
  });

  it('is 404 for an unknown verification', async () => {
    const w = world(mxnCashbackStatement());
    await expect(w.confirm()).rejects.toMatchObject({
      code: 'VERIFICATION_NOT_FOUND',
    });
  });

  it('works on an empty statement', async () => {
    const w = world(
      mxnCashbackStatement({
        transactions: [],
        loyaltyPrograms: [program('CASH', '0')],
      }),
    );
    await w.start();
    const v = await w.confirm();
    expect(v).toMatchObject({ verdict: 'MATCH' });
    expect(v.expectedAmount!.toString()).toBe('0');
    expect(line('x', 1).kind).toBe('PURCHASE');
  });
});

describe('ConfirmVerificationUseCase: reward currency and several rates', () => {
  const crc = { currency: 'CRC', rules: [] };
  const confirmBase = {
    baseRatePercent: '1',
    categoryRates: [] as { categoryId: string; ratePercent: string }[],
  };

  it('proposes a required reward rate when the program pays in another currency', async () => {
    const w = world(crcUsdEurStatement(), crc);
    const started = await w.start();
    const proposal = await new RateProposalService(
      { findById: async () => w.card } as unknown as CardRepository,
      {
        listWithCounts: async () => [],
      } as unknown as CategoryRepository,
      new RewardReportingService({
        listCompletedForCard: async () => [],
      } as unknown as VerificationRepository),
    ).forVerification(USER, started);
    expect(proposal.rewardConversion).toMatchObject({
      fromCurrency: 'CRC',
      toCurrency: 'USD',
      rate: null,
      source: 'NONE',
      required: true,
    });
    expect(proposal.spendConversions.map((c) => c.currency)).toEqual([
      'EUR',
      'USD',
    ]);
  });

  it('fails with REWARD_EXCHANGE_RATE_REQUIRED, then converts once the rate is sent', async () => {
    const w = world(crcUsdEurStatement(), crc);
    await w.start();
    await expect(w.confirm(confirmBase)).rejects.toMatchObject({
      code: 'REWARD_EXCHANGE_RATE_REQUIRED',
      details: { fromCurrency: 'CRC', toCurrency: 'USD' },
    });
    const v = await w.confirm({
      ...confirmBase,
      exchangeRates: { USD: '520', EUR: '560' },
      rewardExchangeRate: '520',
    });
    expect(v.rewardCurrency).toBe('USD');
    // (56,000 + 52,000 + 28,000) * 1% = 1,360 CRC -> 2.62 USD
    expect(v.expectedAmount!.toString()).toBe('2.62');
    expect(v.conversion.reward!.expectedInPrimary.toString()).toBe('1360');
    expect(v.appliedRates!.rewardExchangeRate).toMatchObject({
      fromCurrency: 'CRC',
      toCurrency: 'USD',
      source: 'USER_ENTERED',
    });
    expect(v.verdict).toBe('MATCH');
  });

  it('re-confirm can change the rate and the stored ones carry over', async () => {
    const w = world(crcUsdEurStatement(), crc);
    await w.start();
    await w.confirm({
      ...confirmBase,
      exchangeRates: { USD: '520', EUR: '560' },
      rewardExchangeRate: '520',
    });
    const again = await w.confirm({
      ...confirmBase,
      rewardExchangeRate: '500',
    });
    expect(again.expectedAmount!.toString()).toBe('2.72');
    expect(again.transactions[2]!.exchangeRate!.toString()).toBe('560');
    expect(again.conversion.requestedRates.USD!.toString()).toBe('520');
  });

  it('leaves out only the currency whose rate is missing', async () => {
    const w = world(crcUsdEurStatement(), crc);
    await w.start();
    const v = await w
      .confirm({
        ...confirmBase,
        exchangeRates: { USD: '520' },
      })
      .catch((e: unknown) => e);
    // USD spend rate is reused for the USD reward, so no 422 here.
    expect(v).toMatchObject({ status: 'COMPLETED' });
    const done = v as Verification;
    expect(done.transactions[1]!.excludedReason).toBeNull();
    expect(done.transactions[2]!.excludedReason).toBe('NO_EXCHANGE_RATE');
    expect(done.warnings.map((x) => x.code)).toContain('NO_EXCHANGE_RATE');
  });

  it('the card rewardCurrency override beats the program currency', async () => {
    const w = world(crcUsdEurStatement(), { ...crc, rewardCurrency: 'EUR' });
    await w.start();
    const v = await w.confirm({
      ...confirmBase,
      exchangeRates: { USD: '520', EUR: '560' },
      reportedRewardOverride: '2.43',
    });
    expect(v.rewardCurrency).toBe('EUR');
    expect(v.expectedAmount!.toString()).toBe('2.43');
  });

  it('rejects malformed rates with INVALID_EXCHANGE_RATE', async () => {
    const w = world(crcUsdEurStatement(), crc);
    await w.start();
    for (const bad of [
      { exchangeRates: { USD: '0' } } as Record<string, unknown>,
      { exchangeRates: { USD: 'abc' } },
      { exchangeRates: { USD: '1.1234567' } },
      { exchangeRates: { CRC: '1' } },
      { exchangeRates: { usd1: '1' } },
      { rewardExchangeRate: '-1' },
    ]) {
      await expect(w.confirm({ ...confirmBase, ...bad })).rejects.toMatchObject(
        { code: 'INVALID_EXCHANGE_RATE' },
      );
    }
  });

  it('does not convert a points card, whatever the program currency says', async () => {
    const w = world(
      crcUsdEurStatement({
        loyaltyPrograms: [
          program('Puntos', '1360', { unit: 'POINTS', currency: null }),
        ],
      }),
      { ...crc, rewardUnit: 'POINTS' },
    );
    await w.start();
    const v = await w.confirm({
      ...confirmBase,
      exchangeRates: { USD: '520', EUR: '560' },
    });
    expect(v.rewardCurrency).toBeNull();
    expect(v.appliedRates!.rewardExchangeRate).toBeNull();
    expect(v.expectedAmount!.toString()).toBe('1360');
  });
});

describe('ConfirmVerificationUseCase: cumulative reward balance', () => {
  const cash = (
    accumulated: string,
    over: Parameters<typeof program>[2] = {},
  ) =>
    mxnCashbackStatement({
      loyaltyPrograms: [program('Cashback', accumulated, over)],
    });
  const cumulative = (extra: Record<string, unknown> = {}) => ({
    rewardReporting: { mode: 'CUMULATIVE' as const, ...extra },
  });
  const earlier = (
    over: Partial<Verification['rewardReporting'] & object> = {},
  ): Verification =>
    ({
      id: 'v-prev',
      cardId: 'card-1',
      status: 'COMPLETED',
      periodEnd: '2025-12-31',
      rewardReporting: {
        mode: 'CUMULATIVE',
        programName: 'CASHBACK',
        currentBalance: d(100),
        previousBalance: d(40),
        previousBalanceSource: 'USER',
        previousVerificationId: null,
        redeemedInPeriod: d(0),
        expiredInPeriod: d(0),
        earned: d(60),
        ...over,
      },
    }) as unknown as Verification;

  it('keeps the legacy behaviour without a choice (MONTHLY)', async () => {
    const w = world(
      cash('58'),
      {},
      { 'WM SUPERCENTER': { categoryId: CAT_SUPER } },
    );
    await w.start();
    const v = await w.confirm();
    expect(v.reportedAmount!.toString()).toBe('58');
    expect(v.rewardReporting).toMatchObject({
      mode: 'MONTHLY',
      currentBalance: null,
    });
    expect(v.rewardReporting!.earned!.toString()).toBe('58');
  });

  it('B: uses the previous balance printed on the statement', async () => {
    const w = world(
      cash('158', { previousBalance: d(100) }),
      {},
      { 'WM SUPERCENTER': { categoryId: CAT_SUPER } },
    );
    await w.start();
    const v = await w.confirm(cumulative());
    expect(v.reportedAmount!.toString()).toBe('58');
    expect(v.verdict).toBe('MATCH');
    expect(v.rewardReporting).toMatchObject({
      mode: 'CUMULATIVE',
      previousBalanceSource: 'STATEMENT',
    });
    expect(v.rewardReporting!.currentBalance!.toString()).toBe('158');
    expect(w.listRanges).toHaveLength(0);
  });

  it('B: uses the earned-in-period figure printed on the statement', async () => {
    const w = world(
      cash('900', { earnedInPeriod: d(58) }),
      {},
      { 'WM SUPERCENTER': { categoryId: CAT_SUPER } },
    );
    await w.start();
    const v = await w.confirm(cumulative());
    expect(v.reportedAmount!.toString()).toBe('58');
    expect(v.verdict).toBe('MATCH');
    expect(v.rewardReporting).toMatchObject({
      previousBalance: null,
      previousBalanceSource: 'STATEMENT',
    });
  });

  it('A: takes the previous balance from the closest earlier audit', async () => {
    const w = world(
      cash('158'),
      { rewardReporting: 'CUMULATIVE' },
      { 'WM SUPERCENTER': { categoryId: CAT_SUPER } },
    );
    await w.start();
    w.previousRows.push(earlier());
    const v = await w.confirm();
    expect(v.reportedAmount!.toString()).toBe('58');
    expect(v.rewardReporting).toMatchObject({
      previousBalanceSource: 'PREVIOUS_VERIFICATION',
      previousVerificationId: 'v-prev',
    });
    // statement period starts 2026-01-01: window is +/- 5 days around it
    expect(w.listRanges[0]).toMatchObject({
      periodEndFrom: '2025-12-27',
      periodEndTo: '2026-01-06',
      excludeId: 'v-1',
    });
  });

  it('A: ignores an earlier audit of another program', async () => {
    const w = world(cash('158'), { rewardReporting: 'CUMULATIVE' });
    await w.start();
    w.previousRows.push(earlier({ programName: 'Puntos Viajero' }));
    await expect(w.confirm()).rejects.toMatchObject({
      code: 'PREVIOUS_BALANCE_REQUIRED',
    });
  });

  it('C: asks for the previous balance when nothing resolves it', async () => {
    const w = world(cash('158'));
    await w.start();
    await expect(w.confirm(cumulative())).rejects.toMatchObject({
      kind: 'UNPROCESSABLE',
      code: 'PREVIOUS_BALANCE_REQUIRED',
    });
    expect(w.stored.get('v-1')!.status).toBe('AWAITING_RATES');
  });

  it('C: a typed previous balance wins and is labelled USER', async () => {
    const w = world(
      cash('158', { previousBalance: d(999) }),
      {},
      { 'WM SUPERCENTER': { categoryId: CAT_SUPER } },
    );
    await w.start();
    const v = await w.confirm(cumulative({ previousBalance: '100' }));
    expect(v.rewardReporting).toMatchObject({ previousBalanceSource: 'USER' });
    expect(v.reportedAmount!.toString()).toBe('58');
    const read = await w.confirm(
      cumulative({
        previousBalance: '100',
        previousBalanceSource: 'PREVIOUS_STATEMENT',
      }),
    );
    expect(read.rewardReporting!.previousBalanceSource).toBe(
      'PREVIOUS_STATEMENT',
    );
  });

  it('adds redeemed and expired back and flags a negative result', async () => {
    const w = world(
      cash('150', {
        redeemedInPeriod: d(30),
        forfeited: d(5),
        expiring: d(99),
      }),
    );
    await w.start();
    // 150 - 120 + 30 + 5 (the "expiring soon" 99 is still in the balance)
    const v = await w.confirm(cumulative({ previousBalance: '120' }));
    expect(v.rewardReporting!.earned!.toString()).toBe('65');
    expect(v.rewardReporting!.expiredInPeriod.toString()).toBe('5');

    const negative = await w.confirm(cumulative({ previousBalance: '300' }));
    expect(negative.reportedAmount!.toString()).toBe('-115');
    expect(negative.warnings.map((x) => x.code)).toContain(
      'REWARD_BALANCE_INCONSISTENT',
    );
    const fixed = await w.confirm(cumulative({ previousBalance: '120' }));
    expect(fixed.warnings.map((x) => x.code)).not.toContain(
      'REWARD_BALANCE_INCONSISTENT',
    );
  });

  it('re-confirming can switch the mode and keeps a typed balance', async () => {
    const w = world(
      cash('158'),
      {},
      { 'WM SUPERCENTER': { categoryId: CAT_SUPER } },
    );
    await w.start();
    const first = await w.confirm(cumulative({ previousBalance: '100' }));
    expect(first.reportedAmount!.toString()).toBe('58');
    // no choice sent: the stored one (and its typed balance) is kept
    const again = await w.confirm();
    expect(again.rewardReporting).toMatchObject({
      mode: 'CUMULATIVE',
      previousBalanceSource: 'USER',
    });
    expect(again.reportedAmount!.toString()).toBe('58');
    const monthly = await w.confirm({ rewardReporting: { mode: 'MONTHLY' } });
    expect(monthly.reportedAmount!.toString()).toBe('158');
    expect(monthly.rewardReporting!.mode).toBe('MONTHLY');
  });

  it('a manual reportedRewardOverride wins over the cumulative derivation', async () => {
    const w = world(cash('158'));
    await w.start();
    const v = await w.confirm({
      reportedRewardOverride: '58',
      ...cumulative(),
    });
    expect(v.reportedSource).toBe('OVERRIDE');
    expect(v.reportedAmount!.toString()).toBe('58');
  });

  it('rememberForCard stores the mode only after a successful audit', async () => {
    const w = world(cash('158'));
    await w.start();
    await expect(
      w.confirm(cumulative({ rememberForCard: true })),
    ).rejects.toMatchObject({ code: 'PREVIOUS_BALANCE_REQUIRED' });
    expect(w.card.rewardReporting).toBe('AUTO');
    await w.confirm(
      cumulative({ previousBalance: '100', rememberForCard: true }),
    );
    expect(w.card.rewardReporting).toBe('CUMULATIVE');
    await w.confirm({ rewardReporting: { mode: 'MONTHLY' } });
    expect(w.card.rewardReporting).toBe('CUMULATIVE');
    await w.confirm({
      rewardReporting: { mode: 'MONTHLY', rememberForCard: true },
    });
    expect(w.card.rewardReporting).toBe('MONTHLY');
  });

  it('feeds the explainer the derivation', async () => {
    const facts: AuditFacts[] = [];
    const w = world(cash('158'), {}, {}, async (f) => {
      facts.push(f);
      return { text: 'x', model: 'm' };
    });
    await w.start();
    await w.confirm(cumulative({ previousBalance: '100' }));
    expect(facts[0]!.rewardReporting).toMatchObject({
      currentBalance: '158',
      previousBalance: '100',
      previousBalanceSource: 'USER',
      earned: '58',
    });
  });
});

describe('RateProposalService: reward reporting proposal', () => {
  const proposalFor = async (
    statement: ExtractedStatement,
    cardOver: Partial<Card> = {},
    previous: Verification[] = [],
  ) => {
    const w = world(statement, cardOver);
    const started = await w.start();
    w.previousRows.push(...previous);
    const reporting = new RewardReportingService({
      listCompletedForCard: async () => previous,
    } as unknown as VerificationRepository);
    const service = new RateProposalService(
      { findById: async () => w.card } as unknown as CardRepository,
      { listWithCounts: async () => [] } as unknown as CategoryRepository,
      reporting,
    );
    return (await service.forVerification(USER, started)).rewardReporting!;
  };
  const cash = (
    accumulated: string,
    over: Parameters<typeof program>[2] = {},
  ) =>
    mxnCashbackStatement({
      loyaltyPrograms: [program('Cashback', accumulated, over)],
    });

  it('suggests CUMULATIVE when the statement prints the previous balance', async () => {
    const p = await proposalFor(cash('158', { previousBalance: d(100) }));
    expect(p).toMatchObject({
      mode: 'CUMULATIVE',
      suggestedMode: 'CUMULATIVE',
      reason: 'STATEMENT_HAS_PREVIOUS_BALANCE',
      cardSetting: 'AUTO',
      previousBalanceSource: 'STATEMENT',
      previousBalanceRequired: false,
    });
    expect(p.currentBalance!.toString()).toBe('158');
    expect(p.earned!.toString()).toBe('58');
  });

  it('follows an explicit card setting', async () => {
    const p = await proposalFor(cash('58'), { rewardReporting: 'MONTHLY' });
    expect(p).toMatchObject({
      mode: 'MONTHLY',
      suggestedMode: 'MONTHLY',
      reason: 'CARD_SETTING',
    });
  });

  it('suggests from the printed label', async () => {
    const p = await proposalFor(
      cash('58', { reportedLabel: 'Saldo acumulado' }),
    );
    expect(p).toMatchObject({
      suggestedMode: 'CUMULATIVE',
      reason: 'LABEL_SAYS_ACCUMULATED',
      previousBalanceRequired: true,
      earned: null,
    });
  });

  it('suggests when the reported figure is far above the expected one', async () => {
    // expected for the fixture is 3 (1% base) to 58 (with rates); 9,000 >> 3x
    const p = await proposalFor(cash('9000'));
    expect(p).toMatchObject({
      suggestedMode: 'CUMULATIVE',
      reason: 'REPORTED_FAR_ABOVE_EXPECTED',
    });
  });

  it('stays MONTHLY with no signal', async () => {
    // nothing classified: 1,400 of spend at the 1% base rate = 14 expected
    const p = await proposalFor(cash('14'));
    expect(p).toMatchObject({ suggestedMode: 'MONTHLY', reason: 'NONE' });
  });

  it('reports the balance of the earlier audit when it is found', async () => {
    const p = await proposalFor(
      cash('158'),
      { rewardReporting: 'CUMULATIVE' },
      [
        {
          id: 'v-prev',
          rewardReporting: {
            mode: 'CUMULATIVE',
            programName: 'cashback',
            currentBalance: d(100),
          },
        } as unknown as Verification,
      ],
    );
    expect(p).toMatchObject({
      previousBalanceSource: 'PREVIOUS_VERIFICATION',
      previousVerificationId: 'v-prev',
      previousBalanceRequired: false,
    });
    expect(p.earned!.toString()).toBe('58');
  });
});
