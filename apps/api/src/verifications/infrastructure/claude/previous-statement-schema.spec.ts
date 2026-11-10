import { describe, expect, it } from 'vitest';
import {
  parsePreviousStatement,
  previousStatementOutputSchema,
} from './previous-statement-schema.js';

describe('parsePreviousStatement', () => {
  it('returns null for a document that is not a statement', () => {
    expect(
      parsePreviousStatement({
        isCreditCardStatement: false,
        periodEnd: '',
        programs: [],
      }),
    ).toBeNull();
  });

  it('reads balances (thousands separators, empty sentinel) and the closing date', () => {
    const programs = parsePreviousStatement({
      isCreditCardStatement: true,
      periodEnd: '2025-12-31',
      programs: [
        { name: 'CASH PROGRAM', balance: '1,158.50' },
        { name: 'Puntos', balance: '' },
        { name: 'Millas', balance: 'abc' },
      ],
    })!;
    expect(programs).toHaveLength(1);
    expect(programs[0]).toMatchObject({
      name: 'CASH PROGRAM',
      periodEnd: '2025-12-31',
    });
    expect(programs[0]!.balance.toString()).toBe('1158.5');
  });

  it('drops an unreadable closing date', () => {
    const programs = parsePreviousStatement({
      isCreditCardStatement: true,
      periodEnd: '31/12',
      programs: [{ name: 'CASH', balance: '5' }],
    })!;
    expect(programs[0]!.periodEnd).toBeNull();
  });

  it('rejects malformed output', () => {
    expect(() => parsePreviousStatement({ programs: 3 })).toThrowError(
      expect.objectContaining({ code: 'EXTRACTION_FAILED' }),
    );
  });
});

describe('previous statement schema size', () => {
  it('stays tiny and free of nullable fields (the API grammar limit)', async () => {
    const { zodOutputFormat } = await import('@anthropic-ai/sdk/helpers/zod');
    const json = JSON.stringify(zodOutputFormat(previousStatementOutputSchema));
    expect(json).not.toContain('anyOf');
    expect(json).not.toContain('nullable');
    expect(json.length).toBeLessThan(1200);
  });
});
