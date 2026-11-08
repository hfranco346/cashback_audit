import type {
  CategoryCandidate,
  ClassificationResult,
  ExtractedStatement,
  ExtractionContext,
} from './statement.js';

/** Port: turns a statement PDF (in memory only) into structured data. */
export abstract class StatementExtractor {
  abstract extract(
    pdf: Buffer,
    context: ExtractionContext,
  ): Promise<{ statement: ExtractedStatement; model: string }>;
}

/**
 * Port: classifies the statement lines that no registered merchant matched
 * into one of the user's categories (and optionally to a registered merchant).
 * Never throws for upstream failures of a batch: those descriptors come back in
 * `unclassified`.
 */
export abstract class LineClassifier {
  abstract classify(
    descriptors: string[],
    categories: CategoryCandidate[],
  ): Promise<ClassificationResult>;
}

/** Facts about a finished audit; the explainer only narrates them. */
export interface AuditFacts {
  verdict: 'MATCH' | 'UNDERPAID' | 'OVERPAID';
  rewardUnit: 'CASHBACK_CURRENCY' | 'POINTS';
  primaryCurrency: string;
  /** Currency of reported/expected/difference/tolerance; null for points. */
  rewardCurrency: string | null;
  /** Set only when the reward was converted from the primary currency. */
  expectedInPrimaryCurrency: string | null;
  reported: string;
  expected: string;
  /** reported - expected */
  difference: string;
  tolerance: string;
  programName: string | null;
  reportedSource: 'STATEMENT' | 'OVERRIDE';
  /** Rates used and what they earned, by category (null = base). */
  breakdown: {
    category: string | null;
    ratePercent: string;
    spend: string;
    expectedReward: string;
    capped: boolean;
    monthlyCap: string | null;
  }[];
  excludedForeignLines: number;
  warningCodes: string[];
}

/**
 * Port: one short narrative of an audit result. It receives the already
 * computed numbers and must not compute anything.
 */
export abstract class ResultExplainer {
  abstract explain(facts: AuditFacts): Promise<{ text: string; model: string }>;
}
