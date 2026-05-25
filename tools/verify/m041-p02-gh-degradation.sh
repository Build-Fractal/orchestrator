#!/usr/bin/env bash
# tools/verify/m041-p02-gh-degradation.sh -- Verify search-issues.sh
# degrades gracefully when gh CLI is not on PATH.
#
# Bash 3.2 compatible.
set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"

tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

# Run with a PATH that excludes gh and no GH_MOCK_DIR
env PATH="/usr/bin:/bin" GH_MOCK_DIR="" \
  bash "$PROJECT_ROOT/scripts/diagnostics/search-issues.sh" \
  --query "test" 2>"$tmpfile"
rc=$?

if [ "$rc" -ne 0 ]; then
  echo "FAIL: search-issues.sh exited $rc (expected 0 on degradation)"
  exit 1
fi

stderr_out="$(cat "$tmpfile")"
case "$stderr_out" in
  *"DETECTIVE: gh unavailable"*)
    echo "PASS: search-issues.sh degrades gracefully when gh absent"
    ;;
  *)
    echo "FAIL: expected 'DETECTIVE: gh unavailable' in stderr, got: $stderr_out"
    exit 1
    ;;
esac
