#!/usr/bin/env bash
# m008-p04-migrate-state-dry-run.sh -- --dry-run reports but does not mutate
set -u

SCRIPT="scripts/migrate/migrate-state.sh"

if [[ ! -x "$SCRIPT" ]]; then
  echo "FAIL: $SCRIPT missing or not executable"
  exit 1
fi

REPO_ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.git"
mkdir -p "$TMP/.specify/orchestrator"
echo "sentinel" > "$TMP/.specify/orchestrator/foo.md"

cd "$TMP"
out="$(bash "$REPO_ROOT/$SCRIPT" --dry-run)"

if ! echo "$out" | grep -q '^DRYRUN:'; then
  echo "FAIL: expected DRYRUN: line; got:"
  echo "$out"
  exit 1
fi

# Source must still be intact
if [[ ! -f "$TMP/.specify/orchestrator/foo.md" ]]; then
  echo "FAIL: dry-run mutated the source"
  exit 1
fi

# Destination must still be absent
if [[ -d "$TMP/.orchestrator" ]]; then
  echo "FAIL: dry-run created the destination"
  exit 1
fi

echo "PASS: --dry-run reports without mutating"
exit 0
