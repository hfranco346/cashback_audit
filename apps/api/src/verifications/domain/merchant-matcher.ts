export interface MatchableMerchant {
  id: string;
  name: string;
  keywords: string[];
  categoryId: string;
}

const MIN_NEEDLE_LENGTH = 3;

/** Lowercase, strip accents, turn punctuation into spaces, collapse spaces. */
export function normalizeText(value: string): string {
  return value
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .trim();
}

const compact = (normalized: string) => normalized.replace(/ /g, '');

interface Needle {
  merchant: MatchableMerchant;
  spaced: string;
  compact: string;
}

/**
 * Deterministic matcher: a transaction belongs to the merchant whose name or
 * keyword is contained (normalized, accent/case-insensitive, also ignoring
 * spaces so "WAL MART" finds "WALMART") in the transaction text. The longest
 * matching needle wins; ties go to the merchant listed first.
 */
export class MerchantMatcher {
  private readonly needles: Needle[];

  constructor(merchants: MatchableMerchant[]) {
    this.needles = merchants.flatMap((merchant) =>
      [merchant.name, ...merchant.keywords]
        .map(normalizeText)
        .filter((text) => compact(text).length >= MIN_NEEDLE_LENGTH)
        .map((text) => ({ merchant, spaced: text, compact: compact(text) })),
    );
  }

  match(description: string): MatchableMerchant | null {
    const spaced = normalizeText(description);
    const squashed = compact(spaced);
    let best: { needle: Needle; length: number } | null = null;
    for (const needle of this.needles) {
      const hit =
        spaced.includes(needle.spaced) || squashed.includes(needle.compact);
      if (hit && (!best || needle.compact.length > best.length)) {
        best = { needle, length: needle.compact.length };
      }
    }
    return best?.needle.merchant ?? null;
  }
}
