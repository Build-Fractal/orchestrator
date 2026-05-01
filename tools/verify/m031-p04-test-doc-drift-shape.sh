#!/usr/bin/env bash
# tools/verify/m031-p04-test-doc-drift-shape.sh
#
# M031/P04/T01 shape verifier for the SC-9 doc-drift test source itself
# (Truth #7 — asserts the test exists, is executable, and contains its
# own needle inventory).
#
# This shape verifier reads only the SC-9 test source, NOT the
# production target files. The production target absence-checks are
# left to the SC-9 verifier itself (tests/m031-acceptance/doc-drift-verifier.sh).
#
# Required substrings inside the SC-9 test source:
#   - "SC-9"                                   (envelope identifier)
#   - "evaluate.md"                            (target file name)
#   - "tier-definitions.md"                    (target file name)
#   - "no orchestrator overhead"               (prohibited phrasing needle)
#   - "Do NOT create any orchestrator directory" (prohibited phrasing needle)
#   - "Quick profile"                          (canonical descriptor needle)
#
# AD-19 single-script-file shape. Bash 3.2 + MEM001 compatible.
#
# Output: per-check PASS/FAIL lines + final SUMMARY: line.
# Exit 0 iff fail=0.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

target="$PROJECT_ROOT/tests/m031-acceptance/doc-drift-verifier.sh"

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
    ok "doc-drift-verifier.sh exists"
else
    ng "doc-drift-verifier.sh missing at $target"
    printf 'SUMMARY: m031-p04-test-doc-drift-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2) Executable.
if [ -x "$target" ]; then
    ok "doc-drift-verifier.sh executable"
else
    ng "doc-drift-verifier.sh not executable"
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

check_literal "SC-9 envelope"                            "SC-9"
check_literal "evaluate.md target reference"             "evaluate.md"
check_literal "tier-definitions.md target reference"     "tier-definitions.md"
check_literal "no orchestrator overhead needle"          "no orchestrator overhead"
check_literal "Do NOT create any orchestrator directory needle" "Do NOT create any orchestrator directory"
check_literal "Quick profile needle"                     "Quick profile"

printf 'SUMMARY: m031-p04-test-doc-drift-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
