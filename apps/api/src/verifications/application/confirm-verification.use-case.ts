import { Injectable } from '@nestjs/common';
import { Decimal } from 'decimal.js';
import { CardRepository } from '../../cards/domain/card.repository.js';
import {
  CardNotFoundError,
  DuplicateRuleCategoryError,
} from '../../cards/domain/card-errors.js';
import { CategoryNotFoundError } from '../../categories/domain/category-errors.js';
import { CategoryRepository } from '../../categories/domain/category.repository.js';
import {
  AUDIT_WARNING_CODES,
  buildAuditFacts,
  computeAudit,
} from '../domain/audit.js';
import {
  appliedRateSource,
  findMissingRates,
} from '../domain/rate-proposal.js';
import { UserRepository } from '../../users/domain/user.repository.js';
import { ResultExplainer } from '../domain/statement-extractor.js';
import {
  InvalidExchangeRateError,
  RatesRequiredError,
  VerificationNotFoundError,
  VerificationNotReadyError,
} from '../domain/verification-errors.js';
import type { AppliedRates, Verification } from '../domain/verification.js';
import { VerificationRepository } from '../domain/verification.repository.js';
import { RateProposalService } from './rate-proposal.service.js';
import { RewardReportingService } from './reward-reporting.service.js';
import { selectLoyaltyProgram } from '../domain/loyalty-program-selector.js';
import type {
  PreviousBalance,
  PreviousBalanceSource,
  RewardReportingMode,
} from '../domain/reward-reporting.js';

export interface ConfirmVerificationInput {
  userId: string;
  verificationId: string;
  baseRatePercent: string;
  categoryRates: {
    categoryId: string;
    ratePercent: string;
    monthlyCap?: string | null;
  }[];
  /** Also store the confirmed rates as the card's rates. */
  saveToCard?: boolean;
  reportedRewardOverride?: string;
  /** Legacy: one rate for any foreign currency. */
  exchangeRate?: string;
  /** Per foreign currency: primary-currency units per 1 unit of it. */
  exchangeRates?: Record<string, string>;
  /** Primary-currency units per 1 unit of the reward currency. */
  rewardExchangeRate?: string;
  rewardProgramName?: string;
  /** How the bank reports the reward; omitted = keep the previous choice. */
  rewardReporting?: {
    mode: RewardReportingMode;
    previousBalance?: string;
    previousBalanceSource?: PreviousBalanceSource;
    rememberForCard?: boolean;
  };
}

const CURRENCY_CODE = /^[A-Z]{3}$/;

/** Parses a user-sent rate: positive, at most 6 decimals. */
function parseRate(raw: string, label: string): Decimal {
  const text = String(raw).trim();
  if (!/^\d{1,9}(\.\d{1,6})?$/.test(text) || new Decimal(text).lte(0)) {
    throw new InvalidExchangeRateError(
      `${label} must be a positive decimal with at most 6 decimals`,
    );
  }
  return new Decimal(text);
}

/**
 * Step 2 (and every recalculation): audits the stored extraction with the
 * rates the user confirmed. No Claude call; safe to repeat with other rates.
 */
@Injectable()
export class ConfirmVerificationUseCase {
  constructor(
    private readonly verifications: VerificationRepository,
    private readonly cards: CardRepository,
    private readonly categories: CategoryRepository,
    private readonly proposals: RateProposalService,
    private readonly explainer: ResultExplainer,
    private readonly users: UserRepository,
    private readonly reporting: RewardReportingService,
  ) {}

  async execute(input: ConfirmVerificationInput): Promise<Verification> {
    const verification = await this.verifications.findById(
      input.userId,
      input.verificationId,
    );
    if (!verification) throw new VerificationNotFoundError();
    if (
      verification.status === 'PROCESSING' ||
      verification.status === 'FAILED'
    )
      throw new VerificationNotReadyError();
    const card = await this.cards.findById(input.userId, verification.cardId);
    if (!card) throw new CardNotFoundError();

    // --- validate the confirmed rates ----------------------------------
    const seen = new Set<string>();
    for (const rate of input.categoryRates) {
      if (seen.has(rate.categoryId))
        throw new DuplicateRuleCategoryError(rate.categoryId);
      seen.add(rate.categoryId);
    }
    const categories = await this.categories.listWithCounts(input.userId);
    const categoryNames = new Map(categories.map((c) => [c.id, c.name]));
    if ([...seen].some((id) => !categoryNames.has(id)))
      throw new CategoryNotFoundError();

    const proposal = await this.proposals.forVerification(
      input.userId,
      verification,
    );
    const missing = findMissingRates(proposal.entries, seen);
    if (missing.length > 0) {
      throw new RatesRequiredError(
        missing.map((m) => ({
          categoryId: m.categoryId!,
          categoryName: m.categoryName,
        })),
      );
    }

    const base = new Decimal(input.baseRatePercent);
    const categoryRates = input.categoryRates.map((r) => ({
      categoryId: r.categoryId,
      categoryName: categoryNames.get(r.categoryId) ?? null,
      ratePercent: new Decimal(r.ratePercent),
      monthlyCap: r.monthlyCap ? new Decimal(r.monthlyCap) : null,
    }));
    const byCategory = new Map(proposal.entries.map((e) => [e.categoryId, e]));
    const appliedRates: AppliedRates = {
      baseRatePercent: base,
      baseSource: appliedRateSource(byCategory.get(null), base),
      categoryRates: categoryRates.map((r) => ({
        ...r,
        source: appliedRateSource(byCategory.get(r.categoryId), r.ratePercent),
      })),
      savedToCard: input.saveToCard === true,
      rewardExchangeRate: null,
    };

    // Exchange rates: what the user sends now replaces what was sent before.
    const requestedRates = { ...verification.conversion.requestedRates };
    for (const [code, raw] of Object.entries(input.exchangeRates ?? {})) {
      const currency = code.trim().toUpperCase();
      if (!CURRENCY_CODE.test(currency) || currency === card.currency) {
        throw new InvalidExchangeRateError(
          `exchangeRates keys must be ISO 4217 codes other than ${card.currency}`,
        );
      }
      requestedRates[currency] = parseRate(raw, `exchangeRates.${currency}`);
    }

    // --- how the bank reports the reward (monthly vs accumulated balance) ----
    const mode =
      input.rewardReporting?.mode ??
      this.reporting.defaultMode(verification, card);
    let previous: PreviousBalance | null = null;
    if (mode === 'CUMULATIVE') {
      const selection = selectLoyaltyProgram(
        verification.loyalty.programs,
        input.rewardProgramName ?? verification.loyalty.requestedProgramName,
        card.rewardProgramName,
      );
      if (selection.status === 'SELECTED') {
        const typed = input.rewardReporting?.previousBalance;
        previous = await this.reporting.resolvePrevious(
          input.userId,
          verification,
          selection.program,
          typed
            ? {
                value: new Decimal(typed),
                source: input.rewardReporting?.previousBalanceSource ?? 'USER',
                previousVerificationId: null,
              }
            : this.reporting.storedExplicit(verification),
        );
      }
    }

    // --- audit with stored data + the new inputs --------------------------
    const audit = computeAudit({
      rewardReporting: { mode, previous },
      card,
      rates: {
        baseRatePercent: base,
        rules: categoryRates.map((r) => ({
          categoryId: r.categoryId,
          ratePercent: r.ratePercent,
          monthlyCap: r.monthlyCap,
        })),
      },
      transactions: verification.transactions,
      categoryNames,
      programs: verification.loyalty.programs,
      requestedProgramName:
        input.rewardProgramName ?? verification.loyalty.requestedProgramName,
      cardProgramName: card.rewardProgramName,
      reportedOverride: input.reportedRewardOverride
        ? new Decimal(input.reportedRewardOverride)
        : verification.loyalty.reportedOverride,
      requestedRate: input.exchangeRate
        ? new Decimal(input.exchangeRate)
        : verification.conversion.requestedRate,
      requestedRates,
      requestedRewardRate: input.rewardExchangeRate
        ? parseRate(input.rewardExchangeRate, 'rewardExchangeRate')
        : verification.conversion.requestedRewardRate,
      statementRates: verification.conversion.statementRates,
    });
    appliedRates.rewardExchangeRate = audit.rewardExchangeRate;

    // One short narrative; optional and failure-tolerant. It only receives the
    // numbers computed above and never feeds anything back into them.
    const warnings = [
      ...verification.warnings.filter(
        (w) => !AUDIT_WARNING_CODES.includes(w.code),
      ),
      ...audit.warnings,
    ];
    let explanation: string | null = null;
    let explanationModel: string | null = null;
    try {
      const explained = await this.explainer.explain(
        buildAuditFacts(audit, {
          rewardUnit: card.rewardUnit,
          primaryCurrency: card.currency,
        }),
      );
      explanation = explained.text;
      explanationModel = explained.model;
    } catch {
      warnings.push({
        code: 'EXPLANATION_UNAVAILABLE',
        message: 'The written explanation could not be generated.',
      });
    }

    if (input.rewardReporting?.rememberForCard) {
      await this.cards.update(input.userId, card.id, {
        rewardReporting: input.rewardReporting.mode,
      });
    }
    if (input.saveToCard) {
      await this.cards.update(input.userId, card.id, {
        baseRatePercent: base,
        rules: categoryRates.map((r) => ({
          categoryId: r.categoryId,
          ratePercent: r.ratePercent,
          monthlyCap: r.monthlyCap,
        })),
      });
    }

    const updated = await this.verifications.update(
      input.userId,
      verification.id,
      {
        status: 'COMPLETED',
        rewardCurrency: audit.rewardCurrency,
        reportedAmount: audit.reportedAmount,
        reportedLabel: audit.reportedLabel,
        reportedSource: audit.reportedSource,
        expectedAmount: audit.expectedAmount,
        difference: audit.difference,
        tolerance: audit.tolerance,
        verdict: audit.verdict,
        breakdown: audit.breakdown,
        transactions: audit.transactions,
        conversion: audit.conversion,
        loyalty: audit.loyalty,
        appliedRates,
        warnings,
        explanation,
        rewardReporting: audit.rewardReporting,
        models: { ...verification.models, explanation: explanationModel },
      },
    );
    if (!updated) throw new VerificationNotFoundError();

    // Remember the rates used (best effort: never fails the confirmation).
    const rewardRate = audit.rewardExchangeRate;
    const used = [
      ...Object.entries(requestedRates).map(([code, rate]) => ({
        code,
        rate,
      })),
      ...(rewardRate?.source === 'USER_ENTERED'
        ? [{ code: rewardRate.toCurrency, rate: rewardRate.rate }]
        : []),
    ];
    try {
      await this.users.recordCurrencyRates(input.userId, card.currency, used);
    } catch {
      /* the last-used rates are a convenience only */
    }
    return updated;
  }
}
