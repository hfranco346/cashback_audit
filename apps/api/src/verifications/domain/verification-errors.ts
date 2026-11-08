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
