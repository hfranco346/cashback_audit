#!/usr/bin/env bash
# Build the API locally and deploy it to the production VM (PM2 + dockerized Postgres).
#
# Usage: apps/api/scripts/deploy.sh [--skip-checks]
#
# One-time VM setup (already done, documented in docs/deploy.md):
#   - Postgres container `cashback-audit-postgres` on 127.0.0.1:5438
#   - ~/cashback-audit/api/.env (production secrets, never in git)
#   - nginx site for the API domain proxying to 127.0.0.1:3300
#
# Note: statements are processed in memory. Restarting while a statement is being
# analyzed marks it INTERRUPTED and refunds the credit, so deploy when idle.
set -euo pipefail

VM_HOST="${DEPLOY_HOST:-34.173.253.46}"
VM_USER="${DEPLOY_USER:-hfranco}"
SSH_KEY="${DEPLOY_SSH_KEY:-$HOME/.ssh/gcp_rsa}"
REMOTE_DIR="cashback-audit/api"
PM2_NAME="cashback-api"
PORT=3300
PNPM_VERSION="10.33.0"

API_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SSH=(ssh -i "$SSH_KEY" -o ConnectTimeout=10 "${VM_USER}@${VM_HOST}")

cd "$API_DIR"

if [[ "${1:-}" != "--skip-checks" ]]; then
  echo "==> Lint and tests"
  pnpm lint
  pnpm test
fi

echo "==> Build"
rm -rf dist
pnpm build

echo "==> Upload"
tar -czf - dist package.json pnpm-lock.yaml prisma prisma.config.ts \
  | "${SSH[@]}" "mkdir -p ~/${REMOTE_DIR} && cd ~/${REMOTE_DIR} && rm -rf dist && tar -xzf -"

echo "==> Install, migrate and restart"
"${SSH[@]}" bash -s <<EOF
set -euo pipefail
export NVM_DIR="\$HOME/.nvm"
. "\$NVM_DIR/nvm.sh" >/dev/null
cd ~/${REMOTE_DIR}
corepack pnpm@${PNPM_VERSION} install --frozen-lockfile --ignore-scripts --reporter=silent
set -a; . ./.env; set +a
corepack pnpm@${PNPM_VERSION} exec prisma migrate deploy
if pm2 describe ${PM2_NAME} >/dev/null 2>&1; then
  pm2 restart ${PM2_NAME} --update-env
else
  pm2 start dist/main.js --name ${PM2_NAME} --node-args="--env-file=.env"
  pm2 save
fi
for i in \$(seq 1 20); do
  if curl -fs -o /dev/null "http://127.0.0.1:${PORT}/api/v1/health"; then
    echo "health: ok"; exit 0
  fi
  sleep 1
done
echo "health: FAILED"; pm2 logs ${PM2_NAME} --lines 40 --nostream; exit 1
EOF
