/** Semantic error categories; the HTTP layer maps them to status codes. */
export type DomainErrorKind =
  | 'VALIDATION'
  | 'UNAUTHENTICATED'
  | 'PAYMENT_REQUIRED'
  | 'FORBIDDEN'
  | 'NOT_FOUND'
  | 'CONFLICT'
  | 'UNPROCESSABLE'
  | 'UPSTREAM_FAILURE'
  | 'UPSTREAM_UNAVAILABLE';

export class DomainError extends Error {
  constructor(
    readonly kind: DomainErrorKind,
    readonly code: string,
    message: string,
    readonly details?: unknown,
  ) {
    super(message);
    this.name = new.target.name;
  }
}
