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
    expect(env.SUBSCRIPTION_GATE_ENABLED).toBe(true);
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

  it('parses the gate flag', () => {
    expect(
      validateEnv({ ...base, SUBSCRIPTION_GATE_ENABLED: 'false' })
        .SUBSCRIPTION_GATE_ENABLED,
    ).toBe(false);
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
