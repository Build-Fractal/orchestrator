#!/usr/bin/env bash
# tools/verify/m036-p07-relevance-lib-shape.sh — M036 P07 T02
# relevance-lib token-presence verifier. AD-19.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
F="$ROOT/scripts/dispatch/lib/reference-relevance.sh"
pass=0
fail=0
check() {
  local label="$1" pat="$2"
  if grep -qF -e "$pat" "$F"; then
    echo "PASS: $label"
    pass=$((pass + 1))
  else
    echo "FAIL: $label (missing: $pat)"
    fail=$((fail + 1))
  fi
}
if [ ! -f "$F" ]; then
  echo "FAIL: $F not found"
  echo "SUMMARY: m036-p07-relevance-lib-shape.sh pass=0 fail=1"
  exit 1
fi
check "fn-defn"             "reference_rank()"
check "key-1-topic-overlap" "topic-tag overlap"
check "key-2-field-overlap" "applies_to_field overlap"
check "key-3-published"     "published date"
check "key-4-chunk-id-lex"  "chunk_id lexicographic"
check "Q2-resolution"       "Open Question #Q-2"
echo "SUMMARY: m036-p07-relevance-lib-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
