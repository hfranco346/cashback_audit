# Cashback Audit API

NestJS + Prisma + Postgres backend. Users upload a credit-card statement PDF;
Claude extracts the transactions and the reward reported by the bank; the API
computes the reward the card should have earned from the user's rules and
categories, and stores a verdict.

The HTTP contract for client developers is in
[`../../docs/api-contract.md`](../../docs/api-contract.md).

## Requirements

- Node 24, pnpm 10
- Docker (for Postgres 16)

## Quick start

```bash
# from the repository root: Postgres on localhost:5433 (dev + test databases)
docker compose up -d

cd apps/api
cp .env.example .env        # then edit the secrets, see "Configuration"
pnpm install                # also runs `prisma generate`
pnpm db:deploy              # applies migrations (use `pnpm db:migrate` while developing schema changes)
pnpm start:dev              # http://localhost:3000/api/v1/health  and  /docs (Swagger)
```

Set `SUBSCRIPTION_GATE_ENABLED=false` in `.env` to try `POST /verifications`
without a RevenueCat subscription.

## Scripts

| Command | What it does |
| --- | --- |
| `pnpm build` | Compile to `dist/` |
| `pnpm start:dev` / `pnpm start:prod` | Run with watch / run the compiled build |
| `pnpm lint` | oxlint (type-aware) |
| `pnpm format` / `pnpm format:check` | Prettier |
| `pnpm test` | Unit tests (Vitest, no database needed) |
| `pnpm test:e2e` | End-to-end tests against the docker Postgres `cashback_audit_test` database; migrations are applied automatically. Token verifiers, `StatementExtractor` and `MerchantClassifier` are stubbed, so no Google/Apple/Anthropic access is needed |
| `pnpm db:migrate` | `prisma migrate dev` (create + apply a migration) |
| `pnpm db:deploy` | `prisma migrate deploy` (apply existing migrations) |

The Prisma client is generated into `src/shared/prisma/generated` (git-ignored)
by `postinstall`; run `pnpm db:generate` after editing `prisma/schema.prisma`.

## Configuration

All variables are validated at startup (`src/config/env.ts`); see
[`.env.example`](.env.example) for the full list with comments.

| Variable | Notes |
| --- | --- |
| `DATABASE_URL` | Postgres connection string |
| `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET` | >= 32 chars each, different values. `openssl rand -base64 48` |
| `JWT_ACCESS_TTL`, `JWT_REFRESH_TTL` | `15m`, `12h`, `30d` or seconds. Defaults 15m / 30d |
| `GOOGLE_CLIENT_IDS` | Comma separated OAuth client IDs (iOS, Android, web) accepted as the token audience |
| `APPLE_BUNDLE_ID` | Audience of Apple identity tokens (the iOS bundle ID) |
| `ANTHROPIC_API_KEY` | Claude API key; without it verification returns 503 |
| `ANTHROPIC_EXTRACTION_MODEL` | Model that reads the statement PDF. Default `claude-sonnet-5-5` |
| `ANTHROPIC_CLASSIFICATION_MODEL` | Model that classifies merchants/categories. Default `claude-haiku-5-5` |
| `CLASSIFICATION_MIN_CONFIDENCE` | Minimum classifier confidence (0-1) to accept a category/merchant match. Default `0.7` |
| `ANTHROPIC_MODEL` | Deprecated; fallback for `ANTHROPIC_EXTRACTION_MODEL` only when that one is unset |
| `REVENUECAT_WEBHOOK_AUTH` | Shared secret; RevenueCat sends it verbatim in the `Authorization` header |
| `REVENUECAT_ENTITLEMENT_ID` | Default `pro` |
| `SUBSCRIPTION_GATE_ENABLED` | `true` (default) / `false` for local dev |
| `THROTTLE_*`, `VERIFICATION_THROTTLE_LIMIT` | Rate limits (default 120/min; 5/min for verifications) |

Missing optional credentials fail closed: with no `GOOGLE_CLIENT_IDS` /
`APPLE_BUNDLE_ID` sign-in returns 503, with no `ANTHROPIC_API_KEY` verification
returns 503, and with no `REVENUECAT_WEBHOOK_AUTH` every webhook call is rejected.

## Architecture

Hexagonal, one folder per feature under `src/`:

```
src/<feature>/
  domain/           pure types, rules and ports (abstract classes) - no Nest/Prisma imports
  application/      use cases (orchestrate ports)
  infrastructure/   Prisma repositories, controllers + DTOs, Claude/Google/Apple/jose adapters
```

Features: `auth`, `users`, `cards`, `categories` (categories + merchants),
`verifications`, `subscriptions`; shared pieces in `src/shared`
(Prisma service, `DomainError` + global exception filter, throttling, decimal
validation). The reward maths lives in
`src/verifications/domain/reward-calculator.ts` and the deterministic merchant
matcher in `merchant-matcher.ts`.

Ports that tests replace: `GoogleIdTokenVerifier`, `AppleIdTokenVerifier`,
`StatementExtractor`, `MerchantClassifier`.

## Manual setup you still need to do

These need accounts/consoles that cannot be automated:

1. **Anthropic**: create an API key at <https://console.anthropic.com> and set
   `ANTHROPIC_API_KEY`. The statement PDF is sent to Anthropic for analysis;
   mention that in your privacy policy.
2. **Google Sign-In**: in Google Cloud Console create OAuth client IDs (iOS,
   Android, and a *web* client - the web client ID is what the Flutter
   `google_sign_in` plugin uses as `serverClientId` to obtain an ID token).
   Put every client ID you expect as an `aud` into `GOOGLE_CLIENT_IDS`.
3. **Sign in with Apple**: enable the capability for the app ID in the Apple
   Developer portal and set `APPLE_BUNDLE_ID` to the iOS bundle ID (the audience
   of the identity token). Sign in with Apple through a Services ID (web or
   Android) would need its own audience and is not supported in v1.
4. **RevenueCat**: create the project, the products in App Store Connect / Play
   Console, an entitlement with identifier `pro` (or change
   `REVENUECAT_ENTITLEMENT_ID`) and an offering. Add a webhook pointing to
   `https://<your-host>/api/v1/webhooks/revenuecat` and set its *Authorization
   header value* to the same string as `REVENUECAT_WEBHOOK_AUTH`. The app must
   call `Purchases.logIn(<our user id>)` (see the API contract, section 9).
5. **Production**: generate strong JWT secrets, serve over HTTPS, and run
   `pnpm db:deploy` as part of the release. No deployment config is included yet.

## Known limits

- The Claude integration (document input + structured outputs) is covered by
  tests with a fake SDK client; it has not been exercised against the live API.
  Do a manual smoke test with a real statement after setting `ANTHROPIC_API_KEY`.
- Offset pagination only on `GET /verifications`; other lists are unpaginated.
