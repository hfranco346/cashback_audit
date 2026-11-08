import { Injectable } from '@nestjs/common';
import { CategoryNotFoundError } from '../../categories/domain/category-errors.js';
import { CategoryRepository } from '../../categories/domain/category.repository.js';
import type { Merchant } from '../domain/merchant.js';
import { MerchantNotFoundError } from '../domain/merchant-errors.js';
import { MerchantRepository } from '../domain/merchant.repository.js';

/** Trims, drops empties and de-duplicates case-insensitively (keeps first). */
export function cleanKeywords(keywords: string[]): string[] {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const raw of keywords) {
    const keyword = raw.trim();
    const key = keyword.toLowerCase();
    if (keyword && !seen.has(key)) {
      seen.add(key);
      result.push(keyword);
    }
  }
  return result;
}

@Injectable()
export class CreateMerchantUseCase {
  constructor(
    private readonly merchants: MerchantRepository,
    private readonly categories: CategoryRepository,
  ) {}

  async execute(input: {
    userId: string;
    name: string;
    keywords?: string[];
    categoryId: string;
  }): Promise<Merchant> {
    if (!(await this.categories.findById(input.userId, input.categoryId))) {
      throw new CategoryNotFoundError();
    }
    return this.merchants.create({
      userId: input.userId,
      name: input.name,
      keywords: cleanKeywords(input.keywords ?? []),
      categoryId: input.categoryId,
    });
  }
}

@Injectable()
export class ListMerchantsUseCase {
  constructor(private readonly merchants: MerchantRepository) {}

  execute(
    userId: string,
    filter: { categoryId?: string },
  ): Promise<Merchant[]> {
    return this.merchants.list(userId, filter);
  }
}

@Injectable()
export class GetMerchantUseCase {
  constructor(private readonly merchants: MerchantRepository) {}

  async execute(userId: string, id: string): Promise<Merchant> {
    const merchant = await this.merchants.findById(userId, id);
    if (!merchant) throw new MerchantNotFoundError();
    return merchant;
  }
}

@Injectable()
export class UpdateMerchantUseCase {
  constructor(
    private readonly merchants: MerchantRepository,
    private readonly categories: CategoryRepository,
  ) {}

  async execute(
    userId: string,
    id: string,
    patch: { name?: string; keywords?: string[]; categoryId?: string },
  ): Promise<Merchant> {
    if (
      patch.categoryId &&
      !(await this.categories.findById(userId, patch.categoryId))
    ) {
      throw new CategoryNotFoundError();
    }
    const updated = await this.merchants.update(userId, id, {
      ...patch,
      keywords: patch.keywords ? cleanKeywords(patch.keywords) : undefined,
    });
    if (!updated) throw new MerchantNotFoundError();
    return updated;
  }
}

@Injectable()
export class DeleteMerchantUseCase {
  constructor(private readonly merchants: MerchantRepository) {}

  async execute(userId: string, id: string): Promise<void> {
    if (!(await this.merchants.delete(userId, id)))
      throw new MerchantNotFoundError();
  }
}
