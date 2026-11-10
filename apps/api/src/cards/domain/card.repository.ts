import type {
  Card,
  CardRule,
  RewardReportingSetting,
  RewardUnit,
} from './card.js';
import type { Decimal } from 'decimal.js';

export interface NewCard {
  userId: string;
  alias: string;
  bank: string;
  last4: string;
  network: string | null;
  rewardUnit: RewardUnit;
  pointsPerCurrencyUnit: Decimal;
  baseRatePercent: Decimal;
  currency: string;
  rewardProgramName: string | null;
  rewardCurrency: string | null;
  claimEmail: string | null;
  rewardReporting: RewardReportingSetting;
  rules: CardRule[];
}

export type CardPatch = Partial<Omit<NewCard, 'userId'>>;

export abstract class CardRepository {
  abstract create(input: NewCard): Promise<Card>;
  abstract findById(userId: string, id: string): Promise<Card | null>;
  abstract list(userId: string): Promise<Card[]>;
  /** When `patch.rules` is present it replaces all rules. */
  abstract update(
    userId: string,
    id: string,
    patch: CardPatch,
  ): Promise<Card | null>;
  abstract delete(userId: string, id: string): Promise<boolean>;
}
