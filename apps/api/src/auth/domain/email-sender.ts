export interface OutgoingEmail {
  to: string;
  subject: string;
  text: string;
  html: string;
  /** Plain-text code of a sign-in mail; adapters must never log it in production. */
  code?: string;
}

/** Port: delivers a transactional email. */
export abstract class EmailSender {
  /** Throws when the provider did not accept the message. */
  abstract send(email: OutgoingEmail): Promise<void>;
}
