#!/usr/bin/env bash
# tests/test-phase-transition-frontmatter.sh — Bug F regression tests
#
# Bug F: phase-transition.sh emitted phase-summary frontmatter with
# duplicated tokens in concatenated fields (provides/key_files/...) and
# leaked task IDs into requires/affects (which describe phase-to-phase
# graph position, not internal task layout).
#
# This pins:
#   - dedup of provides/key_files/key_decisions/patterns_established
#   - requires from roadmap Depends:
#   - affects from roadmap reverse-Depends (new query)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PT="$PROJECT_ROOT/scripts/lifecycle/phase-transition.sh"
FIXTURE="$PROJECT_ROOT/tests/fixtures/phase-transition-frontmatter/M999"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1"; }

# --- Run phase-transition.sh on P00 (multiple tasks with dups) ---
out_p00=$(mktemp)
bash "$PT" "$FIXTURE" P00 --output-file="$out_p00" >/dev/null 2>&1 || true

provides=$(grep '^provides=' "$out_p00" | sed 's/^provides=//')
key_files=$(grep '^key_files=' "$out_p00" | sed 's/^key_files=//')
requires=$(grep '^requires=' "$out_p00" | sed 's/^requires=//')
affects=$(grep '^affects=' "$out_p00" | sed 's/^affects=//')

# Dedup: T01 has "foo, bar", T02 has "foo, baz" → expect "foo,bar,baz".
if [[ "$provides" = "foo,bar,baz" ]]; then
  pass "P00 provides deduped to first-seen order (got '$provides')"
else
  fail "P00 provides deduped (expected 'foo,bar,baz', got '$provides')"
fi

# T01 has "scripts/foo.sh, scripts/bar.sh", T02 adds "scripts/baz.sh"; expect dedup.
if [[ "$key_files" = "scripts/foo.sh,scripts/bar.sh,scripts/baz.sh" ]]; then
  pass "P00 key_files deduped (got '$key_files')"
else
  fail "P00 key_files deduped (expected 'scripts/foo.sh,scripts/bar.sh,scripts/baz.sh', got '$key_files')"
fi

# requires: P00 Depends: none in roadmap → expect "none" regardless of T-task content.
if [[ "$requires" = "none" ]]; then
  pass "P00 requires=none (from roadmap Depends, not task IDs)"
else
  fail "P00 requires=none from roadmap (got '$requires')"
fi

# affects: phases that Depend on P00 → P01, P02, P03, P06.
if [[ "$affects" = "P01,P02,P03,P06" ]]; then
  pass "P00 affects=P01,P02,P03,P06 (roadmap reverse-Depends)"
else
  fail "P00 affects=P01,P02,P03,P06 from roadmap (got '$affects')"
fi

rm -f "$out_p00"

# --- Run phase-transition.sh on P02 (Depends: P00, P01) ---
out_p02=$(mktemp)
bash "$PT" "$FIXTURE" P02 --output-file="$out_p02" >/dev/null 2>&1 || true

requires_p02=$(grep '^requires=' "$out_p02" | sed 's/^requires=//')
affects_p02=$(grep '^affects=' "$out_p02" | sed 's/^affects=//')

if [[ "$requires_p02" = "P00,P01" ]]; then
  pass "P02 requires=P00,P01 (roadmap-derived)"
else
  fail "P02 requires=P00,P01 (got '$requires_p02')"
fi

# Nothing depends on P02 in this roadmap → "none".
if [[ "$affects_p02" = "none" ]]; then
  pass "P02 affects=none (no phase Depends: P02)"
else
  fail "P02 affects=none (got '$affects_p02')"
fi

rm -f "$out_p02"

# --- read-roadmap.sh affects query direct test ---
roadmap="$FIXTURE/M999-ROADMAP.md"
read_roadmap="$PROJECT_ROOT/scripts/state/read-roadmap.sh"

aff_p00=$(bash "$read_roadmap" "$roadmap" affects P00)
if [[ "$aff_p00" = "P01,P02,P03,P06" ]]; then
  pass "read-roadmap affects P00 returns dependents in declaration order"
else
  fail "read-roadmap affects P00 (expected 'P01,P02,P03,P06', got '$aff_p00')"
fi

aff_p06=$(bash "$read_roadmap" "$roadmap" affects P06)
if [[ "$aff_p06" = "none" ]]; then
  pass "read-roadmap affects P06 returns 'none' when no dependents"
else
  fail "read-roadmap affects P06 (expected 'none', got '$aff_p06')"
fi

# Missing arg → exits non-zero with stderr message.
err_capture=$(mktemp)
if bash "$read_roadmap" "$roadmap" affects 2>"$err_capture"; then
  fail "read-roadmap affects without arg should exit non-zero"
else
  if grep -q "requires a phase ID" "$err_capture"; then
    pass "read-roadmap affects without arg fails loud with phase-ID hint"
  else
    fail "read-roadmap affects without arg emits phase-ID hint to stderr (got: '$(cat "$err_capture")')"
  fi
fi
rm -f "$err_capture"

echo "----"
echo "PASS: $PASS_COUNT  FAIL: $FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
