import type { Merchant } from '../domain/merchant.js';

export const presentMerchant = (m: Merchant) => ({
  id: m.id,
  name: m.name,
  keywords: m.keywords,
  categoryId: m.categoryId,
  createdAt: m.createdAt.toISOString(),
  updatedAt: m.updatedAt.toISOString(),
});
