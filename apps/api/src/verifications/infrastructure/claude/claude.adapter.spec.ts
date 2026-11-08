import Anthropic from '@anthropic-ai/sdk';
import { ConfigService } from '@nestjs/config';
import { validateEnv } from '../../../config/env.js';
import { ClaudeJsonClient } from './claude-json.client.js';
import { ClaudeLineClassifier } from './claude-line-classifier.js';
import { ClaudeResultExplainer } from './claude-result-explainer.js';
import { ClaudeStatementExtractor } from './claude-statement-extractor.js';
import { parseExtraction } from './extraction-schema.js';

const ctx = {
  categories: [{ id: 'c-super', name: 'Supermarkets', description: null }],
};

const config = (
  key = 'sk-ant-secret-key',
  extra: Record<string, string> = {},
) =>
  new ConfigService(
    validateEnv({
      ...extra,
      DATABASE_URL: 'x',
      JWT_ACCESS_SECRET: 'a'.repeat(32),
      JWT_REFRESH_SECRET: 'b'.repeat(32),
      ANTHROPIC_API_KEY: key,
    }),
  ) as never;

const validOutput = {
  isCreditCardStatement: true,
  bank: 'BAC Credomatic',
  cardLast4: '**** 4321',
  periodStart: '2025-10-01',
  periodEnd: '2025-10-31',
  currency: 'hnl',
  summaries: [
    {
      currency: 'HNL',
      previousBalance: '100.00',
      purchasesAndCharges: '1200.00',
      totalBalance: '1300.00',
    },
    {
      currency: 'usd',
      previousBalance: '0',
      purchasesAndCharges: '10.00',
      totalBalance: '10.00',
    },
  ],
  exchangeRates: [],
  detectedRates: [
    {
      scope: 'CATEGORY',
      categoryHint: 'supermarkets',
      suggestedCategoryId: 'c-super',
      ratePercent: '7',
      unitNote: null,
      evidence: '7% back at supermarkets',
      confidence: 0.9,
    },
  ],
  loyaltyPrograms: [
    {
      name: 'PUNTOS BAC CREDOMATIC',
      accumulated: '1500',
      available: '1400',
      redeemedInPeriod: '100',
      expiring: null,
      forfeited: '0',
      unit: 'POINTS',
    },
    {
      name: 'CASH BAC CREDOMATIC',
      accumulated: '12.50',
      available: '12.50',
      redeemedInPeriod: null,
      expiring: null,
      forfeited: null,
      unit: 'CURRENCY',
    },
  ],
  transactions: [
    {
      date: '2025-10-05',
      reference: '000123',
      description: 'SUPERMERCADO LA COLONIA',
      amount: '1000.00',
      currency: 'HNL',
      isCredit: false,
      kind: 'PURCHASE',
    },
    {
      date: '2025-10-09',
      reference: null,
      description: 'AMAZON',
      amount: '10.00',
      currency: 'usd',
      isCredit: false,
      kind: 'PURCHASE',
    },
    {
      date: '2025-10-10',
      reference: null,
      description: 'SEGURO DE SALDO DE DEUDA',
      amount: '20.00',
      currency: 'HNL',
      isCredit: false,
      kind: 'INSURANCE',
    },
  ],
};

function fakeClient(result: unknown) {
  const calls: any[] = [];
  const stream = (params: unknown) => {
    calls.push(params);
    return {
      finalMessage: async () => {
        if (result instanceof Error) throw result;
        return result;
      },
    };
  };
  return { client: { messages: { stream } } as unknown as Anthropic, calls };
}

const textMessage = (payload: unknown, stop_reason = 'end_turn') => ({
  stop_reason,
  content: [
    {
      type: 'text',
      text: typeof payload === 'string' ? payload : JSON.stringify(payload),
    },
  ],
});

describe('parseExtraction', () => {
  it('normalizes a valid multi-currency response', () => {
    const s = parseExtraction(validOutput)!;
    expect(s.cardLast4).toBe('4321');
    expect(s.currency).toBe('HNL');
    expect(s.summaries.map((x) => x.currency)).toEqual(['HNL', 'USD']);
    expect(s.summaries[0]!.purchasesAndCharges!.toString()).toBe('1200');
    expect(s.exchangeRates).toEqual([]);
    expect(s.loyaltyPrograms).toHaveLength(2);
    expect(s.loyaltyPrograms[1]).toMatchObject({
      name: 'CASH BAC CREDOMATIC',
      unit: 'CURRENCY',
      redeemedInPeriod: null,
    });
    expect(s.transactions).toHaveLength(3);
    expect(s.transactions[0]).toMatchObject({
      reference: '000123',
      merchant: 'SUPERMERCADO LA COLONIA',
      currency: 'HNL',
      kind: 'PURCHASE',
    });
    expect(s.transactions[1]!.currency).toBe('USD');
    expect(s.transactions[2]!.kind).toBe('INSURANCE');
  });

  it('keeps every printed exchange rate and drops unusable ones', () => {
    const printed = parseExtraction({
      ...validOutput,
      exchangeRates: [
        { from: 'usd', to: 'HNL', rate: '26.3500' },
        { from: 'eur', to: 'hnl', rate: '28.1' },
        { from: 'USD', to: 'HNL', rate: '27' },
      ],
    })!;
    expect(printed.exchangeRates).toHaveLength(2);
    expect(printed.exchangeRates[0]).toMatchObject({
      from: 'USD',
      to: 'HNL',
      source: 'STATEMENT',
    });
    expect(printed.exchangeRates[0]!.rate.toString()).toBe('26.35');
    expect(printed.exchangeRates[1]!.from).toBe('EUR');
    for (const bad of [
      { from: 'USD', to: 'USD', rate: '1' },
      { from: 'USD', to: 'HNL', rate: 'abc' },
      { from: 'USD', to: 'HNL', rate: '0' },
    ]) {
      expect(
        parseExtraction({ ...validOutput, exchangeRates: [bad] })!
          .exchangeRates,
      ).toEqual([]);
    }
  });

  it('still accepts the legacy single exchangeRate shape', () => {
    const s = parseExtraction({
      ...validOutput,
      exchangeRates: undefined,
      exchangeRate: { from: 'USD', to: 'HNL', rate: '26.35' },
    })!;
    expect(s.exchangeRates).toHaveLength(1);
  });

  it('keeps detected rates, maps only known categories and nulls bad percentages', () => {
    const s = parseExtraction(validOutput, new Set(['c-super']))!;
    expect(s.detectedRates).toHaveLength(1);
    expect(s.detectedRates[0]).toMatchObject({
      scope: 'CATEGORY',
      suggestedCategoryId: 'c-super',
      evidence: '7% back at supermarkets',
      confidence: 0.9,
    });
    expect(s.detectedRates[0]!.ratePercent!.toString()).toBe('7');

    const unknown = parseExtraction(validOutput)!; // no categories known
    expect(unknown.detectedRates[0]!.suggestedCategoryId).toBeNull();

    const odd = parseExtraction({
      ...validOutput,
      detectedRates: [
        { ...validOutput.detectedRates[0]!, scope: 'BASE', ratePercent: '250' },
        {
          ...validOutput.detectedRates[0]!,
          ratePercent: '2 points',
          confidence: 7,
        },
      ],
    })!;
    expect(odd.detectedRates.map((r) => r.ratePercent)).toEqual([null, null]);
    expect(odd.detectedRates[0]!.suggestedCategoryId).toBeNull(); // BASE never maps
    expect(odd.detectedRates[1]!.confidence).toBe(1);
  });

  it('falls back to the statement currency for an unreadable line currency', () => {
    const s = parseExtraction({
      ...validOutput,
      transactions: [{ ...validOutput.transactions[0]!, currency: 'Lempiras' }],
    })!;
    expect(s.transactions[0]!.currency).toBe('HNL');
  });

  it('returns null when the document is not a statement', () => {
    expect(
      parseExtraction({ ...validOutput, isCreditCardStatement: false }),
    ).toBeNull();
  });

  it('nulls out malformed optional fields instead of failing', () => {
    const s = parseExtraction({
      ...validOutput,
      periodStart: 'last month',
      currency: 'pesos',
      summaries: [
        {
          currency: 'HNL',
          previousBalance: '12,5',
          purchasesAndCharges: null,
          totalBalance: null,
        },
      ],
      cardLast4: '12',
    })!;
    expect(s).toMatchObject({
      periodStart: null,
      currency: 'HNL', // falls back to the first summary currency
      cardLast4: null,
    });
    expect(s.summaries[0]!.previousBalance).toBeNull();
  });

  it('nulls unreadable program cells and unknown units', () => {
    const s = parseExtraction({
      ...validOutput,
      loyaltyPrograms: [
        {
          ...validOutput.loyaltyPrograms[0]!,
          accumulated: 'lots',
          unit: 'STARS',
        },
      ],
    })!;
    expect(s.loyaltyPrograms[0]).toMatchObject({
      accumulated: null,
      unit: 'UNKNOWN',
    });
  });

  it.each([
    ['negative amounts', { amount: '-5.00' }],
    ['comma decimals', { amount: '5,00' }],
    ['bad dates', { date: '05/01/2026' }],
    ['empty descriptions', { description: '   ' }],
    ['unknown kinds', { kind: 'GIFT' }],
  ])('fails loudly on transactions with %s', (_l, patch) => {
    const bad = {
      ...validOutput,
      transactions: [{ ...validOutput.transactions[0]!, ...patch }],
    };
    expect(() => parseExtraction(bad)).toThrow(
      expect.objectContaining({ code: 'EXTRACTION_FAILED' }),
    );
  });
});

describe('ClaudeStatementExtractor', () => {
  it('sends the PDF as a base64 document with structured output and returns the statement', async () => {
    const { client, calls } = fakeClient(textMessage(validOutput));
    const extractor = new ClaudeStatementExtractor(
      new ClaudeJsonClient(client, config()),
    );
    const pdf = Buffer.from('%PDF-1.7 test');

    const { statement, model } = await extractor.extract(pdf, ctx);

    expect(model).toBe('claude-sonnet-5-5');
    expect(statement.transactions).toHaveLength(3);
    const call = calls[0];
    expect(call.model).toBe('claude-sonnet-5-5');
    expect(call.output_config.format.type).toBe('json_schema');
    expect(call.system).toContain('untrusted data');
    expect(call.system).not.toMatch(/Lempiras|Acumulados|BAC/);
    expect(call.system).toContain('ISO 4217');
    const [doc, text] = call.messages[0].content;
    expect(doc).toEqual({
      type: 'document',
      source: {
        type: 'base64',
        media_type: 'application/pdf',
        data: pdf.toString('base64'),
      },
    });
    expect(text.type).toBe('text');
    expect(text.text).toContain('c-super');
  });

  it('routes extraction and classification to their configured models', async () => {
    const cfg = config('sk-ant-secret-key', {
      ANTHROPIC_EXTRACTION_MODEL: 'claude-opus-5-5',
      ANTHROPIC_CLASSIFICATION_MODEL: 'claude-sonnet-5-5',
    });
    const ext = fakeClient(textMessage(validOutput));
    const extracted = await new ClaudeStatementExtractor(
      new ClaudeJsonClient(ext.client, cfg),
    ).extract(Buffer.from('%PDF-'), ctx);
    expect(extracted.model).toBe('claude-opus-5-5');
    expect(ext.calls[0].model).toBe('claude-opus-5-5');

    const cls = fakeClient(textMessage({ matches: [] }));
    const classified = await new ClaudeLineClassifier(
      new ClaudeJsonClient(cls.client, cfg),
    ).classify(['X'], []);
    expect(classified.model).toBe('claude-sonnet-5-5');
    expect(cls.calls[0].model).toBe('claude-sonnet-5-5');
  });

  it('rejects documents that are not statements with 422', async () => {
    const { client } = fakeClient(
      textMessage({ ...validOutput, isCreditCardStatement: false }),
    );
    const extractor = new ClaudeStatementExtractor(
      new ClaudeJsonClient(client, config()),
    );
    await expect(
      extractor.extract(Buffer.from('%PDF-'), ctx),
    ).rejects.toMatchObject({
      kind: 'UNPROCESSABLE',
      code: 'UNREADABLE_STATEMENT',
    });
  });

  it.each([
    ['refusal', textMessage('', 'refusal'), 'UNPROCESSABLE'],
    ['max_tokens', textMessage('{"x"', 'max_tokens'), 'UNPROCESSABLE'],
    ['invalid JSON', textMessage('not json'), 'UPSTREAM_FAILURE'],
    ['schema violation', textMessage({ foo: 1 }), 'UPSTREAM_FAILURE'],
    [
      'no text block',
      { stop_reason: 'end_turn', content: [] },
      'UPSTREAM_FAILURE',
    ],
  ])('maps %s to a clean domain error', async (_label, message, kind) => {
    const { client } = fakeClient(message);
    const extractor = new ClaudeStatementExtractor(
      new ClaudeJsonClient(client, config()),
    );
    await expect(
      extractor.extract(Buffer.from('%PDF-'), ctx),
    ).rejects.toMatchObject({ kind });
  });

  const apiError = (status: number) =>
    Anthropic.APIError.generate(
      status,
      {
        type: 'error',
        error: { type: 'x', message: 'secret sk-ant-secret-key leaked' },
      },
      'secret sk-ant-secret-key leaked',
      new Headers(),
    );

  it.each([
    [400, 'UNPROCESSABLE'],
    [401, 'UPSTREAM_UNAVAILABLE'],
    [429, 'UPSTREAM_UNAVAILABLE'],
    [529, 'UPSTREAM_UNAVAILABLE'],
    [500, 'UPSTREAM_FAILURE'],
  ])(
    'maps Anthropic HTTP %i to %s without leaking upstream text',
    async (status, kind) => {
      const { client } = fakeClient(apiError(status));
      const extractor = new ClaudeStatementExtractor(
        new ClaudeJsonClient(client, config()),
      );
      const error = await extractor
        .extract(Buffer.from('%PDF-'), ctx)
        .catch((e) => e);
      expect(error.kind).toBe(kind);
      expect(error.message).not.toContain('sk-ant');
      expect(error.message).not.toContain('secret');
    },
  );

  it('maps connection failures to 503-class errors', async () => {
    const { client } = fakeClient(
      new Anthropic.APIConnectionError({ message: 'ECONNRESET' }),
    );
    const extractor = new ClaudeStatementExtractor(
      new ClaudeJsonClient(client, config()),
    );
    await expect(
      extractor.extract(Buffer.from('%PDF-'), ctx),
    ).rejects.toMatchObject({ kind: 'UPSTREAM_UNAVAILABLE' });
  });

  it('fails fast without calling Claude when no API key is configured', async () => {
    const { client, calls } = fakeClient(textMessage(validOutput));
    const extractor = new ClaudeStatementExtractor(
      new ClaudeJsonClient(client, config('')),
    );
    await expect(
      extractor.extract(Buffer.from('%PDF-'), ctx),
    ).rejects.toMatchObject({ code: 'EXTRACTION_UNAVAILABLE' });
    expect(calls).toHaveLength(0);
  });
});

describe('ClaudeLineClassifier', () => {
  const categories = [
    {
      id: 'c-super',
      name: 'Supermercados',
      description: 'supermercados, abarroterías, hipermercados',
      merchants: [{ id: 'm1', name: 'Walmart' }],
    },
    { id: 'c-pharm', name: 'Farmacia', description: null, merchants: [] },
  ];
  const make = (client: Anthropic) =>
    new ClaudeLineClassifier(new ClaudeJsonClient(client, config()));

  it('asks for Spanish reasons, explains hint ids and keeps hint answers', async () => {
    const { client, calls } = fakeClient(
      textMessage({
        matches: [
          {
            descriptor: 'POLLO CAMPERO',
            categoryId: 'hint:0',
            matchedMerchantId: null,
            confidence: 0.9,
            reason: 'Comida rápida',
          },
        ],
      }),
    );
    const out = await make(client).classify(
      ['POLLO CAMPERO'],
      [
        ...categories,
        {
          id: 'hint:0',
          name: 'Restaurantes y Comida rápida',
          description: 'Kind of spending named by the statement',
          merchants: [],
        },
      ],
    );
    expect(out.results[0]!.categoryId).toBe('hint:0');
    expect(calls[0].system).toContain('ALWAYS in Spanish');
    expect(calls[0].system).toContain('"hint:"');
    expect(calls[0].messages[0].content[0].text).toContain(
      'Restaurantes y Comida rápida',
    );
  });

  it('sends categories (with description and merchant examples) and validates the answer', async () => {
    const { client, calls } = fakeClient(
      textMessage({
        matches: [
          {
            descriptor: 'LA COLONIA 12',
            categoryId: 'c-super',
            matchedMerchantId: null,
            confidence: 1.7,
            reason: ' supermarket chain ',
          },
          {
            descriptor: 'WM SUPERCENTER',
            categoryId: 'c-pharm',
            matchedMerchantId: 'm1',
            confidence: 0.9,
            reason: 'walmart',
          },
          {
            descriptor: 'FARMACIA SIMAN',
            categoryId: 'made-up',
            matchedMerchantId: 'made-up-too',
            confidence: 0.9,
            reason: 'x',
          },
          {
            descriptor: 'NOT ASKED',
            categoryId: 'c-super',
            matchedMerchantId: null,
            confidence: 0.9,
            reason: 'x',
          },
        ],
      }),
    );
    const out = await make(client).classify(
      ['LA COLONIA 12', 'WM SUPERCENTER', 'FARMACIA SIMAN'],
      categories,
    );

    expect(out.model).toBe('claude-haiku-5-5');
    expect(out.unclassified).toEqual([]);
    expect(out.results).toEqual([
      {
        descriptor: 'LA COLONIA 12',
        categoryId: 'c-super',
        matchedMerchantId: null,
        confidence: 1,
        reason: 'supermarket chain',
      },
      {
        // a matched merchant decides the category
        descriptor: 'WM SUPERCENTER',
        categoryId: 'c-super',
        matchedMerchantId: 'm1',
        confidence: 0.9,
        reason: 'walmart',
      },
      {
        descriptor: 'FARMACIA SIMAN',
        categoryId: null,
        matchedMerchantId: null,
        confidence: 0.9,
        reason: 'x',
      },
    ]);
    expect(calls[0].model).toBe('claude-haiku-5-5');
    expect(calls[0].system).toContain('untrusted');
    const sent = JSON.parse(calls[0].messages[0].content[0].text);
    expect(sent.descriptors).toHaveLength(3);
    expect(sent.categories[0]).toMatchObject({
      id: 'c-super',
      description: 'supermercados, abarroterías, hipermercados',
      merchants: [{ id: 'm1', name: 'Walmart' }],
    });
    expect(sent.categories[1].merchants).toEqual([]);
  });

  it('batches in groups of 100 descriptors', async () => {
    const { client, calls } = fakeClient(textMessage({ matches: [] }));
    const out = await make(client).classify(
      Array.from({ length: 230 }, (_, i) => `D${i}`),
      categories,
    );
    expect(calls).toHaveLength(3);
    expect(
      JSON.parse(calls[0].messages[0].content[0].text).descriptors,
    ).toHaveLength(100);
    // nothing answered -> every descriptor is reported as unclassified
    expect(out.unclassified).toHaveLength(230);
    expect(out.model).toBe('claude-haiku-5-5');
  });

  it('degrades instead of throwing when a call fails or the schema is violated', async () => {
    const bad = fakeClient(textMessage({ nope: true }));
    const out = await make(bad.client).classify(['A', 'B'], categories);
    expect(out).toEqual({
      results: [],
      unclassified: ['A', 'B'],
      model: null,
    });

    const down = fakeClient(new Anthropic.APIConnectionError({ message: 'x' }));
    expect(
      (await make(down.client).classify(['A'], categories)).model,
    ).toBeNull();
  });
});

describe('ClaudeResultExplainer', () => {
  const facts = {
    verdict: 'UNDERPAID',
    rewardUnit: 'CASHBACK_CURRENCY',
    primaryCurrency: 'HNL',
    rewardCurrency: 'HNL',
    expectedInPrimaryCurrency: null,
    reported: '30',
    expected: '58',
    difference: '-28',
    tolerance: '1',
    programName: 'CASH',
    reportedSource: 'STATEMENT',
    breakdown: [
      {
        category: 'Supermercados',
        ratePercent: '5',
        spend: '1100',
        expectedReward: '55',
        capped: false,
        monthlyCap: null,
      },
    ],
    excludedForeignLines: 0,
    warningCodes: [],
  } as const;

  it('asks the cheap model for plain text in Spanish with the computed facts only', async () => {
    const { client, calls } = fakeClient({
      stop_reason: 'end_turn',
      content: [{ type: 'text', text: '  El banco pagó de menos.  ' }],
    });
    const out = await new ClaudeResultExplainer(
      new ClaudeJsonClient(client, config()),
    ).explain(facts as never);
    expect(out).toEqual({
      text: 'El banco pagó de menos.',
      model: 'claude-haiku-5-5',
    });
    expect(calls[0].model).toBe('claude-haiku-5-5');
    expect(calls[0].output_config).toBeUndefined();
    expect(calls[0].system).toContain('NUNCA calcules');
    expect(calls[0].system).toContain('no confiables');
    const sent = JSON.parse(calls[0].messages[0].content[0].text);
    expect(sent).toMatchObject({
      resultado: 'te pagaron de menos',
      reportadoPorElBanco: 'HNL 30.00',
      esperado: 'HNL 58.00',
    });
    expect(JSON.stringify(sent)).not.toMatch(/UNDERPAID|MATCH|OVERPAID/);
    expect(calls[0].system).toContain('NUNCA escribas códigos internos');
  });

  it.each([
    [
      'empty text',
      { stop_reason: 'end_turn', content: [{ type: 'text', text: ' ' }] },
    ],
    ['max_tokens', { stop_reason: 'max_tokens', content: [] }],
    ['refusal', { stop_reason: 'refusal', content: [] }],
  ])('fails cleanly on %s', async (_l, message) => {
    const { client } = fakeClient(message);
    await expect(
      new ClaudeResultExplainer(new ClaudeJsonClient(client, config())).explain(
        facts as never,
      ),
    ).rejects.toMatchObject({ code: 'EXTRACTION_FAILED' });
  });
});
