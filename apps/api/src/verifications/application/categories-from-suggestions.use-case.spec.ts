import { describe, expect, it } from 'vitest';
import { CategoryNameTakenError } from '../../categories/domain/category-errors.js';
import type { Category } from '../../categories/domain/category.js';
import { CategoryRepository } from '../../categories/domain/category.repository.js';
import {
  CAT_PHARMACY,
  d,
  detected,
  line,
  mxnCashbackStatement,
} from '../../../test/fixtures/statements.js';
import type { Verification } from '../domain/verification.js';
import { VerificationRepository } from '../domain/verification.repository.js';
import { proposeSuggestedCategories } from '../domain/statement-hints.js';
import { CategoriesFromSuggestionsUseCase } from './categories-from-suggestions.use-case.js';

const USER = 'u1';
const RESTAURANTS = 'Restaurantes y Comida rápida';

function world(existing: Category[] = []) {
  const categories = [...existing];
  const statement = mxnCashbackStatement({
    detectedRates: [
      detected({
        categoryHint: RESTAURANTS,
        ratePercent: d(7),
        evidence: '7% Restaurantes y Comida rápida',
      }),
      detected({
        categoryHint: 'Débitos automáticos en educación',
        ratePercent: d(7),
        evidence: '7% educación',
      }),
    ],
  });
  const base = (merchant: string, hint: string | null, index: number) => ({
    index,
    merchant,
    amount: d(100),
    currency: 'MXN',
    isCredit: false,
    kind: 'PURCHASE' as const,
    categoryId: null,
    categoryName: null,
    matchSource: 'NONE' as const,
    matchedMerchantId: null,
    matchedMerchantName: null,
    matchConfidence: 0.9,
    matchReason: 'razón',
    suggestedHint: hint,
  });
  let verification = {
    id: 'v1',
    userId: USER,
    status: 'AWAITING_RATES',
    detectedRates: statement.detectedRates,
    transactions: [
      base('POLLO 1', RESTAURANTS, 0),
      base('POLLO 2', RESTAURANTS, 1),
      base('GASOLINA', null, 2),
    ],
  } as unknown as Verification;
  void line;
  const repo = {
    findById: async (_u: string, id: string) =>
      id === 'v1' ? verification : null,
    update: async (_u: string, _id: string, patch: Partial<Verification>) => {
      verification = { ...verification, ...patch } as Verification;
      return verification;
    },
  } as unknown as VerificationRepository;
  const categoriesRepo = {
    listWithCounts: async () =>
      categories.map((c) => ({ ...c, merchantCount: 0 })),
    create: async (input: { name: string; description: string | null }) => {
      if (categories.some((c) => c.name === input.name))
        throw new CategoryNameTakenError();
      const c = {
        id: `cat-${categories.length + 1}`,
        userId: USER,
        ...input,
        createdAt: new Date(),
        updatedAt: new Date(),
      };
      categories.push(c);
      return c;
    },
  } as unknown as CategoryRepository;
  return {
    useCase: new CategoriesFromSuggestionsUseCase(repo, categoriesRepo),
    categories,
    current: () => verification,
  };
}

describe('CategoriesFromSuggestionsUseCase', () => {
  it('creates the category, reassigns the hinted lines and links the rate', async () => {
    const w = world();
    expect(
      proposeSuggestedCategories(
        w.current().detectedRates,
        w.current().transactions,
      ).map((s) => [s.name, s.matchingTransactionCount]),
    ).toEqual([
      [RESTAURANTS, 2],
      ['Débitos automáticos en educación', 0],
    ]);

    const result = await w.useCase.execute({
      userId: USER,
      verificationId: 'v1',
      names: [RESTAURANTS],
    });
    expect(result.created).toEqual([{ id: 'cat-1', name: RESTAURANTS }]);
    expect(result.reused).toEqual([]);
    expect(w.categories[0]).toMatchObject({ description: RESTAURANTS });
    expect(
      result.verification.transactions.map((t) => [
        t.categoryId,
        t.matchSource,
        t.suggestedHint,
      ]),
    ).toEqual([
      ['cat-1', 'AI_CATEGORY', null],
      ['cat-1', 'AI_CATEGORY', null],
      [null, 'NONE', null],
    ]);
    expect(result.verification.detectedRates[0]!.suggestedCategoryId).toBe(
      'cat-1',
    );
    // no longer suggested once linked
    expect(
      proposeSuggestedCategories(
        result.verification.detectedRates,
        result.verification.transactions,
      ).map((s) => s.name),
    ).toEqual(['Débitos automáticos en educación']);
  });

  it('reuses an existing category with the same name (case/accent-insensitive) and is idempotent', async () => {
    const w = world([
      {
        id: 'cat-x',
        userId: USER,
        name: 'restaurantes y comida rapida',
        description: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    ]);
    const first = await w.useCase.execute({
      userId: USER,
      verificationId: 'v1',
      names: [RESTAURANTS, RESTAURANTS.toUpperCase()],
    });
    expect(first.created).toEqual([]);
    expect(first.reused).toEqual([
      { id: 'cat-x', name: 'restaurantes y comida rapida' },
    ]);
    expect(first.verification.transactions[0]!.categoryId).toBe('cat-x');
    const again = await w.useCase.execute({
      userId: USER,
      verificationId: 'v1',
      names: [RESTAURANTS],
    });
    expect(again.created).toEqual([]);
    expect(w.categories).toHaveLength(1);
  });

  it('fails for an unknown verification', async () => {
    await expect(
      world().useCase.execute({
        userId: USER,
        verificationId: 'nope',
        names: ['x'],
      }),
    ).rejects.toMatchObject({ code: 'VERIFICATION_NOT_FOUND' });
  });
});

void CAT_PHARMACY;
