# API deployment (production)

The NestJS API runs on the shared production VM (GCP, `34.173.253.46`, user `hfranco`) next to the GPS Platform services.

| Piece | Where |
|---|---|
| Code + `.env` | `~/cashback-audit/api` (`.env` is mode 600, never in git) |
| Process | PM2 app `cashback-api`, `node --env-file=.env dist/main.js`, port `4300` |
| Database | Docker container `cashback-audit-postgres` (postgres:16-alpine), `127.0.0.1:15432`, volume `cashback-audit-pgdata`, password in `~/cashback-audit/.db-password` |
| Proxy | nginx site `/etc/nginx/sites-available/cashback-api`, host `cashback-api.neargps.net` → `127.0.0.1:4300` |
| TLS | Let's Encrypt via `certbot --nginx` (HTTP → HTTPS redirect, auto-renewed by `certbot.timer`) |
| Public URL | `https://cashback-api.neargps.net/api/v1` (mobile `API_BASE_URL`) |
| DNS | Cloudflare: `A cashback-api → 34.173.253.46` (DNS only, like `app`) |

## Deploy

```bash
apps/api/scripts/deploy.sh            # lint + unit tests, build, upload, install, migrate, restart, health check
apps/api/scripts/deploy.sh --skip-checks
```

Statements are processed in memory: a restart marks in-flight analyses `INTERRUPTED` and refunds the credit. Deploy when idle.

## Not configured yet

`GOOGLE_CLIENT_IDS`, `APPLE_BUNDLE_ID`, `REVENUECAT_WEBHOOK_AUTH`, `REVENUECAT_ENTITLEMENT_ID` are empty in the production `.env`, so Google/Apple sign-in and purchases do not work until they are set (edit `~/cashback-audit/api/.env`, then `pm2 restart cashback-api --update-env`).

## Port convention on the shared VM

GPS Platform owns `3000–3999` (services) and `5432–5499` / `6379–6399` (Postgres / Redis). Projects unrelated to GPS use their own ranges:

| Kind | Range | Cashback Audit |
|---|---|---|
| HTTP APIs | `4300–4399` | `4300` |
| Postgres (bound to `127.0.0.1` only) | `15432–15499` | `15432` |

## Operator commands

Run on the VM from `~/cashback-audit/api` (the `.env` supplies `DATABASE_URL`).

Grant or revoke unlimited credits (no gate, nothing consumed or refunded) for every account with that email, across sign-in providers:

```bash
node --env-file=.env dist/cli/set-unlimited-credits.js <email> [on|off]   # default: on
```

It prints the affected user ids and exits non-zero (`1`) when no user has that email (`2` on bad arguments). The change applies immediately; no restart needed.
