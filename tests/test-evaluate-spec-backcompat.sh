#!/usr/bin/env bash
# tests/test-evaluate-spec-backcompat.sh
# M024/P02 phase test — spec-path backcompat: today-shape metrics + new proposal.md.
# Conventions: parallel arrays for pass/fail tracking (MEM002).
#
# DEVIATION FROM T04-PLAN: plan referenced specs/023-github-native-integration as
# the spec-path target. The proposal-emit / spec-shape-classify path requires
# `type: feature-spec` frontmatter which 023 lacks; T01/T03 verifies already pivoted
# to specs/028-universal-intake-routing for the M014-shaped path. The byte-compat
# baseline diff still consumes the captured 023 baseline (via the per-task verify).

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
SPEC="$ROOT/specs/028-universal-intake-routing/spec.md"

PASS=0; FAIL=0
NAMES_0=""; NAMES_1=""; NAMES_2=""; NAMES_3=""; NAMES_4=""
i=0

pass() { PASS=$((PASS+1)); eval "NAMES_$i=\"PASS: \$1\""; i=$((i+1)); }
fail() { FAIL=$((FAIL+1)); eval "NAMES_$i=\"FAIL: \$1 — \$2\""; i=$((i+1)); }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# (1) Today-shape metrics byte-compat vs baseline (delegated to per-task verify which uses 023).
bash "$ROOT/scripts/verify/m024-p02-evaluate-spec-backcompat.sh" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "today-shape metrics byte-compat vs baseline"
else
  fail "today-shape metrics byte-compat vs baseline" "verify exited $rc"
fi

# (2) Emitter produces a proposal at --spec-path mode.
emit_out=$(bash "$EMIT" --spec-path "$SPEC" --intake-root "$tmp/intake")
prop=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
if [ -f "$prop" ]; then
  pass "emitter produced proposal at --spec-path"
else
  fail "emitter produced proposal at --spec-path" "no proposal_path emitted; out=$emit_out"
fi

# (3) Proposal carries input_shape=spec.
if [ -f "$prop" ] && grep -q '^input_shape: "spec"' "$prop"; then
  pass "proposal frontmatter input_shape=spec"
else
  fail "proposal frontmatter input_shape=spec" "missing or wrong"
fi

# (4) Proposal carries non-stub scope_tier (one of A|B|C, not the placeholder).
if [ -f "$prop" ] && grep -qE '^scope_tier: "[ABC]"' "$prop"; then
  pass "proposal scope_tier in {A,B,C}"
else
  fail "proposal scope_tier in {A,B,C}" "missing or unexpected"
fi

# (5) Proposal carries recommended_command=orchestrator:roadmap (FR-6 byte-compat).
if [ -f "$prop" ] && grep -q '^recommended_command: "orchestrator:roadmap"' "$prop"; then
  pass "proposal recommended_command=orchestrator:roadmap"
else
  fail "proposal recommended_command=orchestrator:roadmap" "missing or wrong"
fi

# Summary.
n=$((PASS + FAIL))
echo
echo "test-evaluate-spec-backcompat: $PASS/$n PASS, $FAIL FAIL"
j=0
while [ "$j" -lt "$n" ]; do
  eval "echo \"  \$NAMES_$j\""
  j=$((j+1))
done

[ "$FAIL" -eq 0 ] || exit 1
exit 0
