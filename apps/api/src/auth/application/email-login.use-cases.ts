import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac, randomInt, timingSafeEqual } from 'node:crypto';
import type { Env } from '../../config/env.js';
import { CreditsService } from '../../credits/application/credits.service.js';
import { UserRepository } from '../../users/domain/user.repository.js';
import {
  EmailDeliveryError,
  InvalidOtpCodeError,
  OtpCodeExpiredError,
  OtpRateLimitedError,
  TooManyOtpAttemptsError,
} from '../domain/auth-errors.js';
import { EmailLoginCodeRepository } from '../domain/email-login-code.repository.js';
import { EmailSender } from '../domain/email-sender.js';
import { AuthSessionService } from './auth-session.service.js';
import { buildLoginCodeEmail, type EmailLocale } from './login-code-email.js';
import type { SignInResult } from './sign-in.use-case.js';

export const OTP_TTL_SECONDS = 600;
export const OTP_RESEND_AFTER_SECONDS = 60;
export const OTP_MAX_ATTEMPTS = 5;
export const OTP_MAX_SENDS_PER_HOUR = 5;
const HOUR_MS = 60 * 60 * 1000;
const RETENTION_MS = 24 * HOUR_MS;

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

function safeEqual(a: string, b: string): boolean {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}

/** Shared by start/verify: HMAC of `email:code` so codes are not reusable across addresses. */
@Injectable()
export class OtpCodec {
  private readonly secret: string;

  constructor(config: ConfigService<Env, true>) {
    this.secret = config.get('OTP_HMAC_SECRET', { infer: true });
  }

  generate(): string {
    return String(randomInt(0, 1_000_000)).padStart(6, '0');
  }

  hash(email: string, code: string): string {
    return createHmac('sha256', this.secret)
      .update(`${email}:${code}`)
      .digest('hex');
  }

  matches(email: string, code: string, storedHash: string): boolean {
    return safeEqual(this.hash(email, code), storedHash);
  }
}

@Injectable()
export class StartEmailLoginUseCase {
  private readonly logger = new Logger(StartEmailLoginUseCase.name);
  private readonly reviewEmail: string | undefined;

  constructor(
    private readonly codes: EmailLoginCodeRepository,
    private readonly sender: EmailSender,
    private readonly codec: OtpCodec,
    config: ConfigService<Env, true>,
  ) {
    this.reviewEmail = config.get('REVIEW_LOGIN_EMAIL', { infer: true });
  }

  async execute(
    rawEmail: string,
    locale: EmailLocale = 'es',
    ip: string | null = null,
    now: Date = new Date(),
  ): Promise<{ expiresInSeconds: number; resendAfterSeconds: number }> {
    const email = normalizeEmail(rawEmail);
    const accepted = {
      expiresInSeconds: OTP_TTL_SECONDS,
      resendAfterSeconds: OTP_RESEND_AFTER_SECONDS,
    };
    // The review account uses a fixed code: nothing to store or send.
    if (email === this.reviewEmail) return accepted;

    await this.assertCanSend(email, now);

    const code = this.codec.generate();
    const record = await this.codes.replaceActive({
      email,
      codeHash: this.codec.hash(email, code),
      expiresAt: new Date(now.getTime() + OTP_TTL_SECONDS * 1000),
      ip,
    });
    const mail = buildLoginCodeEmail(locale, code, OTP_TTL_SECONDS / 60);
    try {
      await this.sender.send({ to: email, ...mail, code });
    } catch (error) {
      // Do not make the user wait a minute for a mail that never left.
      await this.codes.delete(record.id);
      this.logger.error(
        `Email delivery failed: ${error instanceof Error ? error.name : 'unknown'}`,
      );
      throw new EmailDeliveryError();
    }

    // Opportunistic cleanup; failures must not affect the request.
    await this.codes
      .deleteCreatedBefore(new Date(now.getTime() - RETENTION_MS))
      .catch(() => undefined);
    return accepted;
  }

  private async assertCanSend(email: string, now: Date): Promise<void> {
    const last = await this.codes.lastCreatedAt(email);
    if (last) {
      const wait =
        OTP_RESEND_AFTER_SECONDS - (now.getTime() - last.getTime()) / 1000;
      if (wait > 0) throw new OtpRateLimitedError(Math.ceil(wait));
    }
    const recent = await this.codes.createdSince(
      email,
      new Date(now.getTime() - HOUR_MS),
    );
    if (recent.length >= OTP_MAX_SENDS_PER_HOUR) {
      // The window frees up when the oldest counted send leaves it.
      const oldest = recent[recent.length - OTP_MAX_SENDS_PER_HOUR]!;
      const wait = (oldest.getTime() + HOUR_MS - now.getTime()) / 1000;
      throw new OtpRateLimitedError(Math.max(1, Math.ceil(wait)));
    }
  }
}

@Injectable()
export class SignInWithEmailUseCase {
  private readonly reviewEmail: string | undefined;
  private readonly reviewCode: string | undefined;
  /** In-memory guess counter for the review account (no row to count on). */
  private reviewFailures: { count: number; resetAt: number } = {
    count: 0,
    resetAt: 0,
  };

  constructor(
    private readonly codes: EmailLoginCodeRepository,
    private readonly codec: OtpCodec,
    private readonly users: UserRepository,
    private readonly sessions: AuthSessionService,
    private readonly credits: CreditsService,
    config: ConfigService<Env, true>,
  ) {
    this.reviewEmail = config.get('REVIEW_LOGIN_EMAIL', { infer: true });
    this.reviewCode = config.get('REVIEW_LOGIN_CODE', { infer: true });
  }

  async execute(
    rawEmail: string,
    code: string,
    now: Date = new Date(),
  ): Promise<SignInResult> {
    const email = normalizeEmail(rawEmail);
    if (email === this.reviewEmail && this.reviewCode) {
      this.checkReviewCode(code, now);
    } else {
      await this.checkStoredCode(email, code, now);
    }
    const user = await this.users.upsertFromIdentity({
      provider: 'EMAIL',
      subject: email,
      email,
      name: null,
    });
    await this.credits.grantFree(user.id);
    return { user, tokens: await this.sessions.startSession(user.id) };
  }

  private checkReviewCode(code: string, now: Date): void {
    const t = now.getTime();
    if (t >= this.reviewFailures.resetAt) {
      this.reviewFailures = { count: 0, resetAt: t + OTP_TTL_SECONDS * 1000 };
    }
    if (this.reviewFailures.count >= OTP_MAX_ATTEMPTS) {
      throw new TooManyOtpAttemptsError();
    }
    if (!safeEqual(code, this.reviewCode!)) {
      this.reviewFailures.count += 1;
      if (this.reviewFailures.count >= OTP_MAX_ATTEMPTS) {
        throw new TooManyOtpAttemptsError();
      }
      throw new InvalidOtpCodeError(
        OTP_MAX_ATTEMPTS - this.reviewFailures.count,
      );
    }
  }

  private async checkStoredCode(
    email: string,
    code: string,
    now: Date,
  ): Promise<void> {
    const record = await this.codes.findActive(email);
    if (!record || record.expiresAt.getTime() <= now.getTime()) {
      throw new OtpCodeExpiredError();
    }
    // Count the guess first so parallel requests cannot exceed the limit.
    const attempts = await this.codes.claimAttempt(record.id, OTP_MAX_ATTEMPTS);
    if (attempts === null) throw new TooManyOtpAttemptsError();

    if (!this.codec.matches(email, code, record.codeHash)) {
      if (attempts >= OTP_MAX_ATTEMPTS) {
        await this.codes.consume(record.id);
        throw new TooManyOtpAttemptsError();
      }
      throw new InvalidOtpCodeError(OTP_MAX_ATTEMPTS - attempts);
    }
    // Single use: only one concurrent request can win the consume.
    if (!(await this.codes.consume(record.id))) throw new OtpCodeExpiredError();
  }
}
