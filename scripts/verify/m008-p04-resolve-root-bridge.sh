#!/usr/bin/env bash
# m008-p04-resolve-root-bridge.sh -- only .specify/orchestrator present -> bridge resolution
set -u

REPO_ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.git"
mkdir -p "$TMP/.specify/orchestrator"

cd "$TMP"
unset ORCHESTRATOR_ROOT
result="$(bash "$REPO_ROOT/scripts/state/resolve-root.sh")"

if [[ "$result" != ".specify/orchestrator" ]]; then
  echo "FAIL: bridge resolution did not return '.specify/orchestrator'; got '$result'"
  exit 1
fi

echo "PASS: legacy-only project resolves to .specify/orchestrator (migration bridge)"
exit 0
