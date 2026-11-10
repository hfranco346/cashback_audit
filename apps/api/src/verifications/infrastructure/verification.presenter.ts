import type {
  RateProposal,
  RateProposalEntry,
} from '../domain/rate-proposal.js';
import type { RewardReportingProposal } from '../domain/reward-reporting.js';
import {
  creditTypeOf,
  type LoyaltyProgram,
  type StatementExchangeRate,
} from '../domain/statement.js';
import type {
  Verification,
  VerificationSummary,
} from '../domain/verification.js';

const str = (d: { toString(): string } | null) => (d ? d.toString() : null);

const presentProgram = (p: LoyaltyProgram) => ({
  name: p.name,
  unit: p.unit,
  accumulated: str(p.accumulated),
  available: str(p.available),
  redeemedInPeriod: str(p.redeemedInPeriod),
  expiring: str(p.expiring),
  forfeited: str(p.forfeited),
  previousBalance: str(p.previousBalance),
  earnedInPeriod: str(p.earnedInPeriod),
  reportedLabel: p.reportedLabel,
  currency: p.currency,
});

const presentReportingProposal = (p: RewardReportingProposal) => ({
  mode: p.mode,
  suggestedMode: p.suggestedMode,
  reason: p.reason,
  cardSetting: p.cardSetting,
  currentBalance: str(p.currentBalance),
  previousBalance: str(p.previousBalance),
  previousBalanceSource: p.previousBalanceSource,
  previousVerificationId: p.previousVerificationId,
  previousPeriodEnd: p.previousPeriodEnd,
  programName: p.programName,
  reportedLabel: p.reportedLabel,
  redeemedInPeriod: p.redeemedInPeriod.toString(),
  expiredInPeriod: p.expiredInPeriod.toString(),
  earned: str(p.earned),
  previousBalanceRequired: p.previousBalanceRequired,
});

/** Block of a COMPLETED audit; rows from before cumulative support read as MONTHLY. */
function presentReporting(v: Verification) {
  const r = v.rewardReporting;
  if (r) {
    return {
      mode: r.mode,
      programName: r.programName,
      reportedLabel: r.reportedLabel,
      currentBalance: str(r.currentBalance),
      previousBalance: str(r.previousBalance),
      previousBalanceSource: r.previousBalanceSource,
      previousPeriodEnd: r.previousPeriodEnd,
      redeemedInPeriod: r.redeemedInPeriod.toString(),
      expiredInPeriod: r.expiredInPeriod.toString(),
      earned: str(r.earned),
    };
  }
  return {
    mode: 'MONTHLY' as const,
    programName: v.loyalty.selected?.name ?? null,
    reportedLabel: v.loyalty.selected?.reportedLabel ?? null,
    currentBalance: null,
    previousBalance: null,
    previousBalanceSource: null,
    previousPeriodEnd: null,
    redeemedInPeriod: (v.loyalty.selected?.redeemedInPeriod ?? 0).toString(),
    expiredInPeriod: (v.loyalty.selected?.forfeited ?? 0).toString(),
    earned: str(v.reportedAmount),
  };
}

const presentProposalEntry = (e: RateProposalEntry) => ({
  categoryId: e.categoryId,
  categoryName: e.categoryName,
  ratePercent: str(e.ratePercent),
  monthlyCap: str(e.monthlyCap),
  source: e.source,
  evidence: e.evidence,
  unitNote: e.unitNote,
  required: e.required,
});

const presentStatementRate = (r: StatementExchangeRate) => ({
  from: r.from,
  to: r.to,
  rate: r.rate.toString(),
  source: r.source,
});

const REWARD_RATE_NOTE =
  'rate = units of the primary (card) currency per 1 unit of the other currency';

/** Decimals are strings; dates `YYYY-MM-DD`; timestamps ISO 8601 UTC. */
export function presentSummary(v: VerificationSummary) {
  return {
    id: v.id,
    cardId: v.cardId,
    card: v.card ?? null,
    status: v.status,
    failureCode: v.failureCode,
    seenAt: v.seenAt?.toISOString() ?? null,
    statement: {
      bank: v.statementBank,
      cardLast4: v.statementLast4,
      periodStart: v.periodStart,
      periodEnd: v.periodEnd,
      currency: v.currency,
    },
    primaryCurrency: v.primaryCurrency,
    rewardUnit: v.reportedUnit,
    rewardCurrency: v.rewardCurrency,
    reportedAmount: str(v.reportedAmount),
    expectedAmount: str(v.expectedAmount),
    difference: str(v.difference),
    verdict: v.verdict,
    createdAt: v.createdAt.toISOString(),
  };
}

/**
 * `rateProposal` is only meaningful (and only returned) while the verification
 * is AWAITING_RATES; for COMPLETED ones it is the proposal that applies now,
 * which clients can use to prefill a recalculation.
 */
export function presentVerification(v: Verification, proposal: RateProposal) {
  const done = v.status === 'COMPLETED';
  return {
    id: v.id,
    cardId: v.cardId,
    card: v.card ?? null,
    status: v.status,
    failureCode: v.failureCode,
    seenAt: v.seenAt?.toISOString() ?? null,
    statement: {
      bank: v.statementBank,
      cardLast4: v.statementLast4,
      periodStart: v.periodStart,
      periodEnd: v.periodEnd,
      currency: v.currency,
      totalSpent: str(v.totalSpent),
      totalToPay: str(v.totalToPay),
      summaries: v.summaries.map((s) => ({
        currency: s.currency,
        previousBalance: str(s.previousBalance),
        purchasesAndCharges: str(s.purchasesAndCharges),
        purchases: str(s.purchases),
        chargesAndInterest: str(s.chargesAndInterest),
        totalBalance: str(s.totalBalance),
      })),
    },
    primaryCurrency: v.primaryCurrency,
    rewardCurrency: v.rewardCurrency,
    reported: done
      ? {
          amount: str(v.reportedAmount),
          unit: v.reportedUnit,
          currency: v.rewardCurrency,
          label: v.reportedLabel,
          source: v.reportedSource,
        }
      : null,
    expected: done
      ? {
          amount: str(v.expectedAmount),
          unit: v.reportedUnit,
          currency: v.rewardCurrency,
        }
      : null,
    expectedInPrimaryCurrency: done
      ? (str(v.conversion.reward?.expectedInPrimary ?? null) ??
        str(v.expectedAmount))
      : null,
    difference: str(v.difference),
    tolerance: str(v.tolerance),
    verdict: v.verdict,
    explanation: v.explanation,
    rewardCapApplied:
      done && v.conversion.rewardCapApplied
        ? {
            cap: v.conversion.rewardCapApplied.cap.toString(),
            uncapped: v.conversion.rewardCapApplied.uncapped.toString(),
            capped: v.conversion.rewardCapApplied.capped.toString(),
          }
        : null,
    rewardProgramChoice: proposal.rewardProgramChoice,
    rewardReporting: done ? presentReporting(v) : null,
    rewardReportingProposal: proposal.rewardReporting
      ? presentReportingProposal(proposal.rewardReporting)
      : null,
    detectedRates: v.detectedRates.map((r) => ({
      scope: r.scope,
      categoryHint: r.categoryHint,
      suggestedCategoryId: r.suggestedCategoryId,
      ratePercent: str(r.ratePercent),
      unitNote: r.unitNote,
      evidence: r.evidence,
      confidence: r.confidence,
    })),
    rateProposal: proposal.entries.map(presentProposalEntry),
    rewardConversion: proposal.rewardConversion
      ? {
          fromCurrency: proposal.rewardConversion.fromCurrency,
          toCurrency: proposal.rewardConversion.toCurrency,
          rate: str(proposal.rewardConversion.rate),
          source: proposal.rewardConversion.source,
          required: proposal.rewardConversion.required,
          note: REWARD_RATE_NOTE,
        }
      : null,
    suggestedCategories: proposal.suggestedCategories.map((c) => ({
      name: c.name,
      ratePercent: str(c.ratePercent),
      evidence: c.evidence,
      matchingTransactionCount: c.matchingTransactionCount,
    })),
    exchangeRateProposal: proposal.spendConversions.map((c) => ({
      currency: c.currency,
      rate: str(c.rate),
      source: c.source,
      required: c.required,
    })),
    appliedRates: v.appliedRates
      ? {
          baseRatePercent: v.appliedRates.baseRatePercent.toString(),
          baseSource: v.appliedRates.baseSource,
          categoryRates: v.appliedRates.categoryRates.map((c) => ({
            categoryId: c.categoryId,
            categoryName: c.categoryName,
            ratePercent: c.ratePercent.toString(),
            monthlyCap: str(c.monthlyCap),
            source: c.source,
          })),
          savedToCard: v.appliedRates.savedToCard,
          rewardExchangeRate: v.appliedRates.rewardExchangeRate
            ? {
                fromCurrency: v.appliedRates.rewardExchangeRate.fromCurrency,
                toCurrency: v.appliedRates.rewardExchangeRate.toCurrency,
                rate: v.appliedRates.rewardExchangeRate.rate.toString(),
                source: v.appliedRates.rewardExchangeRate.source,
              }
            : null,
        }
      : null,
    conversion: {
      primaryCurrency: v.primaryCurrency,
      requestedRate: str(v.conversion.requestedRate),
      requestedRates: Object.fromEntries(
        Object.entries(v.conversion.requestedRates).map(([k, r]) => [
          k,
          r.toString(),
        ]),
      ),
      requestedRewardRate: str(v.conversion.requestedRewardRate),
      statementRates: v.conversion.statementRates.map(presentStatementRate),
      /** @deprecated first of statementRates. */
      statementRate: v.conversion.statementRates[0]
        ? presentStatementRate(v.conversion.statementRates[0])
        : null,
    },
    currencies: v.conversion.currencies.map((c) => ({
      currency: c.currency,
      isPrimary: c.isPrimary,
      spent: c.spent.toString(),
      eligibleSpent: c.eligibleSpent.toString(),
      convertedEligibleSpent: c.convertedEligibleSpent.toString(),
      exchangeRate: str(c.exchangeRate),
      exchangeRateSource: c.rateSource,
      expectedReward: c.expectedReward.toString(),
      excludedCount: c.excludedCount,
    })),
    loyalty: {
      selectedBy: v.loyalty.selectedBy,
      selectedProgram: v.loyalty.selected
        ? presentProgram(v.loyalty.selected)
        : null,
      programs: v.loyalty.programs.map(presentProgram),
      requestedProgramName: v.loyalty.requestedProgramName,
    },
    breakdown: v.breakdown.map((l) => ({
      categoryId: l.categoryId,
      categoryName: l.categoryName,
      ratePercent: l.ratePercent.toString(),
      transactionCount: l.transactionCount,
      spend: l.spend.toString(),
      uncappedReward: l.uncappedReward.toString(),
      expectedReward: l.expectedReward.toString(),
      monthlyCap: str(l.monthlyCap),
      capped: l.capped,
    })),
    transactions: v.transactions.map((t) => ({
      index: t.index,
      date: t.date,
      reference: t.reference,
      merchant: t.merchant,
      amount: t.amount.toString(),
      currency: t.currency,
      isCredit: t.isCredit,
      kind: t.kind,
      creditType: creditTypeOf(t.kind, t.isCredit),
      convertedAmount: str(t.convertedAmount),
      exchangeRate: str(t.exchangeRate),
      exchangeRateSource: t.rateSource,
      excludedReason: t.excludedReason,
      matchedMerchantId: t.matchedMerchantId,
      matchedMerchantName: t.matchedMerchantName,
      categoryId: t.categoryId,
      categoryName: t.categoryName,
      matchSource: t.matchSource,
      matchConfidence: t.matchConfidence,
      matchReason: t.matchReason,
      suggestedHint: t.suggestedHint,
      appliedRatePercent: str(t.appliedRatePercent),
      ruleApplied: t.ruleApplied,
      expectedReward: str(t.expectedReward),
    })),
    warnings: v.warnings,
    model: v.models.extraction,
    models: v.models,
    createdAt: v.createdAt.toISOString(),
  };
}
