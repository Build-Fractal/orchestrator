#!/usr/bin/env bash
# tests/test-conversus-provider-error-guard.sh — Group 3 / paper-cut sweep
#
# Bug: scripts/dispatch/adapters/tool/conversus.sh::_parse_verdict extracted
# the verdict from gate-result.md without validating that per-agent artifacts
# contained real deliberation content. Conversus 0.3.0 has a known
# correctness bug where unreachable model IDs synthesize stub error-string
# content that gets returned as PASS-by-empty.
#
# Fix: defensive grep for known SDK-error sentinels in gate-result.md (and
# per-agent artifacts under conversus_output_dir) BEFORE parsing the verdict.
# On match emit FAIL: and exit 1.
#
# This test stages two fixtures:
#   - gate-result-stub.md: contains the known sentinel; parse-verdict MUST
#     refuse with exit 1 + FAIL: substring.
#   - gate-result-clean.md: clean output; parse-verdict MUST return verdict=PASS.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ADAPTER="$PROJECT_ROOT/scripts/dispatch/adapters/tool/conversus.sh"
FIXTURE_DIR="$PROJECT_ROOT/tests/fixtures/conversus-provider-error"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1"; }

# --- Test 1: stub gate-result triggers refusal ---
stub_out_file="$(mktemp -t conversus-pe-stub.XXXXXX)"
trap 'rm -f "$stub_out_file"' EXIT
bash "$ADAPTER" parse-verdict "$FIXTURE_DIR/gate-result-stub.md" >"$stub_out_file" 2>&1 && rc_stub=$? || rc_stub=$?
if [[ "$rc_stub" -ne 0 ]] && grep -qE 'FAIL: conversus produced provider-error stub content' "$stub_out_file"; then
  pass "stub gate-result is refused with FAIL: substring (rc=$rc_stub)"
else
  fail "stub gate-result should be refused (rc=$rc_stub, output: $(cat "$stub_out_file"))"
fi

# --- Test 2: clean gate-result returns verdict=PASS ---
clean_out_file="$(mktemp -t conversus-pe-clean.XXXXXX)"
bash "$ADAPTER" parse-verdict "$FIXTURE_DIR/gate-result-clean.md" >"$clean_out_file" 2>&1 && rc_clean=$? || rc_clean=$?
if [[ "$rc_clean" -eq 0 ]] && grep -qE '^verdict=PASS$' "$clean_out_file"; then
  pass "clean gate-result returns verdict=PASS (rc=$rc_clean)"
else
  fail "clean gate-result should return verdict=PASS (rc=$rc_clean, output: $(cat "$clean_out_file"))"
fi
rm -f "$clean_out_file"

echo "----"
echo "PASS: $PASS_COUNT  FAIL: $FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
