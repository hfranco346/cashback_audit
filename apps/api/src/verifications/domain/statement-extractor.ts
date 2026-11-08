import type {
  ExtractedStatement,
  MerchantCandidate,
  MerchantGuess,
} from './statement.js';

/** Port: turns a statement PDF (in memory only) into structured data. */
export abstract class StatementExtractor {
  abstract extract(
    pdf: Buffer,
  ): Promise<{ statement: ExtractedStatement; model: string }>;
}

/** Port: fuzzy-matches unmatched statement descriptors to the user's merchants. */
export abstract class MerchantClassifier {
  abstract classify(
    descriptors: string[],
    merchants: MerchantCandidate[],
  ): Promise<MerchantGuess[]>;
}
