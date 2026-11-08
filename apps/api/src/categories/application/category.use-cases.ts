import { Injectable } from '@nestjs/common';
import type { Category, CategoryWithCount } from '../domain/category.js';
import {
  CategoryInUseError,
  CategoryNotFoundError,
} from '../domain/category-errors.js';
import { CategoryRepository } from '../domain/category.repository.js';
import { MerchantRepository } from '../../merchants/domain/merchant.repository.js';
import type { Merchant } from '../../merchants/domain/merchant.js';

export interface CategoryDetail extends CategoryWithCount {
  merchants?: Merchant[];
}

@Injectable()
export class CreateCategoryUseCase {
  constructor(private readonly categories: CategoryRepository) {}

  execute(input: {
    userId: string;
    name: string;
    description?: string | null;
  }): Promise<Category> {
    return this.categories.create({
      userId: input.userId,
      name: input.name,
      description: input.description ?? null,
    });
  }
}

@Injectable()
export class ListCategoriesUseCase {
  constructor(
    private readonly categories: CategoryRepository,
    private readonly merchants: MerchantRepository,
  ) {}

  async execute(
    userId: string,
    includeMerchants: boolean,
  ): Promise<CategoryDetail[]> {
    const categories = await this.categories.listWithCounts(userId);
    if (!includeMerchants) return categories;
    const merchants = await this.merchants.list(userId, {});
    return categories.map((c) => ({
      ...c,
      merchants: merchants.filter((m) => m.categoryId === c.id),
    }));
  }
}

@Injectable()
export class GetCategoryUseCase {
  constructor(
    private readonly categories: CategoryRepository,
    private readonly merchants: MerchantRepository,
  ) {}

  async execute(userId: string, id: string): Promise<CategoryDetail> {
    const category = await this.categories.findById(userId, id);
    if (!category) throw new CategoryNotFoundError();
    const merchants = await this.merchants.list(userId, { categoryId: id });
    return { ...category, merchantCount: merchants.length, merchants };
  }
}

@Injectable()
export class UpdateCategoryUseCase {
  constructor(private readonly categories: CategoryRepository) {}

  async execute(
    userId: string,
    id: string,
    patch: { name?: string; description?: string | null },
  ): Promise<Category> {
    const updated = await this.categories.update(userId, id, patch);
    if (!updated) throw new CategoryNotFoundError();
    return updated;
  }
}

@Injectable()
export class DeleteCategoryUseCase {
  constructor(private readonly categories: CategoryRepository) {}

  async execute(
    userId: string,
    id: string,
    reassignTo?: string,
  ): Promise<void> {
    const category = await this.categories.findById(userId, id);
    if (!category) throw new CategoryNotFoundError();

    if (reassignTo !== undefined) {
      // 404 (not 409) for a target that is missing or owned by someone else.
      if (
        reassignTo === id ||
        !(await this.categories.findById(userId, reassignTo))
      ) {
        throw new CategoryNotFoundError();
      }
    } else {
      const usage = await this.categories.usage(userId, id);
      if (usage.merchants > 0 || usage.cardRules > 0) {
        throw new CategoryInUseError(usage);
      }
    }
    await this.categories.delete(userId, id, reassignTo ?? null);
  }
}
