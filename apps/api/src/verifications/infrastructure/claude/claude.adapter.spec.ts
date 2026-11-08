import Anthropic from '@anthropic-ai/sdk';
import { ConfigService } from '@nestjs/config';
import { validateEnv } from '../../../config/env.js';
import { ClaudeJsonClient } from './claude-json.client.js';
import { ClaudeMerchantClassifier } from './claude-merchant-classifier.js';
import { ClaudeStatementExtractor } from './claude-statement-extractor.js';
import { parseExtraction } from './extraction-schema.js';

const config = (key = 'sk-ant-secret-key') =>
  new ConfigService(
    validateEnv({
      DATABASE_URL: 'x',
      JWT_ACCESS_SECRET: 'a'.repeat(32),
      JWT_REFRESH_SECRET: 'b'.repeat(32),
      ANTHROPIC_API_KEY: key,
    }),
  ) as never;

const validOutput = {
  isCreditCardStatement: true,
  bank: 'BBVA',
  cardLast4: '**** 4321',
  periodStart: '2026-01-01',
  periodEnd: '2026-01-31',
  currency: 'mxn',
  totalSpent: '1200.00',
  totalToPay: '1500.00',
  reportedReward: { amount: '12.50', unit: 'CURRENCY', label: 'Bonificación' },
  transactions: [
    {
      date: '2026-01-05',
      merchant: 'WAL MART SUC 123',
      amount: '1000.00',
      isCredit: false,
    },
    {
      date: '2026-01-09',
      merchant: 'WAL MART SUC 123',
      amount: '200.00',
      isCredit: true,
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
  it('normalizes a valid response', () => {
    const s = parseExtraction(validOutput)!;
    expect(s.cardLast4).toBe('4321');
    expect(s.currency).toBe('MXN');
    expect(s.totalSpent!.toString()).toBe('1200');
    expect(s.reportedReward).toMatchObject({
      unit: 'CURRENCY',
      label: 'Bonificación',
    });
    expect(s.transactions).toHaveLength(2);
    expect(s.transactions[1]!.isCredit).toBe(true);
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
      totalSpent: '12,5',
      cardLast4: '12',
    })!;
    expect(s).toMatchObject({
      periodStart: null,
      currency: null,
      totalSpent: null,
      cardLast4: null,
    });
  });

  it('drops an unusable reward to null', () => {
    const s = parseExtraction({
      ...validOutput,
      reportedReward: { amount: 'lots', unit: 'POINTS', label: 'x' },
    })!;
    expect(s.reportedReward).toBeNull();
  });

  it.each([
    ['negative amounts', { amount: '-5.00' }],
    ['comma decimals', { amount: '5,00' }],
    ['bad dates', { date: '05/01/2026' }],
    ['empty merchants', { merchant: '   ' }],
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
    expect(statement.transactions).toHaveLength(2);
    const call = calls[0];
    expect(call.model).toBe('claude-sonnet-5-5');
    expect(call.output_config.format.type).toBe('json_schema');
    expect(call.system).toContain('untrusted data');
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

describe('ClaudeMerchantClassifier', () => {
  const merchants = [
    {
      id: 'm1',
      name: 'Walmart',
      keywords: ['WAL MART'],
      categoryName: 'Supermarkets',
    },
  ];

  it('returns guesses, clamping confidence and discarding unknown ids/descriptors', async () => {
    const { client, calls } = fakeClient(
      textMessage({
        matches: [
          {
            descriptor: 'WM SUPERCENTER 55',
            merchantId: 'm1',
            confidence: 1.7,
          },
          {
            descriptor: 'UBER TRIP',
            merchantId: 'made-up-id',
            confidence: 0.9,
          },
          { descriptor: 'NOT ASKED', merchantId: 'm1', confidence: 0.9 },
        ],
      }),
    );
    const classifier = new ClaudeMerchantClassifier(
      new ClaudeJsonClient(client, config()),
    );
    const guesses = await classifier.classify(
      ['WM SUPERCENTER 55', 'UBER TRIP'],
      merchants,
    );

    expect(guesses).toEqual([
      { descriptor: 'WM SUPERCENTER 55', merchantId: 'm1', confidence: 1 },
      { descriptor: 'UBER TRIP', merchantId: null, confidence: 0.9 },
    ]);
    const sent = JSON.parse(calls[0].messages[0].content[0].text);
    expect(sent.descriptors).toEqual(['WM SUPERCENTER 55', 'UBER TRIP']);
    expect(sent.merchants[0]).toMatchObject({
      id: 'm1',
      category: 'Supermarkets',
    });
    expect(calls[0].system).toContain('untrusted');
  });

  it('batches large descriptor lists', async () => {
    const { client, calls } = fakeClient(textMessage({ matches: [] }));
    const classifier = new ClaudeMerchantClassifier(
      new ClaudeJsonClient(client, config()),
    );
    await classifier.classify(
      Array.from({ length: 170 }, (_, i) => `D${i}`),
      merchants,
    );
    expect(calls).toHaveLength(3);
  });
});
