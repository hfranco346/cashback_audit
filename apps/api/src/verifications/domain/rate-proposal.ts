import { Decimal } from 'decimal.js';
import type { CardRule } from '../../cards/domain/card.js';
import type { RewardProgramChoice } from './loyalty-program-selector.js';
import type { RewardReportingProposal } from './reward-reporting.js';
import type { DetectedRate } from './statement.js';
import type { SuggestedCategory } from './statement-hints.js';
import type {
  RewardConversionProposal,
  SpendConversionProposal,
} from './reward-currency.js';

export type RateSource = 'STATEMENT' | 'CARD_RULE' | 'NONE';

/** A detected rate below this confidence is ignored. */
export const DETECTED_RATE_MIN_CONFIDENCE = 0.5;

export interface RateProposalEntry {
  /** Null = the base rate (spend with no category rate). */
  categoryId: string | null;
  categoryName: string | null;
  ratePercent: Decimal | null;
  monthlyCap: Decimal | null;
  source: RateSource;
  evidence: string | null;
  unitNote: string | null;
  /** True when nothing proposes a rate: the client must make the user fill it. */
  required: boolean;
}

/** Everything the client needs to prefill the confirmation screen. */
export interface RateProposal {
  /** Category rates (null categoryId = base). */
  entries: RateProposalEntry[];
  /** Null when the reward is in the primary currency (or points). */
  rewardConversion: RewardConversionProposal | null;
  /** One entry per foreign spend currency present in eligible lines. */
  spendConversions: SpendConversionProposal[];
  /** Statement category rates the user has no category for. */
  suggestedCategories: SuggestedCategory[];
  /** Null unless the verification is AWAITING_RATES or COMPLETED. */
  rewardReporting: RewardReportingProposal | null;
  /** Non-null only in AWAITING_RATES when the user must pick the loyalty program. */
  rewardProgramChoice: RewardProgramChoice | null;
}

export interface RateProposalInput {
  baseRatePercent: Decimal;
  rules: CardRule[];
  detectedRates: DetectedRate[];
  /** Names of the user's categories, by id. */
  categoryNames: Map<string, string>;
  /** Categories that at least one classified transaction belongs to. */
  usedCategoryIds: string[];
}

const best = (candidates: DetectedRate[]): DetectedRate | null =>
  candidates
    .filter(
      (d) =>
        d.ratePercent !== null && d.confidence >= DETECTED_RATE_MIN_CONFIDENCE,
    )
    .sort((a, b) => b.confidence - a.confidence)[0] ?? null;

/**
 * Proposes the rate to audit for the base spend and for every category that is
 * used by a classified transaction or has a card rule.
 * Priority: STATEMENT (stated by the document) > CARD_RULE > NONE.
 * The base always has the card's `baseRatePercent` as a fallback, so it is
 * never required; a category with neither a statement nor a card rate is.
 */
export function buildRateProposal(
  input: RateProposalInput,
): RateProposalEntry[] {
  const rulesByCategory = new Map(input.rules.map((r) => [r.categoryId, r]));

  const base = best(input.detectedRates.filter((d) => d.scope === 'BASE'));
  const entries: RateProposalEntry[] = [
    base
      ? {
          categoryId: null,
          categoryName: null,
          ratePercent: base.ratePercent,
          monthlyCap: null,
          source: 'STATEMENT',
          evidence: base.evidence,
          unitNote: base.unitNote,
          required: false,
        }
      : {
          categoryId: null,
          categoryName: null,
          ratePercent: input.baseRatePercent,
          monthlyCap: null,
          source: 'CARD_RULE',
          evidence: null,
          unitNote: null,
          required: false,
        },
  ];

  const categoryIds = [
    ...new Set([
      ...input.rules.map((r) => r.categoryId),
      ...input.usedCategoryIds,
    ]),
  ].filter((id) => input.categoryNames.has(id));
  categoryIds.sort((a, b) =>
    input.categoryNames.get(a)!.localeCompare(input.categoryNames.get(b)!),
  );

  for (const categoryId of categoryIds) {
    const rule = rulesByCategory.get(categoryId) ?? null;
    const stated = best(
      input.detectedRates.filter(
        (d) => d.scope === 'CATEGORY' && d.suggestedCategoryId === categoryId,
      ),
    );
    const common = {
      categoryId,
      categoryName: input.categoryNames.get(categoryId)!,
      monthlyCap: rule?.monthlyCap ?? null,
    };
    if (stated) {
      entries.push({
        ...common,
        ratePercent: stated.ratePercent,
        source: 'STATEMENT',
        evidence: stated.evidence,
        unitNote: stated.unitNote,
        required: false,
      });
    } else if (rule) {
      entries.push({
        ...common,
        ratePercent: rule.ratePercent,
        source: 'CARD_RULE',
        evidence: null,
        unitNote: null,
        required: false,
      });
    } else {
      entries.push({
        ...common,
        ratePercent: null,
        source: 'NONE',
        evidence: null,
        unitNote: null,
        required: true,
      });
    }
  }
  return entries;
}

/** Required entries (categories) the client did not provide a rate for. */
export function findMissingRates(
  proposal: RateProposalEntry[],
  providedCategoryIds: Set<string>,
): RateProposalEntry[] {
  return proposal.filter(
    (e) =>
      e.required &&
      e.categoryId !== null &&
      !providedCategoryIds.has(e.categoryId),
  );
}

export type AppliedRateSource =
  'STATEMENT_CONFIRMED' | 'CARD_RULE_CONFIRMED' | 'USER_ENTERED';

/** How a confirmed rate relates to what was proposed. */
export function appliedRateSource(
  entry: RateProposalEntry | undefined,
  confirmed: Decimal,
): AppliedRateSource {
  if (!entry || !entry.ratePercent || !entry.ratePercent.eq(confirmed)) {
    return 'USER_ENTERED';
  }
  return entry.source === 'STATEMENT'
    ? 'STATEMENT_CONFIRMED'
    : entry.source === 'CARD_RULE'
      ? 'CARD_RULE_CONFIRMED'
      : 'USER_ENTERED';
}
