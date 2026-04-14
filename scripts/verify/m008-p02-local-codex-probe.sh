#!/usr/bin/env bash
# Verifies local-codex.sh --probe works and emits available= key.
set -u

f="scripts/dispatch/adapters/backend/local-codex.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

# Check --probe flag handling exists
grep -q '\-\-probe' "$f" || { echo "FAIL: $f does not handle --probe"; exit 1; }
grep -q 'backend=local-codex' "$f" || { echo "FAIL: $f missing backend=local-codex identifier"; exit 1; }
grep -q 'command -v codex' "$f" || { echo "FAIL: $f does not check for codex binary on PATH"; exit 1; }

# Run probe — must emit available= key with true or false value, and exit 0
output="$(bash "$f" --probe 2>/dev/null)"
rc=$?
if [[ $rc -ne 0 ]]; then
  echo "FAIL: probe exited $rc (expected 0)"; exit 1
fi
echo "$output" | grep -qE '^available=(true|false)$' || { echo "FAIL: probe did not emit available=true|false: $output"; exit 1; }
echo "$output" | grep -q '^backend=local-codex' || { echo "FAIL: probe did not emit backend=local-codex"; exit 1; }

echo "PASS: local-codex.sh --probe emits available= and backend=local-codex"
