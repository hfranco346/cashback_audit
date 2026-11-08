import {
  Injectable,
  Logger,
  type OnModuleDestroy,
  type OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Env } from '../../config/env.js';
import { VerificationRepository } from '../domain/verification.repository.js';

const DAY_MS = 24 * 60 * 60 * 1000;
const RUN_EVERY_MS = 6 * 60 * 60 * 1000;

/**
 * Deletes verifications abandoned in AWAITING_RATES (the user never confirmed
 * the rates). Runs at startup and every 6 hours; disabled under NODE_ENV=test.
 */
@Injectable()
export class CleanupAwaitingRatesService
  implements OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(CleanupAwaitingRatesService.name);
  private timer: NodeJS.Timeout | undefined;

  constructor(
    private readonly verifications: VerificationRepository,
    private readonly config: ConfigService<Env, true>,
  ) {}

  onModuleInit(): void {
    if (this.config.get('NODE_ENV', { infer: true }) === 'test') return;
    const tick = () =>
      this.run().catch((error: unknown) =>
        this.logger.error(
          `Cleanup failed: ${error instanceof Error ? error.name : 'unknown'}`,
        ),
      );
    void tick();
    this.timer = setInterval(tick, RUN_EVERY_MS);
    this.timer.unref();
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }

  /** Returns how many abandoned verifications were deleted. */
  async run(now: Date = new Date()): Promise<number> {
    const days = this.config.get('AWAITING_RATES_TTL_DAYS', { infer: true });
    const deleted = await this.verifications.deleteAwaitingCreatedBefore(
      new Date(now.getTime() - days * DAY_MS),
    );
    if (deleted > 0)
      this.logger.log(
        `Deleted ${deleted} abandoned AWAITING_RATES verification(s)`,
      );
    return deleted;
  }
}
