import { parseDurationSeconds, validateEnv } from './env.js';

const base = {
  DATABASE_URL: 'postgresql://x',
  JWT_ACCESS_SECRET: 'a'.repeat(32),
  JWT_REFRESH_SECRET: 'b'.repeat(32),
};

describe('validateEnv', () => {
  it('applies defaults', () => {
    const env = validateEnv(base);
    expect(env.ANTHROPIC_EXTRACTION_MODEL).toBe('claude-sonnet-5-5');
    expect(env.ANTHROPIC_CLASSIFICATION_MODEL).toBe('claude-haiku-5-5');
    expect(env.REVENUECAT_ENTITLEMENT_ID).toBe('pro');
    expect(env.CREDITS_GATE_ENABLED).toBe(true);
    expect(env.FREE_CREDITS).toBe(1);
    expect(env.PLAN_CREDITS_PER_PERIOD).toBe(5);
    expect(env.CREDIT_PACKS).toEqual({ credits_3: 3, credits_10: 10 });
    expect(env.PORT).toBe(3000);
  });

  describe('classification threshold', () => {
    it('defaults to 0.7 and accepts 0-1', () => {
      expect(validateEnv(base).CLASSIFICATION_MIN_CONFIDENCE).toBe(0.7);
      expect(
        validateEnv({ ...base, CLASSIFICATION_MIN_CONFIDENCE: '0.85' })
          .CLASSIFICATION_MIN_CONFIDENCE,
      ).toBe(0.85);
    });

    it.each(['1.5', '-0.1', 'high'])('rejects %s', (value) => {
      expect(() =>
        validateEnv({ ...base, CLASSIFICATION_MIN_CONFIDENCE: value }),
      ).toThrow(/CLASSIFICATION_MIN_CONFIDENCE/);
    });
  });

  describe('model routing', () => {
    it('uses the explicit per-task models', () => {
      const env = validateEnv({
        ...base,
        ANTHROPIC_EXTRACTION_MODEL: 'claude-opus-5-5',
        ANTHROPIC_CLASSIFICATION_MODEL: 'claude-sonnet-5-5',
      });
      expect(env.ANTHROPIC_EXTRACTION_MODEL).toBe('claude-opus-5-5');
      expect(env.ANTHROPIC_CLASSIFICATION_MODEL).toBe('claude-sonnet-5-5');
    });

    it('falls back to the deprecated ANTHROPIC_MODEL for extraction only', () => {
      const env = validateEnv({ ...base, ANTHROPIC_MODEL: 'claude-opus-5' });
      expect(env.ANTHROPIC_EXTRACTION_MODEL).toBe('claude-opus-5');
      expect(env.ANTHROPIC_CLASSIFICATION_MODEL).toBe('claude-haiku-5-5');
    });

    it('lets ANTHROPIC_EXTRACTION_MODEL win over the deprecated variable', () => {
      const env = validateEnv({
        ...base,
        ANTHROPIC_MODEL: 'claude-opus-5',
        ANTHROPIC_EXTRACTION_MODEL: 'claude-sonnet-5',
      });
      expect(env.ANTHROPIC_EXTRACTION_MODEL).toBe('claude-sonnet-5');
    });

    it('treats empty values as unset', () => {
      const env = validateEnv({
        ...base,
        ANTHROPIC_EXTRACTION_MODEL: '',
        ANTHROPIC_CLASSIFICATION_MODEL: '  ',
        ANTHROPIC_MODEL: '',
      });
      expect(env.ANTHROPIC_EXTRACTION_MODEL).toBe('claude-sonnet-5-5');
      expect(env.ANTHROPIC_CLASSIFICATION_MODEL).toBe('claude-haiku-5-5');
    });

    it.each(['claude sonnet', 'bad;id', '-x'])(
      'rejects the invalid model id %j',
      (value) => {
        expect(() =>
          validateEnv({ ...base, ANTHROPIC_CLASSIFICATION_MODEL: value }),
        ).toThrow(/ANTHROPIC_CLASSIFICATION_MODEL/);
        expect(() =>
          validateEnv({ ...base, ANTHROPIC_EXTRACTION_MODEL: value }),
        ).toThrow(/ANTHROPIC_EXTRACTION_MODEL/);
      },
    );
  });

  describe('credits', () => {
    it('parses the gate flag; the old name is an alias used only when the new one is unset', () => {
      expect(
        validateEnv({ ...base, CREDITS_GATE_ENABLED: 'false' })
          .CREDITS_GATE_ENABLED,
      ).toBe(false);
      expect(
        validateEnv({ ...base, SUBSCRIPTION_GATE_ENABLED: 'false' })
          .CREDITS_GATE_ENABLED,
      ).toBe(false);
      expect(
        validateEnv({
          ...base,
          CREDITS_GATE_ENABLED: 'true',
          SUBSCRIPTION_GATE_ENABLED: 'false',
        }).CREDITS_GATE_ENABLED,
      ).toBe(true);
      expect(() =>
        validateEnv({ ...base, CREDITS_GATE_ENABLED: 'maybe' }),
      ).toThrow(/CREDITS_GATE_ENABLED/);
    });

    it('parses CREDIT_PACKS into a product -> credits map', () => {
      expect(
        validateEnv({ ...base, CREDIT_PACKS: ' pack.a:2 , pack_b:50 ' })
          .CREDIT_PACKS,
      ).toEqual({ 'pack.a': 2, pack_b: 50 });
      expect(validateEnv({ ...base, CREDIT_PACKS: '' }).CREDIT_PACKS).toEqual(
        {},
      );
    });

    it.each([
      'credits_3',
      'credits_3:x',
      'credits_3:0',
      ':3',
      'a:1,a:2',
      'a:1:2',
      'a b:3',
      'a:1001',
    ])('rejects the invalid pack list %j', (value) => {
      expect(() => validateEnv({ ...base, CREDIT_PACKS: value })).toThrow(
        /CREDIT_PACKS/,
      );
    });

    it('validates the credit amounts', () => {
      expect(
        validateEnv({
          ...base,
          FREE_CREDITS: '0',
          PLAN_CREDITS_PER_PERIOD: '10',
        }),
      ).toMatchObject({ FREE_CREDITS: 0, PLAN_CREDITS_PER_PERIOD: 10 });
      expect(() => validateEnv({ ...base, FREE_CREDITS: '-1' })).toThrow(
        /FREE_CREDITS/,
      );
    });
  });

  it('fails with a readable message when required values are missing', () => {
    expect(() => validateEnv({})).toThrow(/DATABASE_URL/);
  });

  it('rejects short JWT secrets', () => {
    expect(() => validateEnv({ ...base, JWT_ACCESS_SECRET: 'short' })).toThrow(
      /JWT_ACCESS_SECRET/,
    );
  });
});

describe('validateEnv email sign-in', () => {
  it('defaults: dev secret, log provider, default sender, no review account', () => {
    const env = validateEnv(base);
    expect(env.OTP_HMAC_SECRET.length).toBeGreaterThanOrEqual(32);
    expect(env.EMAIL_PROVIDER).toBe('log');
    expect(env.EMAIL_FROM).toBe('Cashback Audit <no-reply@neargps.net>');
    expect(env.REVIEW_LOGIN_EMAIL).toBeUndefined();
  });

  it('requires OTP_HMAC_SECRET in production', () => {
    expect(() => validateEnv({ ...base, NODE_ENV: 'production' })).toThrow(
      /OTP_HMAC_SECRET/,
    );
    expect(() =>
      validateEnv({
        ...base,
        NODE_ENV: 'production',
        OTP_HMAC_SECRET: 'short',
      }),
    ).toThrow(/OTP_HMAC_SECRET/);
    expect(
      validateEnv({
        ...base,
        NODE_ENV: 'production',
        OTP_HMAC_SECRET: 'c'.repeat(32),
      }).OTP_HMAC_SECRET,
    ).toBe('c'.repeat(32));
  });

  it('review login needs both email and a 6-digit code', () => {
    expect(() =>
      validateEnv({ ...base, REVIEW_LOGIN_EMAIL: 'r@example.com' }),
    ).toThrow(/together/);
    expect(() => validateEnv({ ...base, REVIEW_LOGIN_CODE: '123456' })).toThrow(
      /together/,
    );
    expect(() =>
      validateEnv({
        ...base,
        REVIEW_LOGIN_EMAIL: 'r@example.com',
        REVIEW_LOGIN_CODE: '12345',
      }),
    ).toThrow(/6 digits/);
    const env = validateEnv({
      ...base,
      REVIEW_LOGIN_EMAIL: ' Review@Example.com ',
      REVIEW_LOGIN_CODE: '123456',
    });
    expect(env.REVIEW_LOGIN_EMAIL).toBe('review@example.com');
  });
});

describe('parseDurationSeconds', () => {
  it.each([
    ['45', 45],
    ['45s', 45],
    ['15m', 900],
    ['2h', 7200],
    ['30d', 2592000],
  ])('parses %s', (input, expected) => {
    expect(parseDurationSeconds(input)).toBe(expected);
  });

  it('rejects garbage', () => {
    expect(() => parseDurationSeconds('abc')).toThrow();
  });
});
