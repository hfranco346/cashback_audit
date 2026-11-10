# Feature: claim-credits-refresh

## Objective
1. Implement the "Claim to the bank" screen from the design (`docs/cashback-audit-design/project/Reclamo.dc.html` + `-en`), previously marked future: a prefilled email the user can copy or open in their mail app.
2. Unlimited credits for specific accounts (owner: hfranco5232@gmail.com).
3. Verification status changes must refresh Home and History without pull-to-refresh.

## Why
User feedback (2026-11-09): could not find the prefilled claim; needs unlimited credits for own testing; Home/History stayed stale until pull-to-refresh.

## Contract
- Credits: `User.unlimitedCredits` boolean (default false). When true, the credits gate never blocks and no credit is consumed or refunded for that user; credit balance responses add `unlimited: true` (false otherwise); `GET /me` adds `unlimitedCredits`. Set by an operator (CLI/script or SQL), never by an API endpoint.
- Cards: optional `claimEmail` (email, nullable) on create/patch/get, used as the claim "To".
- Claim (mobile only, deterministic template, no AI): for UNDERPAID results. Email language selector (ES/EN, defaults to app language, independent), tone (formal / firm), To (card claimEmail, editable, saved back to the card), subject, body with bank/program name, card last 4, period, reported vs expected, per-category lines (rate, spend, purchases count, expected reward), total expected, user name; Copy and "Open in Mail" (mailto). Bank-provided names untranslated.
- Refresh: Home attention + History poll while any item is PROCESSING (every ~5 s, stop when none / screen not visible / app paused), refresh on app resume and when returning from verify/confirm/result flows.

## Constraints
- TDD off. Runners: apps/api `pnpm lint`, `pnpm build`, `pnpm test`, `pnpm test:e2e`; apps/mobile `dart format --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`.
- RDD off. Local commits on `main`; push after the owner approves.

## Tasks
- [x] C1 Backend: unlimitedCredits flag + gate/ledger bypass + balance/me fields + operator script; card claimEmail; tests; contract doc. Route: delegated.
- [ ] C2 Mobile: claim screen + entry from Result; unlimited credits UI; status auto-refresh in Home/History; tests. Route: delegated.
- [ ] C3 Deploy API, set unlimited for the owner in production, install builds on devices. Route: inline.

## Progress / evidence
- C1 (delegated, done): migration `20261110120000_unlimited_credits_card_claim_email` applied to dev DB; gate/reserve bypass in CreditsService; `unlimited` in GET /credits/me, `unlimitedCredits` in GET /me; card `claimEmail`; operator command `node --env-file=.env dist/cli/set-unlimited-credits.js <email> [on|off]` (docs/deploy.md); contract + changelog updated. Checks in apps/api: lint clean, build ok, test 347 passed, test:e2e 166 passed. Commit: feat(api) unlimited credits (see git log).
