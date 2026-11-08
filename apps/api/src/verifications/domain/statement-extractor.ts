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
