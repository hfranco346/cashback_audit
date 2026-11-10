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
- [x] C2 Mobile: claim screen + entry from Result; unlimited credits UI; status auto-refresh in Home/History; tests. Route: delegated.
- [ ] C4 Align with the design exactly: onboarding prefilled Supermercados + Farmacia 7%; guided empty categories lets the user add several suggestions without leaving the guided view; offline History shows last-updated date (cache stores timestamp); change-category sheet title in Bodoni like the design. Route: delegated.
- [ ] C3 Deploy API, set unlimited for the owner in production, install builds on devices. Route: inline.

## Progress / evidence
- C1 (delegated, done): migration `20261110120000_unlimited_credits_card_claim_email` applied to dev DB; gate/reserve bypass in CreditsService; `unlimited` in GET /credits/me, `unlimitedCredits` in GET /me; card `claimEmail`; operator command `node --env-file=.env dist/cli/set-unlimited-credits.js <email> [on|off]` (docs/deploy.md); contract + changelog updated. Checks in apps/api: lint clean, build ok, test 347 passed, test:e2e 166 passed. Commit: feat(api) unlimited credits (see git log).
- C2 (delegated, done): commit be9a9c3 feat(mobile) claim screen (`features/claim`, `Routes.claim`, entry button `result-claim` on underpaid results only), `claimEmail` on cards (partial PATCH via `ClaimEmailRepository`), unlimited credits UI (Profile, Home pill, verify pill, credit history; `hasCredits` true when unlimited so the paywall is never pushed), `url_launcher` added. Second commit: auto refresh. Root cause of the stale Home/History: both tabs live in an `IndexedStack` (kept alive) and loaded once in `onReady`; Home only reloaded on app resume, nothing polled, and nothing reloaded when returning from verify/progress/confirm/result routes, so only pull-to-refresh updated them. Fix: `VerificationEvents` bus emitted by the repository (upload, confirm, seen, delete, analysis finished), a `routingCallback` that emits when the user comes back to `/home`, and `AutoRefresh` (5 s poll while any item is PROCESSING, only when the tab and route are visible and the app is in the foreground; refresh on resume, tab shown and events; no overlapping requests). Checks in apps/mobile: `flutter gen-l10n` ok, `dart format --set-exit-if-changed lib test` 0 changed, `flutter analyze` no issues, `flutter test` 596 passed.
