#!/usr/bin/env bash
# tools/verify/m036-p07-relevance-deterministic.sh — M036 P07 T02
# determinism + tie-break verifier. AD-19.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
LIB="$ROOT/scripts/dispatch/lib/reference-relevance.sh"
if [ ! -f "$LIB" ]; then
  echo "FAIL: $LIB not found"
  echo "SUMMARY: m036-p07-relevance-deterministic.sh pass=0 fail=1"
  exit 1
fi
# shellcheck disable=SC1090
. "$LIB"
WS="$(mktemp -d)"
trap 'rm -rf "$WS"' EXIT
IN="$WS/in.txt"
O1="$WS/out1.txt"
O2="$WS/out2.txt"
# 4 candidates; task topics = "pbj-staffing"; task fields = "staff_count".
# Expected order:
#   REF-A — topic match (1) + field match (1) + 2026-01 → highest
#   REF-B — topic match (1) + field match (0) + 2025-06 → second
#   REF-C — topic match (0) + field match (1) + 2025-01 → third
#   REF-D — same as REF-C scores but lex chunk_id breaks tie below it
{
  printf 'REF-A|/p/A|pbj-staffing,other|staff_count|2026-01-01\n'
  printf 'REF-B|/p/B|pbj-staffing|other|2025-06-01\n'
  printf 'REF-D|/p/D|other|staff_count|2025-01-01\n'
  printf 'REF-C|/p/C|other|staff_count|2025-01-01\n'
} > "$IN"
reference_rank "$IN" "pbj-staffing" "staff_count" > "$O1"
reference_rank "$IN" "pbj-staffing" "staff_count" > "$O2"
pass=0
fail=0
if cmp -s "$O1" "$O2"; then
  echo "PASS: deterministic-byte-equality"
  pass=$((pass + 1))
else
  echo "FAIL: nondeterministic-output"
  fail=$((fail + 1))
fi
first="$(head -n 1 "$O1" | cut -d'|' -f1)"
if [ "$first" = "REF-A" ]; then
  echo "PASS: highest-rank-is-REF-A"
  pass=$((pass + 1))
else
  echo "FAIL: highest-rank-was-$first-expected-REF-A"
  fail=$((fail + 1))
fi
second="$(sed -n '2p' "$O1" | cut -d'|' -f1)"
if [ "$second" = "REF-B" ]; then
  echo "PASS: second-rank-is-REF-B"
  pass=$((pass + 1))
else
  echo "FAIL: second-rank-was-$second-expected-REF-B"
  fail=$((fail + 1))
fi
third="$(sed -n '3p' "$O1" | cut -d'|' -f1)"
fourth="$(sed -n '4p' "$O1" | cut -d'|' -f1)"
if [ "$third" = "REF-C" ] && [ "$fourth" = "REF-D" ]; then
  echo "PASS: chunk-id-lex-tie-break-C-before-D"
  pass=$((pass + 1))
else
  echo "FAIL: tie-break-third=$third-fourth=$fourth-expected-C-then-D"
  fail=$((fail + 1))
fi
echo "SUMMARY: m036-p07-relevance-deterministic.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
