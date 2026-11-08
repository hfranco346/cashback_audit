import type { RateProposalEntry } from '../domain/rate-proposal.js';
import type { LoyaltyProgram } from '../domain/statement.js';
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
});

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

/** Decimals are strings; dates `YYYY-MM-DD`; timestamps ISO 8601 UTC. */
export function presentSummary(v: VerificationSummary) {
  return {
    id: v.id,
    cardId: v.cardId,
    status: v.status,
    statement: {
      bank: v.statementBank,
      cardLast4: v.statementLast4,
      periodStart: v.periodStart,
      periodEnd: v.periodEnd,
      currency: v.currency,
    },
    primaryCurrency: v.primaryCurrency,
    rewardUnit: v.reportedUnit,
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
export function presentVerification(
  v: Verification,
  rateProposal: RateProposalEntry[],
) {
  const done = v.status === 'COMPLETED';
  return {
    id: v.id,
    cardId: v.cardId,
    status: v.status,
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
        totalBalance: str(s.totalBalance),
      })),
    },
    primaryCurrency: v.primaryCurrency,
    reported: done
      ? {
          amount: str(v.reportedAmount),
          unit: v.reportedUnit,
          label: v.reportedLabel,
          source: v.reportedSource,
        }
      : null,
    expected: done
      ? { amount: str(v.expectedAmount), unit: v.reportedUnit }
      : null,
    difference: str(v.difference),
    tolerance: str(v.tolerance),
    verdict: v.verdict,
    explanation: v.explanation,
    detectedRates: v.detectedRates.map((r) => ({
      scope: r.scope,
      categoryHint: r.categoryHint,
      suggestedCategoryId: r.suggestedCategoryId,
      ratePercent: str(r.ratePercent),
      unitNote: r.unitNote,
      evidence: r.evidence,
      confidence: r.confidence,
    })),
    rateProposal: rateProposal.map(presentProposalEntry),
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
        }
      : null,
    conversion: {
      primaryCurrency: v.primaryCurrency,
      requestedRate: str(v.conversion.requestedRate),
      statementRate: v.conversion.statementRate
        ? {
            from: v.conversion.statementRate.from,
            to: v.conversion.statementRate.to,
            rate: v.conversion.statementRate.rate.toString(),
            source: v.conversion.statementRate.source,
          }
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
