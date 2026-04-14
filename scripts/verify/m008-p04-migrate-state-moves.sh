#!/usr/bin/env bash
# m008-p04-migrate-state-moves.sh -- migrate-state.sh moves content and emits MIGRATED:
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
mkdir -p "$TMP/.specify/orchestrator/milestones"
echo "sentinel-content" > "$TMP/.specify/orchestrator/KNOWLEDGE.md"

cd "$TMP"
out="$(bash "$REPO_ROOT/$SCRIPT")"

if ! echo "$out" | grep -q '^MIGRATED:'; then
  echo "FAIL: expected MIGRATED: line; got:"
  echo "$out"
  exit 1
fi

if [[ -d "$TMP/.specify/orchestrator" ]]; then
  echo "FAIL: source dir still exists after migration"
  exit 1
fi

if [[ ! -f "$TMP/.orchestrator/KNOWLEDGE.md" ]]; then
  echo "FAIL: content did not arrive at .orchestrator/KNOWLEDGE.md"
  exit 1
fi

content="$(cat "$TMP/.orchestrator/KNOWLEDGE.md")"
if [[ "$content" != "sentinel-content" ]]; then
  echo "FAIL: content altered during migration"
  exit 1
fi

echo "PASS: migrate-state.sh moves content and emits MIGRATED:"
exit 0
