#!/usr/bin/env bash
# tools/verify/m037-p02-feedback-routing.sh — M037 P02 T01 FR-18 verifier.
#
# Asserts:
#  1. scripts/wiki/wiki-scan-sources.sh contains the literal strings
#     "feedback:" (record-emit prefix) and "INCLUDE_FEEDBACK" (env override).
#  2. scripts/wiki/wiki-generate-stubs.sh contains the literal strings
#     "feedback:*)" (case arm) and "existing_stub_is_protected" (MIT-01/02
#     escape-hatch helper consumed, not forked).
#  3. tests/m037-acceptance/p01-feedback-routing.sh exists and exits 0
#     against the fixture corpus under tests/fixtures/m037-feedback-routing/.
#
# AD-19 compliant: invokes the acceptance test via `bash <path>` only.
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SCANNER="$PROJECT_ROOT/scripts/wiki/wiki-scan-sources.sh"
STUBS="$PROJECT_ROOT/scripts/wiki/wiki-generate-stubs.sh"
ACCEPT="$PROJECT_ROOT/tests/m037-acceptance/p01-feedback-routing.sh"

pass=0
fail=0

ok() {
  printf 'PASS: %s\n' "$1"
  pass=$((pass + 1))
}

bad() {
  printf 'FAIL: %s\n' "$1"
  fail=$((fail + 1))
}

# 1. Scanner literal markers.
if [ -f "$SCANNER" ]; then
  ok "scripts/wiki/wiki-scan-sources.sh exists"
else
  bad "scripts/wiki/wiki-scan-sources.sh missing"
  printf 'SUMMARY: m037-p02-feedback-routing pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

if grep -q 'feedback:' "$SCANNER"; then
  ok "scanner contains literal 'feedback:' record prefix"
else
  bad "scanner missing 'feedback:' record prefix"
fi

if grep -q 'INCLUDE_FEEDBACK' "$SCANNER"; then
  ok "scanner contains INCLUDE_FEEDBACK env override"
else
  bad "scanner missing INCLUDE_FEEDBACK env override"
fi

# 2. Stub generator routing arm + MIT-01/02 helper consumption.
if [ -f "$STUBS" ]; then
  ok "scripts/wiki/wiki-generate-stubs.sh exists"
else
  bad "scripts/wiki/wiki-generate-stubs.sh missing"
  printf 'SUMMARY: m037-p02-feedback-routing pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

if grep -q 'feedback:\*)' "$STUBS"; then
  ok "stubs.sh contains feedback:*) case arm"
else
  bad "stubs.sh missing feedback:*) case arm"
fi

if grep -q 'existing_stub_is_protected' "$STUBS"; then
  ok "stubs.sh references existing_stub_is_protected helper (MIT-01/02 inheritance)"
else
  bad "stubs.sh missing existing_stub_is_protected reference"
fi

# 3. Acceptance test present + executable.
if [ -f "$ACCEPT" ]; then
  ok "tests/m037-acceptance/p01-feedback-routing.sh exists"
else
  bad "tests/m037-acceptance/p01-feedback-routing.sh missing"
  printf 'SUMMARY: m037-p02-feedback-routing pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# 4. Acceptance test passes end-to-end.
if bash "$ACCEPT" >/dev/null 2>&1; then
  ok "p01-feedback-routing.sh exits 0 against fixture corpus"
else
  bad "p01-feedback-routing.sh exits non-zero — run directly for diagnostic output"
fi

printf 'SUMMARY: m037-p02-feedback-routing pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
