import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Env } from '../../config/env.js';
import { EmailSender, type OutgoingEmail } from '../domain/email-sender.js';

const RESEND_URL = 'https://api.resend.com/emails';
const TIMEOUT_MS = 10_000;

/** Production adapter: delivers through the Resend HTTP API. Never logs codes. */
@Injectable()
export class ResendEmailSender extends EmailSender {
  private readonly logger = new Logger(ResendEmailSender.name);
  private readonly apiKey: string;
  private readonly from: string;
  /** Overridable in tests; Nest only injects the config. */
  fetchFn: typeof fetch = (input, init) => fetch(input, init);

  constructor(config: ConfigService<Env, true>) {
    super();
    this.apiKey = config.get('RESEND_API_KEY', { infer: true }) ?? '';
    this.from = config.get('EMAIL_FROM', { infer: true });
  }

  async send(email: OutgoingEmail): Promise<void> {
    const response = await this.fetchFn(RESEND_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: this.from,
        to: [email.to],
        subject: email.subject,
        text: email.text,
        html: email.html,
      }),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    if (!response.ok) {
      // Resend error bodies are {name, message}; they never echo the content.
      const detail = await response.text().catch(() => '');
      this.logger.error(
        `Resend rejected the email (${response.status}): ${detail.slice(0, 300)}`,
      );
      throw new Error(`Resend responded ${response.status}`);
    }
  }
}
