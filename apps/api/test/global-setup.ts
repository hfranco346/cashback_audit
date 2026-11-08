import { execSync } from 'node:child_process';
import { TEST_DATABASE_URL } from './test-env.js';

/** Applies all migrations to the dedicated e2e database. */
export default function setup() {
  execSync('pnpm exec prisma migrate deploy', {
    stdio: 'pipe',
    env: { ...process.env, DATABASE_URL: TEST_DATABASE_URL },
  });
}
