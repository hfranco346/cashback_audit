import type { Decimal } from 'decimal.js';

export type RewardUnit = 'CASHBACK_CURRENCY' | 'POINTS';

export interface CardRule {
  categoryId: string;
  /** Percent of spend, e.g. 5 means 5%. */
  ratePercent: Decimal;
  /**
   * Max reward obtainable from this rule per statement period, expressed in
   * the card's reward unit (currency for cashback, points for POINTS).
   */
  monthlyCap: Decimal | null;
}

export interface Card {
  id: string;
  userId: string;
  alias: string;
  bank: string;
  /** Exactly four digits. A full card number is never accepted or stored. */
  last4: string;
  network: string | null;
  rewardUnit: RewardUnit;
  /** Points granted per currency unit of reward; only used for POINTS. */
  pointsPerCurrencyUnit: Decimal;
  baseRatePercent: Decimal;
  /** ISO 4217 code. */
  currency: string;
  rules: CardRule[];
  createdAt: Date;
  updatedAt: Date;
}
