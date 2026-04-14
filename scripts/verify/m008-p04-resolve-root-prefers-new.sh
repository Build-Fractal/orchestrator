#!/usr/bin/env bash
# m008-p04-resolve-root-prefers-new.sh -- both roots present -> .orchestrator wins
set -u

REPO_ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.git"
mkdir -p "$TMP/.orchestrator"
mkdir -p "$TMP/.specify/orchestrator"

cd "$TMP"
unset ORCHESTRATOR_ROOT
result="$(bash "$REPO_ROOT/scripts/state/resolve-root.sh")"

if [[ "$result" != ".orchestrator" ]]; then
  echo "FAIL: when both roots exist, expected '.orchestrator', got '$result'"
  exit 1
fi

echo "PASS: .orchestrator preferred when both roots present"
exit 0
