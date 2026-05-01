#!/usr/bin/env bash
# tools/verify/m031-p04-test-auto-proceed-shape.sh
#
# M031/P04/T01 shape verifier for the SC-10 auto-proceed-default test
# source (Truth #8 — asserts the test exists, is executable, and
# references the template + CHANGELOG).
#
# Required substrings inside the SC-10 test source:
#   - "SC-10"               (envelope identifier)
#   - "auto_proceed"        (target knob name)
#   - "CHANGELOG"           (CHANGELOG file reference — uppercase used
#                            in the test's path resolution)
#   - "orchestrator-config-default.yml" (template file reference)
#
# AD-19 single-script-file shape. Bash 3.2 + MEM001 compatible.
#
# Output: per-check PASS/FAIL lines + final SUMMARY: line.
# Exit 0 iff fail=0.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

target="$PROJECT_ROOT/tests/m031-acceptance/test-auto-proceed-default.sh"

pass=0
fail=0

ok() {
    pass=$(( pass + 1 ))
    printf 'PASS: %s\n' "$1"
}
ng() {
    fail=$(( fail + 1 ))
    printf 'FAIL: %s\n' "$1"
}

# 1) Existence.
if [ -f "$target" ]; then
    ok "test-auto-proceed-default.sh exists"
else
    ng "test-auto-proceed-default.sh missing at $target"
    printf 'SUMMARY: m031-p04-test-auto-proceed-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2) Executable.
if [ -x "$target" ]; then
    ok "test-auto-proceed-default.sh executable"
else
    ng "test-auto-proceed-default.sh not executable"
fi

check_literal() {
    local label="$1"
    local needle="$2"
    if grep -qF -- "$needle" "$target"; then
        ok "$label literal present"
    else
        ng "$label literal missing ($needle)"
    fi
}

check_literal "SC-10 envelope"                  "SC-10"
check_literal "auto_proceed knob reference"     "auto_proceed"
check_literal "CHANGELOG reference"             "CHANGELOG"
check_literal "template reference"              "orchestrator-config-default.yml"

printf 'SUMMARY: m031-p04-test-auto-proceed-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
