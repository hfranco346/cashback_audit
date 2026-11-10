import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Env } from '../../config/env.js';
import { EmailSender, type OutgoingEmail } from '../domain/email-sender.js';

/**
 * Dev/test adapter: writes the mail to the log. The code is printed only
 * outside production, where this adapter delivers nothing.
 */
@Injectable()
export class LogEmailSender extends EmailSender {
  private readonly logger = new Logger(LogEmailSender.name);
  private readonly production: boolean;

  constructor(config: ConfigService<Env, true>) {
    super();
    this.production = config.get('NODE_ENV', { infer: true }) === 'production';
    if (this.production) {
      this.logger.warn(
        'EMAIL_PROVIDER=log in production: no email is delivered',
      );
    }
  }

  async send(email: OutgoingEmail): Promise<void> {
    if (this.production) {
      this.logger.warn(
        `Email to ${email.to.replace(/^(.).*(@.*)$/, '$1***$2')} not delivered`,
      );
      return;
    }
    this.logger.log(
      `To ${email.to}: ${email.subject}${email.code ? ` (code ${email.code})` : ''}`,
    );
  }
}
