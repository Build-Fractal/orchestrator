#!/usr/bin/env bash
# scripts/verify/m027-p00-perf-bound.sh — M027/P00 CON-12 / AD-2 / SC-13.
#
# Generates a >=10 MB JSONL via the T02 perf generator, runs the rollup
# under a wall-clock timer, and asserts elapsed < 5 s. If the bound is
# exceeded, prints a structured `RELAX-CANDIDATE` advisory alongside the
# FAIL so plan-phase can revisit CON-12 with concrete evidence.
#
# Bash 3.2 compatible. MEM004 carve-out — pipes/$()/awk permitted.

set -u

NAME="m027-p00-perf-bound.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROLLUP="$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh"
GEN="$PROJECT_ROOT/tests/fixtures/m027-p00/perf-10mb.jsonl.gen.sh"

if [ ! -r "$ROLLUP" ] || [ ! -x "$GEN" ]; then
  printf 'FAIL: %s rollup-or-generator-missing\n' "$NAME" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

perf_log="$tmp/perf-10mb.jsonl"
bash "$GEN" "$perf_log" >/dev/null 2>"$tmp/gen.err"
gen_rc=$?
if [ "$gen_rc" -ne 0 ]; then
  printf 'FAIL: %s generator rc=%d\n' "$NAME" "$gen_rc" >&2
  cat "$tmp/gen.err" >&2 || true
  exit 1
fi

if [ ! -f "$perf_log" ]; then
  printf 'FAIL: %s generator did not produce %s\n' "$NAME" "$perf_log" >&2
  exit 1
fi

bytes="$(wc -c < "$perf_log" | tr -d ' ')"
min_bytes=10485760  # 10 MB
if [ "$bytes" -lt "$min_bytes" ]; then
  printf 'FAIL: %s perf log only %s bytes (< 10 MB)\n' "$NAME" "$bytes" >&2
  exit 1
fi

# Wall-clock timer. We use date +%s for portability — bash 3.2 has no
# built-in $EPOCHREALTIME. Sub-second precision is captured via the awk
# diff on date +%s.%N where supported, with a fallback to integer seconds.
t_start_s="$(date +%s)"
t_start_ns="$(date +%N 2>/dev/null || printf '0')"
case "$t_start_ns" in
  N|[!0-9]*) t_start_ns=0 ;;
esac

bash "$ROLLUP" --granularity milestone --milestone M999 --log "$perf_log" >/dev/null 2>"$tmp/rollup.err"
rc=$?

t_end_s="$(date +%s)"
t_end_ns="$(date +%N 2>/dev/null || printf '0')"
case "$t_end_ns" in
  N|[!0-9]*) t_end_ns=0 ;;
esac

if [ "$rc" -ne 0 ]; then
  printf 'FAIL: %s rollup rc=%d on perf log\n' "$NAME" "$rc" >&2
  cat "$tmp/rollup.err" >&2 || true
  exit 1
fi

# Compute elapsed seconds (float) via awk.
elapsed="$(awk -v s0="$t_start_s" -v ns0="$t_start_ns" -v s1="$t_end_s" -v ns1="$t_end_ns" '
  BEGIN {
    # date +%N may be left-padded; awk treats as int. Normalize ns to seconds.
    es = s1 - s0;
    en = (ns1 - ns0) / 1000000000.0;
    total = es + en;
    if (total < 0) total = es;  # ns rollover edge case
    printf "%.3f", total;
  }
')"

bound="5.0"
ok="$(awk -v e="$elapsed" -v b="$bound" 'BEGIN { print (e+0 < b+0) ? "yes" : "no" }')"

if [ "$ok" != "yes" ]; then
  printf 'FAIL: %s elapsed=%ss exceeds bound=%ss\n' "$NAME" "$elapsed" "$bound" >&2
  printf 'RELAX-CANDIDATE: %ss observed against 10MB; consider relaxing CON-12 if architectural rework is required\n' "$elapsed" >&2
  exit 1
fi

printf 'PASS: %s bytes=%s elapsed=%ss bound=%ss\n' "$NAME" "$bytes" "$elapsed" "$bound"
exit 0
