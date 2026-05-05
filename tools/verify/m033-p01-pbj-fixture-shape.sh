#!/usr/bin/env bash
# m033-p01-pbj-fixture-shape.sh
#
# Verifies the M033/P01/T01 PBJ-shape acceptance fixture lives at the
# expected path with the four required documents, that no `src/` or
# `.git/` directory is present (so FR-2 rule-2 fires cleanly), that
# each document meets the minimum line count from the task plan
# artifacts list, and that the required content tokens are present.
#
# Emits PASS:/FAIL: lines per assertion and a final SUMMARY: line.
# Exit 0 iff all assertions PASS.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIX_DIR="${REPO_ROOT}/tests/fixtures/m033-pbj-materials-fixture"
PASS_COUNT=0
FAIL_COUNT=0

pass() {
  echo "PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "FAIL: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

assert_file() {
  local path="$1"
  if [ -f "$path" ]; then
    pass "file exists: $path"
  else
    fail "file missing: $path"
  fi
}

assert_no_dir() {
  local path="$1"
  if [ -d "$path" ]; then
    fail "forbidden dir present: $path"
  else
    pass "forbidden dir absent: $path"
  fi
}

assert_min_lines() {
  local path="$1"
  local min="$2"
  if [ ! -f "$path" ]; then
    fail "min-lines: missing file $path"
    return
  fi
  local n
  n=$(wc -l < "$path" | tr -d ' ')
  if [ "$n" -ge "$min" ]; then
    pass "min-lines >=$min ($n) in $path"
  else
    fail "min-lines: $path has $n lines, need >=$min"
  fi
}

assert_grep() {
  local path="$1"
  local pattern="$2"
  if [ ! -f "$path" ]; then
    fail "grep: missing file $path"
    return
  fi
  if grep -q -- "$pattern" "$path"; then
    pass "token present in $(basename "$path"): $pattern"
  else
    fail "token missing in $(basename "$path"): $pattern"
  fi
}

# Required documents
PB="${FIX_DIR}/PRODUCT-BRIEF.md"
MP="${FIX_DIR}/MVP-PLAN.md"
DC="${FIX_DIR}/DECISIONS.md"
MA="${FIX_DIR}/MILESTONE-AUDIT.md"

assert_file "$PB"
assert_file "$MP"
assert_file "$DC"
assert_file "$MA"

# Forbidden dirs (FR-2 rule-2 cleanliness)
assert_no_dir "${FIX_DIR}/src"
assert_no_dir "${FIX_DIR}/.git"

# Minimum line counts per task plan
assert_min_lines "$PB" 25
assert_min_lines "$MP" 25
assert_min_lines "$DC" 20
assert_min_lines "$MA" 20

# PRODUCT-BRIEF tokens
assert_grep "$PB" "## Problem"
assert_grep "$PB" "## Target User"
assert_grep "$PB" "US-"
assert_grep "$PB" "US-3"
assert_grep "$PB" "MVP timeline: 4 weeks"
assert_grep "$PB" "DR-001"
assert_grep "$PB" "DR-002"

# MVP-PLAN tokens
assert_grep "$MP" "## User Stories"
assert_grep "$MP" "US-"
assert_grep "$MP" "MVP timeline: 6 weeks"
assert_grep "$MP" "Cloudflare Workers"

# DECISIONS tokens
assert_grep "$DC" "DR-"
assert_grep "$DC" "DR-001"
assert_grep "$DC" "DR-002"
assert_grep "$DC" "DR-003"
assert_grep "$DC" "Deploy via Vercel"

# MILESTONE-AUDIT tokens
assert_grep "$MA" "M-"
assert_grep "$MA" "M-1"
assert_grep "$MA" "M-2"
assert_grep "$MA" "M-3"

echo "SUMMARY: m033-p01-pbj-fixture-shape.sh pass=${PASS_COUNT} fail=${FAIL_COUNT}"

if [ "$FAIL_COUNT" -eq 0 ]; then
  exit 0
else
  exit 1
fi
