import type { ConfigService } from '@nestjs/config';
import type { Env } from '../../config/env.js';
import type { CreditsService } from '../../credits/application/credits.service.js';
import { UnreadableStatementError } from '../domain/verification-errors.js';
import type { VerificationUpdate } from '../domain/verification.js';
import type { VerificationRepository } from '../domain/verification.repository.js';
import type {
  ProcessVerificationUseCase,
  VerificationJob,
} from './process-verification.use-case.js';
import { VerificationProcessingService } from './verification-processing.service.js';

const job = (id: string): VerificationJob => ({
  verificationId: id,
  userId: 'u-1',
  card: {} as VerificationJob['card'],
  pdf: Buffer.from('%PDF-'),
});

function setup(
  behavior: (job: VerificationJob) => Promise<void>,
  opts: { concurrency?: number; processing?: string[] } = {},
) {
  const updates: { id: string; patch: VerificationUpdate }[] = [];
  const refunds: string[] = [];
  let active = 0;
  let peak = 0;
  const service = new VerificationProcessingService(
    {
      execute: async (j: VerificationJob) => {
        active++;
        peak = Math.max(peak, active);
        try {
          await behavior(j);
        } finally {
          active--;
        }
      },
    } as unknown as ProcessVerificationUseCase,
    {
      update: async (_u: string, id: string, patch: VerificationUpdate) => {
        updates.push({ id, patch });
        return null;
      },
      listProcessing: async () =>
        (opts.processing ?? []).map((id) => ({ id, userId: 'u-1' })),
    } as unknown as VerificationRepository,
    {
      refundVerification: async (_u: string, id: string) => {
        refunds.push(id);
      },
    } as unknown as CreditsService,
    {
      get: () => opts.concurrency ?? 2,
    } as unknown as ConfigService<Env, true>,
  );
  return { service, updates, refunds, peak: () => peak };
}

describe('VerificationProcessingService', () => {
  it('runs queued jobs and leaves successful ones untouched', async () => {
    const s = setup(async () => {});
    s.service.enqueue(job('a'));
    await s.service.idle();
    expect(s.updates).toEqual([]);
    expect(s.refunds).toEqual([]);
  });

  it('fails NOT_A_STATEMENT on unreadable statements and refunds first', async () => {
    const s = setup(async () => {
      throw new UnreadableStatementError();
    });
    s.service.enqueue(job('a'));
    await s.service.idle();
    expect(s.refunds).toEqual(['a']);
    expect(s.updates).toHaveLength(1);
    expect(s.updates[0]!.patch).toMatchObject({
      status: 'FAILED',
      failureCode: 'NOT_A_STATEMENT',
    });
  });

  it('fails EXTRACTION_FAILED on any other error', async () => {
    const s = setup(async () => {
      throw new Error('boom');
    });
    s.service.enqueue(job('a'));
    await s.service.idle();
    expect(s.refunds).toEqual(['a']);
    expect(s.updates[0]!.patch).toMatchObject({
      status: 'FAILED',
      failureCode: 'EXTRACTION_FAILED',
    });
  });

  it('never runs more jobs at once than the configured concurrency', async () => {
    const s = setup(() => new Promise((resolve) => setTimeout(resolve, 5)), {
      concurrency: 2,
    });
    for (const id of ['a', 'b', 'c', 'd', 'e']) s.service.enqueue(job(id));
    await s.service.idle();
    expect(s.peak()).toBe(2);
  });

  it('boot recovery fails orphaned PROCESSING rows as INTERRUPTED with a refund', async () => {
    const s = setup(async () => {}, { processing: ['x', 'y'] });
    await s.service.onApplicationBootstrap();
    expect(s.refunds).toEqual(['x', 'y']);
    expect(
      s.updates.map((u) => [u.id, u.patch.status, u.patch.failureCode]),
    ).toEqual([
      ['x', 'FAILED', 'INTERRUPTED'],
      ['y', 'FAILED', 'INTERRUPTED'],
    ]);
  });

  it('does not let a failing recovery break the boot', async () => {
    const s = setup(async () => {});
    s.service['verifications'].listProcessing = async () => {
      throw new Error('db down');
    };
    await expect(s.service.onApplicationBootstrap()).resolves.toBeUndefined();
  });
});
