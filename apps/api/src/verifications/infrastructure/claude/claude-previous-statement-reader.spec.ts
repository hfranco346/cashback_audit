import type Anthropic from '@anthropic-ai/sdk';
import { ConfigService } from '@nestjs/config';
import { describe, expect, it } from 'vitest';
import { validateEnv } from '../../../config/env.js';
import { ClaudeJsonClient } from './claude-json.client.js';
import { ClaudePreviousStatementReader } from './claude-previous-statement-reader.js';

const config = (extra: Record<string, string> = {}) =>
  new ConfigService(
    validateEnv({
      ...extra,
      DATABASE_URL: 'x',
      JWT_ACCESS_SECRET: 'a'.repeat(32),
      JWT_REFRESH_SECRET: 'b'.repeat(32),
      ANTHROPIC_API_KEY: 'sk-ant-secret-key',
    }),
  ) as never;

function fakeClient(payload: unknown) {
  const calls: any[] = [];
  const client = {
    messages: {
      stream: (params: unknown) => {
        calls.push(params);
        return {
          finalMessage: async () => ({
            stop_reason: 'end_turn',
            content: [{ type: 'text', text: JSON.stringify(payload) }],
          }),
        };
      },
    },
  } as unknown as Anthropic;
  return { client, calls };
}

describe('ClaudePreviousStatementReader', () => {
  it('sends the PDF with the small schema on the extraction model', async () => {
    const { client, calls } = fakeClient({
      isCreditCardStatement: true,
      periodEnd: '2025-12-31',
      programs: [{ name: 'CASH', balance: '1,200.5' }],
    });
    const reader = new ClaudePreviousStatementReader(
      new ClaudeJsonClient(
        client,
        config({ ANTHROPIC_EXTRACTION_MODEL: 'claude-opus-5-5' }),
      ),
    );
    const { programs, model } = await reader.read(Buffer.from('%PDF-1.7'));
    expect(model).toBe('claude-opus-5-5');
    expect(programs[0]!.balance.toString()).toBe('1200.5');
    expect(calls[0].model).toBe('claude-opus-5-5');
    expect(calls[0].system).toContain('untrusted data');
    expect(calls[0].messages[0].content[0]).toMatchObject({
      type: 'document',
    });
    expect(calls[0].output_config.format.type).toBe('json_schema');
  });

  it('answers NOT_A_STATEMENT for other documents', async () => {
    const { client } = fakeClient({
      isCreditCardStatement: false,
      periodEnd: '',
      programs: [],
    });
    const reader = new ClaudePreviousStatementReader(
      new ClaudeJsonClient(client, config()),
    );
    await expect(reader.read(Buffer.from('%PDF-'))).rejects.toMatchObject({
      kind: 'UNPROCESSABLE',
      code: 'NOT_A_STATEMENT',
    });
  });
});
