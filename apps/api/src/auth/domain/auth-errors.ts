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
