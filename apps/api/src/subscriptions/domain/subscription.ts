export type SubscriptionStatus =
  'ACTIVE' | 'CANCELLED' | 'BILLING_ISSUE' | 'EXPIRED';

export interface Subscription {
  userId: string;
  entitlementId: string;
  status: SubscriptionStatus;
  expiresAt: Date | null;
  store: string | null;
  productId: string | null;
  rcAppUserId: string;
  willRenew: boolean;
  lastEventAt: Date;
}

/**
 * Whether the entitlement currently grants access. CANCELLED (auto-renew off)
 * and BILLING_ISSUE (grace period) keep access until `expiresAt`.
 */
export function isEntitled(
  subscription: Pick<Subscription, 'status' | 'expiresAt'> | null,
  now: Date = new Date(),
): boolean {
  if (!subscription || subscription.status === 'EXPIRED') return false;
  return (
    subscription.expiresAt === null ||
    subscription.expiresAt.getTime() > now.getTime()
  );
}

export interface RevenueCatEventInput {
  id: string;
  type: string;
  appUserId: string;
  /** Other ids RevenueCat knows this customer by. */
  aliases: string[];
  /** Absent means the payload carried no entitlement information. */
  entitlementIds: string[] | null;
  productId: string | null;
  store: string | null;
  /** Store transaction id (stable across webhook redeliveries). */
  transactionId: string | null;
  /** CANCELLATION reason, e.g. CUSTOMER_SUPPORT for refunds. */
  cancelReason: string | null;
  expirationAt: Date | null;
  eventAt: Date;
}

export interface SubscriptionTransition {
  status: SubscriptionStatus;
  willRenew: boolean;
}

/** Maps a RevenueCat event type to the resulting state, or null if irrelevant. */
export function transitionFor(type: string): SubscriptionTransition | null {
  switch (type) {
    case 'INITIAL_PURCHASE':
    case 'RENEWAL':
    case 'PRODUCT_CHANGE':
    case 'UNCANCELLATION':
      return { status: 'ACTIVE', willRenew: true };
    case 'CANCELLATION':
      // Still entitled until the period ends.
      return { status: 'CANCELLED', willRenew: false };
    case 'BILLING_ISSUE':
      return { status: 'BILLING_ISSUE', willRenew: false };
    case 'EXPIRATION':
      return { status: 'EXPIRED', willRenew: false };
    default:
      return null;
  }
}
