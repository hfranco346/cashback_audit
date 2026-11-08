import 'dotenv/config';

export const TEST_DATABASE_URL =
  process.env.TEST_DATABASE_URL ??
  'postgresql://cashback:cashback@localhost:5433/cashback_audit_test?schema=public';
