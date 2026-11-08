export interface Merchant {
  id: string;
  userId: string;
  name: string;
  /** Aliases / statement descriptors used for deterministic matching. */
  keywords: string[];
  /** Category the user EXPECTS this merchant to accrue under. */
  categoryId: string;
  createdAt: Date;
  updatedAt: Date;
}
