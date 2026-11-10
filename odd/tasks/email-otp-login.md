# Feature: email-otp-login (sign in with a 6-digit code sent by email)

## Objective
First release signs in with an email one-time code instead of Google/Apple (no Google Cloud / Apple setup needed). Google/Apple code stays but its buttons are hidden while their client IDs are not configured.

## Why
Lowest-friction option that needs no third-party identity setup; a code (not a magic link) avoids Universal/App Links, works when the email is opened on another device, and is simpler for store review.

## Contract
- `POST /auth/email/start` `{ email, locale? ("es"|"en") }` → `202 { expiresInSeconds: 600, resendAfterSeconds: 60 }`. Always 202 for valid emails (no account enumeration). `429 TOO_MANY_REQUESTS` with `retryAfterSeconds` when resend/rate limits hit.
- `POST /auth/email/verify` `{ email, code }` → `200` with the same token payload as the existing Google/Apple sign-in. Errors: `400 INVALID_CODE { attemptsLeft }`, `410 CODE_EXPIRED` (also when no active code), `429 TOO_MANY_ATTEMPTS` (code burned after 5 failures).
- Codes: 6 digits from a CSPRNG, stored hashed (HMAC-SHA256 with a server secret), single use, 10 min TTL, max 5 attempts, resend after 60 s, max 5 sends per email per hour, per-IP throttle.
- Email normalized (trim + lowercase). User identity: `AuthProvider.EMAIL`; a user is found/created by verified email so Google/Apple can link later.
- Store review: optional `REVIEW_LOGIN_EMAIL` + `REVIEW_LOGIN_CODE` env pair accepts a fixed code for that single address (no email sent).
- Email delivery behind an `EmailSender` port. Dev/test: log adapter (prints the code only when NODE_ENV != production). Production adapter: pending provider decision.
- Email copy in ES/EN (locale from request, default es), subject "Tu código de Cashback Audit: 123456" / "Your Cashback Audit code: 123456", plain text + simple HTML, no links.

## Constraints
- TDD mode: off. Runners: apps/api `pnpm lint`, `pnpm build`, `pnpm test`, `pnpm test:e2e`; apps/mobile `dart format --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`.
- RDD off. Local work-unit commits on `main`; push only after the user approves.

## Tasks
- [x] E1 Backend: OTP module (start/verify, hashing, limits, review account, EmailSender port + log adapter), Prisma migration, tests, contract doc. Route: delegated.
- [ ] E2 Mobile: email + code screens (login and onboarding "create account" step), autofill one-time code, resend countdown, error states, hide Google/Apple when not configured, ES/EN, tests. Route: delegated.
- [ ] E3 Production email provider adapter + DNS (SPF/DKIM) + prod env + deploy. Route: inline after provider decision.

## Progress / evidence
- E1 (delegated writer): migration `20261110003132_email_otp_login`; `GET /auth/providers`, `POST /auth/email/start|verify`; new env `OTP_HMAC_SECRET`, `EMAIL_FROM`, `EMAIL_PROVIDER`, `REVIEW_LOGIN_EMAIL/CODE`, `OTP_THROTTLE_LIMIT`; contract in `docs/api-contract.md` (section 3, 11, 12). Checks in apps/api: `pnpm lint` clean, `pnpm build` ok, `pnpm test` 339 passed, `pnpm test:e2e` 161 passed. Commit: see `git log` (feat(api): email one-time code sign-in).
