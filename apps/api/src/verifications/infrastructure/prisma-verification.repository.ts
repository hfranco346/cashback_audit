import { Injectable } from '@nestjs/common';
import { Decimal } from 'decimal.js';
import { PrismaService } from '../../shared/prisma/prisma.service.js';
import type {
  Prisma,
  Verification as PrismaVerification,
} from '../../shared/prisma/generated/client.js';
import type {
  NewVerification,
  Verification,
  VerificationBreakdownLine,
  VerificationSummary,
  VerificationTransaction,
  VerificationWarning,
} from '../domain/verification.js';
import {
  VerificationRepository,
  type VerificationPage,
} from '../domain/verification.repository.js';

const dec = (value: { toString(): string }) => new Decimal(value.toString());
const decOrNull = (value: { toString(): string } | null) =>
  value ? dec(value) : null;
const dateOnly = (date: Date | null) =>
  date ? date.toISOString().slice(0, 10) : null;

// JSON (de)serialization: decimals travel as strings.
const serializeTransaction = (t: VerificationTransaction) => ({
  ...t,
  amount: t.amount.toString(),
  appliedRatePercent: t.appliedRatePercent.toString(),
  expectedReward: t.expectedReward.toString(),
});
const deserializeTransaction = (
  j: Record<string, unknown>,
): VerificationTransaction =>
  ({
    ...j,
    amount: new Decimal(j.amount as string),
    appliedRatePercent: new Decimal(j.appliedRatePercent as string),
    expectedReward: new Decimal(j.expectedReward as string),
  }) as VerificationTransaction;

const serializeLine = (l: VerificationBreakdownLine) => ({
  ...l,
  ratePercent: l.ratePercent.toString(),
  spend: l.spend.toString(),
  uncappedReward: l.uncappedReward.toString(),
  expectedReward: l.expectedReward.toString(),
  monthlyCap: l.monthlyCap?.toString() ?? null,
});
const deserializeLine = (
  j: Record<string, unknown>,
): VerificationBreakdownLine =>
  ({
    ...j,
    ratePercent: new Decimal(j.ratePercent as string),
    spend: new Decimal(j.spend as string),
    uncappedReward: new Decimal(j.uncappedReward as string),
    expectedReward: new Decimal(j.expectedReward as string),
    monthlyCap: j.monthlyCap ? new Decimal(j.monthlyCap as string) : null,
  }) as VerificationBreakdownLine;

function toSummary(row: PrismaVerification): VerificationSummary {
  return {
    id: row.id,
    userId: row.userId,
    cardId: row.cardId,
    statementBank: row.statementBank,
    statementLast4: row.statementLast4,
    periodStart: dateOnly(row.periodStart),
    periodEnd: dateOnly(row.periodEnd),
    currency: row.currency,
    totalSpent: decOrNull(row.totalSpent),
    totalToPay: decOrNull(row.totalToPay),
    reportedAmount: dec(row.reportedAmount),
    reportedUnit: row.reportedUnit,
    reportedLabel: row.reportedLabel,
    reportedSource: row.reportedSource,
    expectedAmount: dec(row.expectedAmount),
    difference: dec(row.difference),
    tolerance: dec(row.tolerance),
    verdict: row.verdict,
    model: row.model,
    createdAt: row.createdAt,
  };
}

function toDomain(row: PrismaVerification): Verification {
  return {
    ...toSummary(row),
    breakdown: (row.breakdown as Record<string, unknown>[]).map(
      deserializeLine,
    ),
    transactions: (row.transactions as Record<string, unknown>[]).map(
      deserializeTransaction,
    ),
    warnings: row.warnings as unknown as VerificationWarning[],
  };
}

@Injectable()
export class PrismaVerificationRepository extends VerificationRepository {
  constructor(private readonly prisma: PrismaService) {
    super();
  }

  async create(input: NewVerification): Promise<Verification> {
    const row = await this.prisma.verification.create({
      data: {
        userId: input.userId,
        cardId: input.cardId,
        statementBank: input.statementBank,
        statementLast4: input.statementLast4,
        periodStart: input.periodStart
          ? new Date(`${input.periodStart}T00:00:00Z`)
          : null,
        periodEnd: input.periodEnd
          ? new Date(`${input.periodEnd}T00:00:00Z`)
          : null,
        currency: input.currency,
        totalSpent: input.totalSpent?.toString() ?? null,
        totalToPay: input.totalToPay?.toString() ?? null,
        reportedAmount: input.reportedAmount.toString(),
        reportedUnit: input.reportedUnit,
        reportedLabel: input.reportedLabel,
        reportedSource: input.reportedSource,
        expectedAmount: input.expectedAmount.toString(),
        difference: input.difference.toString(),
        tolerance: input.tolerance.toString(),
        verdict: input.verdict,
        breakdown: input.breakdown.map(serializeLine) as Prisma.InputJsonValue,
        transactions: input.transactions.map(
          serializeTransaction,
        ) as Prisma.InputJsonValue,
        warnings: input.warnings as unknown as Prisma.InputJsonValue,
        model: input.model,
      },
    });
    return toDomain(row);
  }

  async findById(userId: string, id: string): Promise<Verification | null> {
    const row = await this.prisma.verification.findFirst({
      where: { id, userId },
    });
    return row ? toDomain(row) : null;
  }

  async list(
    userId: string,
    filter: { cardId?: string; skip: number; take: number },
  ): Promise<VerificationPage> {
    const where = { userId, ...(filter.cardId && { cardId: filter.cardId }) };
    const [rows, total] = await Promise.all([
      this.prisma.verification.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: filter.skip,
        take: filter.take,
      }),
      this.prisma.verification.count({ where }),
    ]);
    return { items: rows.map(toSummary), total };
  }

  async delete(userId: string, id: string): Promise<boolean> {
    const result = await this.prisma.verification.deleteMany({
      where: { id, userId },
    });
    return result.count > 0;
  }
}
