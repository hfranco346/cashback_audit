import type { CreditSource } from './credit-ledger.js';

/** Maps the RevenueCat `store` of an event to the ledger source. */
export function sourceForStore(store: string | null): CreditSource {
  switch (store) {
    case 'APP_STORE':
    case 'MAC_APP_STORE':
      return 'APPLE';
    case 'PLAY_STORE':
      return 'GOOGLE';
    case 'STRIPE':
    case 'RC_BILLING':
    case 'PADDLE':
      return 'WEB';
    default:
      return 'SYSTEM';
  }
}

/** A refunded purchase, as RevenueCat reports it. */
export function isRefundEvent(type: string, cancelReason: string | null) {
  return (
    type === 'REFUND' ||
    (type === 'CANCELLATION' &&
      cancelReason !== null &&
      ['CUSTOMER_SUPPORT', 'REFUND', 'REFUNDED'].includes(
        cancelReason.toUpperCase(),
      ))
  );
}
