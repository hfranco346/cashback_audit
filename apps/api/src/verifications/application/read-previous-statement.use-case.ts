import { Injectable } from '@nestjs/common';
import { CardRepository } from '../../cards/domain/card.repository.js';
import { selectLoyaltyProgram } from '../domain/loyalty-program-selector.js';
import { matchProgramName } from '../domain/reward-reporting.js';
import { PreviousStatementReader } from '../domain/statement-extractor.js';
import {
  InvalidPdfError,
  ProgramNotFoundError,
  VerificationNotFoundError,
  VerificationNotReadyError,
} from '../domain/verification-errors.js';
import { VerificationRepository } from '../domain/verification.repository.js';

export interface PreviousStatementInput {
  userId: string;
  verificationId: string;
  /** Last month's statement; read in memory and never stored. */
  pdf: Buffer;
  /** Picks the program when the verification has several candidates. */
  rewardProgramName?: string;
}

export interface PreviousStatementResult {
  programs: { name: string; balance: string; periodEnd: string | null }[];
  /** Balance of this verification's program, when it could be matched. */
  matchedBalance: string | null;
}

const PDF_MAGIC = Buffer.from('%PDF-');

/**
 * Reads last month's loyalty balances so the user does not have to type the
 * previous balance. Costs no credit: it only feeds a recalculation of an
 * audit that was already paid for.
 */
@Injectable()
export class ReadPreviousStatementUseCase {
  constructor(
    private readonly verifications: VerificationRepository,
    private readonly cards: CardRepository,
    private readonly reader: PreviousStatementReader,
  ) {}

  async execute(
    input: PreviousStatementInput,
  ): Promise<PreviousStatementResult> {
    if (
      input.pdf.length < PDF_MAGIC.length ||
      !input.pdf.subarray(0, 5).equals(PDF_MAGIC)
    ) {
      throw new InvalidPdfError();
    }
    const verification = await this.verifications.findById(
      input.userId,
      input.verificationId,
    );
    if (!verification) throw new VerificationNotFoundError();
    if (
      verification.status !== 'AWAITING_RATES' &&
      verification.status !== 'COMPLETED'
    ) {
      throw new VerificationNotReadyError();
    }
    const card = await this.cards.findById(input.userId, verification.cardId);

    const selection = selectLoyaltyProgram(
      verification.loyalty.programs,
      input.rewardProgramName ?? verification.loyalty.requestedProgramName,
      card?.rewardProgramName,
    );
    const wanted =
      selection.status === 'SELECTED' ? selection.program.name : null;

    const { programs } = await this.reader.read(input.pdf);
    const listed = programs.map((p) => ({
      name: p.name,
      balance: p.balance.toString(),
      periodEnd: p.periodEnd,
    }));
    if (programs.length === 0) throw new ProgramNotFoundError([]);
    if (!wanted) return { programs: listed, matchedBalance: null };

    const match = matchProgramName(programs, (p) => p.name, wanted);
    if (!match) throw new ProgramNotFoundError(programs.map((p) => p.name));
    return { programs: listed, matchedBalance: match.balance.toString() };
  }
}
