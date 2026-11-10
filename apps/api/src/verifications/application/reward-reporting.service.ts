import { Injectable } from '@nestjs/common';
import { Decimal } from 'decimal.js';
import type { Card } from '../../cards/domain/card.js';
import { statementRatesToPrimary } from '../domain/exchange-rates.js';
import type { RateProposal } from '../domain/rate-proposal.js';
import {
  calculateExpectedReward,
  convertRewardToCurrency,
} from '../domain/reward-calculator.js';
import { resolveRewardCurrency } from '../domain/reward-currency.js';
import {
  deriveEarned,
  expiredInPeriod,
  matchProgramName,
  PREVIOUS_PERIOD_TOLERANCE_DAYS,
  previousFromStatement,
  programBalance,
  shiftDate,
  suggestMode,
  type PreviousBalance,
  type RewardReportingChoice,
  type RewardReportingMode,
  type RewardReportingProposal,
} from '../domain/reward-reporting.js';
import { selectLoyaltyProgram } from '../domain/loyalty-program-selector.js';
import type { LoyaltyProgram } from '../domain/statement.js';
import type { Verification } from '../domain/verification.js';
import { VerificationRepository } from '../domain/verification.repository.js';

const zero = new Decimal(0);

/**
 * Finds the previous balance of a program and builds the "earned this month or
 * accumulated?" proposal. Resolution order: B (printed on the statement), A
 * (the card's closest earlier audit), then C (the user, outside this class).
 */
@Injectable()
export class RewardReportingService {
  constructor(private readonly verifications: VerificationRepository) {}

  /** Decision A: balance kept by the closest earlier COMPLETED audit of the card. */
  async findPreviousVerification(
    userId: string,
    verification: Pick<Verification, 'id' | 'cardId' | 'periodStart'>,
    programName: string,
  ): Promise<PreviousBalance | null> {
    if (!verification.periodStart) return null;
    const rows = await this.verifications.listCompletedForCard(
      userId,
      verification.cardId,
      {
        periodEndFrom: shiftDate(
          verification.periodStart,
          -PREVIOUS_PERIOD_TOLERANCE_DAYS,
        ),
        periodEndTo: shiftDate(
          verification.periodStart,
          PREVIOUS_PERIOD_TOLERANCE_DAYS,
        ),
        excludeId: verification.id,
        take: 5,
      },
    );
    for (const row of rows) {
      const kept = row.rewardReporting;
      if (!kept || kept.currentBalance === null || !kept.programName) continue;
      if (matchProgramName([kept], (k) => k.programName ?? '', programName)) {
        return {
          value: kept.currentBalance,
          source: 'PREVIOUS_VERIFICATION',
          previousVerificationId: row.id,
          previousPeriodEnd: row.periodEnd,
        };
      }
    }
    return null;
  }

  /**
   * The previous balance for a CUMULATIVE audit: what the user sent, else B,
   * else (when the statement prints no earned figure) A. Null means the audit
   * either uses the printed earned figure or needs the user's balance.
   */
  async resolvePrevious(
    userId: string,
    verification: Pick<Verification, 'id' | 'cardId' | 'periodStart'>,
    program: LoyaltyProgram,
    explicit: PreviousBalance | null,
  ): Promise<PreviousBalance | null> {
    if (explicit) return explicit;
    const printed = previousFromStatement(program);
    if (printed) return printed;
    if (program.earnedInPeriod) return null;
    return this.findPreviousVerification(userId, verification, program.name);
  }

  /** The choice to audit with when the client did not send one. */
  defaultMode(
    verification: Verification,
    card: Pick<Card, 'rewardReporting'>,
  ): RewardReportingMode {
    if (verification.rewardReporting) return verification.rewardReporting.mode;
    return card.rewardReporting === 'CUMULATIVE' ? 'CUMULATIVE' : 'MONTHLY';
  }

  /** Previous balance the user typed/read earlier, kept for recalculations. */
  storedExplicit(verification: Verification): PreviousBalance | null {
    const kept = verification.rewardReporting;
    if (
      kept?.mode === 'CUMULATIVE' &&
      kept.previousBalance &&
      (kept.previousBalanceSource === 'USER' ||
        kept.previousBalanceSource === 'PREVIOUS_STATEMENT')
    ) {
      return {
        value: kept.previousBalance,
        source: kept.previousBalanceSource,
        previousVerificationId: null,
      };
    }
    return null;
  }

  explicitFromChoice(choice: RewardReportingChoice): PreviousBalance | null {
    return choice.previousBalance
      ? {
          value: choice.previousBalance,
          source: choice.previousBalanceSource ?? 'USER',
          previousVerificationId: null,
        }
      : null;
  }

  /** Proposal for AWAITING_RATES / COMPLETED verifications; null otherwise. */
  async buildProposal(
    userId: string,
    verification: Verification,
    card: Card,
    context: Pick<
      RateProposal,
      'entries' | 'rewardConversion' | 'spendConversions'
    >,
  ): Promise<RewardReportingProposal | null> {
    if (
      verification.status !== 'AWAITING_RATES' &&
      verification.status !== 'COMPLETED'
    ) {
      return null;
    }
    const selection = selectLoyaltyProgram(
      verification.loyalty.programs,
      verification.loyalty.requestedProgramName,
      card.rewardProgramName,
    );
    const program =
      verification.loyalty.selected ??
      (selection.status === 'SELECTED' ? selection.program : null);
    const kept = verification.rewardReporting;

    const suggestion = suggestMode({
      program,
      cardSetting: card.rewardReporting,
      expected: this.estimateExpected(verification, card, context),
      rewardUnit: card.rewardUnit,
    });

    const currentBalance = program ? programBalance(program) : null;
    const redeemed = program?.redeemedInPeriod ?? zero;
    const expired = program ? expiredInPeriod(program) : zero;

    let previous: PreviousBalance | null = null;
    if (program) {
      previous =
        this.storedExplicit(verification) ??
        (await this.resolvePrevious(userId, verification, program, null));
    }
    const earned =
      program?.earnedInPeriod && !previous
        ? program.earnedInPeriod
        : previous && currentBalance
          ? deriveEarned({
              currentBalance,
              previousBalance: previous.value,
              redeemedInPeriod: redeemed,
              expiredInPeriod: expired,
            })
          : null;

    const mode: RewardReportingMode =
      kept?.mode ??
      (card.rewardReporting !== 'AUTO'
        ? card.rewardReporting
        : suggestion.suggestedMode);

    return {
      mode,
      suggestedMode: suggestion.suggestedMode,
      reason: suggestion.reason,
      cardSetting: card.rewardReporting,
      currentBalance,
      previousBalance: previous?.value ?? null,
      previousBalanceSource: previous?.source ?? null,
      previousVerificationId: previous?.previousVerificationId ?? null,
      previousPeriodEnd: previous?.previousPeriodEnd ?? null,
      programName: program?.name ?? null,
      reportedLabel: program?.reportedLabel ?? null,
      redeemedInPeriod: redeemed,
      expiredInPeriod: expired,
      earned,
      previousBalanceRequired: earned === null,
    };
  }

  /**
   * Rough expected reward from the proposed rates (reward unit), only to tell
   * whether the reported figure is far above it. Null when it cannot be told.
   */
  private estimateExpected(
    verification: Verification,
    card: Card,
    context: Pick<
      RateProposal,
      'entries' | 'rewardConversion' | 'spendConversions'
    >,
  ): Decimal | null {
    try {
      const base = context.entries.find((e) => e.categoryId === null);
      const calculation = calculateExpectedReward(
        {
          currency: verification.primaryCurrency,
          rewardUnit: card.rewardUnit,
          pointsPerCurrencyUnit: card.pointsPerCurrencyUnit,
          baseRatePercent: base?.ratePercent ?? zero,
          rules: context.entries.flatMap((e) =>
            e.categoryId && e.ratePercent
              ? [
                  {
                    categoryId: e.categoryId,
                    ratePercent: e.ratePercent,
                    monthlyCap: e.monthlyCap,
                  },
                ]
              : [],
          ),
        },
        verification.transactions.map((t) => ({
          index: t.index,
          amount: t.amount,
          currency: t.currency,
          kind: t.kind,
          isCredit: t.isCredit,
          categoryId: t.categoryId,
        })),
        [
          ...context.spendConversions.flatMap((c) =>
            c.rate
              ? [
                  {
                    from: c.currency,
                    rate: c.rate,
                    source: 'STATEMENT' as const,
                  },
                ]
              : [],
          ),
          ...statementRatesToPrimary(
            verification.conversion.statementRates,
            verification.primaryCurrency,
          ),
        ],
      );
      const rewardCurrency = resolveRewardCurrency({
        rewardUnit: card.rewardUnit,
        cardRewardCurrency: card.rewardCurrency,
        programCurrency: verification.loyalty.selected?.currency ?? null,
        primaryCurrency: verification.primaryCurrency,
      });
      if (rewardCurrency && rewardCurrency !== verification.primaryCurrency) {
        const rate = context.rewardConversion?.rate;
        return rate
          ? convertRewardToCurrency(
              calculation.expectedTotalExact,
              rate,
              rewardCurrency,
            )
          : null;
      }
      return calculation.expectedTotal;
    } catch {
      return null;
    }
  }
}
