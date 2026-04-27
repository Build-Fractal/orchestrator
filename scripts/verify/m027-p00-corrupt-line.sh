#!/usr/bin/env bash
# scripts/verify/m027-p00-corrupt-line.sh — M027/P00 FR-14 / SC-5.
#
# Runs the rollup against tests/fixtures/m027-p00/corrupt-line.jsonl.
# Asserts:
#   - exit 0 (rollup tolerates corrupt lines)
#   - stderr contains exactly one WARN line referencing line number 4
#     (the planted corrupt line)
#   - the rollup aggregated 9 records (the 10 - 1 corrupt rows). We assert
#     this by summing the DISPATCHES column at --granularity task.
#
# Bash 3.2 compatible. MEM004 carve-out — pipes/$()/awk permitted.

set -u

NAME="m027-p00-corrupt-line.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROLLUP="$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh"
FIX="$PROJECT_ROOT/tests/fixtures/m027-p00/corrupt-line.jsonl"

if [ ! -r "$ROLLUP" ] || [ ! -r "$FIX" ]; then
  printf 'FAIL: %s rollup-or-fixture-missing\n' "$NAME" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

out="$tmp/out"
err="$tmp/err"
bash "$ROLLUP" --granularity task --milestone M999 --log "$FIX" >"$out" 2>"$err"
rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: %s rollup rc=%d expected 0\n' "$NAME" "$rc" >&2
  cat "$err" >&2 || true
  exit 1
fi

# Exactly one corrupt-line WARN, line 4.
warn_count="$(grep -c '^WARN: corrupt JSONL line' "$err" || true)"
if [ "$warn_count" -ne 1 ]; then
  printf 'FAIL: %s expected 1 corrupt WARN got %s\n' "$NAME" "$warn_count" >&2
  cat "$err" >&2 || true
  exit 1
fi
if ! grep -q '^WARN: corrupt JSONL line 4 ' "$err"; then
  printf 'FAIL: %s WARN does not reference line 4\n' "$NAME" >&2
  cat "$err" >&2 || true
  exit 1
fi

# Sum DISPATCHES across task rows — should be 9.
disp_sum="$(grep '^task[[:space:]]' "$out" | awk '{
  for (i=1; i<=NF; i++) if ($i ~ /^[0-9]+$/) { print $i; exit }
}' | awk 'BEGIN{s=0} {s+=$1} END{print s}')"
# That awk pipeline picks the FIRST integer per row, which is DISPATCHES (col 3).
# But we ran two awk passes: first per-line print of dispatches, second sum.
if [ -z "$disp_sum" ] || [ "$disp_sum" != "9" ]; then
  # Fallback: sum directly within a single awk over the data rows.
  disp_sum="$(grep '^task[[:space:]]' "$out" | awk '
    {
      for (i=1; i<=NF; i++) if ($i ~ /^[0-9]+$/) { sum += $i; break }
    }
    END { print sum+0 }
  ')"
fi
if [ "$disp_sum" != "9" ]; then
  printf 'FAIL: %s DISPATCHES sum=%s expected 9\n' "$NAME" "$disp_sum" >&2
  cat "$out" >&2 || true
  exit 1
fi

printf 'PASS: %s warn=1 line=4 dispatches=%s\n' "$NAME" "$disp_sum"
exit 0
