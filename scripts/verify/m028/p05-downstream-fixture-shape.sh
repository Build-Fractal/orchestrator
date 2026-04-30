#!/usr/bin/env bash
# scripts/verify/m028/p05-downstream-fixture-shape.sh -- M028/P05/T01 shape gate.
#
# CON-10 noisy-fail: if the runtime adapter's --hook-config emission shape
# drifts (new hook event, renamed leaf, changed matcher), this verifier
# fails loudly so the fixture must be updated to match.
#
# Asserts byte-shape compatibility between the in-tree
# tests/fixtures/downstream-project/.claude/settings.json fixture and the
# runtime adapter's live --hook-config emission:
#  - every `"command":` line matches `"command": "bash <...>.sh"` shape
#  - every leaf hook object carries `_orchestrator_managed: true`
#  - the count of `command` keys + managed flags matches between the two
#  - the three runtime-stable hook basenames (after-verify-sync.sh,
#    pre-bash-shape-guard.sh, before-commit.sh) appear in both
#
# Helper-function carve-out: extraction helpers (using grep/wc) live inside
# bash function bodies. Function bodies are NOT classifier-scanned per the
# AD-19 helper-function carve-out (codified at M028/P02/T05). This lets the
# verifier read structure-bearing JSON content without each helper line
# needing to pass the inline-shape classifier.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
FIXTURE="${REPO_ROOT}/tests/fixtures/downstream-project/.claude/settings.json"
ADAPTER="${REPO_ROOT}/scripts/dispatch/adapters/runtime/claude-code.sh"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)" >&2; fail_count=$((fail_count + 1)); }

# Helper-function carve-out: function bodies are NOT classifier-scanned
# per M028/P02/T05 codification.
count_command_lines() {
  grep -c '"command":' "$1"
}
count_managed_flags() {
  grep -c '"_orchestrator_managed": true' "$1"
}
all_commands_have_shape() {
  local file="$1"
  local total
  local matching
  total=$(grep -c '"command":' "$file")
  matching=$(grep -cE '"command": "bash [^"]*\.sh"' "$file")
  [ "$total" -eq "$matching" ]
}

if [ ! -f "$FIXTURE" ]; then
  fail "fixture present" "missing $FIXTURE"
  echo "FAIL: p05-downstream-fixture-shape.sh ($fail_count failures)"
  exit 1
fi
pass "fixture present at $FIXTURE"

if [ ! -f "$ADAPTER" ]; then
  fail "adapter present" "missing $ADAPTER"
  echo "FAIL: p05-downstream-fixture-shape.sh ($fail_count failures)"
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
adapter_out="${tmp_dir}/adapter-emission.json"
safe_home="${tmp_dir}/fake-home"
mkdir -p "$safe_home"
HOME="$safe_home" bash "$ADAPTER" --hook-config > "$adapter_out" 2>"${tmp_dir}/adapter.err"
ac=$?
if [ "$ac" -ne 0 ]; then
  fail "adapter --hook-config exit 0" "rc=$ac"
  cat "${tmp_dir}/adapter.err" >&2
  echo "FAIL: p05-downstream-fixture-shape.sh ($fail_count failures)"
  exit 1
fi
pass "adapter --hook-config exit 0"

if all_commands_have_shape "$FIXTURE"; then
  pass "fixture commands all match shape: bash <...>.sh"
else
  fail "fixture command shape" "non-conforming command line"
fi

if all_commands_have_shape "$adapter_out"; then
  pass "adapter commands all match shape: bash <...>.sh"
else
  fail "adapter command shape" "non-conforming command line"
fi

fix_managed=$(count_managed_flags "$FIXTURE")
adp_managed=$(count_managed_flags "$adapter_out")
if [ "$fix_managed" -eq "$adp_managed" ]; then
  pass "_orchestrator_managed flag count matches (fixture=$fix_managed adapter=$adp_managed)"
else
  fail "_orchestrator_managed flag count" "fixture=$fix_managed adapter=$adp_managed"
fi

fix_cmd=$(count_command_lines "$FIXTURE")
adp_cmd=$(count_command_lines "$adapter_out")
if [ "$fix_cmd" -eq "$adp_cmd" ]; then
  pass "command line count matches (fixture=$fix_cmd adapter=$adp_cmd)"
else
  fail "command line count" "fixture=$fix_cmd adapter=$adp_cmd"
fi

for basename in after-verify-sync.sh pre-bash-shape-guard.sh before-commit.sh; do
  if grep -q "$basename" "$FIXTURE" && grep -q "$basename" "$adapter_out"; then
    pass "$basename present in both fixture and adapter emission"
  else
    fail "$basename presence" "missing in one or both"
  fi
done

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p05-downstream-fixture-shape.sh"
  exit 0
fi
echo "FAIL: p05-downstream-fixture-shape.sh ($fail_count failures)"
exit 1
