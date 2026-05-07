#!/usr/bin/env bash
# tests/m037-acceptance/run-acceptance-battery.sh — M037 acceptance battery
# aggregator (SC-12 scaffold, P01 portion).
#
# Iterates `tests/m037-acceptance/p01-*.sh`, captures exit codes, and prints a
# `BATTERY: pass=N skip=M fail=K` summary line at end. Exits 0 only when
# fail=0. P02 will append a parallel iteration over `p02-*.sh` plus the SC-10
# strict-build smoke and the SC-11 PBJ-update evidence; OUT OF SCOPE here.
#
# Phase artifact contract: this script is >= 20 lines and contains the literal
# string "BATTERY: pass=" (M037 P01 plan must-have).
# Bash 3.2 + POSIX sh compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

P0X_GLOB="$SCRIPT_DIR/p0[0-9]-*.sh"

pass=0
skip=0
fail=0

# shellcheck disable=SC2206  # word-splitting is desired for glob expansion
P0X_TESTS=( $P0X_GLOB )

# When the glob fails to expand (no p0*-*.sh files), bash leaves the literal
# pattern in the array. Detect and treat as zero tests.
if [ "${#P0X_TESTS[@]}" -eq 1 ] && [ ! -f "${P0X_TESTS[0]}" ]; then
  printf 'WARN: no p0[0-9]-*.sh tests found at %s\n' "$P0X_GLOB" >&2
  P0X_TESTS=()
fi

for t in "${P0X_TESTS[@]}"; do
  test_name="$(basename "$t")"
  printf -- '--- %s ---\n' "$test_name"
  if [ ! -x "$t" ] && [ ! -r "$t" ]; then
    printf 'SKIP: %s (not readable)\n' "$test_name"
    skip=$((skip + 1))
    continue
  fi
  set +e
  bash "$t"
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    printf 'OK: %s (rc=0)\n\n' "$test_name"
    pass=$((pass + 1))
  else
    printf 'FAIL: %s (rc=%d)\n\n' "$test_name" "$rc"
    fail=$((fail + 1))
  fi
done

# M037/P02/T05 — explicit invocation of verbatim handoff-doc test scaffolds.
# These tests live at the test-tree root (not under tests/m037-acceptance/)
# so they are not picked up by the p01-*.sh glob; invoke explicitly to
# include in the battery total.
for explicit_test in \
  "$PROJECT_ROOT/tests/test-wiki-init-workflow-mode.sh" \
  "$PROJECT_ROOT/tests/test-wiki-init-private-site-url.sh"; do
  test_name="$(basename "$explicit_test")"
  if [ ! -f "$explicit_test" ]; then
    printf 'SKIP: %s (not present)\n' "$test_name"
    skip=$((skip + 1))
    continue
  fi
  printf -- '--- %s ---\n' "$test_name"
  set +e
  bash "$explicit_test"
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    printf 'OK: %s (rc=0)\n\n' "$test_name"
    pass=$((pass + 1))
  else
    printf 'FAIL: %s (rc=%d)\n\n' "$test_name" "$rc"
    fail=$((fail + 1))
  fi
done

printf 'BATTERY: pass=%d skip=%d fail=%d\n' "$pass" "$skip" "$fail"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
exit 0
