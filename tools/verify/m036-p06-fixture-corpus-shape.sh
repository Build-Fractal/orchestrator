#!/usr/bin/env bash
# tools/verify/m036-p06-fixture-corpus-shape.sh -- M036 P06 T03.
# Token-presence verifier on the supersede-corpus fixtures.
# AD-19 single-script-file shape. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
BASE="$ROOT/tests/fixtures/m036-p06-supersede-corpus"
V1="$BASE/original/cms-rule/REF-cms-rule-supersede-fixture.md"
V2="$BASE/mutated/cms-rule/REF-cms-rule-supersede-fixture.md"
CITER="$BASE/citer-spec/SPEC-requirement-supersede-citer.md"
pass=0
fail=0
chk() {
  local label="$1" file="$2" pat="$3"
  if [ -f "$file" ] && grep -qF -e "$pat" "$file"; then
    echo "PASS: $label"
    pass=$((pass + 1))
  else
    echo "FAIL: $label (file=$file pat=$pat)"
    fail=$((fail + 1))
  fi
}
chk "v1-exists"                    "$V1" "BODY V1"
chk "v1-cite_id"                   "$V1" 'cite_id: "supersede-fixture"'
chk "v1-category-cms-rule"         "$V1" 'category: "cms-rule"'
chk "v1-topic-tag-pbj-staffing"    "$V1" "pbj-staffing"
chk "v1-applies-to-field"          "$V1" "staff_count"
chk "v2-exists"                    "$V2" "BODY V2"
chk "v2-cite_id"                   "$V2" 'cite_id: "supersede-fixture"'
chk "v2-version-2"                 "$V2" "version: 2"
chk "citer-spec-exists"            "$CITER" "SPEC-requirement-supersede-citer"
chk "citer-cites-v1-id"            "$CITER" "cites: [REF-cms-rule-supersede-fixture]"
# Negative: citer must NOT name the v2 successor (the test exercises
# the chain-walk from V1 -- if the citer pointed at v2 directly, the
# supersede-walk would have nothing to surface).
if [ -f "$CITER" ] && grep -qF -e "REF-cms-rule-supersede-fixture-v2" "$CITER"; then
  echo "FAIL: citer-must-not-name-v2-successor"
  fail=$((fail + 1))
else
  echo "PASS: citer-points-at-V1-only"
  pass=$((pass + 1))
fi
echo "SUMMARY: m036-p06-fixture-corpus-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
