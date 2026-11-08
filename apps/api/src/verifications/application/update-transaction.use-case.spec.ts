import { CategoryRepository } from '../../categories/domain/category.repository.js';
import type {
  Verification,
  VerificationUpdate,
} from '../domain/verification.js';
import { VerificationRepository } from '../domain/verification.repository.js';
import { UpdateTransactionCategoryUseCase } from './update-transaction.use-case.js';

const tx = (index: number, over = {}) => ({
  index,
  kind: 'PURCHASE',
  categoryId: 'old',
  categoryName: 'Old',
  matchedMerchantId: 'm1',
  matchedMerchantName: 'Merchant',
  matchSource: 'KEYWORD',
  matchConfidence: 0.9,
  matchReason: 'x',
  ...over,
});

function setup(owned: string[] = ['cat-1']) {
  let current = {
    id: 'v-1',
    status: 'COMPLETED',
    transactions: [tx(0), tx(1, { kind: 'FEE' })],
  } as unknown as Verification;
  const useCase = new UpdateTransactionCategoryUseCase(
    {
      findById: async (_u: string, id: string) =>
        id === 'v-1' ? current : null,
      update: async (_u: string, _id: string, patch: VerificationUpdate) => {
        current = { ...current, ...patch } as Verification;
        return current;
      },
    } as unknown as VerificationRepository,
    {
      findManyByIds: async (_u: string, ids: string[]) =>
        ids.filter((i) => owned.includes(i)).map((id) => ({ id, name: 'New' })),
    } as unknown as CategoryRepository,
  );
  return { useCase, get: () => current };
}
const run = (
  s: ReturnType<typeof setup>,
  over: Partial<{
    verificationId: string;
    index: number;
    categoryId: string | null;
  }> = {},
) =>
  s.useCase.execute({
    userId: 'u',
    verificationId: 'v-1',
    index: 0,
    categoryId: 'cat-1',
    ...over,
  });

describe('UpdateTransactionCategoryUseCase', () => {
  it('assigns the category and marks the line as a user correction', async () => {
    const s = setup();
    const v = await run(s);
    expect(v.transactions[0]).toMatchObject({
      categoryId: 'cat-1',
      categoryName: 'New',
      matchSource: 'USER',
      matchedMerchantId: null,
      matchConfidence: null,
      matchReason: null,
    });
    expect(v.transactions[1]!.categoryId).toBe('old');
  });

  it('clears the category with null', async () => {
    const v = await run(setup(), { categoryId: null });
    expect(v.transactions[0]).toMatchObject({
      categoryId: null,
      categoryName: null,
      matchSource: 'NONE',
    });
  });

  it('rejects unknown verifications, lines, foreign categories and non-purchases', async () => {
    const s = setup();
    await expect(run(s, { verificationId: 'x' })).rejects.toMatchObject({
      code: 'VERIFICATION_NOT_FOUND',
    });
    await expect(run(s, { index: 9 })).rejects.toMatchObject({
      code: 'TRANSACTION_NOT_FOUND',
    });
    await expect(run(s, { index: 1 })).rejects.toMatchObject({
      code: 'TRANSACTION_NOT_CLASSIFIABLE',
    });
    await expect(run(setup([]))).rejects.toMatchObject({
      code: 'CATEGORY_NOT_FOUND',
    });
  });
});
