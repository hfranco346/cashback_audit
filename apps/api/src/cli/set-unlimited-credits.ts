import { pathToFileURL } from 'node:url';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../shared/prisma/generated/client.js';

/** The slice of the user table the operator command needs. */
export interface UnlimitedCreditsStore {
  /** Users whose email equals `email`, case-insensitively, any provider. */
  findUserIdsByEmail(email: string): Promise<string[]>;
  setUnlimited(ids: string[], value: boolean): Promise<void>;
}

export const USAGE =
  'Usage: node --env-file=.env dist/cli/set-unlimited-credits.js <email> [on|off]';

export type ParsedArgs =
  { ok: true; email: string; value: boolean } | { ok: false; error: string };

export function parseArgs(args: string[]): ParsedArgs {
  const [rawEmail, mode = 'on', ...extra] = args;
  const email = rawEmail?.trim().toLowerCase();
  if (!email || !email.includes('@') || extra.length > 0) {
    return { ok: false, error: USAGE };
  }
  if (mode !== 'on' && mode !== 'off') {
    return { ok: false, error: `Unknown mode "${mode}". ${USAGE}` };
  }
  return { ok: true, email, value: mode === 'on' };
}

/** Sets the flag on every user with that email; returns their ids. */
export async function setUnlimitedCredits(
  store: UnlimitedCreditsStore,
  email: string,
  value: boolean,
): Promise<string[]> {
  const ids = await store.findUserIdsByEmail(email.trim().toLowerCase());
  if (ids.length > 0) await store.setUnlimited(ids, value);
  return ids;
}

export function prismaStore(prisma: PrismaClient): UnlimitedCreditsStore {
  return {
    async findUserIdsByEmail(email) {
      const rows = await prisma.user.findMany({
        where: { email: { equals: email, mode: 'insensitive' } },
        select: { id: true },
      });
      return rows.map((r) => r.id);
    },
    async setUnlimited(ids, value) {
      await prisma.user.updateMany({
        where: { id: { in: ids } },
        data: { unlimitedCredits: value },
      });
    },
  };
}

export async function main(argv: string[]): Promise<number> {
  const parsed = parseArgs(argv);
  if (!parsed.ok) {
    console.error(parsed.error);
    return 2;
  }
  const url = process.env.DATABASE_URL;
  if (!url) {
    console.error('DATABASE_URL is not set (use --env-file=.env).');
    return 2;
  }
  const u = new URL(url);
  const schema = u.searchParams.get('schema') ?? undefined;
  u.searchParams.delete('schema');
  const prisma = new PrismaClient({
    adapter: new PrismaPg(
      { connectionString: u.toString() },
      schema ? { schema } : undefined,
    ),
  });
  try {
    const ids = await setUnlimitedCredits(
      prismaStore(prisma),
      parsed.email,
      parsed.value,
    );
    if (ids.length === 0) {
      console.error(`No user found with email ${parsed.email}.`);
      return 1;
    }
    console.log(
      `unlimitedCredits=${parsed.value ? 'on' : 'off'} for ${ids.length} user(s):`,
    );
    for (const id of ids) console.log(id);
    return 0;
  } finally {
    await prisma.$disconnect();
  }
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  process.exitCode = await main(process.argv.slice(2));
}
