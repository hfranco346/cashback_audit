import { DomainError } from '../../shared/domain/domain-error.js';

export class InvalidIdentityTokenError extends DomainError {
  constructor(message = 'Invalid or expired identity token') {
    super('UNAUTHENTICATED', 'INVALID_IDENTITY_TOKEN', message);
  }
}

export class InvalidAccessTokenError extends DomainError {
  constructor() {
    super(
      'UNAUTHENTICATED',
      'INVALID_ACCESS_TOKEN',
      'Invalid or expired access token',
    );
  }
}

export class InvalidRefreshTokenError extends DomainError {
  constructor() {
    super(
      'UNAUTHENTICATED',
      'INVALID_REFRESH_TOKEN',
      'Invalid, expired or revoked refresh token',
    );
  }
}

export class IdentityProviderUnavailableError extends DomainError {
  constructor(provider: string) {
    super(
      'UPSTREAM_UNAVAILABLE',
      'IDENTITY_PROVIDER_UNAVAILABLE',
      `${provider} sign-in is not configured or unreachable`,
    );
  }
}

/** Resend/hourly limits of the email sign-in code. */
export class OtpRateLimitedError extends DomainError {
  constructor(retryAfterSeconds: number) {
    super(
      'RATE_LIMITED',
      'TOO_MANY_REQUESTS',
      'Too many sign-in codes requested. Try again later.',
      { retryAfterSeconds },
    );
  }
}

export class InvalidOtpCodeError extends DomainError {
  constructor(attemptsLeft: number) {
    super('VALIDATION', 'INVALID_CODE', 'The code is not correct', {
      attemptsLeft,
    });
  }
}

/** Also used when no active code exists for the address. */
export class OtpCodeExpiredError extends DomainError {
  constructor() {
    super('GONE', 'CODE_EXPIRED', 'The code expired. Request a new one.');
  }
}

/** The code was burned after too many wrong guesses. */
export class TooManyOtpAttemptsError extends DomainError {
  constructor() {
    super(
      'RATE_LIMITED',
      'TOO_MANY_ATTEMPTS',
      'Too many wrong attempts. Request a new code.',
    );
  }
}

export class EmailDeliveryError extends DomainError {
  constructor() {
    super(
      'UPSTREAM_UNAVAILABLE',
      'EMAIL_DELIVERY_FAILED',
      'Could not send the email. Try again shortly.',
    );
  }
}
