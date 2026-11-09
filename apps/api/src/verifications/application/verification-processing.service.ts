import {
  Injectable,
  Logger,
  type OnApplicationBootstrap,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Env } from '../../config/env.js';
import { CreditsService } from '../../credits/application/credits.service.js';
import { UnreadableStatementError } from '../domain/verification-errors.js';
import type { VerificationFailureCode } from '../domain/verification.js';
import { VerificationRepository } from '../domain/verification.repository.js';
import {
  ProcessVerificationUseCase,
  type VerificationJob,
} from './process-verification.use-case.js';

/**
 * In-process background queue with bounded concurrency. The PDF travels in
 * memory only (it is never written to disk or the database), so a crash loses
 * the job: boot recovery turns the orphaned PROCESSING rows into FAILED /
 * INTERRUPTED and refunds their credit.
 */
@Injectable()
export class VerificationProcessingService implements OnApplicationBootstrap {
  private readonly logger = new Logger(VerificationProcessingService.name);
  private readonly concurrency: number;
  private readonly waiting: VerificationJob[] = [];
  private running = 0;
  private idleWaiters: (() => void)[] = [];

  constructor(
    private readonly processor: ProcessVerificationUseCase,
    private readonly verifications: VerificationRepository,
    private readonly credits: CreditsService,
    config: ConfigService<Env, true>,
  ) {
    this.concurrency = config.get('VERIFICATION_CONCURRENCY', { infer: true });
  }

  async onApplicationBootstrap(): Promise<void> {
    try {
      await this.recoverInterrupted();
    } catch (error) {
      this.logger.error(
        `Boot recovery failed: ${error instanceof Error ? error.name : 'unknown'}`,
      );
    }
  }

  /** Queues a job; never throws and never blocks the caller. */
  enqueue(job: VerificationJob): void {
    this.waiting.push(job);
    this.pump();
  }

  /** Resolves when nothing is running or waiting (used by tests and shutdown). */
  idle(): Promise<void> {
    if (this.running === 0 && this.waiting.length === 0)
      return Promise.resolve();
    return new Promise((resolve) => this.idleWaiters.push(resolve));
  }

  /**
   * PROCESSING rows with no job in this process (a previous run crashed or
   * restarted): the PDF is gone, so they fail as INTERRUPTED with a refund.
   */
  async recoverInterrupted(): Promise<number> {
    const orphans = await this.verifications.listProcessing();
    for (const { id, userId } of orphans) {
      await this.fail(userId, id, 'INTERRUPTED');
    }
    if (orphans.length > 0)
      this.logger.warn(
        `Recovered ${orphans.length} interrupted verification(s)`,
      );
    return orphans.length;
  }

  private pump(): void {
    while (this.running < this.concurrency && this.waiting.length > 0) {
      const job = this.waiting.shift()!;
      this.running++;
      void this.run(job).finally(() => {
        this.running--;
        this.pump();
        if (this.running === 0 && this.waiting.length === 0) {
          const waiters = this.idleWaiters;
          this.idleWaiters = [];
          for (const resolve of waiters) resolve();
        }
      });
    }
  }

  private async run(job: VerificationJob): Promise<void> {
    try {
      await this.processor.execute(job);
    } catch (error) {
      const code: VerificationFailureCode =
        error instanceof UnreadableStatementError
          ? 'NOT_A_STATEMENT'
          : 'EXTRACTION_FAILED';
      this.logger.warn(
        `Verification ${job.verificationId} failed: ${code} (${error instanceof Error ? error.name : 'unknown'})`,
      );
      await this.fail(job.userId, job.verificationId, code);
    }
  }

  /** Refunds first (idempotent) so a crash in between is repaired on boot. */
  private async fail(
    userId: string,
    id: string,
    failureCode: VerificationFailureCode,
  ): Promise<void> {
    try {
      await this.credits.refundVerification(userId, id);
      await this.verifications.update(
        userId,
        id,
        { status: 'FAILED', failureCode, processedAt: new Date() },
        { onlyIfStatus: 'PROCESSING' },
      );
    } catch (error) {
      this.logger.error(
        `Could not mark verification ${id} as failed: ${error instanceof Error ? error.name : 'unknown'}`,
      );
    }
  }
}
