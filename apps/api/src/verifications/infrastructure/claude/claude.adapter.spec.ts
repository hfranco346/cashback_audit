import Anthropic from '@anthropic-ai/sdk';
import { ConfigService } from '@nestjs/config';
import { validateEnv } from '../../../config/env.js';
import { ClaudeJsonClient } from './claude-json.client.js';
import { ClaudeLineClassifier } from './claude-line-classifier.js';
import { ClaudeStatementExtractor } from './claude-statement-extractor.js';
import { parseExtraction } from './extraction-schema.js';

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
  exchangeRate: null,
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
    expect(s.exchangeRate).toBeNull();
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

  it('keeps a printed exchange rate and drops unusable ones', () => {
    const printed = parseExtraction({
      ...validOutput,
      exchangeRate: { from: 'usd', to: 'HNL', rate: '26.3500' },
    })!;
    expect(printed.exchangeRate).toMatchObject({
      from: 'USD',
      to: 'HNL',
      source: 'STATEMENT',
    });
    expect(printed.exchangeRate!.rate.toString()).toBe('26.35');
    for (const bad of [
      { from: 'USD', to: 'USD', rate: '1' },
      { from: 'USD', to: 'HNL', rate: 'abc' },
      { from: 'USD', to: 'HNL', rate: '0' },
    ]) {
      expect(
        parseExtraction({ ...validOutput, exchangeRate: bad })!.exchangeRate,
      ).toBeNull();
    }
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

    const { statement, model } = await extractor.extract(pdf);

    expect(model).toBe('claude-sonnet-5-5');
    expect(statement.transactions).toHaveLength(3);
    const call = calls[0];
    expect(call.model).toBe('claude-sonnet-5-5');
    expect(call.output_config.format.type).toBe('json_schema');
    expect(call.system).toContain('untrusted data');
    expect(call.system).toContain('Lempiras=HNL');
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
  });

  it('routes extraction and classification to their configured models', async () => {
    const cfg = config('sk-ant-secret-key', {
      ANTHROPIC_EXTRACTION_MODEL: 'claude-opus-5-5',
      ANTHROPIC_CLASSIFICATION_MODEL: 'claude-sonnet-5-5',
    });
    const ext = fakeClient(textMessage(validOutput));
    const extracted = await new ClaudeStatementExtractor(
      new ClaudeJsonClient(ext.client, cfg),
    ).extract(Buffer.from('%PDF-'));
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
    await expect(extractor.extract(Buffer.from('%PDF-'))).rejects.toMatchObject(
      {
        kind: 'UNPROCESSABLE',
        code: 'UNREADABLE_STATEMENT',
      },
    );
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
    await expect(extractor.extract(Buffer.from('%PDF-'))).rejects.toMatchObject(
      { kind },
    );
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
        .extract(Buffer.from('%PDF-'))
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
    await expect(extractor.extract(Buffer.from('%PDF-'))).rejects.toMatchObject(
      { kind: 'UPSTREAM_UNAVAILABLE' },
    );
  });

  it('fails fast without calling Claude when no API key is configured', async () => {
    const { client, calls } = fakeClient(textMessage(validOutput));
    const extractor = new ClaudeStatementExtractor(
      new ClaudeJsonClient(client, config('')),
    );
    await expect(extractor.extract(Buffer.from('%PDF-'))).rejects.toMatchObject(
      { code: 'EXTRACTION_UNAVAILABLE' },
    );
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
