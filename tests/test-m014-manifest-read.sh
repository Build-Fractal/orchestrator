#!/usr/bin/env bash
# tests/test-m014-manifest-read.sh
# M024/P02 phase test — live M014 manifest reader (AD-4 direction `a`).
# Conventions: parallel arrays for pass/fail tracking (MEM002).
#
# DEVIATION FROM T04-PLAN: plan referenced specs/023-github-native-integration as
# the spec-path target. The reader requires `type: feature-spec` frontmatter which
# 023 lacks; this test pivots to specs/028-universal-intake-routing (matches the
# precedent set by scripts/verify/m024-p02-m014-manifest-read.sh from T02).

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
READER="$ROOT/scripts/intake/m014-manifest-read.sh"
SPEC_DIR="$ROOT/specs/028-universal-intake-routing"
SPEC="$SPEC_DIR/spec.md"
TEMPLATE="$ROOT/templates/spec-template.md"

PASS=0; FAIL=0
NAMES_0=""; NAMES_1=""; NAMES_2=""; NAMES_3=""; NAMES_4=""
i=0

pass() { PASS=$((PASS+1)); eval "NAMES_$i=\"PASS: \$1\""; i=$((i+1)); }
fail() { FAIL=$((FAIL+1)); eval "NAMES_$i=\"FAIL: \$1 — \$2\""; i=$((i+1)); }

tmp=$(mktemp -d)
# trap-guarded restore: if we pivot the template and the test crashes mid-flight,
# the trap restores the template back to its original location (SB-3 atomic round-trip).
TEMPLATE_PARKED="$tmp/spec-template.md.parked"
restore_template() {
  if [ -f "$TEMPLATE_PARKED" ] && [ ! -f "$TEMPLATE" ]; then
    mv "$TEMPLATE_PARKED" "$TEMPLATE"
  fi
  rm -rf "$tmp"
}
trap restore_template EXIT

# (1) --spec-path mode: six lines in canonical order.
out=$(bash "$READER" --spec-path "$SPEC")
lc=$(echo "$out" | grep -c '^')
if [ "$lc" -eq 6 ]; then
  pass "reader emits exactly six lines"
else
  fail "reader emits exactly six lines" "got $lc"
fi

# (2) Canonical key order.
keys=$(echo "$out" | sed -E 's/=.*//')
expected="schema_version
type
feature_slug
created_at
status
milestone"
if [ "$keys" = "$expected" ]; then
  pass "canonical six-key order"
else
  fail "canonical six-key order" "got: $keys"
fi

# (3) --specs-dir parity with --spec-path.
out2=$(bash "$READER" --specs-dir "$SPEC_DIR")
if [ "$out" = "$out2" ]; then
  pass "--spec-path / --specs-dir parity"
else
  fail "--spec-path / --specs-dir parity" "differ"
fi

# (4) Invoke-time M014 probe — pivot the template to /tmp and confirm exit 3.
mv "$TEMPLATE" "$TEMPLATE_PARKED"
rc=0
bash "$READER" --spec-path "$SPEC" >/dev/null 2>&1 || rc=$?
mv "$TEMPLATE_PARKED" "$TEMPLATE"
if [ "$rc" -eq 3 ]; then
  pass "invoke-time probe exits 3 when template missing"
else
  fail "invoke-time probe exits 3 when template missing" "got rc=$rc"
fi

# Summary.
n=$((PASS + FAIL))
echo
echo "test-m014-manifest-read: $PASS/$n PASS, $FAIL FAIL"
j=0
while [ "$j" -lt "$n" ]; do
  eval "echo \"  \$NAMES_$j\""
  j=$((j+1))
done

[ "$FAIL" -eq 0 ] || exit 1
exit 0
