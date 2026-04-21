#!/usr/bin/env bash
# scripts/verify/m012-p03-remap-contract.sh — M012/P03 T04 gate.
#
# Exercises help, dry-run, and odd-arg-count paths of the remap script.
# No external network calls: never hits `gh api`. Writes only to /tmp;
# cleans up on exit. Bash 3.2 compliant.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ROOT="${1:-$DEFAULT_ROOT}"

GATE="$ROOT/scripts/diagnostics/wiki-giscus-remap.sh"
if [ ! -f "$GATE" ]; then
  printf 'FAIL: %s not found\n' "$GATE" >&2
  exit 1
fi
if [ ! -x "$GATE" ]; then
  printf 'FAIL: %s not executable\n' "$GATE" >&2
  exit 1
fi

HELP_OUT="/tmp/m012-p03-remap-help.$$.out"
DRY_OUT="/tmp/m012-p03-remap-dry.$$.out"
DRY_ERR="/tmp/m012-p03-remap-dry.$$.err"
ODD_OUT="/tmp/m012-p03-remap-odd.$$.out"
ODD_ERR="/tmp/m012-p03-remap-odd.$$.err"
# shellcheck disable=SC2064
trap "rm -f '$HELP_OUT' '$DRY_OUT' '$DRY_ERR' '$ODD_OUT' '$ODD_ERR'" EXIT INT TERM

# --help -> exit 0.
rc=0
bash "$GATE" --help >"$HELP_OUT" 2>&1 || rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: --help exit %d != 0 (out=%s)\n' "$rc" "$HELP_OUT" >&2
  exit 1
fi

# --dry-run valid pair -> exit 0 + DRY-RUN: line.
rc=0
bash "$GATE" --dry-run /a/ /b/ >"$DRY_OUT" 2>"$DRY_ERR" || rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: --dry-run exit %d != 0 (err=%s)\n' "$rc" "$DRY_ERR" >&2
  exit 1
fi
if ! grep -qF 'DRY-RUN: /a/ -> /b/' "$DRY_OUT"; then
  printf 'FAIL: --dry-run missing "DRY-RUN: /a/ -> /b/" line (out=%s)\n' "$DRY_OUT" >&2
  exit 1
fi

# Odd positional count -> exit 2.
rc=0
bash "$GATE" --dry-run /a/ >"$ODD_OUT" 2>"$ODD_ERR" || rc=$?
if [ "$rc" -ne 2 ]; then
  printf 'FAIL: odd-arg exit %d != 2 (err=%s)\n' "$rc" "$ODD_ERR" >&2
  exit 1
fi

# Idempotency surface: two back-to-back dry-runs on same pair both exit 0.
rc=0
bash "$GATE" --dry-run /a/ /b/ >/dev/null 2>&1 || rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: first idempotency dry-run exit %d != 0\n' "$rc" >&2
  exit 1
fi
rc=0
bash "$GATE" --dry-run /a/ /b/ >/dev/null 2>&1 || rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: second idempotency dry-run exit %d != 0\n' "$rc" >&2
  exit 1
fi

printf 'PASS: remap script contract (help=0, dry-run=0+DRY-RUN:, odd-arg=2, idempotent dry-run)\n'
exit 0
