import type { Merchant } from './merchant.js';

export interface NewMerchant {
  userId: string;
  name: string;
  keywords: string[];
  categoryId: string;
}

export abstract class MerchantRepository {
  /** Throws MerchantNameTakenError on duplicate (userId, name). */
  abstract create(input: NewMerchant): Promise<Merchant>;
  abstract findById(userId: string, id: string): Promise<Merchant | null>;
  abstract list(
    userId: string,
    filter: { categoryId?: string },
  ): Promise<Merchant[]>;
  abstract update(
    userId: string,
    id: string,
    patch: Partial<Pick<NewMerchant, 'name' | 'keywords' | 'categoryId'>>,
  ): Promise<Merchant | null>;
  abstract delete(userId: string, id: string): Promise<boolean>;
}
