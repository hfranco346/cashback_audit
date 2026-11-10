import { ConfigService } from '@nestjs/config';
import type { CreditsService } from '../../credits/application/credits.service.js';
import type { UserRepository } from '../../users/domain/user.repository.js';
import type {
  EmailLoginCodeRecord,
  EmailLoginCodeRepository,
} from '../domain/email-login-code.repository.js';
import type { EmailSender, OutgoingEmail } from '../domain/email-sender.js';
import type { AuthSessionService } from './auth-session.service.js';
import {
  OtpCodec,
  SignInWithEmailUseCase,
  StartEmailLoginUseCase,
} from './email-login.use-cases.js';

class MemoryCodes implements EmailLoginCodeRepository {
  rows: EmailLoginCodeRecord[] = [];
  private seq = 0;
  async findActive(email: string) {
    return (
      [...this.rows]
        .reverse()
        .find((r) => r.email === email && !r.consumedAt) ?? null
    );
  }
  async createdSince(email: string, since: Date) {
    return this.rows
      .filter((r) => r.email === email && r.createdAt > since)
      .map((r) => r.createdAt);
  }
  async lastCreatedAt(email: string) {
    const mine = this.rows.filter((r) => r.email === email);
    return mine.at(-1)?.createdAt ?? null;
  }
  async replaceActive(data: {
    email: string;
    codeHash: string;
    expiresAt: Date;
  }) {
    for (const r of this.rows)
      if (r.email === data.email && !r.consumedAt) r.consumedAt = new Date();
    const row: EmailLoginCodeRecord = {
      id: String(++this.seq),
      ...data,
      attempts: 0,
      consumedAt: null,
      createdAt: this.now(),
    };
    this.rows.push(row);
    return row;
  }
  now = () => new Date();
  async claimAttempt(id: string, max: number) {
    const r = this.rows.find((x) => x.id === id);
    if (!r || r.consumedAt || r.attempts >= max) return null;
    return ++r.attempts;
  }
  async consume(id: string) {
    const r = this.rows.find((x) => x.id === id);
    if (!r || r.consumedAt) return false;
    r.consumedAt = new Date();
    return true;
  }
  async deleteCreatedBefore() {
    return 0;
  }
  async delete(id: string) {
    this.rows = this.rows.filter((r) => r.id !== id);
  }
}

function setup(extra: Record<string, string> = {}) {
  const config = new ConfigService({
    OTP_HMAC_SECRET: 's'.repeat(32),
    ...extra,
  }) as never;
  const codes = new MemoryCodes();
  const sent: OutgoingEmail[] = [];
  const sender = { send: async (m: OutgoingEmail) => void sent.push(m) };
  const codec = new OtpCodec(config);
  const users = {
    upsertFromIdentity: async (i: { subject: string }) => ({
      id: `u-${i.subject}`,
    }),
  };
  const sessions = { startSession: async () => ({ accessToken: 'a' }) };
  const credits = { grantFree: async () => undefined };
  const start = new StartEmailLoginUseCase(
    codes,
    sender as unknown as EmailSender,
    codec,
    config,
  );
  const verify = new SignInWithEmailUseCase(
    codes,
    codec,
    users as unknown as UserRepository,
    sessions as unknown as AuthSessionService,
    credits as unknown as CreditsService,
    config,
  );
  const lastCode = () => /\b(\d{6})\b/.exec(sent.at(-1)!.text)![1]!;
  return { codes, sent, start, verify, lastCode, codec };
}

describe('email sign-in use cases', () => {
  it('stores only an HMAC, never the code', async () => {
    const { start, codes, lastCode } = setup();
    await start.execute(' Ana@Example.com ');
    const code = lastCode();
    expect(codes.rows[0]!.email).toBe('ana@example.com');
    expect(codes.rows[0]!.codeHash).not.toContain(code);
    expect(codes.rows[0]!.codeHash).toMatch(/^[0-9a-f]{64}$/);
  });

  it('hash is bound to the address', () => {
    const { codec } = setup();
    expect(codec.hash('a@x.com', '123456')).not.toBe(
      codec.hash('b@x.com', '123456'),
    );
  });

  it('generates 6-digit codes, zero padded', () => {
    const { codec } = setup();
    for (let i = 0; i < 200; i++) expect(codec.generate()).toMatch(/^\d{6}$/);
  });

  it('sends Spanish by default and English on request', async () => {
    const { start, sent } = setup();
    await start.execute('a@x.com');
    expect(sent[0]!.subject).toMatch(/^Tu código de Cashback Audit: \d{6}$/);
    const t = new Date(Date.now() + 61_000);
    await start.execute('a@x.com', 'en', null, t);
    expect(sent[1]!.subject).toMatch(/^Your Cashback Audit code: \d{6}$/);
    expect(sent[1]!.html).not.toContain('http');
  });

  it('blocks a resend before 60 s with retryAfterSeconds', async () => {
    const { start } = setup();
    await start.execute('a@x.com');
    await expect(start.execute('a@x.com')).rejects.toMatchObject({
      code: 'TOO_MANY_REQUESTS',
      details: { retryAfterSeconds: expect.any(Number) },
    });
  });

  it('caps sends per hour', async () => {
    const { start, codes } = setup();
    const t0 = Date.now();
    for (let i = 0; i < 5; i++) {
      codes.now = () => new Date(t0 + i * 61_000);
      await start.execute('a@x.com', 'es', null, new Date(t0 + i * 61_000));
    }
    const now = new Date(t0 + 5 * 61_000);
    await expect(
      start.execute('a@x.com', 'es', null, now),
    ).rejects.toMatchObject({
      code: 'TOO_MANY_REQUESTS',
      details: { retryAfterSeconds: expect.any(Number) },
    });
  });

  it('verifies once: the second use finds no active code', async () => {
    const { start, verify, lastCode } = setup();
    await start.execute('a@x.com');
    const code = lastCode();
    await expect(verify.execute('A@x.com', code)).resolves.toBeDefined();
    await expect(verify.execute('a@x.com', code)).rejects.toMatchObject({
      code: 'CODE_EXPIRED',
    });
  });

  it('counts wrong guesses and burns the code at 5', async () => {
    const { start, verify, lastCode } = setup();
    await start.execute('a@x.com');
    const good = lastCode();
    const bad = good === '000000' ? '000001' : '000000';
    for (const left of [4, 3, 2, 1]) {
      await expect(verify.execute('a@x.com', bad)).rejects.toMatchObject({
        code: 'INVALID_CODE',
        details: { attemptsLeft: left },
      });
    }
    await expect(verify.execute('a@x.com', bad)).rejects.toMatchObject({
      code: 'TOO_MANY_ATTEMPTS',
    });
    await expect(verify.execute('a@x.com', good)).rejects.toMatchObject({
      code: 'CODE_EXPIRED',
    });
  });

  it('rejects expired codes', async () => {
    const { start, verify, lastCode } = setup();
    await start.execute('a@x.com');
    const later = new Date(Date.now() + 601_000);
    await expect(
      verify.execute('a@x.com', lastCode(), later),
    ).rejects.toMatchObject({ code: 'CODE_EXPIRED' });
  });

  it('a new code invalidates the previous one', async () => {
    const { start, verify, lastCode } = setup();
    await start.execute('a@x.com');
    const first = lastCode();
    await start.execute('a@x.com', 'es', null, new Date(Date.now() + 61_000));
    const second = lastCode();
    if (first !== second) {
      await expect(verify.execute('a@x.com', first)).rejects.toMatchObject({
        code: 'INVALID_CODE',
      });
    }
    await expect(verify.execute('a@x.com', second)).resolves.toBeDefined();
  });

  it('removes the code when delivery fails so the user can retry', async () => {
    const { start, codes } = setup();
    const failing = new StartEmailLoginUseCase(
      codes,
      {
        send: async () => {
          throw new Error('smtp down');
        },
      } as unknown as EmailSender,
      new OtpCodec(
        new ConfigService({ OTP_HMAC_SECRET: 's'.repeat(32) }) as never,
      ),
      new ConfigService({}) as never,
    );
    await expect(failing.execute('a@x.com')).rejects.toMatchObject({
      code: 'EMAIL_DELIVERY_FAILED',
    });
    expect(codes.rows).toHaveLength(0);
    void start;
  });

  describe('review account', () => {
    const review = {
      REVIEW_LOGIN_EMAIL: 'review@example.com',
      REVIEW_LOGIN_CODE: '424242',
    };

    it('sends nothing and accepts the fixed code', async () => {
      const { start, verify, sent, codes } = setup(review);
      await start.execute('Review@example.com');
      expect(sent).toHaveLength(0);
      expect(codes.rows).toHaveLength(0);
      await expect(
        verify.execute('review@example.com', '424242'),
      ).resolves.toBeDefined();
      // reusable, unlike normal codes
      await expect(
        verify.execute('review@example.com', '424242'),
      ).resolves.toBeDefined();
    });

    it('limits wrong guesses', async () => {
      const { verify } = setup(review);
      for (let i = 0; i < 4; i++)
        await expect(
          verify.execute('review@example.com', '000000'),
        ).rejects.toMatchObject({ code: 'INVALID_CODE' });
      await expect(
        verify.execute('review@example.com', '000000'),
      ).rejects.toMatchObject({ code: 'TOO_MANY_ATTEMPTS' });
    });

    it('does not open other addresses', async () => {
      const { verify } = setup(review);
      await expect(
        verify.execute('other@example.com', '424242'),
      ).rejects.toMatchObject({ code: 'CODE_EXPIRED' });
    });
  });
});
