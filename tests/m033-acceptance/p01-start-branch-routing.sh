#!/usr/bin/env bash
set -e -u -o pipefail

# SC-1: M033 P01 branch-routing acceptance test.
# Asserts FR-1 (start-command-skeleton) + FR-2 (branch-detection-rules)
# against six fixture shapes covering US-1 / FR-1 / FR-2.
#
# Invokes scripts/lifecycle/start.sh against six staged fixtures and
# verifies branch-detection output, sub-flow stub dispatch, the
# MIT-006 / RISK-006 disambiguation case, and idempotent re-invocation.

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STAGING_BASE="$(mktemp -d)/m033-p01-sc1-$$"
mkdir -p "$STAGING_BASE"

cleanup() { rm -rf "$STAGING_BASE"; }
trap cleanup EXIT

pass=0
fail=0

pass() { pass=$((pass+1)); echo "PASS: $1"; }
fail() { fail=$((fail+1)); echo "FAIL: $1" >&2; }

# Helpers: stage fixture-N at a temp dir, populate it per the requested shape.
make_fixture_1_greenfield_empty() {
  local d="$STAGING_BASE/fix1"
  mkdir -p "$d"
  echo "$d"
}

make_fixture_2_greenfield_with_materials() {
  local d="$STAGING_BASE/fix2"
  mkdir -p "$d"
  printf 'placeholder\n' > "$d/PRODUCT-BRIEF.md"
  printf 'placeholder\n' > "$d/MVP-PLAN.md"
  printf 'placeholder\n' > "$d/DECISIONS.md"
  echo "$d"
}

make_fixture_3_existing_codebase() {
  local d="$STAGING_BASE/fix3"
  mkdir -p "$d/src"
  printf '{}\n' > "$d/package.json"
  printf 'export const x = 1;\n' > "$d/src/index.ts"
  git -C "$d" init -q
  git -C "$d" add -A
  git -C "$d" -c user.email=fixture@example.com -c user.name=fixture commit -q -m initial
  echo "$d"
}

make_fixture_4_migrating() {
  local d="$STAGING_BASE/fix4"
  mkdir -p "$d/.gsd"
  printf 'version: 1\n' > "$d/.gsd/v1-roadmap.yml"
  echo "$d"
}

make_fixture_5_ambiguous() {
  local d="$STAGING_BASE/fix5"
  mkdir -p "$d/src" "$d/.gsd"
  printf '{}\n' > "$d/package.json"
  printf 'version: 1\n' > "$d/.gsd/v1-roadmap.yml"
  echo "$d"
}

make_fixture_6_mit006() {
  local d="$STAGING_BASE/fix6"
  mkdir -p "$d"
  printf 'export const x = 1;\n' > "$d/index.ts"
  git -C "$d" init -q
  git -C "$d" add -A
  git -C "$d" -c user.email=fixture@example.com -c user.name=fixture commit -q -m initial
  echo "$d"
}

# Test 1: greenfield-empty
f1=$(make_fixture_1_greenfield_empty)
out1=$(cd "$PROJECT_ROOT" && bash scripts/lifecycle/start.sh --project-dir "$f1" --yes --dry-run 2>&1) || fail "fixture-1 start failed"
echo "$out1" | grep -q '^branch: greenfield-empty' && pass "fixture-1 detects greenfield-empty" || fail "fixture-1 wrong branch"
echo "$out1" | grep -q 'would-execute: ideation-stub' && pass "fixture-1 dispatches ideation-stub" || fail "fixture-1 wrong stub"

# Test 2: greenfield-with-materials
f2=$(make_fixture_2_greenfield_with_materials)
out2=$(cd "$PROJECT_ROOT" && bash scripts/lifecycle/start.sh --project-dir "$f2" --yes --dry-run 2>&1) || fail "fixture-2 start failed"
echo "$out2" | grep -q '^branch: greenfield-with-materials' && pass "fixture-2 detects greenfield-with-materials" || fail "fixture-2 wrong branch"
echo "$out2" | grep -q 'would-execute: materials-intake-stub' && pass "fixture-2 dispatches materials-intake-stub" || fail "fixture-2 wrong stub"

# Test 3: existing-codebase
f3=$(make_fixture_3_existing_codebase)
out3=$(cd "$PROJECT_ROOT" && bash scripts/lifecycle/start.sh --project-dir "$f3" --yes --dry-run 2>&1) || fail "fixture-3 start failed"
echo "$out3" | grep -q '^branch: existing-codebase' && pass "fixture-3 detects existing-codebase" || fail "fixture-3 wrong branch"
echo "$out3" | grep -q 'would-execute: ingest-codebase-stub' && pass "fixture-3 dispatches ingest-codebase-stub" || fail "fixture-3 wrong stub"

# Test 4: migrating
f4=$(make_fixture_4_migrating)
out4=$(cd "$PROJECT_ROOT" && bash scripts/lifecycle/start.sh --project-dir "$f4" --yes --dry-run 2>&1) || fail "fixture-4 start failed"
echo "$out4" | grep -q '^branch: migrating' && pass "fixture-4 detects migrating" || fail "fixture-4 wrong branch"
echo "$out4" | grep -q 'would-execute: migrate-routing-stub' && pass "fixture-4 dispatches migrate-routing-stub" || fail "fixture-4 wrong stub"
echo "$out4" | grep -q -- '--from gsd-v1' && pass "fixture-4 pre-fills --from gsd-v1" || fail "fixture-4 wrong --from"

# Test 5: ambiguous (rule-1 + rule-3) — disambiguation question fires without --yes
f5=$(make_fixture_5_ambiguous)
out5=$(cd "$PROJECT_ROOT" && printf 'y\n' | bash scripts/lifecycle/start.sh --project-dir "$f5" --dry-run 2>&1) || true
echo "$out5" | grep -q 'disambiguation:' && pass "fixture-5 fires disambiguation question" || fail "fixture-5 missing disambiguation"
echo "$out5" | grep -q 'recommended:' && pass "fixture-5 recommendation present" || fail "fixture-5 missing recommendation"

# Test 6: MIT-006 / RISK-006 (git-init-only, ≤9 source files)
f6=$(make_fixture_6_mit006)
out6=$(cd "$PROJECT_ROOT" && printf 'y\n' | bash scripts/lifecycle/start.sh --project-dir "$f6" --dry-run 2>&1) || true
echo "$out6" | grep -q 'MIT-006' && pass "fixture-6 fires MIT-006 disambiguation" || fail "fixture-6 missing MIT-006"
echo "$out6" | grep -q 'recommended: greenfield-empty' && pass "fixture-6 recommends greenfield-empty" || fail "fixture-6 wrong MIT-006 recommendation"

# Idempotency: re-run against fixture-1, assert "init already complete"
out1b=$(cd "$PROJECT_ROOT" && bash scripts/lifecycle/start.sh --project-dir "$f1" --yes --dry-run 2>&1) || fail "fixture-1 re-run failed"
echo "$out1b" | grep -q 'init already complete' && pass "fixture-1 second run idempotent" || fail "fixture-1 second run not idempotent"

echo "SUMMARY: p01-start-branch-routing.sh pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
