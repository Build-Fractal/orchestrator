#!/usr/bin/env bash
# scripts/verify/m027-p00-pre-m019-additivity.sh — M027/P00 SC-10 carry-forward.
#
# Runs the rollup against tests/fixtures/m027-p00/pre-m019-mixed.jsonl
# (3 pre-M019 lines without record_type + 3 valid M019 unit_close lines).
# Asserts:
#   - exit 0
#   - stderr contains NO WARN diagnostics for the 3 pre-M019 lines (they
#     are silently ignored).
#   - the rollup counted 3 records (the M019 ones), not 6.
#
# Bash 3.2 compatible. MEM004 carve-out — pipes/$()/awk permitted.

set -u

NAME="m027-p00-pre-m019-additivity.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROLLUP="$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh"
FIX="$PROJECT_ROOT/tests/fixtures/m027-p00/pre-m019-mixed.jsonl"

if [ ! -r "$ROLLUP" ] || [ ! -r "$FIX" ]; then
  printf 'FAIL: %s rollup-or-fixture-missing\n' "$NAME" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

out="$tmp/out"
err="$tmp/err"
bash "$ROLLUP" --granularity milestone --milestone M999 --log "$FIX" >"$out" 2>"$err"
rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: %s rollup rc=%d\n' "$NAME" "$rc" >&2
  cat "$err" >&2 || true
  exit 1
fi

# No WARN about the pre-M019 lines.
warn_lines="$(grep -c '^WARN: ' "$err" || true)"
if [ "$warn_lines" -ne 0 ]; then
  printf 'FAIL: %s expected 0 WARN diagnostics got %s\n' "$NAME" "$warn_lines" >&2
  cat "$err" >&2 || true
  exit 1
fi

# DISPATCHES on the milestone row should be 3.
disp="$(grep '^milestone[[:space:]]' "$out" | awk '
  {
    for (i=1; i<=NF; i++) if ($i ~ /^[0-9]+$/) { print $i; exit }
  }
')"
if [ "$disp" != "3" ]; then
  printf 'FAIL: %s DISPATCHES=%s expected 3\n' "$NAME" "$disp" >&2
  cat "$out" >&2 || true
  exit 1
fi

printf 'PASS: %s warnings=0 dispatches=%s\n' "$NAME" "$disp"
exit 0
