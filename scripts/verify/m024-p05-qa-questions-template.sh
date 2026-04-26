#!/usr/bin/env bash
# scripts/verify/m024-p05-qa-questions-template.sh
# Verifies templates/intake-qa-questions.md ships with the pinned schema
# fields and the five ### Q<N> heading blocks per M024/P05 #Q-3 resolution.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
F="$ROOT/templates/intake-qa-questions.md"

[ -f "$F" ] || { echo "FAIL: $F missing"; exit 1; }

grep -q '^schema_version: "1.0"' "$F" \
  || { echo "FAIL: schema_version 1.0 not present in $F"; exit 1; }
grep -q '^type: intake-qa-questions' "$F" \
  || { echo "FAIL: type: intake-qa-questions not present in $F"; exit 1; }

for n in 1 2 3 4 5; do
  grep -q "^### Q$n " "$F" \
    || { echo "FAIL: ### Q$n heading missing in $F"; exit 1; }
done

# Topic words must be grep-stable so T02 can rely on them.
grep -q -i 'goal'             "$F" || { echo "FAIL: Q1 goal topic missing";          exit 1; }
grep -q -i 'scope'            "$F" || { echo "FAIL: Q2 scope topic missing";         exit 1; }
grep -q -i 'surface'          "$F" || { echo "FAIL: Q3 visible surface missing";     exit 1; }
grep -q -i 'adversarial'      "$F" || { echo "FAIL: Q4 adversarial review missing";  exit 1; }
grep -q -i 'time'             "$F" || { echo "FAIL: Q5 time-boxing missing";         exit 1; }

echo "PASS: intake-qa-questions.md — schema + five ### Q<N> blocks + topic words present"
exit 0
