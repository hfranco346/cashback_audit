import { Decimal } from 'decimal.js';
import {
  appliedRateSource,
  buildRateProposal,
  findMissingRates,
} from './rate-proposal.js';
import type { DetectedRate } from './statement.js';

const d = (v: string | number) => new Decimal(v);
const detected = (over: Partial<DetectedRate>): DetectedRate => ({
  scope: 'CATEGORY',
  categoryHint: null,
  suggestedCategoryId: null,
  ratePercent: d(7),
  unitNote: null,
  evidence: 'quote',
  confidence: 0.9,
  ...over,
});
const names = new Map([
  ['super', 'Supermarkets'],
  ['pharm', 'Pharmacies'],
  ['fuel', 'Fuel'],
]);
const input = (over = {}) => ({
  baseRatePercent: d(1),
  rules: [],
  detectedRates: [],
  categoryNames: names,
  usedCategoryIds: [],
  ...over,
});
const byCategory = (
  p: ReturnType<typeof buildRateProposal>,
  id: string | null,
) => p.find((e) => e.categoryId === id)!;

describe('buildRateProposal', () => {
  it('always proposes the card base rate when the statement states none', () => {
    const p = buildRateProposal(input());
    expect(p).toHaveLength(1);
    expect(p[0]).toMatchObject({
      categoryId: null,
      source: 'CARD_RULE',
      required: false,
    });
    expect(p[0]!.ratePercent!.toString()).toBe('1');
  });

  it('prefers a stated base rate over the card base rate', () => {
    const p = buildRateProposal(
      input({
        detectedRates: [detected({ scope: 'BASE', ratePercent: d('1.5') })],
      }),
    );
    expect(p[0]).toMatchObject({ source: 'STATEMENT', evidence: 'quote' });
    expect(p[0]!.ratePercent!.toString()).toBe('1.5');
  });

  it('priority: STATEMENT > CARD_RULE > NONE per category', () => {
    const p = buildRateProposal(
      input({
        rules: [
          { categoryId: 'super', ratePercent: d(5), monthlyCap: d(100) },
          { categoryId: 'fuel', ratePercent: d(3), monthlyCap: null },
        ],
        detectedRates: [detected({ suggestedCategoryId: 'super' })],
        usedCategoryIds: ['super', 'pharm', 'fuel'],
      }),
    );
    expect(byCategory(p, 'super')).toMatchObject({
      source: 'STATEMENT',
      required: false,
    });
    expect(byCategory(p, 'super').ratePercent!.toString()).toBe('7');
    // the card cap is kept next to the stated rate
    expect(byCategory(p, 'super').monthlyCap!.toString()).toBe('100');
    expect(byCategory(p, 'fuel')).toMatchObject({ source: 'CARD_RULE' });
    expect(byCategory(p, 'pharm')).toMatchObject({
      source: 'NONE',
      ratePercent: null,
      required: true,
    });
  });

  it('lists categories with a card rule even when unused, and used ones without a rule', () => {
    const p = buildRateProposal(
      input({
        rules: [{ categoryId: 'fuel', ratePercent: d(3), monthlyCap: null }],
        usedCategoryIds: ['pharm', 'pharm'],
      }),
    );
    expect(p.map((e) => e.categoryId)).toEqual([null, 'fuel', 'pharm']);
  });

  it('ignores low-confidence, rate-less and unmapped detections; picks the most confident', () => {
    const p = buildRateProposal(
      input({
        usedCategoryIds: ['super'],
        detectedRates: [
          detected({ suggestedCategoryId: 'super', confidence: 0.3 }),
          detected({ suggestedCategoryId: 'super', ratePercent: null }),
          detected({ suggestedCategoryId: null }),
          detected({
            suggestedCategoryId: 'super',
            ratePercent: d(4),
            confidence: 0.6,
          }),
          detected({
            suggestedCategoryId: 'super',
            ratePercent: d(6),
            confidence: 0.8,
          }),
        ],
      }),
    );
    expect(byCategory(p, 'super').ratePercent!.toString()).toBe('6');
  });

  it('passes the unit note through and drops unknown categories', () => {
    const p = buildRateProposal(
      input({
        usedCategoryIds: ['gone'],
        detectedRates: [
          detected({
            scope: 'BASE',
            ratePercent: d(10),
            unitNote: '1 point per 10 spent',
          }),
        ],
      }),
    );
    expect(p).toHaveLength(1);
    expect(p[0]!.unitNote).toBe('1 point per 10 spent');
  });
});

describe('findMissingRates', () => {
  const proposal = buildRateProposal(
    input({ usedCategoryIds: ['pharm', 'fuel'] }),
  );
  it('returns the required entries that were not provided', () => {
    expect(
      findMissingRates(proposal, new Set(['pharm'])).map((e) => e.categoryId),
    ).toEqual(['fuel']);
    expect(findMissingRates(proposal, new Set(['pharm', 'fuel']))).toEqual([]);
  });
});

describe('appliedRateSource', () => {
  const proposal = buildRateProposal(
    input({
      rules: [{ categoryId: 'fuel', ratePercent: d(3), monthlyCap: null }],
      detectedRates: [detected({ suggestedCategoryId: 'super' })],
      usedCategoryIds: ['super', 'pharm'],
    }),
  );
  const entry = (id: string | null) => byCategory(proposal, id);
  it('classifies confirmed rates against the proposal', () => {
    expect(appliedRateSource(entry('super'), d(7))).toBe('STATEMENT_CONFIRMED');
    expect(appliedRateSource(entry('fuel'), d('3.0'))).toBe(
      'CARD_RULE_CONFIRMED',
    );
    expect(appliedRateSource(entry('fuel'), d(4))).toBe('USER_ENTERED');
    expect(appliedRateSource(entry('pharm'), d(2))).toBe('USER_ENTERED');
    expect(appliedRateSource(undefined, d(2))).toBe('USER_ENTERED');
  });
});
