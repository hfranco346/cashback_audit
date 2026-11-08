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

/** Decimals are strings; dates `YYYY-MM-DD`; timestamps ISO 8601 UTC. */
export function presentSummary(v: VerificationSummary) {
  return {
    id: v.id,
    cardId: v.cardId,
    statement: {
      bank: v.statementBank,
      cardLast4: v.statementLast4,
      periodStart: v.periodStart,
      periodEnd: v.periodEnd,
      currency: v.currency,
    },
    primaryCurrency: v.primaryCurrency,
    rewardUnit: v.reportedUnit,
    reportedAmount: v.reportedAmount.toString(),
    expectedAmount: v.expectedAmount.toString(),
    difference: v.difference.toString(),
    verdict: v.verdict,
    createdAt: v.createdAt.toISOString(),
  };
}

export function presentVerification(v: Verification) {
  return {
    id: v.id,
    cardId: v.cardId,
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
    reported: {
      amount: v.reportedAmount.toString(),
      unit: v.reportedUnit,
      label: v.reportedLabel,
      source: v.reportedSource,
    },
    expected: { amount: v.expectedAmount.toString(), unit: v.reportedUnit },
    difference: v.difference.toString(),
    tolerance: v.tolerance.toString(),
    verdict: v.verdict,
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
      appliedRatePercent: t.appliedRatePercent.toString(),
      ruleApplied: t.ruleApplied,
      expectedReward: t.expectedReward.toString(),
    })),
    warnings: v.warnings,
    model: v.models.extraction,
    models: v.models,
    createdAt: v.createdAt.toISOString(),
  };
}
