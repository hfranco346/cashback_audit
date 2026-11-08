import { isEntitled, transitionFor } from './subscription.js';

const now = new Date('2026-06-01T00:00:00Z');
const future = new Date('2026-07-01T00:00:00Z');
const past = new Date('2026-05-01T00:00:00Z');

describe('isEntitled', () => {
  it.each([
    ['no subscription', null, false],
    ['active in the future', { status: 'ACTIVE', expiresAt: future }, true],
    ['active but past expiry', { status: 'ACTIVE', expiresAt: past }, false],
    ['active at exactly expiry', { status: 'ACTIVE', expiresAt: now }, false],
    [
      'active lifetime (no expiry)',
      { status: 'ACTIVE', expiresAt: null },
      true,
    ],
    [
      'cancelled until period end',
      { status: 'CANCELLED', expiresAt: future },
      true,
    ],
    [
      'cancelled after period end',
      { status: 'CANCELLED', expiresAt: past },
      false,
    ],
    [
      'billing issue in grace period',
      { status: 'BILLING_ISSUE', expiresAt: future },
      true,
    ],
    [
      'expired status even with future date',
      { status: 'EXPIRED', expiresAt: future },
      false,
    ],
  ] as const)('%s', (_label, sub, expected) => {
    expect(isEntitled(sub as never, now)).toBe(expected);
  });
});

describe('transitionFor', () => {
  it.each([
    ['INITIAL_PURCHASE', 'ACTIVE'],
    ['RENEWAL', 'ACTIVE'],
    ['PRODUCT_CHANGE', 'ACTIVE'],
    ['UNCANCELLATION', 'ACTIVE'],
    ['CANCELLATION', 'CANCELLED'],
    ['BILLING_ISSUE', 'BILLING_ISSUE'],
    ['EXPIRATION', 'EXPIRED'],
  ])('%s -> %s', (type, status) => {
    expect(transitionFor(type)?.status).toBe(status);
  });

  it('ignores unrelated events', () => {
    expect(transitionFor('TEST')).toBeNull();
    expect(transitionFor('TRANSFER')).toBeNull();
  });

  it('cancelled subscriptions will not renew', () => {
    expect(transitionFor('CANCELLATION')?.willRenew).toBe(false);
    expect(transitionFor('UNCANCELLATION')?.willRenew).toBe(true);
  });
});
