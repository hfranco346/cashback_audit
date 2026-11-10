import { TEST_DATABASE_URL } from './test-env.js';

process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = TEST_DATABASE_URL;
process.env.JWT_ACCESS_SECRET = 'test-access-secret-test-access-secret-1234';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-test-refresh-secret-1234';
process.env.GOOGLE_CLIENT_IDS = 'test-google-client';
process.env.APPLE_BUNDLE_ID = 'com.example.cashbackaudit';
process.env.ANTHROPIC_API_KEY = 'test-key';
process.env.REVENUECAT_WEBHOOK_AUTH = 'test-webhook-secret';
process.env.THROTTLE_LIMIT = '100000';
process.env.VERIFICATION_THROTTLE_LIMIT = '100000';
process.env.CREDITS_GATE_ENABLED = 'false';
process.env.OTP_THROTTLE_LIMIT = '100000';
