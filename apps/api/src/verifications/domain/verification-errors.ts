import { DomainError } from '../../shared/domain/domain-error.js';

export class VerificationNotFoundError extends DomainError {
  constructor() {
    super('NOT_FOUND', 'VERIFICATION_NOT_FOUND', 'Verification not found');
  }
}

export class InvalidPdfError extends DomainError {
  constructor() {
    super('VALIDATION', 'INVALID_PDF', 'The uploaded file is not a valid PDF');
  }
}

export class UnreadableStatementError extends DomainError {
  constructor(
    message = 'The statement could not be read. Upload the original PDF from your bank.',
  ) {
    super('UNPROCESSABLE', 'UNREADABLE_STATEMENT', message);
  }
}

export class ReportedRewardMissingError extends DomainError {
  constructor() {
    super(
      'UNPROCESSABLE',
      'REPORTED_REWARD_NOT_FOUND',
      'No reward amount was found on the statement. Send it as reportedRewardOverride.',
    );
  }
}

export class ExtractionUnavailableError extends DomainError {
  constructor(
    message = 'Statement analysis is temporarily unavailable. Try again later.',
  ) {
    super('UPSTREAM_UNAVAILABLE', 'EXTRACTION_UNAVAILABLE', message);
  }
}

export class ExtractionFailedError extends DomainError {
  constructor() {
    super(
      'UPSTREAM_FAILURE',
      'EXTRACTION_FAILED',
      'The statement analysis service returned an unusable response. Try again.',
    );
  }
}

export class RewardProgramAmbiguousError extends DomainError {
  constructor(programNames: string[], requestedName: string | null) {
    super(
      'UNPROCESSABLE',
      'REWARD_PROGRAM_AMBIGUOUS',
      requestedName
        ? `No single loyalty program matches "${requestedName}". Choose one and retry with rewardProgramName.`
        : 'The statement lists several loyalty programs. Choose one and retry with rewardProgramName.',
      { programs: programNames },
    );
  }
}

export class RatesRequiredError extends DomainError {
  constructor(missing: { categoryId: string; categoryName: string | null }[]) {
    super(
      'UNPROCESSABLE',
      'RATES_REQUIRED',
      'A reward rate is required for every category without a known rate. Send categoryRates for the missing categories.',
      { missing },
    );
  }
}

export class VerificationAlreadyCompletedError extends DomainError {
  constructor() {
    super(
      'CONFLICT',
      'VERIFICATION_NOT_AWAITING_RATES',
      'This verification is already completed.',
    );
  }
}

export class TransactionNotFoundError extends DomainError {
  constructor() {
    super('NOT_FOUND', 'TRANSACTION_NOT_FOUND', 'Transaction not found');
  }
}

export class TransactionNotClassifiableError extends DomainError {
  constructor() {
    super(
      'UNPROCESSABLE',
      'TRANSACTION_NOT_CLASSIFIABLE',
      'Only purchases and refunds can be assigned to a category.',
    );
  }
}

export class RewardExchangeRateRequiredError extends DomainError {
  constructor(fromCurrency: string, toCurrency: string) {
    super(
      'UNPROCESSABLE',
      'REWARD_EXCHANGE_RATE_REQUIRED',
      `The reward is paid in ${toCurrency} but spend is in ${fromCurrency}. Send rewardExchangeRate: ${fromCurrency} units per 1 ${toCurrency}.`,
      { fromCurrency, toCurrency },
    );
  }
}

export class InvalidExchangeRateError extends DomainError {
  constructor(message: string) {
    super('VALIDATION', 'INVALID_EXCHANGE_RATE', message);
  }
}
