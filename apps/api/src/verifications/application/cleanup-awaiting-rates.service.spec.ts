import { ConfigService } from '@nestjs/config';
import { VerificationRepository } from '../domain/verification.repository.js';
import { CleanupAwaitingRatesService } from './cleanup-awaiting-rates.service.js';

describe('CleanupAwaitingRatesService', () => {
  const make = (days: number) => {
    const cutoffs: Date[] = [];
    const service = new CleanupAwaitingRatesService(
      {
        deleteAwaitingCreatedBefore: async (cutoff: Date) => {
          cutoffs.push(cutoff);
          return 3;
        },
      } as unknown as VerificationRepository,
      new ConfigService({
        AWAITING_RATES_TTL_DAYS: days,
        NODE_ENV: 'test',
      }) as never,
    );
    return { service, cutoffs };
  };

  it('deletes AWAITING_RATES older than the configured TTL', async () => {
    const { service, cutoffs } = make(7);
    const deleted = await service.run(new Date('2026-02-15T12:00:00Z'));
    expect(deleted).toBe(3);
    expect(cutoffs[0]!.toISOString()).toBe('2026-02-08T12:00:00.000Z');
  });

  it('does not schedule anything under NODE_ENV=test', () => {
    const { service } = make(7);
    service.onModuleInit();
    service.onModuleDestroy();
    expect(cutoffs0(service)).toBeUndefined();
  });
});

const cutoffs0 = (service: object) => (service as { timer?: unknown }).timer;
