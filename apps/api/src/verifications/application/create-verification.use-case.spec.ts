import type { Card } from '../../cards/domain/card.js';
import type { CardRepository } from '../../cards/domain/card.repository.js';
import type { CreditsService } from '../../credits/application/credits.service.js';
import { NoCreditsError } from '../../credits/domain/credit-errors.js';
import type { NewVerification, Verification } from '../domain/verification.js';
import type { VerificationRepository } from '../domain/verification.repository.js';
import { CreateVerificationUseCase } from './create-verification.use-case.js';
import type { VerificationProcessingService } from './verification-processing.service.js';
import type { VerificationJob } from './process-verification.use-case.js';

const USER = 'user-1';
const pdf = Buffer.from('%PDF-1.4 fake');
const card = {
  id: 'card-1',
  userId: USER,
  currency: 'MXN',
  rewardUnit: 'CASHBACK_CURRENCY',
} as Card;

function setup(opts: { card?: Card | null; credits?: 'ok' | 'none' } = {}) {
  const events: string[] = [];
  const saved: NewVerification[] = [];
  const jobs: VerificationJob[] = [];
  const useCase = new CreateVerificationUseCase(
    {
      findById: async () => (opts.card === undefined ? card : opts.card),
    } as unknown as CardRepository,
    {
      create: async (input: NewVerification) => {
        events.push('create');
        saved.push(input);
        return { ...input, createdAt: new Date() } as Verification;
      },
    } as unknown as VerificationRepository,
    {
      reserve: async (_user: string, verificationId: string) => {
        events.push('reserve');
        if (opts.credits === 'none')
          throw new NoCreditsError({
            free: 0,
            plan: 0,
            planPeriodEnd: null,
            purchased: 0,
            total: 0,
            subscriptionActive: false,
          });
        return { entryId: 'e-1', verificationId };
      },
      refund: async () => {
        events.push('refund');
      },
    } as unknown as CreditsService,
    {
      enqueue: (job: VerificationJob) => {
        events.push('enqueue');
        jobs.push(job);
      },
    } as unknown as VerificationProcessingService,
  );
  const run = (input: { pdf?: Buffer } = {}) =>
    useCase.execute({ userId: USER, cardId: 'card-1', pdf, ...input });
  return { run, events, saved, jobs };
}

describe('CreateVerificationUseCase', () => {
  it('reserves the credit, stores a PROCESSING row and queues the job', async () => {
    const s = setup();
    const v = await s.run();
    expect(s.events).toEqual(['reserve', 'create', 'enqueue']);
    expect(v.status).toBe('PROCESSING');
    expect(s.saved[0]).toMatchObject({
      status: 'PROCESSING',
      cardId: 'card-1',
      primaryCurrency: 'MXN',
      transactions: [],
      verdict: null,
    });
    expect(s.saved[0]!.processingStartedAt).toBeInstanceOf(Date);
    expect(s.jobs[0]).toMatchObject({
      verificationId: s.saved[0]!.id,
      userId: USER,
      card,
      pdf,
    });
    expect(s.saved[0]!.id).toMatch(/^[0-9a-f-]{36}$/);
  });

  it('rejects non-PDF bytes and unknown cards without spending anything', async () => {
    const s = setup();
    await expect(s.run({ pdf: Buffer.from('GIF89a') })).rejects.toMatchObject({
      code: 'INVALID_PDF',
    });
    const none = setup({ card: null });
    await expect(none.run()).rejects.toMatchObject({ code: 'CARD_NOT_FOUND' });
    expect(s.events).toEqual([]);
    expect(none.events).toEqual([]);
  });

  it('answers NO_CREDITS before storing or queueing anything', async () => {
    const s = setup({ credits: 'none' });
    await expect(s.run()).rejects.toMatchObject({ code: 'NO_CREDITS' });
    expect(s.events).toEqual(['reserve']);
  });
});
