#!/usr/bin/env bash
# tools/verify/m031-p01-test-quick-injects-knowledge-shape.sh
#
# M031/P01/T03 shape verifier (project-owned, slug-bearing under
# tools/verify/) for tests/m031-acceptance/test-quick-injects-knowledge.sh.
#
# Asserts:
#   1) the SC-1 acceptance script exists and is executable,
#   2) the script body carries the literal substrings "SC-1",
#      "knowledge_section_tokens", and "payload_breakdown" (file-header
#      schema commitment per the task plan must-haves),
#   3) the script exits 0 on invocation (i.e. the SC-1 contract holds
#      against the current T01 build-context.sh + P00 corpus).
#
# Single-script Truth Check shape per AD-19. Bash 3.2 compatible.
#
# Output:
#   per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 iff fail=0

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/tests/m031-acceptance/test-quick-injects-knowledge.sh"

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

# 1) Exists and is executable.
if [ -f "$target" ]; then
    ok "SC-1 script exists at $target"
else
    ng "SC-1 script missing at $target"
    printf 'SUMMARY: m031-p01-test-quick-injects-knowledge-shape.sh pass=%d fail=%d\n' \
        "$pass" "$fail"
    exit 1
fi
if [ -x "$target" ]; then
    ok "SC-1 script is executable"
else
    ng "SC-1 script is not executable"
fi

# 2) Literal substring contract.
for lit in "SC-1" "knowledge_section_tokens" "payload_breakdown"; do
    if grep -q "$lit" "$target"; then
        ok "SC-1 script contains literal $lit"
    else
        ng "SC-1 script missing literal $lit"
    fi
done

# 3) Run it.
bash "$target" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
    ok "SC-1 script exits 0"
else
    ng "SC-1 script exited rc=$rc"
fi

printf 'SUMMARY: m031-p01-test-quick-injects-knowledge-shape.sh pass=%d fail=%d\n' \
    "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
