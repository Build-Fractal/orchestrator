#!/usr/bin/env bash
# tools/verify/m036-p06-extract-manifest-shape.sh -- M036 P06 T03.
# Token-presence verifier on the supersede-fixture extract manifest.
# AD-19 single-script-file shape. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
F="$ROOT/tests/fixtures/m036-p06-extract-manifest.yaml"
pass=0
fail=0
chk() {
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
  echo "SUMMARY: m036-p06-extract-manifest-shape.sh pass=0 fail=1"
  exit 1
fi
chk "schema_version-declared"      "schema_version:"
chk "type-extract-manifest"        "type: extract-manifest"
chk "milestone-M036"               'milestone: "M036"'
chk "size_cap_bytes-declared"      "size_cap_bytes:"
chk "documents-array"              "documents:"
chk "fixture-cite_id"              'cite_id: "supersede-fixture"'
chk "category-cms-rule"            'category: "cms-rule"'
chk "tier-1"                       "tier: 1"
chk "summary_mode-operator"        'summary_mode: "operator"'
echo "SUMMARY: m036-p06-extract-manifest-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
