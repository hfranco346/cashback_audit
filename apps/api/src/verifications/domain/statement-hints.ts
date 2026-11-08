import type { Decimal } from 'decimal.js';
import { DETECTED_RATE_MIN_CONFIDENCE } from './rate-proposal.js';
import { normalizeText } from './merchant-matcher.js';
import type { DetectedRate } from './statement.js';

/** Id prefix of the pseudo-categories offered to the classifier. */
export const HINT_ID_PREFIX = 'hint:';

/** A category the statement itself rewards but the user has no category for. */
export interface CategoryHint {
  /** Wording used by the statement. */
  name: string;
  ratePercent: Decimal | null;
  evidence: string;
}

/**
 * Statement category rates with no matching category of the user, in a stable
 * order (the position is the `hint:<n>` id sent to the classifier).
 */
export function statementCategoryHints(rates: DetectedRate[]): CategoryHint[] {
  const byName = new Map<string, DetectedRate>();
  for (const rate of rates) {
    if (
      rate.scope !== 'CATEGORY' ||
      rate.suggestedCategoryId !== null ||
      !rate.categoryHint ||
      rate.ratePercent === null ||
      rate.confidence < DETECTED_RATE_MIN_CONFIDENCE
    ) {
      continue;
    }
    const key = normalizeText(rate.categoryHint);
    if (!key) continue;
    const current = byName.get(key);
    if (!current || rate.confidence > current.confidence) byName.set(key, rate);
  }
  return [...byName.values()].map((r) => ({
    name: r.categoryHint!,
    ratePercent: r.ratePercent,
    evidence: r.evidence,
  }));
}

/**
 * Statement wordings that are broader than (but map to) one of the user's
 * categories, e.g. "Farmacias y Hospitales" for the category "Farmacia".
 * They are shown to the classifier as part of that category's description.
 */
export function broadeningWordings(
  rates: DetectedRate[],
  categories: { id: string; name: string }[],
): Map<string, string[]> {
  const names = new Map(categories.map((c) => [c.id, normalizeText(c.name)]));
  const out = new Map<string, string[]>();
  for (const rate of rates) {
    if (
      rate.scope !== 'CATEGORY' ||
      !rate.suggestedCategoryId ||
      !rate.categoryHint ||
      !names.has(rate.suggestedCategoryId)
    ) {
      continue;
    }
    const wording = rate.categoryHint.trim();
    if (normalizeText(wording) === names.get(rate.suggestedCategoryId))
      continue;
    const list = out.get(rate.suggestedCategoryId) ?? [];
    if (!list.some((w) => normalizeText(w) === normalizeText(wording))) {
      list.push(wording);
    }
    out.set(rate.suggestedCategoryId, list);
  }
  return out;
}

export interface SuggestedCategory extends CategoryHint {
  matchingTransactionCount: number;
}

/** Hints plus how many uncategorized lines the classifier tagged with each. */
export function proposeSuggestedCategories(
  rates: DetectedRate[],
  lines: { categoryId: string | null; suggestedHint: string | null }[],
): SuggestedCategory[] {
  return statementCategoryHints(rates).map((hint) => {
    const key = normalizeText(hint.name);
    return {
      ...hint,
      matchingTransactionCount: lines.filter(
        (l) =>
          l.categoryId === null &&
          l.suggestedHint !== null &&
          normalizeText(l.suggestedHint) === key,
      ).length,
    };
  });
}
