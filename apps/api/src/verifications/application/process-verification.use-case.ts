import { Inject, Injectable } from '@nestjs/common';
import { Decimal } from 'decimal.js';
import type { Card } from '../../cards/domain/card.js';
import { CategoryRepository } from '../../categories/domain/category.repository.js';
import { MerchantRepository } from '../../merchants/domain/merchant.repository.js';
import {
  broadeningWordings,
  HINT_ID_PREFIX,
  statementCategoryHints,
} from '../domain/statement-hints.js';
import { checkStatementTotals } from '../domain/totals-check.js';
import { selectLoyaltyProgram } from '../domain/loyalty-program-selector.js';
import {
  MerchantMatcher,
  type MatchableMerchant,
} from '../domain/merchant-matcher.js';
import {
  REWARD_ELIGIBLE_KINDS,
  type CategoryCandidate,
} from '../domain/statement.js';
import {
  LineClassifier,
  StatementExtractor,
} from '../domain/statement-extractor.js';
import type {
  MatchSource,
  VerificationTransaction,
  VerificationWarning,
} from '../domain/verification.js';
import { VerificationRepository } from '../domain/verification.repository.js';

/** Injection token: minimum classifier confidence (0..1) to accept a result. */
export const CLASSIFICATION_MIN_CONFIDENCE = Symbol(
  'CLASSIFICATION_MIN_CONFIDENCE',
);

/** What the background processor needs; the PDF lives in memory only. */
export interface VerificationJob {
  verificationId: string;
  userId: string;
  card: Card;
  pdf: Buffer;
  /** Decimal string: card-currency units per 1 unit of the foreign currency. */
  exchangeRate?: string;
  /** Loyalty program to audit; overrides the card's `rewardProgramName`. */
  rewardProgramName?: string;
}

/**
 * Reads the statement (Claude), classifies its lines and stores everything on
 * the PROCESSING verification, which becomes AWAITING_RATES. No reward is
 * computed here: the user confirms the rates first (ConfirmVerificationUseCase).
 * Throws when the statement cannot be processed; the caller marks it FAILED.
 */
@Injectable()
export class ProcessVerificationUseCase {
  constructor(
    private readonly categories: CategoryRepository,
    private readonly merchants: MerchantRepository,
    private readonly extractor: StatementExtractor,
    private readonly classifier: LineClassifier,
    private readonly verifications: VerificationRepository,
    @Inject(CLASSIFICATION_MIN_CONFIDENCE)
    private readonly minConfidence: number,
  ) {}

  async execute(job: VerificationJob): Promise<void> {
    const { card, userId, verificationId } = job;
    const input = job;
    const userMerchants = await this.merchants.list(userId, {});
    const categories = await this.categories.listWithCounts(userId);
    const categoryName = new Map(categories.map((c) => [c.id, c.name]));
    const merchantById = new Map(userMerchants.map((m) => [m.id, m]));

    const { statement, model } = await this.extractor.extract(input.pdf, {
      categories: categories.map((c) => ({
        id: c.id,
        name: c.name,
        description: c.description,
      })),
    });
    const warnings: VerificationWarning[] = [];
    let classificationModel: string | null = null;

    // --- sanity warnings -----------------------------------------------
    if (statement.cardLast4 && statement.cardLast4 !== card.last4) {
      warnings.push({
        code: 'CARD_LAST4_MISMATCH',
        message: `The statement belongs to a card ending in ${statement.cardLast4}, but you selected a card ending in ${card.last4}.`,
      });
    }
    const statementCurrencies = new Set([
      ...statement.transactions.map((t) => t.currency),
      ...statement.summaries.map((s) => s.currency),
    ]);
    if (
      statementCurrencies.size > 0 &&
      !statementCurrencies.has(card.currency)
    ) {
      warnings.push({
        code: 'CURRENCY_MISMATCH',
        message: `The statement currencies (${[...statementCurrencies].join(', ')}) do not include the card currency (${card.currency}).`,
      });
    }
    if (statement.transactions.length === 0) {
      warnings.push({
        code: 'NO_TRANSACTIONS',
        message: 'No transactions were found on the statement.',
      });
    }

    // Statement totals per currency vs the extracted lines (warn only).
    for (const summary of statement.summaries) {
      const warning = checkStatementTotals(summary, statement.transactions);
      if (warning) warnings.push(warning);
    }

    // --- line matching: keywords first, then one classification pass ------
    const matcher = new MerchantMatcher(
      userMerchants.map((m): MatchableMerchant => ({
        id: m.id,
        name: m.name,
        keywords: m.keywords,
        categoryId: m.categoryId,
      })),
    );
    const eligible = statement.transactions.map((tx) =>
      REWARD_ELIGIBLE_KINDS.includes(tx.kind),
    );
    interface Match {
      merchantId: string | null;
      categoryId: string | null;
      source: MatchSource;
      confidence: number | null;
      reason: string | null;
      suggestedHint?: string | null;
    }
    const matches: Match[] = statement.transactions.map((tx, i) => {
      const merchant = eligible[i] ? matcher.match(tx.merchant) : null;
      return {
        merchantId: merchant?.id ?? null,
        categoryId: merchant?.categoryId ?? null,
        source: merchant ? 'KEYWORD' : 'NONE',
        confidence: null,
        reason: null,
      };
    });

    const unmatchedDescriptors = [
      ...new Set(
        statement.transactions
          .filter((_, i) => eligible[i] && matches[i]!.source === 'NONE')
          .map((t) => t.merchant),
      ),
    ];
    // Statement rates for kinds of spending the user has no category for are
    // offered to the classifier as pseudo-categories (`hint:<n>`).
    const hints = statementCategoryHints(statement.detectedRates);
    const wordings = broadeningWordings(statement.detectedRates, categories);
    if (
      unmatchedDescriptors.length > 0 &&
      categories.length + hints.length > 0
    ) {
      try {
        const merchantsByCategory = new Map<
          string,
          CategoryCandidate['merchants']
        >();
        for (const m of userMerchants) {
          const list = merchantsByCategory.get(m.categoryId) ?? [];
          list.push({ id: m.id, name: m.name });
          merchantsByCategory.set(m.categoryId, list);
        }
        const candidates: CategoryCandidate[] = [
          ...categories.map((c) => ({
            id: c.id,
            name: c.name,
            description:
              [
                c.description,
                wordings.has(c.id)
                  ? `Also covers what the statement calls: ${wordings
                      .get(c.id)!
                      .map((w) => `"${w}"`)
                      .join(', ')}`
                  : null,
              ]
                .filter(Boolean)
                .join('. ') || null,
            merchants: merchantsByCategory.get(c.id) ?? [],
          })),
          ...hints.map((h, n) => ({
            id: `${HINT_ID_PREFIX}${n}`,
            name: h.name,
            description:
              'Kind of spending named by the statement; the user has no category for it',
            merchants: [],
          })),
        ];
        const classified = await this.classifier.classify(
          unmatchedDescriptors,
          candidates,
        );
        classificationModel = classified.model;
        const byDescriptor = new Map(
          classified.results.map((r) => [r.descriptor, r]),
        );
        statement.transactions.forEach((tx, i) => {
          if (!eligible[i] || matches[i]!.source !== 'NONE') return;
          const verdict = byDescriptor.get(tx.merchant);
          if (!verdict || verdict.confidence < this.minConfidence) return;
          const merchant = verdict.matchedMerchantId
            ? merchantById.get(verdict.matchedMerchantId)
            : undefined;
          const hint = verdict.categoryId?.startsWith(HINT_ID_PREFIX)
            ? hints[Number(verdict.categoryId.slice(HINT_ID_PREFIX.length))]
            : undefined;
          if (hint) {
            matches[i] = {
              merchantId: null,
              categoryId: null,
              source: 'NONE',
              confidence: verdict.confidence,
              reason: verdict.reason || null,
              suggestedHint: hint.name,
            };
          } else if (merchant) {
            matches[i] = {
              merchantId: merchant.id,
              categoryId: merchant.categoryId,
              source: 'AI_MERCHANT',
              confidence: verdict.confidence,
              reason: verdict.reason || null,
            };
          } else if (
            verdict.categoryId &&
            categoryName.has(verdict.categoryId)
          ) {
            matches[i] = {
              merchantId: null,
              categoryId: verdict.categoryId,
              source: 'AI_CATEGORY',
              confidence: verdict.confidence,
              reason: verdict.reason || null,
            };
          }
        });
        if (classified.unclassified.length > 0) {
          warnings.push({
            code: 'AI_MATCHING_UNAVAILABLE',
            message: `Automatic classification failed for ${classified.unclassified.length} line(s); they were left unclassified.`,
          });
        }
      } catch {
        warnings.push({
          code: 'AI_MATCHING_UNAVAILABLE',
          message:
            'Automatic classification was unavailable; only keyword matches were applied.',
        });
      }
    }

    const transactions: VerificationTransaction[] = statement.transactions.map(
      (tx, index) => {
        const match = matches[index]!;
        const merchant = match.merchantId
          ? merchantById.get(match.merchantId)!
          : null;
        return {
          index,
          date: tx.date,
          reference: tx.reference,
          merchant: tx.merchant,
          amount: tx.amount,
          currency: tx.currency,
          isCredit: tx.isCredit,
          kind: tx.kind,
          convertedAmount: null,
          exchangeRate: null,
          rateSource: null,
          excludedReason: eligible[index] ? null : 'NON_PURCHASE_KIND',
          matchedMerchantId: merchant?.id ?? null,
          matchedMerchantName: merchant?.name ?? null,
          categoryId: match.categoryId,
          categoryName: match.categoryId
            ? (categoryName.get(match.categoryId) ?? null)
            : null,
          matchSource: match.source,
          matchConfidence: match.confidence,
          matchReason: match.reason,
          suggestedHint: match.suggestedHint ?? null,
          appliedRatePercent: null,
          ruleApplied: false,
          expectedReward: null,
        };
      },
    );

    // The program is only *proposed* here; confirming resolves ambiguity.
    const selection = selectLoyaltyProgram(
      statement.loyaltyPrograms,
      input.rewardProgramName,
      card.rewardProgramName,
    );
    const primarySummary = statement.summaries.find(
      (x) => x.currency === card.currency,
    );

    // Skipped when the user deleted the verification meanwhile, or when it
    // was already failed (boot recovery) and its credit refunded.
    await this.verifications.update(
      userId,
      verificationId,
      {
        status: 'AWAITING_RATES',
        failureCode: null,
        processedAt: new Date(),
        statementBank: statement.bank,
        statementLast4: statement.cardLast4,
        periodStart: statement.periodStart,
        periodEnd: statement.periodEnd,
        currency: statement.currency,
        primaryCurrency: card.currency,
        totalSpent: primarySummary?.purchasesAndCharges ?? null,
        totalToPay: primarySummary?.totalBalance ?? null,
        summaries: statement.summaries,
        conversion: {
          requestedRate: input.exchangeRate
            ? new Decimal(input.exchangeRate)
            : null,
          requestedRates: {},
          requestedRewardRate: null,
          statementRates: statement.exchangeRates,
          currencies: [],
          rewardCapApplied: null,
          reward: null,
        },
        loyalty: {
          requestedProgramName: input.rewardProgramName ?? null,
          reportedOverride: null,
          selected: selection.status === 'SELECTED' ? selection.program : null,
          selectedBy: selection.status === 'SELECTED' ? selection.source : null,
          programs: statement.loyaltyPrograms,
        },
        reportedAmount: null,
        reportedUnit: card.rewardUnit,
        rewardCurrency: null,
        reportedLabel: null,
        reportedSource: null,
        expectedAmount: null,
        difference: null,
        tolerance: null,
        verdict: null,
        detectedRates: statement.detectedRates,
        appliedRates: null,
        explanation: null,
        rewardReporting: null,
        breakdown: [],
        transactions,
        warnings,
        model,
        models: {
          extraction: model,
          classification: classificationModel,
          explanation: null,
        },
      },
      { onlyIfStatus: 'PROCESSING' },
    );
  }
}
