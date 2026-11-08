import { Injectable } from '@nestjs/common';
import { Decimal } from 'decimal.js';
import { PrismaService } from '../../shared/prisma/prisma.service.js';
import type {
  Prisma,
  Verification as PrismaVerification,
} from '../../shared/prisma/generated/client.js';
import type { CurrencySubtotal } from '../domain/reward-calculator.js';
import type { CurrencySummary, LoyaltyProgram } from '../domain/statement.js';
import type {
  NewVerification,
  Verification,
  VerificationBreakdownLine,
  VerificationConversion,
  VerificationLoyalty,
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
type Json = Record<string, unknown>;
const decStr = (value: Decimal | null | undefined) =>
  value ? value.toString() : null;
const parseDec = (value: unknown) =>
  value === null || value === undefined ? null : new Decimal(value as string);

const serializeTransaction = (t: VerificationTransaction) => ({
  ...t,
  amount: t.amount.toString(),
  appliedRatePercent: t.appliedRatePercent.toString(),
  expectedReward: t.expectedReward.toString(),
  convertedAmount: decStr(t.convertedAmount),
  exchangeRate: decStr(t.exchangeRate),
});
const deserializeTransaction = (j: Json): VerificationTransaction =>
  ({
    reference: null,
    kind: j.isCredit ? 'REFUND' : 'PURCHASE',
    rateSource: null,
    excludedReason: null,
    ...j,
    amount: new Decimal(j.amount as string),
    appliedRatePercent: new Decimal(j.appliedRatePercent as string),
    expectedReward: new Decimal(j.expectedReward as string),
    convertedAmount: parseDec(j.convertedAmount),
    exchangeRate: parseDec(j.exchangeRate),
  }) as VerificationTransaction;

const serializeSummary = (s: CurrencySummary) => ({
  currency: s.currency,
  previousBalance: decStr(s.previousBalance),
  purchasesAndCharges: decStr(s.purchasesAndCharges),
  totalBalance: decStr(s.totalBalance),
});
const deserializeSummary = (j: Json): CurrencySummary => ({
  currency: j.currency as string,
  previousBalance: parseDec(j.previousBalance),
  purchasesAndCharges: parseDec(j.purchasesAndCharges),
  totalBalance: parseDec(j.totalBalance),
});

const serializeProgram = (p: LoyaltyProgram) => ({
  name: p.name,
  unit: p.unit,
  accumulated: decStr(p.accumulated),
  available: decStr(p.available),
  redeemedInPeriod: decStr(p.redeemedInPeriod),
  expiring: decStr(p.expiring),
  forfeited: decStr(p.forfeited),
});
const deserializeProgram = (j: Json): LoyaltyProgram => ({
  name: j.name as string,
  unit: j.unit as LoyaltyProgram['unit'],
  accumulated: parseDec(j.accumulated),
  available: parseDec(j.available),
  redeemedInPeriod: parseDec(j.redeemedInPeriod),
  expiring: parseDec(j.expiring),
  forfeited: parseDec(j.forfeited),
});

const serializeSubtotal = (c: CurrencySubtotal) => ({
  ...c,
  spent: c.spent.toString(),
  eligibleSpent: c.eligibleSpent.toString(),
  convertedEligibleSpent: c.convertedEligibleSpent.toString(),
  exchangeRate: decStr(c.exchangeRate),
  expectedReward: c.expectedReward.toString(),
});
const deserializeSubtotal = (j: Json): CurrencySubtotal =>
  ({
    ...j,
    spent: new Decimal(j.spent as string),
    eligibleSpent: new Decimal(j.eligibleSpent as string),
    convertedEligibleSpent: new Decimal(j.convertedEligibleSpent as string),
    exchangeRate: parseDec(j.exchangeRate),
    expectedReward: new Decimal(j.expectedReward as string),
  }) as CurrencySubtotal;

const serializeConversion = (c: VerificationConversion) => ({
  requestedRate: decStr(c.requestedRate),
  statementRate: c.statementRate
    ? { ...c.statementRate, rate: c.statementRate.rate.toString() }
    : null,
  currencies: c.currencies.map(serializeSubtotal),
});
const deserializeConversion = (j: Json): VerificationConversion => {
  const rate = j.statementRate as Json | null | undefined;
  return {
    requestedRate: parseDec(j.requestedRate),
    statementRate: rate
      ? ({
          ...rate,
          rate: new Decimal(rate.rate as string),
        } as VerificationConversion['statementRate'])
      : null,
    currencies: ((j.currencies as Json[] | undefined) ?? []).map(
      deserializeSubtotal,
    ),
  };
};

const serializeLoyalty = (l: VerificationLoyalty) => ({
  selected: l.selected ? serializeProgram(l.selected) : null,
  selectedBy: l.selectedBy,
  programs: l.programs.map(serializeProgram),
});
const deserializeLoyalty = (j: Json): VerificationLoyalty => ({
  selected: j.selected ? deserializeProgram(j.selected as Json) : null,
  selectedBy: (j.selectedBy as VerificationLoyalty['selectedBy']) ?? null,
  programs: ((j.programs as Json[] | undefined) ?? []).map(deserializeProgram),
});

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
    primaryCurrency: row.primaryCurrency,
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

const asRecord = (value: unknown): Json =>
  value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Json)
    : {};
const asArray = (value: unknown): Json[] =>
  Array.isArray(value) ? (value as Json[]) : [];

function toDomain(row: PrismaVerification): Verification {
  return {
    ...toSummary(row),
    breakdown: asArray(row.breakdown).map(deserializeLine),
    transactions: asArray(row.transactions).map(deserializeTransaction),
    warnings: row.warnings as unknown as VerificationWarning[],
    summaries: asArray(row.summaries).map(deserializeSummary),
    conversion: deserializeConversion(asRecord(row.conversion)),
    loyalty: deserializeLoyalty(asRecord(row.loyalty)),
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
        primaryCurrency: input.primaryCurrency,
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
        summaries: input.summaries.map(
          serializeSummary,
        ) as Prisma.InputJsonValue,
        conversion: serializeConversion(
          input.conversion,
        ) as Prisma.InputJsonValue,
        loyalty: serializeLoyalty(input.loyalty) as Prisma.InputJsonValue,
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
