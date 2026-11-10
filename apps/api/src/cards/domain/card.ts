import type { Decimal } from 'decimal.js';

export type RewardReportingSetting = 'AUTO' | 'MONTHLY' | 'CUMULATIVE';

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
  /** ISO 4217 code of the card's primary currency (rewards are expressed in it). */
  currency: string;
  /**
   * Loyalty program to audit when the statement lists several (e.g.
   * "CASH BAC CREDOMATIC"); matched case/accent-insensitively by "contains".
   */
  rewardProgramName: string | null;
  /**
   * ISO 4217 currency the reward is paid in when it differs from `currency`
   * (e.g. spend in HNL, cashback in USD). Overrides what the statement says.
   */
  rewardCurrency: string | null;
  /** Where the user sends bank claims; null when not set. */
  claimEmail: string | null;
  /** Whether the bank prints this month's reward or an accumulated balance. */
  rewardReporting: RewardReportingSetting;
  rules: CardRule[];
  createdAt: Date;
  updatedAt: Date;
}
