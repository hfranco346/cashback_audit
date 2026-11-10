import { Injectable } from '@nestjs/common';
import { isUniqueViolation } from '../../shared/prisma/errors.js';
import { PrismaService } from '../../shared/prisma/prisma.service.js';
import type { Prisma } from '../../shared/prisma/generated/client.js';
import {
  balanceOf,
  decideConsumption,
  packDebit,
  planRenewal,
  refundOf,
  type CreditBalance,
  type CreditSource,
  type EntryDraft,
  type LedgerState,
} from '../domain/credit-ledger.js';
import {
  CreditLedgerRepository,
  type GrantOutcome,
  type LedgerEntry,
  type Reservation,
} from '../domain/credit-ledger.repository.js';

type Tx = Prisma.TransactionClient;

class DuplicateRef extends Error {}

@Injectable()
export class PrismaCreditLedgerRepository extends CreditLedgerRepository {
  constructor(private readonly prisma: PrismaService) {
    super();
  }

  /** Serializes everything that touches one user's credits. */
  private async lock(tx: Tx, userId: string): Promise<boolean> {
    const rows = await tx.$queryRaw<{ id: string }[]>`
      SELECT "id" FROM "User" WHERE "id" = ${userId}::uuid FOR UPDATE`;
    return rows.length > 0;
  }

  private async state(tx: Tx, userId: string): Promise<LedgerState> {
    const groups = await tx.creditLedger.groupBy({
      by: ['bucket', 'periodEnd'],
      where: { userId },
      _sum: { delta: true },
    });
    const grants = await tx.creditLedger.findMany({
      where: { userId, reason: 'GRANT_PLAN' },
      select: { periodEnd: true },
    });
    return {
      pools: groups.map((g) => ({
        bucket: g.bucket,
        periodEnd: g.periodEnd,
        balance: g._sum.delta ?? 0,
      })),
      grantedPlanPeriods: grants.flatMap((g) =>
        g.periodEnd ? [g.periodEnd] : [],
      ),
    };
  }

  private async append(
    tx: Tx,
    userId: string,
    draft: EntryDraft,
    extra: {
      source: CreditSource;
      externalRef?: string | null;
      verificationId?: string | null;
    },
  ) {
    try {
      return await tx.creditLedger.create({
        data: {
          userId,
          delta: draft.delta,
          bucket: draft.bucket,
          reason: draft.reason,
          periodEnd: draft.periodEnd,
          source: extra.source,
          externalRef: extra.externalRef ?? null,
          verificationId: extra.verificationId ?? null,
        },
      });
    } catch (error) {
      if (isUniqueViolation(error)) throw new DuplicateRef();
      throw error;
    }
  }

  /** Runs `work` locked; a duplicate idempotency key rolls it all back. */
  private async locked<T>(
    userId: string,
    work: (tx: Tx) => Promise<T>,
    onDuplicate: T,
  ): Promise<T> {
    try {
      return await this.prisma.$transaction(async (tx) => {
        if (!(await this.lock(tx, userId))) return onDuplicate;
        return work(tx);
      });
    } catch (error) {
      if (error instanceof DuplicateRef) return onDuplicate;
      throw error;
    }
  }

  async balance(userId: string, now: Date): Promise<CreditBalance> {
    return balanceOf(await this.state(this.prisma, userId), now);
  }

  async isUnlimited(userId: string): Promise<boolean> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { unlimitedCredits: true },
    });
    return user?.unlimitedCredits ?? false;
  }

  async history(userId: string, skip: number, take: number) {
    const [rows, total] = await Promise.all([
      this.prisma.creditLedger.findMany({
        where: { userId },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip,
        take,
      }),
      this.prisma.creditLedger.count({ where: { userId } }),
    ]);
    const items: LedgerEntry[] = rows.map((r) => ({
      id: r.id,
      delta: r.delta,
      bucket: r.bucket,
      reason: r.reason,
      source: r.source,
      verificationId: r.verificationId,
      periodEnd: r.periodEnd,
      createdAt: r.createdAt,
    }));
    return { items, total };
  }

  async ensureFree(userId: string, credits: number): Promise<void> {
    if (credits <= 0) return;
    const existing = await this.prisma.creditLedger.findUnique({
      where: { externalRef: `free:${userId}` },
      select: { id: true },
    });
    if (existing) return;
    await this.locked(
      userId,
      async (tx) => {
        await this.append(
          tx,
          userId,
          {
            delta: credits,
            bucket: 'FREE',
            reason: 'GRANT_FREE',
            periodEnd: null,
          },
          { source: 'SYSTEM', externalRef: `free:${userId}` },
        );
      },
      undefined,
    );
  }

  async reserve(
    userId: string,
    params: { now: Date; freeCredits: number; verificationId: string | null },
  ) {
    return this.prisma.$transaction(async (tx) => {
      await this.lock(tx, userId);
      if (params.freeCredits > 0) {
        const granted = await tx.creditLedger.findUnique({
          where: { externalRef: `free:${userId}` },
          select: { id: true },
        });
        if (!granted) {
          await this.append(
            tx,
            userId,
            {
              delta: params.freeCredits,
              bucket: 'FREE',
              reason: 'GRANT_FREE',
              periodEnd: null,
            },
            { source: 'SYSTEM', externalRef: `free:${userId}` },
          );
        }
      }
      const state = await this.state(tx, userId);
      const draft = decideConsumption(state, params.now);
      if (!draft) {
        return { ok: false as const, balance: balanceOf(state, params.now) };
      }
      const entry = await this.append(tx, userId, draft, {
        source: 'SYSTEM',
        verificationId: params.verificationId,
      });
      return {
        ok: true as const,
        reservation: {
          entryId: entry.id,
          userId,
          draft,
          verificationId: params.verificationId,
        },
      };
    });
  }

  async refund(reservation: Reservation): Promise<void> {
    await this.locked(
      reservation.userId,
      async (tx) => {
        await this.append(tx, reservation.userId, refundOf(reservation.draft), {
          source: 'SYSTEM',
          externalRef: `refund:${reservation.entryId}`,
          verificationId: reservation.verificationId,
        });
      },
      undefined,
    );
  }

  async refundVerification(
    userId: string,
    verificationId: string,
  ): Promise<void> {
    const consumed = await this.prisma.creditLedger.findFirst({
      where: { userId, verificationId, reason: 'CONSUME' },
      orderBy: { createdAt: 'asc' },
    });
    if (!consumed) return;
    await this.refund({
      entryId: consumed.id,
      userId,
      verificationId,
      draft: {
        delta: consumed.delta,
        bucket: consumed.bucket,
        reason: 'CONSUME',
        periodEnd: consumed.periodEnd,
      },
    });
  }

  async grantPlanPeriod(
    userId: string,
    params: {
      periodEnd: Date;
      credits: number;
      source: CreditSource;
      externalRef: string;
    },
  ): Promise<GrantOutcome> {
    return this.locked<GrantOutcome>(
      userId,
      async (tx) => {
        const drafts = planRenewal(await this.state(tx, userId), params);
        if (drafts.length === 0) return 'NOTHING';
        for (const [i, draft] of drafts.entries()) {
          await this.append(tx, userId, draft, {
            source: params.source,
            // Only the grant carries the idempotency key.
            externalRef:
              draft.reason === 'GRANT_PLAN'
                ? params.externalRef
                : `${params.externalRef}:expire:${i}`,
          });
        }
        return 'APPLIED';
      },
      'DUPLICATE',
    );
  }

  async grantPack(
    userId: string,
    params: { credits: number; source: CreditSource; externalRef: string },
  ): Promise<GrantOutcome> {
    return this.locked<GrantOutcome>(
      userId,
      async (tx) => {
        await this.append(
          tx,
          userId,
          {
            delta: params.credits,
            bucket: 'PURCHASED',
            reason: 'GRANT_PACK',
            periodEnd: null,
          },
          { source: params.source, externalRef: params.externalRef },
        );
        return 'APPLIED';
      },
      'DUPLICATE',
    );
  }

  async debitPack(
    userId: string,
    params: {
      credits: number;
      source: CreditSource;
      externalRef: string;
      now: Date;
    },
  ) {
    return this.locked<{ outcome: GrantOutcome; debited: number }>(
      userId,
      async (tx) => {
        const draft = packDebit(
          await this.state(tx, userId),
          params.now,
          params.credits,
        );
        if (!draft) {
          // Record the event so it is not reprocessed.
          await this.append(
            tx,
            userId,
            {
              delta: 0,
              bucket: 'PURCHASED',
              reason: 'REFUND',
              periodEnd: null,
            },
            { source: params.source, externalRef: params.externalRef },
          );
          return { outcome: 'NOTHING' as const, debited: 0 };
        }
        await this.append(tx, userId, draft, {
          source: params.source,
          externalRef: params.externalRef,
        });
        return { outcome: 'APPLIED' as const, debited: -draft.delta };
      },
      { outcome: 'DUPLICATE' as const, debited: 0 },
    );
  }
}
