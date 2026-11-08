import { z } from 'zod';

const booleanString = z
  .enum(['true', 'false'])
  .transform((value) => value === 'true');

export const DEFAULT_EXTRACTION_MODEL = 'claude-sonnet-5-5';
export const DEFAULT_CLASSIFICATION_MODEL = 'claude-haiku-5-5';

/** Empty values (`KEY=`) count as unset; ids are plain tokens, no spaces. */
const modelId = z.preprocess(
  (value) =>
    typeof value === 'string' && value.trim() === '' ? undefined : value,
  z
    .string()
    .trim()
    .regex(
      /^[A-Za-z0-9][A-Za-z0-9._:/-]{0,99}$/,
      'must be a model id such as claude-sonnet-5-5',
    )
    .optional(),
);

const baseSchema = z.object({
  NODE_ENV: z
    .enum(['development', 'test', 'production'])
    .default('development'),
  PORT: z.coerce.number().int().positive().default(3000),
  DATABASE_URL: z.string().min(1, 'DATABASE_URL is required'),

  JWT_ACCESS_SECRET: z.string().min(32, 'JWT_ACCESS_SECRET needs >= 32 chars'),
  JWT_REFRESH_SECRET: z
    .string()
    .min(32, 'JWT_REFRESH_SECRET needs >= 32 chars'),
  /** Duration such as `15m`, `1h`, `30d` or a number of seconds. */
  JWT_ACCESS_TTL: z.string().default('15m'),
  JWT_REFRESH_TTL: z.string().default('30d'),

  /** Comma separated list of OAuth client IDs (iOS, Android, web). */
  GOOGLE_CLIENT_IDS: z.string().default(''),
  /** Expected `aud` claim of Apple identity tokens (the iOS bundle ID). */
  APPLE_BUNDLE_ID: z.string().default(''),

  ANTHROPIC_API_KEY: z.string().default(''),
  /** Model used to read the statement PDF. */
  ANTHROPIC_EXTRACTION_MODEL: modelId,
  /** Model used for merchant/category classification (cheap and fast). */
  ANTHROPIC_CLASSIFICATION_MODEL: modelId,
  /** @deprecated Fallback for ANTHROPIC_EXTRACTION_MODEL only. */
  ANTHROPIC_MODEL: modelId,

  /** Classifier results below this confidence (0-1) are ignored. */
  CLASSIFICATION_MIN_CONFIDENCE: z.coerce.number().min(0).max(1).default(0.7),

  REVENUECAT_WEBHOOK_AUTH: z.string().default(''),
  REVENUECAT_ENTITLEMENT_ID: z.string().default('pro'),
  SUBSCRIPTION_GATE_ENABLED: booleanString.default(true),

  THROTTLE_TTL_SECONDS: z.coerce.number().int().positive().default(60),
  THROTTLE_LIMIT: z.coerce.number().int().positive().default(120),
  VERIFICATION_THROTTLE_LIMIT: z.coerce.number().int().positive().default(5),
});

/**
 * Resolves the per-task models: extraction = ANTHROPIC_EXTRACTION_MODEL, else
 * the deprecated ANTHROPIC_MODEL, else the default; classification =
 * ANTHROPIC_CLASSIFICATION_MODEL, else the default.
 */
export const envSchema = baseSchema.transform((env) => ({
  ...env,
  ANTHROPIC_EXTRACTION_MODEL:
    env.ANTHROPIC_EXTRACTION_MODEL ??
    env.ANTHROPIC_MODEL ??
    DEFAULT_EXTRACTION_MODEL,
  ANTHROPIC_CLASSIFICATION_MODEL:
    env.ANTHROPIC_CLASSIFICATION_MODEL ?? DEFAULT_CLASSIFICATION_MODEL,
}));

export type Env = z.infer<typeof envSchema>;

/** Used by `ConfigModule.forRoot({ validate })`; throws with a readable list. */
export function validateEnv(raw: Record<string, unknown>): Env {
  const result = envSchema.safeParse(raw);
  if (!result.success) {
    const details = result.error.issues
      .map((issue) => `  - ${issue.path.join('.')}: ${issue.message}`)
      .join('\n');
    throw new Error(`Invalid environment configuration:\n${details}`);
  }
  return result.data;
}

/** Parses `15m`, `2h`, `30d`, `45s` or plain seconds into seconds. */
export function parseDurationSeconds(value: string): number {
  const match = /^(\d+)\s*(s|m|h|d)?$/.exec(value.trim());
  if (!match) {
    throw new Error(`Invalid duration "${value}" (use e.g. 15m, 12h, 30d)`);
  }
  const amount = Number(match[1]);
  const unit = match[2] ?? 's';
  const multiplier = { s: 1, m: 60, h: 3600, d: 86400 }[unit] as number;
  return amount * multiplier;
}
