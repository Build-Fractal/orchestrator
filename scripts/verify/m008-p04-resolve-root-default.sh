#!/usr/bin/env bash
# m008-p04-resolve-root-default.sh -- fresh project with no state dirs defaults to .orchestrator
set -u

REPO_ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.git"

cd "$TMP"
unset ORCHESTRATOR_ROOT
result="$(bash "$REPO_ROOT/scripts/state/resolve-root.sh")"

if [[ "$result" != ".orchestrator" ]]; then
  echo "FAIL: default resolution did not return '.orchestrator'; got '$result'"
  exit 1
fi

echo "PASS: fresh project defaults to .orchestrator"
exit 0
