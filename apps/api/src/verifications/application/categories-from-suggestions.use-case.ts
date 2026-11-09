import { Injectable } from '@nestjs/common';
import { CategoryNameTakenError } from '../../categories/domain/category-errors.js';
import type { Category } from '../../categories/domain/category.js';
import { CategoryRepository } from '../../categories/domain/category.repository.js';
import { normalizeText } from '../domain/merchant-matcher.js';
import { statementCategoryHints } from '../domain/statement-hints.js';
import {
  VerificationNotFoundError,
  VerificationNotReadyError,
} from '../domain/verification-errors.js';
import type { Verification } from '../domain/verification.js';
import { VerificationRepository } from '../domain/verification.repository.js';

export interface CategoriesFromSuggestionsResult {
  verification: Verification;
  created: { id: string; name: string }[];
  /** Existing categories of the user with the same name. */
  reused: { id: string; name: string }[];
}

/**
 * Creates the user's missing categories for statement-stated rates, moves the
 * lines the classifier tagged with that wording into them and links the
 * statement rate to the category (so the rate proposal prefills it). No Claude
 * call and no credit; it does not recompute a completed audit.
 */
@Injectable()
export class CategoriesFromSuggestionsUseCase {
  constructor(
    private readonly verifications: VerificationRepository,
    private readonly categories: CategoryRepository,
  ) {}

  async execute(input: {
    userId: string;
    verificationId: string;
    names: string[];
  }): Promise<CategoriesFromSuggestionsResult> {
    const verification = await this.verifications.findById(
      input.userId,
      input.verificationId,
    );
    if (!verification) throw new VerificationNotFoundError();
    if (
      verification.status === 'PROCESSING' ||
      verification.status === 'FAILED'
    )
      throw new VerificationNotReadyError();

    const hints = statementCategoryHints(verification.detectedRates);
    const existing = await this.categories.listWithCounts(input.userId);
    const byName = new Map<string, Category>(
      existing.map((c) => [normalizeText(c.name), c]),
    );

    const created: { id: string; name: string }[] = [];
    const reused: { id: string; name: string }[] = [];
    const resolved = new Map<string, Category>();
    const seen = new Set<string>();
    for (const raw of input.names) {
      const name = raw.trim();
      const key = normalizeText(name);
      if (!key || seen.has(key)) continue;
      seen.add(key);
      const hint = hints.find((h) => normalizeText(h.name) === key);
      let category = byName.get(key) ?? null;
      if (category) {
        reused.push({ id: category.id, name: category.name });
      } else {
        try {
          category = await this.categories.create({
            userId: input.userId,
            name,
            description: hint?.name ?? null,
          });
          created.push({ id: category.id, name: category.name });
        } catch (error) {
          if (!(error instanceof CategoryNameTakenError)) throw error;
          // Same exact name created concurrently: use it.
          const again = (
            await this.categories.listWithCounts(input.userId)
          ).find((c) => c.name === name);
          if (!again) throw error;
          category = again;
          reused.push({ id: again.id, name: again.name });
        }
      }
      resolved.set(key, category);
    }

    const transactions = verification.transactions.map((t) => {
      const target =
        t.categoryId === null && t.suggestedHint
          ? resolved.get(normalizeText(t.suggestedHint))
          : undefined;
      return target
        ? {
            ...t,
            categoryId: target.id,
            categoryName: target.name,
            matchSource: 'AI_CATEGORY' as const,
            suggestedHint: null,
          }
        : t;
    });
    const detectedRates = verification.detectedRates.map((r) => {
      const target =
        r.scope === 'CATEGORY' &&
        r.suggestedCategoryId === null &&
        r.categoryHint
          ? resolved.get(normalizeText(r.categoryHint))
          : undefined;
      return target ? { ...r, suggestedCategoryId: target.id } : r;
    });

    const updated = await this.verifications.update(
      input.userId,
      verification.id,
      { transactions, detectedRates },
    );
    if (!updated) throw new VerificationNotFoundError();
    return { verification: updated, created, reused };
  }
}
