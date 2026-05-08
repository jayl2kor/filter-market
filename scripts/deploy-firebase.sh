#!/usr/bin/env bash
# Firebase production deployment orchestrator.
#
# Usage:
#   ./scripts/deploy-firebase.sh rules
#   ./scripts/deploy-firebase.sh indexes
#   ./scripts/deploy-firebase.sh functions
#   ./scripts/deploy-firebase.sh all
#
# Required secrets (set once via `firebase functions:secrets:set <NAME>`):
#   R2_ENDPOINT, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET
#   APP_STORE_ENV   ("PRODUCTION" or "SANDBOX")
#   APP_APPLE_ID    (numeric App Apple ID — only for PRODUCTION)
#
# Project alias from .firebaserc default = moodit-a9e7a.
set -euo pipefail

target="${1:-}"
if [[ -z "$target" ]]; then
  echo "usage: $0 {rules|indexes|functions|all}" >&2
  exit 2
fi

require_secret() {
  local name="$1"
  if ! firebase functions:secrets:access "$name" >/dev/null 2>&1; then
    echo "ERROR: secret $name not configured. Run: firebase functions:secrets:set $name" >&2
    return 1
  fi
}

deploy_rules() {
  echo "→ deploying firestore.rules + storage.rules"
  firebase deploy --only firestore:rules,storage
}

deploy_indexes() {
  echo "→ deploying firestore.indexes.json"
  firebase deploy --only firestore:indexes
}

deploy_functions() {
  echo "→ verifying required secrets"
  for s in R2_ENDPOINT R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_BUCKET APP_STORE_ENV; do
    require_secret "$s"
  done
  if [[ "$(firebase functions:secrets:access APP_STORE_ENV 2>/dev/null || true)" == "PRODUCTION" ]]; then
    require_secret APP_APPLE_ID
  fi
  echo "→ npm test (functions)"
  npm --prefix functions test
  echo "→ deploying functions"
  firebase deploy --only functions
}

case "$target" in
  rules)     deploy_rules ;;
  indexes)   deploy_indexes ;;
  functions) deploy_functions ;;
  all)       deploy_rules; deploy_indexes; deploy_functions ;;
  *)         echo "unknown target: $target" >&2; exit 2 ;;
esac

echo "✓ deploy ($target) complete"
