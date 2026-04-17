#!/usr/bin/env bash
# scripts/verify/m021-p01-read-range.sh — Gate for scripts/util/read-range.sh
# Exits 0 when all assertions hold, 1 otherwise.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WRAPPER="${REPO_ROOT}/scripts/util/read-range.sh"

fail_count=0

assert_eq() {
  if [ "$2" = "$3" ]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 (expected=$2 actual=$3)"
    fail_count=$((fail_count + 1))
  fi
}

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

# Build a 10-line fixture.
i=1
while [ "$i" -le 10 ]; do
  printf "line-%s\n" "$i" >> "$tmp"
  i=$((i + 1))
done

# 1. Happy path: lines 3..5.
got=$(bash "$WRAPPER" "$tmp" 3 5)
want=$(printf "line-3\nline-4\nline-5")
assert_eq "reads lines 3..5" "$want" "$got"

# 2. Single-line range: line 1.
got=$(bash "$WRAPPER" "$tmp" 1 1)
assert_eq "reads single line 1..1" "line-1" "$got"

# 3. Missing file: exit 1.
bash "$WRAPPER" /no/such/file 1 5 >/dev/null 2>&1
rc=$?
assert_eq "missing file exits 1" "1" "$rc"

# 4. Inverted range: exit 2.
bash "$WRAPPER" "$tmp" 5 3 >/dev/null 2>&1
rc=$?
assert_eq "inverted range exits 2" "2" "$rc"

# 5. Out-of-file range: exit 2.
bash "$WRAPPER" "$tmp" 5 9999 >/dev/null 2>&1
rc=$?
assert_eq "out-of-file range exits 2" "2" "$rc"

# 6. Non-integer arg: exit 2.
bash "$WRAPPER" "$tmp" abc 5 >/dev/null 2>&1
rc=$?
assert_eq "non-integer M exits 2" "2" "$rc"

# 7. Missing args: exit 2.
bash "$WRAPPER" "$tmp" 3 >/dev/null 2>&1
rc=$?
assert_eq "missing N arg exits 2" "2" "$rc"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p01-read-range.sh"
  exit 0
fi
echo "FAIL: m021-p01-read-range.sh ($fail_count failures)"
exit 1
