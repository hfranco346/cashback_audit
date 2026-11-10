import { Decimal } from 'decimal.js';
import { describe, expect, it } from 'vitest';
import type { CardRepository } from '../../cards/domain/card.repository.js';
import type {
  PreviousStatementProgram,
  PreviousStatementReader,
} from '../domain/statement-extractor.js';
import { NotAStatementError } from '../domain/verification-errors.js';
import type { Verification } from '../domain/verification.js';
import type { VerificationRepository } from '../domain/verification.repository.js';
import { ReadPreviousStatementUseCase } from './read-previous-statement.use-case.js';

const PDF = Buffer.from('%PDF-1.4 fake');
const program = (name: string): never =>
  ({
    name,
    unit: 'CURRENCY',
  }) as never;

function setup(options: {
  status?: Verification['status'];
  programs?: string[];
  card?: string | null;
  read?: () => Promise<{ programs: PreviousStatementProgram[]; model: string }>;
}) {
  let reads = 0;
  const verification = {
    id: 'v-1',
    cardId: 'c-1',
    status: options.status ?? 'AWAITING_RATES',
    loyalty: {
      requestedProgramName: null,
      programs: (options.programs ?? ['CASH BAC']).map(program),
    },
  } as unknown as Verification;
  const useCase = new ReadPreviousStatementUseCase(
    {
      findById: async (user: string, id: string) =>
        user === 'u-1' && id === 'v-1' ? verification : null,
    } as unknown as VerificationRepository,
    {
      findById: async () => ({ rewardProgramName: options.card ?? null }),
    } as unknown as CardRepository,
    {
      read: async () => {
        reads++;
        return (
          options.read?.() ?? {
            programs: [
              {
                name: 'cash bac',
                balance: new Decimal('120.5'),
                periodEnd: '2025-12-31',
              },
              { name: 'Puntos', balance: new Decimal(9), periodEnd: null },
            ],
            model: 'm',
          }
        );
      },
    } as unknown as PreviousStatementReader,
  );
  return {
    run: (user = 'u-1', pdf = PDF) =>
      useCase.execute({ userId: user, verificationId: 'v-1', pdf }),
    reads: () => reads,
  };
}

describe('ReadPreviousStatementUseCase', () => {
  it('returns every program and the balance of the matching one', async () => {
    const s = setup({});
    expect(await s.run()).toEqual({
      programs: [
        { name: 'cash bac', balance: '120.5', periodEnd: '2025-12-31' },
        { name: 'Puntos', balance: '9', periodEnd: null },
      ],
      matchedBalance: '120.5',
    });
  });

  it('answers 422 PROGRAM_NOT_FOUND when the program is not on the statement', async () => {
    const s = setup({ programs: ['Millas Viajero'] });
    await expect(s.run()).rejects.toMatchObject({
      kind: 'UNPROCESSABLE',
      code: 'PROGRAM_NOT_FOUND',
      details: { programs: ['cash bac', 'Puntos'] },
    });
  });

  it('answers 422 PROGRAM_NOT_FOUND when the statement lists no program', async () => {
    const s = setup({ read: async () => ({ programs: [], model: 'm' }) });
    await expect(s.run()).rejects.toMatchObject({ code: 'PROGRAM_NOT_FOUND' });
  });

  it('lists the programs without a match when the verification has several', async () => {
    const s = setup({ programs: ['CASH BAC', 'Puntos'] });
    const result = await s.run();
    expect(result.matchedBalance).toBeNull();
    expect(result.programs).toHaveLength(2);
  });

  it('propagates NOT_A_STATEMENT', async () => {
    const s = setup({
      read: async () => {
        throw new NotAStatementError();
      },
    });
    await expect(s.run()).rejects.toMatchObject({ code: 'NOT_A_STATEMENT' });
  });

  it('rejects non-PDF files, foreign and not-ready verifications before calling Claude', async () => {
    const s = setup({});
    await expect(s.run('u-1', Buffer.from('nope!!'))).rejects.toMatchObject({
      code: 'INVALID_PDF',
    });
    await expect(s.run('u-2')).rejects.toMatchObject({
      code: 'VERIFICATION_NOT_FOUND',
    });
    const processing = setup({ status: 'PROCESSING' });
    await expect(processing.run()).rejects.toMatchObject({
      code: 'VERIFICATION_NOT_READY',
    });
    expect(s.reads() + processing.reads()).toBe(0);
  });

  it('accepts COMPLETED verifications', async () => {
    const s = setup({ status: 'COMPLETED' });
    expect((await s.run()).matchedBalance).toBe('120.5');
  });
});
