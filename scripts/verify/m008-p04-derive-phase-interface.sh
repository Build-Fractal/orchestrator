#!/usr/bin/env bash
# m008-p04-derive-phase-interface.sh -- derive-phase.sh still accepts a single positional
# milestone-dir argument and emits a single state word to stdout.
set -u

SCRIPT="scripts/state/derive-phase.sh"

if [[ ! -x "$SCRIPT" ]]; then
  echo "FAIL: $SCRIPT missing or not executable"
  exit 1
fi

REPO_ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Case 1: non-existent directory -> pre-planning
result="$(bash "$REPO_ROOT/$SCRIPT" "$TMP/does/not/exist")"
if [[ "$result" != "pre-planning" ]]; then
  echo "FAIL: expected 'pre-planning' for missing dir, got '$result'"
  exit 1
fi

# Case 2: empty dir (no M###-* files, no phases/) -> pre-planning
mkdir -p "$TMP/empty-milestone"
result="$(bash "$REPO_ROOT/$SCRIPT" "$TMP/empty-milestone")"
if [[ "$result" != "pre-planning" ]]; then
  echo "FAIL: expected 'pre-planning' for empty dir, got '$result'"
  exit 1
fi

# No-arg invocation must exit non-zero
if bash "$REPO_ROOT/$SCRIPT" >/dev/null 2>&1; then
  echo "FAIL: no-arg invocation unexpectedly succeeded"
  exit 1
fi

echo "PASS: derive-phase.sh preserves positional-arg interface and state-word output"
exit 0
