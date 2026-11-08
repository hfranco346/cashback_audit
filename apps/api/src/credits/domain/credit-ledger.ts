export type CreditBucket = 'FREE' | 'PLAN' | 'PURCHASED';
export type CreditReason =
  | 'GRANT_FREE'
  | 'GRANT_PLAN'
  | 'GRANT_PACK'
  | 'CONSUME'
  | 'REFUND'
  | 'EXPIRE_PLAN';
export type CreditSource = 'APPLE' | 'GOOGLE' | 'WEB' | 'SYSTEM';

/** What a ledger entry needs besides user, source and idempotency key. */
export interface EntryDraft {
  delta: number;
  bucket: CreditBucket;
  reason: CreditReason;
  /** PLAN entries: end of the billing period they belong to. */
  periodEnd: Date | null;
}

/** Sum of the ledger entries of one bucket (and, for PLAN, one period). */
export interface Pool {
  bucket: CreditBucket;
  periodEnd: Date | null;
  balance: number;
}

/** Aggregated view of a user's ledger, read under the user's lock. */
export interface LedgerState {
  pools: Pool[];
  /** Period ends for which a GRANT_PLAN already exists (duplicate guard). */
  grantedPlanPeriods: Date[];
}

export interface CreditBalance {
  free: number;
  /** Credits of the current billing period only. */
  plan: number;
  /** End of the current billing period when there are plan credits. */
  planPeriodEnd: Date | null;
  purchased: number;
  total: number;
}

const sameTime = (a: Date | null, b: Date | null) =>
  (a?.getTime() ?? null) === (b?.getTime() ?? null);

const currentPlanPools = (state: LedgerState, now: Date) =>
  state.pools.filter(
    (p) =>
      p.bucket === 'PLAN' &&
      p.periodEnd !== null &&
      p.periodEnd.getTime() > now.getTime() &&
      p.balance > 0,
  );

/** PLAN credits only count while their period is current. */
export function balanceOf(state: LedgerState, now: Date): CreditBalance {
  const sum = (bucket: CreditBucket) =>
    state.pools
      .filter((p) => p.bucket === bucket)
      .reduce((n, p) => n + p.balance, 0);
  const planPools = currentPlanPools(state, now);
  const plan = planPools.reduce((n, p) => n + p.balance, 0);
  const free = Math.max(0, sum('FREE'));
  const purchased = Math.max(0, sum('PURCHASED'));
  return {
    free,
    plan,
    planPeriodEnd: planPools.length
      ? new Date(Math.max(...planPools.map((p) => p.periodEnd!.getTime())))
      : null,
    purchased,
    total: free + plan + purchased,
  };
}

/**
 * Consumption order: FREE -> PLAN (the period that ends first) -> PURCHASED.
 * Returns null when nothing can be spent.
 */
export function decideConsumption(
  state: LedgerState,
  now: Date,
): EntryDraft | null {
  const balance = balanceOf(state, now);
  if (balance.free > 0)
    return { delta: -1, bucket: 'FREE', reason: 'CONSUME', periodEnd: null };
  const plan = currentPlanPools(state, now).sort(
    (a, b) => a.periodEnd!.getTime() - b.periodEnd!.getTime(),
  )[0];
  if (plan)
    return {
      delta: -1,
      bucket: 'PLAN',
      reason: 'CONSUME',
      periodEnd: plan.periodEnd,
    };
  if (balance.purchased > 0)
    return {
      delta: -1,
      bucket: 'PURCHASED',
      reason: 'CONSUME',
      periodEnd: null,
    };
  return null;
}

/** The entry that gives back a consumed credit to the same bucket/period. */
export function refundOf(consumed: EntryDraft): EntryDraft {
  return {
    delta: -consumed.delta,
    bucket: consumed.bucket,
    reason: 'REFUND',
    periodEnd: consumed.periodEnd,
  };
}

/**
 * A new billing period starts: whatever is left of every other period is
 * expired and `credits` are granted for the new one. Credits do not roll over.
 * A period that was already granted yields nothing (renewals can be reported
 * more than once under different event ids).
 */
export function planRenewal(
  state: LedgerState,
  period: { periodEnd: Date; credits: number },
): EntryDraft[] {
  if (state.grantedPlanPeriods.some((p) => sameTime(p, period.periodEnd)))
    return [];
  const expire = state.pools
    .filter(
      (p) =>
        p.bucket === 'PLAN' &&
        p.balance > 0 &&
        !sameTime(p.periodEnd, period.periodEnd),
    )
    .map((p): EntryDraft => ({
      delta: -p.balance,
      bucket: 'PLAN',
      reason: 'EXPIRE_PLAN',
      periodEnd: p.periodEnd,
    }));
  return [
    ...expire,
    {
      delta: period.credits,
      bucket: 'PLAN',
      reason: 'GRANT_PLAN',
      periodEnd: period.periodEnd,
    },
  ];
}

/** Debit for a refunded pack: never more than what is left (never below 0). */
export function packDebit(
  state: LedgerState,
  now: Date,
  credits: number,
): EntryDraft | null {
  const amount = Math.min(credits, balanceOf(state, now).purchased);
  if (amount <= 0) return null;
  return {
    delta: -amount,
    bucket: 'PURCHASED',
    reason: 'REFUND',
    periodEnd: null,
  };
}
