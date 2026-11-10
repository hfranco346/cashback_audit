import { Injectable } from '@nestjs/common';
import { Decimal } from 'decimal.js';
import { PrismaService } from '../../shared/prisma/prisma.service.js';
import {
  Prisma,
  type Verification as PrismaVerification,
} from '../../shared/prisma/generated/client.js';
import type { VerificationRewardReporting } from '../domain/reward-reporting.js';
import type { CurrencySubtotal } from '../domain/reward-calculator.js';
import type { DetectedRate } from '../domain/statement.js';
import type {
  CurrencySummary,
  LoyaltyProgram,
  StatementExchangeRate,
} from '../domain/statement.js';
import type {
  AppliedRates,
  NewVerification,
  VerificationUpdate,
  Verification,
  VerificationBreakdownLine,
  VerificationConversion,
  VerificationLoyalty,
  VerificationStatus,
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
  appliedRatePercent: decStr(t.appliedRatePercent),
  expectedReward: decStr(t.expectedReward),
  convertedAmount: decStr(t.convertedAmount),
  exchangeRate: decStr(t.exchangeRate),
});
const deserializeTransaction = (j: Json): VerificationTransaction =>
  ({
    reference: null,
    matchReason: null,
    suggestedHint: null,
    kind: j.isCredit ? 'REFUND' : 'PURCHASE',
    rateSource: null,
    excludedReason: null,
    ...j,
    matchSource: j.matchSource === 'AI' ? 'AI_MERCHANT' : j.matchSource,
    amount: new Decimal(j.amount as string),
    appliedRatePercent: parseDec(j.appliedRatePercent),
    expectedReward: parseDec(j.expectedReward),
    convertedAmount: parseDec(j.convertedAmount),
    exchangeRate: parseDec(j.exchangeRate),
  }) as VerificationTransaction;

const serializeSummary = (s: CurrencySummary) => ({
  currency: s.currency,
  previousBalance: decStr(s.previousBalance),
  purchasesAndCharges: decStr(s.purchasesAndCharges),
  purchases: decStr(s.purchases),
  chargesAndInterest: decStr(s.chargesAndInterest),
  totalBalance: decStr(s.totalBalance),
});
const deserializeSummary = (j: Json): CurrencySummary => ({
  currency: j.currency as string,
  previousBalance: parseDec(j.previousBalance),
  purchasesAndCharges: parseDec(j.purchasesAndCharges),
  purchases: parseDec(j.purchases),
  chargesAndInterest: parseDec(j.chargesAndInterest),
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
  previousBalance: decStr(p.previousBalance),
  earnedInPeriod: decStr(p.earnedInPeriod),
  reportedLabel: p.reportedLabel,
  currency: p.currency,
});
const deserializeProgram = (j: Json): LoyaltyProgram => ({
  name: j.name as string,
  unit: j.unit as LoyaltyProgram['unit'],
  accumulated: parseDec(j.accumulated),
  available: parseDec(j.available),
  redeemedInPeriod: parseDec(j.redeemedInPeriod),
  expiring: parseDec(j.expiring),
  forfeited: parseDec(j.forfeited),
  previousBalance: parseDec(j.previousBalance),
  earnedInPeriod: parseDec(j.earnedInPeriod),
  reportedLabel: (j.reportedLabel as string | null | undefined) ?? null,
  currency: (j.currency as string | null | undefined) ?? null,
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

const serializeStatementRate = (r: StatementExchangeRate) => ({
  ...r,
  rate: r.rate.toString(),
});
const deserializeStatementRate = (j: Json): StatementExchangeRate =>
  ({ ...j, rate: new Decimal(j.rate as string) }) as StatementExchangeRate;

const serializeConversion = (c: VerificationConversion) => ({
  requestedRate: decStr(c.requestedRate),
  requestedRates: Object.fromEntries(
    Object.entries(c.requestedRates).map(([k, v]) => [k, v.toString()]),
  ),
  requestedRewardRate: decStr(c.requestedRewardRate),
  statementRates: c.statementRates.map(serializeStatementRate),
  currencies: c.currencies.map(serializeSubtotal),
  rewardCapApplied: c.rewardCapApplied
    ? {
        cap: c.rewardCapApplied.cap.toString(),
        uncapped: c.rewardCapApplied.uncapped.toString(),
        capped: c.rewardCapApplied.capped.toString(),
      }
    : null,
  reward: c.reward
    ? {
        ...c.reward,
        rate: c.reward.rate.toString(),
        expectedInPrimary: c.reward.expectedInPrimary.toString(),
      }
    : null,
});
const deserializeConversion = (j: Json): VerificationConversion => {
  // Rows written before multi-rate support carry a single `statementRate`.
  const legacy = j.statementRate as Json | null | undefined;
  const reward = j.reward as Json | null | undefined;
  const cap = j.rewardCapApplied as Json | null | undefined;
  return {
    requestedRate: parseDec(j.requestedRate),
    requestedRates: Object.fromEntries(
      Object.entries(asRecord(j.requestedRates)).map(([k, v]) => [
        k,
        new Decimal(v as string),
      ]),
    ),
    requestedRewardRate: parseDec(j.requestedRewardRate),
    statementRates: j.statementRates
      ? asArray(j.statementRates).map(deserializeStatementRate)
      : legacy
        ? [deserializeStatementRate(legacy)]
        : [],
    currencies: ((j.currencies as Json[] | undefined) ?? []).map(
      deserializeSubtotal,
    ),
    rewardCapApplied: cap
      ? {
          cap: new Decimal(cap.cap as string),
          uncapped: new Decimal(cap.uncapped as string),
          capped: new Decimal(cap.capped as string),
        }
      : null,
    reward: reward
      ? ({
          ...reward,
          rate: new Decimal(reward.rate as string),
          expectedInPrimary: new Decimal(reward.expectedInPrimary as string),
        } as VerificationConversion['reward'])
      : null,
  };
};

const serializeLoyalty = (l: VerificationLoyalty) => ({
  requestedProgramName: l.requestedProgramName,
  reportedOverride: decStr(l.reportedOverride),
  selected: l.selected ? serializeProgram(l.selected) : null,
  selectedBy: l.selectedBy,
  programs: l.programs.map(serializeProgram),
});
const deserializeLoyalty = (j: Json): VerificationLoyalty => ({
  requestedProgramName: (j.requestedProgramName as string | undefined) ?? null,
  reportedOverride: parseDec(j.reportedOverride),
  selected: j.selected ? deserializeProgram(j.selected as Json) : null,
  selectedBy: (j.selectedBy as VerificationLoyalty['selectedBy']) ?? null,
  programs: ((j.programs as Json[] | undefined) ?? []).map(deserializeProgram),
});

const serializeReporting = (r: VerificationRewardReporting) => ({
  mode: r.mode,
  programName: r.programName,
  reportedLabel: r.reportedLabel,
  previousPeriodEnd: r.previousPeriodEnd,
  currentBalance: decStr(r.currentBalance),
  previousBalance: decStr(r.previousBalance),
  previousBalanceSource: r.previousBalanceSource,
  previousVerificationId: r.previousVerificationId,
  redeemedInPeriod: r.redeemedInPeriod.toString(),
  expiredInPeriod: r.expiredInPeriod.toString(),
  earned: decStr(r.earned),
});
const deserializeReporting = (j: Json): VerificationRewardReporting => ({
  mode: j.mode as VerificationRewardReporting['mode'],
  programName: (j.programName as string | null | undefined) ?? null,
  reportedLabel: (j.reportedLabel as string | null | undefined) ?? null,
  previousPeriodEnd: (j.previousPeriodEnd as string | null | undefined) ?? null,
  currentBalance: parseDec(j.currentBalance),
  previousBalance: parseDec(j.previousBalance),
  previousBalanceSource:
    (j.previousBalanceSource as VerificationRewardReporting['previousBalanceSource']) ??
    null,
  previousVerificationId:
    (j.previousVerificationId as string | null | undefined) ?? null,
  redeemedInPeriod: new Decimal((j.redeemedInPeriod as string) ?? '0'),
  expiredInPeriod: new Decimal((j.expiredInPeriod as string) ?? '0'),
  earned: parseDec(j.earned),
});

const serializeDetected = (r: DetectedRate) => ({
  ...r,
  ratePercent: decStr(r.ratePercent),
});
const deserializeDetected = (j: Json): DetectedRate =>
  ({ ...j, ratePercent: parseDec(j.ratePercent) }) as DetectedRate;

const serializeApplied = (a: AppliedRates) => ({
  baseRatePercent: a.baseRatePercent.toString(),
  baseSource: a.baseSource,
  savedToCard: a.savedToCard,
  rewardExchangeRate: a.rewardExchangeRate
    ? { ...a.rewardExchangeRate, rate: a.rewardExchangeRate.rate.toString() }
    : null,
  categoryRates: a.categoryRates.map((c) => ({
    ...c,
    ratePercent: c.ratePercent.toString(),
    monthlyCap: decStr(c.monthlyCap),
  })),
});
const deserializeApplied = (j: Json): AppliedRates => ({
  baseRatePercent: new Decimal(j.baseRatePercent as string),
  baseSource: j.baseSource as AppliedRates['baseSource'],
  savedToCard: Boolean(j.savedToCard),
  rewardExchangeRate: j.rewardExchangeRate
    ? ({
        ...(j.rewardExchangeRate as Json),
        rate: new Decimal((j.rewardExchangeRate as Json).rate as string),
      } as AppliedRates['rewardExchangeRate'])
    : null,
  categoryRates: asArray(j.categoryRates).map(
    (c) =>
      ({
        ...c,
        ratePercent: new Decimal(c.ratePercent as string),
        monthlyCap: parseDec(c.monthlyCap),
      }) as AppliedRates['categoryRates'][number],
  ),
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

const asRecord = (value: unknown): Json =>
  value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Json)
    : {};
type Row = PrismaVerification & {
  card?: { alias: string; bank: string; last4: string; deletedAt: Date | null };
};
const CARD_REF = {
  card: { select: { alias: true, bank: true, last4: true, deletedAt: true } },
} as const;

function toSummary(row: Row): VerificationSummary {
  return {
    id: row.id,
    userId: row.userId,
    cardId: row.cardId,
    ...(row.card && {
      card: {
        alias: row.card.alias,
        bank: row.card.bank,
        last4: row.card.last4,
        deleted: row.card.deletedAt !== null,
      },
    }),
    statementBank: row.statementBank,
    statementLast4: row.statementLast4,
    periodStart: dateOnly(row.periodStart),
    periodEnd: dateOnly(row.periodEnd),
    currency: row.currency,
    primaryCurrency: row.primaryCurrency,
    totalSpent: decOrNull(row.totalSpent),
    totalToPay: decOrNull(row.totalToPay),
    status: row.status,
    failureCode: row.failureCode,
    seenAt: row.seenAt,
    processingStartedAt: row.processingStartedAt,
    processedAt: row.processedAt,
    reportedAmount: decOrNull(row.reportedAmount),
    reportedUnit: row.reportedUnit,
    rewardCurrency: row.rewardCurrency,
    reportedLabel: row.reportedLabel,
    reportedSource: row.reportedSource,
    expectedAmount: decOrNull(row.expectedAmount),
    difference: decOrNull(row.difference),
    tolerance: decOrNull(row.tolerance),
    verdict: row.verdict,
    model: row.model,
    models: {
      extraction: (asRecord(row.models).extraction as string) ?? row.model,
      classification: (asRecord(row.models).classification as string) ?? null,
      explanation: (asRecord(row.models).explanation as string) ?? null,
    },
    createdAt: row.createdAt,
  };
}

const asArray = (value: unknown): Json[] =>
  Array.isArray(value) ? (value as Json[]) : [];

function toDomain(row: Row): Verification {
  return {
    ...toSummary(row),
    breakdown: asArray(row.breakdown).map(deserializeLine),
    transactions: asArray(row.transactions).map(deserializeTransaction),
    warnings: row.warnings as unknown as VerificationWarning[],
    summaries: asArray(row.summaries).map(deserializeSummary),
    conversion: deserializeConversion(asRecord(row.conversion)),
    loyalty: deserializeLoyalty(asRecord(row.loyalty)),
    detectedRates: asArray(row.detectedRates).map(deserializeDetected),
    appliedRates: row.appliedRates
      ? deserializeApplied(asRecord(row.appliedRates))
      : null,
    explanation: row.explanation,
    rewardReporting: row.rewardReporting
      ? deserializeReporting(asRecord(row.rewardReporting))
      : null,
  };
}

const iso = (date: string | null) =>
  date ? new Date(`${date}T00:00:00Z`) : null;

/** Maps the provided domain fields (all of them on create) to column values. */
function toData(input: VerificationUpdate): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  const set = (key: string, value: unknown) => {
    if (value !== undefined) out[key] = value;
  };
  const dstr = (v: Decimal | null | undefined) =>
    v === undefined ? undefined : (v?.toString() ?? null);
  set('statementBank', input.statementBank);
  set('statementLast4', input.statementLast4);
  set(
    'periodStart',
    input.periodStart === undefined ? undefined : iso(input.periodStart),
  );
  set(
    'periodEnd',
    input.periodEnd === undefined ? undefined : iso(input.periodEnd),
  );
  set('currency', input.currency);
  set('primaryCurrency', input.primaryCurrency);
  set('totalSpent', dstr(input.totalSpent));
  set('totalToPay', dstr(input.totalToPay));
  set('status', input.status);
  set('failureCode', input.failureCode);
  set('seenAt', input.seenAt);
  set('processingStartedAt', input.processingStartedAt);
  set('processedAt', input.processedAt);
  set('reportedAmount', dstr(input.reportedAmount));
  set('reportedUnit', input.reportedUnit);
  set('rewardCurrency', input.rewardCurrency);
  set('reportedLabel', input.reportedLabel);
  set('reportedSource', input.reportedSource);
  set('expectedAmount', dstr(input.expectedAmount));
  set('difference', dstr(input.difference));
  set('tolerance', dstr(input.tolerance));
  set('verdict', input.verdict);
  set('explanation', input.explanation);
  if (input.rewardReporting !== undefined) {
    out.rewardReporting =
      input.rewardReporting === null
        ? Prisma.JsonNull
        : serializeReporting(input.rewardReporting);
  }
  set('model', input.model);
  set('models', input.models);
  set('summaries', input.summaries?.map(serializeSummary));
  set('conversion', input.conversion && serializeConversion(input.conversion));
  set('loyalty', input.loyalty && serializeLoyalty(input.loyalty));
  set('detectedRates', input.detectedRates?.map(serializeDetected));
  if (input.appliedRates !== undefined) {
    out.appliedRates =
      input.appliedRates === null
        ? Prisma.JsonNull
        : serializeApplied(input.appliedRates);
  }
  set('breakdown', input.breakdown?.map(serializeLine));
  set('transactions', input.transactions?.map(serializeTransaction));
  set('warnings', input.warnings);
  return out;
}

@Injectable()
export class PrismaVerificationRepository extends VerificationRepository {
  constructor(private readonly prisma: PrismaService) {
    super();
  }

  async create(input: NewVerification): Promise<Verification> {
    const row = await this.prisma.verification.create({
      data: {
        ...(input.id && { id: input.id }),
        userId: input.userId,
        cardId: input.cardId,
        ...toData(input),
      } as Prisma.VerificationUncheckedCreateInput,
      include: CARD_REF,
    });
    return toDomain(row);
  }

  async update(
    userId: string,
    id: string,
    patch: VerificationUpdate,
    options?: { onlyIfStatus?: VerificationStatus },
  ): Promise<Verification | null> {
    const owned = await this.prisma.verification.updateMany({
      where: {
        id,
        userId,
        ...(options?.onlyIfStatus && { status: options.onlyIfStatus }),
      },
      data: toData(patch) as Prisma.VerificationUncheckedUpdateManyInput,
    });
    if (owned.count === 0) return null;
    return this.findById(userId, id);
  }

  async findById(userId: string, id: string): Promise<Verification | null> {
    const row = await this.prisma.verification.findFirst({
      where: { id, userId },
      include: CARD_REF,
    });
    return row ? toDomain(row) : null;
  }

  async list(
    userId: string,
    filter: {
      cardId?: string;
      status?: VerificationStatus;
      skip: number;
      take: number;
    },
  ): Promise<VerificationPage> {
    const where = {
      userId,
      ...(filter.cardId && { cardId: filter.cardId }),
      ...(filter.status && { status: filter.status }),
    };
    const [rows, total] = await Promise.all([
      this.prisma.verification.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: filter.skip,
        take: filter.take,
        include: CARD_REF,
      }),
      this.prisma.verification.count({ where }),
    ]);
    return { items: rows.map(toSummary), total };
  }

  async listAttention(userId: string): Promise<VerificationSummary[]> {
    const rows = await this.prisma.verification.findMany({
      where: {
        userId,
        OR: [
          { status: { in: ['PROCESSING', 'AWAITING_RATES'] } },
          { status: { in: ['FAILED', 'COMPLETED'] }, seenAt: null },
        ],
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      include: CARD_REF,
    });
    return rows.map(toSummary);
  }

  async markSeen(userId: string, id: string, at: Date): Promise<boolean> {
    const first = await this.prisma.verification.updateMany({
      where: { id, userId, seenAt: null },
      data: { seenAt: at },
    });
    if (first.count > 0) return true;
    const exists = await this.prisma.verification.count({
      where: { id, userId },
    });
    return exists > 0;
  }

  listProcessing(): Promise<{ id: string; userId: string }[]> {
    return this.prisma.verification.findMany({
      where: { status: 'PROCESSING' },
      select: { id: true, userId: true },
    });
  }

  async deleteAwaitingCreatedBefore(cutoff: Date): Promise<number> {
    const result = await this.prisma.verification.deleteMany({
      where: { status: 'AWAITING_RATES', createdAt: { lt: cutoff } },
    });
    return result.count;
  }

  async listCompletedForCard(
    userId: string,
    cardId: string,
    range: {
      periodEndFrom: string;
      periodEndTo: string;
      excludeId: string;
      take: number;
    },
  ): Promise<Verification[]> {
    const rows = await this.prisma.verification.findMany({
      where: {
        userId,
        cardId,
        status: 'COMPLETED',
        id: { not: range.excludeId },
        periodEnd: {
          gte: new Date(`${range.periodEndFrom}T00:00:00Z`),
          lte: new Date(`${range.periodEndTo}T00:00:00Z`),
        },
      },
      orderBy: [{ periodEnd: 'desc' }, { createdAt: 'desc' }],
      take: range.take,
      include: CARD_REF,
    });
    return rows.map(toDomain);
  }

  async delete(userId: string, id: string): Promise<boolean> {
    const result = await this.prisma.verification.deleteMany({
      where: { id, userId },
    });
    return result.count > 0;
  }
}
