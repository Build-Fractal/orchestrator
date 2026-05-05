#!/usr/bin/env bash
# m033-p01-pbj-fixture-readme-oracle.sh
#
# Verifies the M033/P01/T01 PBJ fixture README ground-truth oracle.
# Asserts the README exists; that exactly five numbered list entries
# (lines starting `1. `..`5. `) are present; that each entry contains
# exactly one CON-4 category token from the closed enum
# `id-misalignment | scheme-contradiction | orphan-reference`; that
# across the 5 entries each of the three categories appears at least
# once (FR-23); and that the required README section headers are
# present.
#
# Emits PASS:/FAIL: lines per assertion and a final SUMMARY: line.
# Exit 0 iff all assertions PASS.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
README="${REPO_ROOT}/tests/fixtures/m033-pbj-materials-fixture/README.md"
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

if [ ! -f "$README" ]; then
  fail "README missing: $README"
  echo "SUMMARY: m033-p01-pbj-fixture-readme-oracle.sh pass=${PASS_COUNT} fail=${FAIL_COUNT}"
  exit 1
fi

pass "README exists"

# Required headers
HEADERS="# m033 PBJ Materials Fixture
## Purpose
## Inconsistencies (Ground-Truth Oracle)
## Determinism Guarantee
## Consumers"

while IFS= read -r header; do
  if [ -z "$header" ]; then
    continue
  fi
  if grep -F -q -- "$header" "$README"; then
    pass "header present: $header"
  else
    fail "header missing: $header"
  fi
done <<EOF
$HEADERS
EOF

# Numbered list entries: lines starting `^[1-5]\. `
ENTRY_COUNT=0
ID_MIS=0
SCHEME=0
ORPHAN=0

# Collect the five oracle entries into temp variables, one per slot.
ENTRY_1=""
ENTRY_2=""
ENTRY_3=""
ENTRY_4=""
ENTRY_5=""

while IFS= read -r line; do
  case "$line" in
    "1. "*) ENTRY_1="$line" ;;
    "2. "*) ENTRY_2="$line" ;;
    "3. "*) ENTRY_3="$line" ;;
    "4. "*) ENTRY_4="$line" ;;
    "5. "*) ENTRY_5="$line" ;;
  esac
done < "$README"

check_entry() {
  local n="$1"
  local entry="$2"
  if [ -z "$entry" ]; then
    fail "numbered entry $n. missing"
    return
  fi
  pass "numbered entry $n. present"
  ENTRY_COUNT=$((ENTRY_COUNT + 1))
  local hits=0
  case "$entry" in
    *id-misalignment*)
      hits=$((hits + 1))
      ID_MIS=$((ID_MIS + 1))
      ;;
  esac
  case "$entry" in
    *scheme-contradiction*)
      hits=$((hits + 1))
      SCHEME=$((SCHEME + 1))
      ;;
  esac
  case "$entry" in
    *orphan-reference*)
      hits=$((hits + 1))
      ORPHAN=$((ORPHAN + 1))
      ;;
  esac
  if [ "$hits" -eq 1 ]; then
    pass "entry $n. has exactly one CON-4 category token"
  else
    fail "entry $n. has $hits CON-4 category tokens (need exactly 1)"
  fi
}

check_entry 1 "$ENTRY_1"
check_entry 2 "$ENTRY_2"
check_entry 3 "$ENTRY_3"
check_entry 4 "$ENTRY_4"
check_entry 5 "$ENTRY_5"

if [ "$ENTRY_COUNT" -eq 5 ]; then
  pass "exactly 5 numbered oracle entries present"
else
  fail "found $ENTRY_COUNT numbered oracle entries (need exactly 5)"
fi

if [ "$ID_MIS" -ge 1 ]; then
  pass "id-misalignment category appears (count=$ID_MIS)"
else
  fail "id-misalignment category missing"
fi

if [ "$SCHEME" -ge 1 ]; then
  pass "scheme-contradiction category appears (count=$SCHEME)"
else
  fail "scheme-contradiction category missing"
fi

if [ "$ORPHAN" -ge 1 ]; then
  pass "orphan-reference category appears (count=$ORPHAN)"
else
  fail "orphan-reference category missing"
fi

echo "SUMMARY: m033-p01-pbj-fixture-readme-oracle.sh pass=${PASS_COUNT} fail=${FAIL_COUNT}"

if [ "$FAIL_COUNT" -eq 0 ]; then
  exit 0
else
  exit 1
fi
