import type {
  Verification,
  VerificationSummary,
} from '../domain/verification.js';

const str = (d: { toString(): string } | null) => (d ? d.toString() : null);

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
    },
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
      merchant: t.merchant,
      amount: t.amount.toString(),
      isCredit: t.isCredit,
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
    model: v.model,
    createdAt: v.createdAt.toISOString(),
  };
}
