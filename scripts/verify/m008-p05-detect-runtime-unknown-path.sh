#!/usr/bin/env bash
# Verifies detect-runtime.sh returns runtime=unknown / confidence=low
# with exit code 0 when no signals match.
set -u

SCRIPT="scripts/dispatch/detect-runtime.sh"

if [[ ! -f "$SCRIPT" ]]; then
  echo "FAIL: $SCRIPT missing"
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# Hermetic env: no runtime env vars, empty HOME, cwd in tmpdir.
out="$(cd "$tmpdir" && env -i HOME="$tmpdir" PATH="/usr/bin:/bin" bash "$OLDPWD/$SCRIPT" 2>/dev/null)"
rc=$?

if [[ $rc -ne 0 ]]; then
  echo "FAIL: unknown-path exit=$rc (expected 0)"
  exit 1
fi

if ! echo "$out" | grep -qE '^runtime=unknown$'; then
  echo "FAIL: unknown-path did not yield runtime=unknown"
  echo "---OUTPUT---"
  echo "$out"
  exit 1
fi

if ! echo "$out" | grep -qE '^confidence=low$'; then
  echo "FAIL: unknown-path did not yield confidence=low"
  echo "---OUTPUT---"
  echo "$out"
  exit 1
fi

echo "PASS: detect-runtime.sh unknown-path returns runtime=unknown / confidence=low with exit 0"
