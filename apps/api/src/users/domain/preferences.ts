import type { Decimal } from 'decimal.js';

export type UserLocale = 'AUTO' | 'ES' | 'EN';

/** A currency the user works with and the last rate used for it. */
export interface UserCurrency {
  /** ISO 4217. */
  code: string;
  /** Units of the user's primary currency per 1 unit of `code`; null = unknown. */
  lastRateToPrimary: Decimal | null;
  updatedAt: Date;
}

export interface UserPreferences {
  locale: UserLocale;
  /** ISO 4217; null until the user picks one. */
  primaryCurrency: string | null;
  currencies: UserCurrency[];
}

export interface PreferencesPatch {
  locale?: UserLocale;
  primaryCurrency?: string | null;
  /**
   * The complete list of the user's currencies. A missing `lastRateToPrimary`
   * keeps the stored rate; null clears it.
   */
  currencies?: { code: string; lastRateToPrimary?: Decimal | null }[];
}
