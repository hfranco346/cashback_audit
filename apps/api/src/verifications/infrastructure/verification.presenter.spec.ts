import { presentSummary } from './verification.presenter.js';
import type { VerificationSummary } from '../domain/verification.js';

const base = {
  id: 'v-1',
  cardId: 'c-1',
  status: 'COMPLETED',
  seenAt: null,
  createdAt: new Date('2026-01-01T00:00:00Z'),
} as unknown as VerificationSummary;

describe('presentSummary card reference', () => {
  it('exposes the card snapshot, including when the card was deleted', () => {
    const card = { alias: 'Daily', bank: 'BBVA', last4: '4321', deleted: true };
    expect(presentSummary({ ...base, card }).card).toEqual(card);
  });

  it('is null when the card is not loaded', () => {
    expect(presentSummary(base).card).toBeNull();
  });
});
