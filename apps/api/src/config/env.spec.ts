import { parseDurationSeconds, validateEnv } from './env.js';

const base = {
  DATABASE_URL: 'postgresql://x',
  JWT_ACCESS_SECRET: 'a'.repeat(32),
  JWT_REFRESH_SECRET: 'b'.repeat(32),
};

describe('validateEnv', () => {
  it('applies defaults', () => {
    const env = validateEnv(base);
    expect(env.ANTHROPIC_MODEL).toBe('claude-sonnet-5-5');
    expect(env.REVENUECAT_ENTITLEMENT_ID).toBe('pro');
    expect(env.SUBSCRIPTION_GATE_ENABLED).toBe(true);
    expect(env.PORT).toBe(3000);
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
