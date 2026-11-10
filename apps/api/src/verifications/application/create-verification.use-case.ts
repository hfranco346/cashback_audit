import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { CardRepository } from '../../cards/domain/card.repository.js';
import { CardNotFoundError } from '../../cards/domain/card-errors.js';
import { CreditsService } from '../../credits/application/credits.service.js';
import { InvalidPdfError } from '../domain/verification-errors.js';
import type { Verification } from '../domain/verification.js';
import { VerificationRepository } from '../domain/verification.repository.js';
import { VerificationProcessingService } from './verification-processing.service.js';

export interface CreateVerificationInput {
  userId: string;
  cardId: string;
  /** The uploaded PDF; held in memory only. */
  pdf: Buffer;
  /** Decimal string: card-currency units per 1 unit of the foreign currency. */
  exchangeRate?: string;
  /** Loyalty program to audit; overrides the card's `rewardProgramName`. */
  rewardProgramName?: string;
}

const PDF_MAGIC = Buffer.from('%PDF-');

/**
 * Accepts an upload: validates it, spends one credit and stores a PROCESSING
 * verification. The evaluation itself (Claude extraction, classification, rate
 * proposal) runs in the background (VerificationProcessingService), which ends
 * in AWAITING_RATES, or in FAILED with the credit refunded.
 */
@Injectable()
export class CreateVerificationUseCase {
  constructor(
    private readonly cards: CardRepository,
    private readonly verifications: VerificationRepository,
    private readonly credits: CreditsService,
    private readonly processing: VerificationProcessingService,
  ) {}

  async execute(input: CreateVerificationInput): Promise<Verification> {
    if (
      input.pdf.length < PDF_MAGIC.length ||
      !input.pdf.subarray(0, 5).equals(PDF_MAGIC)
    ) {
      throw new InvalidPdfError();
    }
    const card = await this.cards.findById(input.userId, input.cardId);
    if (!card) throw new CardNotFoundError();

    // One credit is spent atomically before any paid work starts; a failed
    // verification gives it back (see VerificationProcessingService).
    const verificationId = randomUUID();
    const reservation = await this.credits.reserve(
      input.userId,
      verificationId,
    );
    let verification: Verification;
    try {
      verification = await this.verifications.create({
        id: verificationId,
        userId: input.userId,
        cardId: card.id,
        status: 'PROCESSING',
        processingStartedAt: new Date(),
        statementBank: null,
        statementLast4: null,
        periodStart: null,
        periodEnd: null,
        currency: null,
        primaryCurrency: card.currency,
        totalSpent: null,
        totalToPay: null,
        summaries: [],
        conversion: {
          requestedRate: null,
          requestedRates: {},
          requestedRewardRate: null,
          statementRates: [],
          currencies: [],
          reward: null,
        },
        loyalty: {
          requestedProgramName: input.rewardProgramName ?? null,
          reportedOverride: null,
          selected: null,
          selectedBy: null,
          programs: [],
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
        detectedRates: [],
        appliedRates: null,
        explanation: null,
        rewardReporting: null,
        breakdown: [],
        transactions: [],
        warnings: [],
        model: '',
        models: { extraction: '', classification: null, explanation: null },
      });
    } catch (error) {
      await this.credits.refund(reservation);
      throw error;
    }

    this.processing.enqueue({
      verificationId,
      userId: input.userId,
      card,
      pdf: input.pdf,
      exchangeRate: input.exchangeRate,
      rewardProgramName: input.rewardProgramName,
    });
    return verification;
  }
}
