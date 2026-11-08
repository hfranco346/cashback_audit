import type { Category, CategoryUsage, CategoryWithCount } from './category.js';

export interface NewCategory {
  userId: string;
  name: string;
  description: string | null;
}

export abstract class CategoryRepository {
  /** Throws CategoryNameTakenError on duplicate (userId, name). */
  abstract create(input: NewCategory): Promise<Category>;
  abstract findById(userId: string, id: string): Promise<Category | null>;
  /** Returns only categories owned by `userId`. */
  abstract findManyByIds(userId: string, ids: string[]): Promise<Category[]>;
  abstract listWithCounts(userId: string): Promise<CategoryWithCount[]>;
  abstract update(
    userId: string,
    id: string,
    patch: { name?: string; description?: string | null },
  ): Promise<Category | null>;
  abstract usage(userId: string, id: string): Promise<CategoryUsage>;
  /**
   * Deletes the category. When `reassignTo` is given, its merchants move to
   * that category and its card rules move too (dropped if the card already
   * has a rule for the target). Runs atomically.
   */
  abstract delete(
    userId: string,
    id: string,
    reassignTo: string | null,
  ): Promise<void>;
}
