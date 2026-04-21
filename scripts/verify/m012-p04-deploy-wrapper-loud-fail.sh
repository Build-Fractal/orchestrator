#!/usr/bin/env bash
# scripts/verify/m012-p04-deploy-wrapper-loud-fail.sh — M012/P04 T03 gate.
#
# Runs `bash scripts/wiki/wiki-deploy.sh --dry-run` with GISCUS_REPO_ID
# unset (the other three GISCUS_* vars set to "x"). Asserts the wrapper:
#   - exits 1 (gate 1 abort before any other gate runs)
#   - emits `GATE: giscus-config FAIL` on stdout
#   - NEVER reaches `DRY-RUN: would deploy` or `OK: deployed to`
#
# Maps to Constitution VI "Loud failure on missing external config"
# and SC-9. Writes only to /tmp; cleans up on exit. Bash 3.2 compliant.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ROOT="${1:-$DEFAULT_ROOT}"

WRAPPER="$ROOT/scripts/wiki/wiki-deploy.sh"
if [ ! -f "$WRAPPER" ]; then
  printf 'FAIL: %s not found\n' "$WRAPPER" >&2
  exit 1
fi

LOUD_OUT="/tmp/m012-p04-deploy-loud.$$.out"
LOUD_ERR="/tmp/m012-p04-deploy-loud.$$.err"
# shellcheck disable=SC2064
trap "rm -f '$LOUD_OUT' '$LOUD_ERR'" EXIT INT TERM

# Fixture env: GISCUS_REPO_ID deliberately unset. Other vars present
# but meaningless (the config-check gate must still abort because one
# required var is missing — loud failure, not silent best-effort).
rc=0
env -i PATH="$PATH" HOME="$HOME" \
  GISCUS_REPO=x \
  GISCUS_CATEGORY=x \
  GISCUS_CATEGORY_ID=x \
  bash "$WRAPPER" --root "$ROOT" --dry-run \
  >"$LOUD_OUT" 2>"$LOUD_ERR" || rc=$?

if [ "$rc" -eq 0 ]; then
  printf 'FAIL: expected non-zero exit with GISCUS_REPO_ID unset; got 0\n' >&2
  sed 's/^/  /' "$LOUD_OUT" >&2
  exit 1
fi

if ! grep -qF 'GATE: giscus-config FAIL' "$LOUD_OUT"; then
  printf 'FAIL: missing `GATE: giscus-config FAIL` on stdout\n' >&2
  sed 's/^/  /' "$LOUD_OUT" >&2
  sed 's/^/  /' "$LOUD_ERR" >&2
  exit 1
fi

# Ensure the loud-fail short-circuited before any deploy-adjacent line.
if grep -qF 'DRY-RUN: would deploy' "$LOUD_OUT"; then
  printf 'FAIL: wrapper reached DRY-RUN terminator despite GISCUS_REPO_ID unset\n' >&2
  exit 1
fi
if grep -qF 'OK: deployed to' "$LOUD_OUT"; then
  printf 'FAIL: wrapper reached OK terminator despite GISCUS_REPO_ID unset\n' >&2
  exit 1
fi

printf 'PASS: wrapper loud-fails (exit=%d) with GISCUS_REPO_ID unset — no silent deploy\n' "$rc"
exit 0
