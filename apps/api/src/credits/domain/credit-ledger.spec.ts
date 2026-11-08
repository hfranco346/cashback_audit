import {
  balanceOf,
  decideConsumption,
  packDebit,
  planRenewal,
  refundOf,
  type LedgerState,
  type Pool,
} from './credit-ledger.js';
import { isRefundEvent, sourceForStore } from './revenuecat-credits.js';

const now = new Date('2026-06-15T00:00:00Z');
const P1 = new Date('2026-07-01T00:00:00Z');
const P2 = new Date('2026-08-01T00:00:00Z');
const PAST = new Date('2026-06-01T00:00:00Z');

const state = (
  pools: Pool[],
  grantedPlanPeriods: Date[] = [],
): LedgerState => ({ pools, grantedPlanPeriods });
const free = (balance: number): Pool => ({
  bucket: 'FREE',
  periodEnd: null,
  balance,
});
const plan = (balance: number, periodEnd: Date): Pool => ({
  bucket: 'PLAN',
  periodEnd,
  balance,
});
const bought = (balance: number): Pool => ({
  bucket: 'PURCHASED',
  periodEnd: null,
  balance,
});

describe('balanceOf', () => {
  it('sums buckets and only counts plan credits of a current period', () => {
    const b = balanceOf(
      state([free(1), plan(5, P1), plan(3, PAST), bought(4)]),
      now,
    );
    expect(b).toEqual({
      free: 1,
      plan: 5,
      planPeriodEnd: P1,
      purchased: 4,
      total: 10,
    });
  });

  it('is empty without entries and never negative', () => {
    expect(balanceOf(state([]), now)).toMatchObject({
      total: 0,
      planPeriodEnd: null,
    });
    expect(balanceOf(state([free(-2), bought(-1)]), now).total).toBe(0);
  });

  it('ignores an exhausted plan period for planPeriodEnd', () => {
    expect(balanceOf(state([plan(0, P1)]), now).planPeriodEnd).toBeNull();
  });
});

describe('decideConsumption (FREE -> PLAN -> PURCHASED)', () => {
  it('spends the free credit first', () => {
    expect(
      decideConsumption(state([free(1), plan(5, P1), bought(3)]), now),
    ).toEqual({
      delta: -1,
      bucket: 'FREE',
      reason: 'CONSUME',
      periodEnd: null,
    });
  });

  it('then plan credits, from the period that ends first', () => {
    expect(
      decideConsumption(
        state([free(0), plan(2, P2), plan(1, P1), bought(3)]),
        now,
      ),
    ).toMatchObject({ bucket: 'PLAN', periodEnd: P1 });
  });

  it('then purchased credits, skipping expired plan credits', () => {
    expect(
      decideConsumption(state([free(0), plan(5, PAST), bought(1)]), now),
    ).toMatchObject({ bucket: 'PURCHASED', periodEnd: null });
  });

  it('returns null when nothing can be spent', () => {
    expect(
      decideConsumption(state([free(0), plan(5, PAST), bought(0)]), now),
    ).toBeNull();
    expect(decideConsumption(state([]), now)).toBeNull();
  });
});

describe('refundOf', () => {
  it('gives back exactly the consumed credit to the same bucket and period', () => {
    const consumed = decideConsumption(state([plan(1, P1)]), now)!;
    expect(refundOf(consumed)).toEqual({
      delta: 1,
      bucket: 'PLAN',
      reason: 'REFUND',
      periodEnd: P1,
    });
  });

  it('restores the balance after a failed reservation', () => {
    const before = state([free(0), plan(1, P1)]);
    const consumed = decideConsumption(before, now)!;
    const after = state(
      [plan(0, P1), plan(1, P1)]
        .slice(1)
        .map((p) => ({ ...p, balance: p.balance + consumed.delta })),
    );
    expect(balanceOf(after, now).total).toBe(0);
    const refunded = state([
      {
        ...after.pools[0]!,
        balance: after.pools[0]!.balance + refundOf(consumed).delta,
      },
    ]);
    expect(balanceOf(refunded, now).total).toBe(1);
  });
});

describe('planRenewal', () => {
  it('grants the credits of the first period', () => {
    expect(planRenewal(state([]), { periodEnd: P1, credits: 5 })).toEqual([
      { delta: 5, bucket: 'PLAN', reason: 'GRANT_PLAN', periodEnd: P1 },
    ]);
  });

  it('expires what is left of the previous period and grants the new one (no roll over)', () => {
    const drafts = planRenewal(state([plan(4, P1)], [P1]), {
      periodEnd: P2,
      credits: 5,
    });
    expect(drafts).toEqual([
      { delta: -4, bucket: 'PLAN', reason: 'EXPIRE_PLAN', periodEnd: P1 },
      { delta: 5, bucket: 'PLAN', reason: 'GRANT_PLAN', periodEnd: P2 },
    ]);
    // applying them leaves exactly the new period's credits
    const applied = state([plan(0, P1), plan(5, P2)]);
    expect(balanceOf(applied, now).plan).toBe(5);
  });

  it('does not expire periods with nothing left', () => {
    expect(
      planRenewal(state([plan(0, P1)], [P1]), { periodEnd: P2, credits: 5 }),
    ).toHaveLength(1);
  });

  it('is idempotent per period: a period already granted yields nothing', () => {
    expect(
      planRenewal(state([plan(5, P1)], [P1]), { periodEnd: P1, credits: 5 }),
    ).toEqual([]);
  });
});

describe('packDebit', () => {
  it('debits the pack credits when available', () => {
    expect(packDebit(state([bought(5)]), now, 3)).toMatchObject({
      delta: -3,
      bucket: 'PURCHASED',
    });
  });

  it('never goes below zero', () => {
    expect(packDebit(state([bought(1)]), now, 3)).toMatchObject({ delta: -1 });
    expect(packDebit(state([bought(0)]), now, 3)).toBeNull();
    expect(packDebit(state([free(2), plan(5, P1)]), now, 3)).toBeNull();
  });
});

describe('RevenueCat helpers', () => {
  it.each([
    ['APP_STORE', 'APPLE'],
    ['MAC_APP_STORE', 'APPLE'],
    ['PLAY_STORE', 'GOOGLE'],
    ['STRIPE', 'WEB'],
    ['RC_BILLING', 'WEB'],
    ['PADDLE', 'WEB'],
    ['PROMOTIONAL', 'SYSTEM'],
    [null, 'SYSTEM'],
  ])('maps store %s to %s', (store, source) => {
    expect(sourceForStore(store)).toBe(source);
  });

  it('detects refund events', () => {
    expect(isRefundEvent('REFUND', null)).toBe(true);
    expect(isRefundEvent('CANCELLATION', 'CUSTOMER_SUPPORT')).toBe(true);
    expect(isRefundEvent('CANCELLATION', 'customer_support')).toBe(true);
    expect(isRefundEvent('CANCELLATION', 'UNSUBSCRIBE')).toBe(false);
    expect(isRefundEvent('CANCELLATION', null)).toBe(false);
    expect(isRefundEvent('RENEWAL', 'CUSTOMER_SUPPORT')).toBe(false);
  });
});
