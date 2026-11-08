import type {
  RevenueCatEventInput,
  Subscription,
  SubscriptionTransition,
} from './subscription.js';

export type ApplyOutcome = 'APPLIED' | 'DUPLICATE' | 'STALE';

export abstract class SubscriptionRepository {
  abstract find(
    userId: string,
    entitlementId: string,
  ): Promise<Subscription | null>;
  /**
   * Atomically records the event id (idempotency) and, unless an equal or newer
   * event was already applied, updates the subscription.
   */
  abstract applyEvent(
    userId: string,
    entitlementId: string,
    event: RevenueCatEventInput,
    transition: SubscriptionTransition,
  ): Promise<ApplyOutcome>;
  /** Records an event that changes nothing (idempotent; true when first seen). */
  abstract recordIgnored(
    event: RevenueCatEventInput,
    userId: string | null,
    reason: string,
  ): Promise<boolean>;
}
