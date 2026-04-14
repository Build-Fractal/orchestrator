#!/usr/bin/env bash
# m008-p04-resolve-root-env-override.sh -- ORCHESTRATOR_ROOT env var wins over all other signals
set -u

REPO_ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Create a stub project with BOTH legacy and new roots so env var must beat them.
mkdir -p "$TMP/.git"
mkdir -p "$TMP/.orchestrator"
mkdir -p "$TMP/.specify/orchestrator"

cd "$TMP"
result="$(ORCHESTRATOR_ROOT=custom/state bash "$REPO_ROOT/scripts/state/resolve-root.sh")"

if [[ "$result" != "custom/state" ]]; then
  echo "FAIL: env override not honored; got '$result', expected 'custom/state'"
  exit 1
fi

echo "PASS: ORCHESTRATOR_ROOT env var takes precedence"
exit 0
