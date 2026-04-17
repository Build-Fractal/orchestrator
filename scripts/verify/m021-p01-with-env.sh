#!/usr/bin/env bash
# scripts/verify/m021-p01-with-env.sh — Gate for scripts/util/with-env.sh
# Exits 0 when all assertions hold, 1 otherwise.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WRAPPER="${REPO_ROOT}/scripts/util/with-env.sh"

fail_count=0

assert_eq() {
  # $1 = label, $2 = expected, $3 = actual
  if [ "$2" = "$3" ]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 (expected=$2 actual=$3)"
    fail_count=$((fail_count + 1))
  fi
}

# 1. Happy path: KEY is exported into the child and passed through.
got=$(bash "$WRAPPER" FOO=bar -- bash -c 'printf "%s" "$FOO"')
assert_eq "exports single KEY=VALUE into child" "bar" "$got"

# 2. Multiple assignments.
got=$(bash "$WRAPPER" A=1 B=2 -- bash -c 'printf "%s-%s" "$A" "$B"')
assert_eq "exports multiple KEY=VALUE pairs" "1-2" "$got"

# 3. Child RC is forwarded.
bash "$WRAPPER" X=y -- bash -c 'exit 7'
rc=$?
assert_eq "forwards child exit code" "7" "$rc"

# 4. Missing `--` separator: exit 2.
bash "$WRAPPER" FOO=bar bash -c 'true' >/dev/null 2>&1
rc=$?
assert_eq "missing -- separator exits 2" "2" "$rc"

# 5. No command after `--`: exit 2.
bash "$WRAPPER" FOO=bar -- >/dev/null 2>&1
rc=$?
assert_eq "empty command after -- exits 2" "2" "$rc"

# 6. Malformed assignment: exit 2.
bash "$WRAPPER" 'not an assignment' -- bash -c 'true' >/dev/null 2>&1
rc=$?
assert_eq "malformed assignment exits 2" "2" "$rc"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p01-with-env.sh"
  exit 0
fi
echo "FAIL: m021-p01-with-env.sh ($fail_count failures)"
exit 1
