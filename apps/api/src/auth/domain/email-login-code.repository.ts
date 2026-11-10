export interface EmailLoginCodeRecord {
  id: string;
  email: string;
  codeHash: string;
  expiresAt: Date;
  attempts: number;
  consumedAt: Date | null;
  createdAt: Date;
}

export abstract class EmailLoginCodeRepository {
  /** Newest code of the address that is neither consumed nor burned. */
  abstract findActive(email: string): Promise<EmailLoginCodeRecord | null>;
  /** Creation times of codes sent since `since`, oldest first. */
  abstract createdSince(email: string, since: Date): Promise<Date[]>;
  /** Newest creation time of any code of the address. */
  abstract lastCreatedAt(email: string): Promise<Date | null>;
  /** Invalidates older codes of the address and stores the new one. */
  abstract replaceActive(data: {
    email: string;
    codeHash: string;
    expiresAt: Date;
    ip: string | null;
  }): Promise<EmailLoginCodeRecord>;
  /**
   * Atomically counts one guess. Returns the new attempt count, or null when
   * the code is already used/burned or has no attempts left.
   */
  abstract claimAttempt(
    id: string,
    maxAttempts: number,
  ): Promise<number | null>;
  /** Marks the code used. False when somebody else consumed it first. */
  abstract consume(id: string): Promise<boolean>;
  abstract deleteCreatedBefore(date: Date): Promise<number>;
  abstract delete(id: string): Promise<void>;
}
