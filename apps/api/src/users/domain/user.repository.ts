import type { Decimal } from 'decimal.js';
import type { PreferencesPatch, UserPreferences } from './preferences.js';
import type { User, VerifiedIdentity } from './user.js';

export abstract class UserRepository {
  /**
   * Creates the user on first sign-in. Afterwards the email is refreshed when
   * present and the name is stored only if the user has none yet (Apple sends
   * the name once, so a later sign-in must never erase it).
   */
  abstract upsertFromIdentity(identity: VerifiedIdentity): Promise<User>;
  abstract findById(id: string): Promise<User | null>;
  abstract getPreferences(userId: string): Promise<UserPreferences | null>;
  /**
   * Applies the patch atomically. Changing the primary currency clears the
   * stored rates (they were relative to the old one) and drops the new primary
   * from the currency list.
   */
  abstract updatePreferences(
    userId: string,
    patch: PreferencesPatch,
  ): Promise<UserPreferences | null>;
  /**
   * Remembers the rates used in a confirmed verification (units of
   * `cardCurrency` per 1 unit of each currency). Only applies when the user's
   * primary currency is `cardCurrency` or still unset; never throws for that.
   */
  abstract recordCurrencyRates(
    userId: string,
    cardCurrency: string,
    rates: { code: string; rate: Decimal }[],
  ): Promise<void>;
}
