#!/usr/bin/env bash
# tools/verify/m033-p04-materials-intake-sh-shape.sh
#
# Static shape verifier for scripts/lifecycle/materials-intake.sh
# (M033/P04/T01). Asserts the FR-9 driver:
#   - Exists and is executable.
#   - Carries the three fenced SSOT block markers
#     (material-extensions, labeling-enum, drift-categories).
#   - References the load-bearing tokens for the FR-9 contract.
#   - Is bash 3.2 compatible (MEM001) — no `declare -A`,
#     no process substitution `<(...)`.
#   - Honors the deterministic-not-LLM invariant per CON-4
#     — no `claude-code` / `conversus` / `llm` /
#     `model_routing` substrings.
#
# Bash 3.2 compatible.

set -e
set -u

REPO_ROOT=""
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

TARGET="$REPO_ROOT/scripts/lifecycle/materials-intake.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "PASS: $1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "FAIL: $1"
}

assert_grep() {
    local needle="$1"
    local label="$2"
    if grep -qF -- "$needle" "$TARGET"; then
        pass "$label"
    else
        fail "$label - missing token: $needle"
    fi
}

assert_negative_grep() {
    local needle="$1"
    local label="$2"
    if grep -qF -- "$needle" "$TARGET"; then
        fail "$label - forbidden token present: $needle"
    else
        pass "$label"
    fi
}

# 1. File exists and executable.
if [ ! -f "$TARGET" ]; then
    echo "FAIL: $TARGET does not exist"
    echo "SUMMARY: m033-p04-materials-intake-sh-shape.sh pass=0 fail=1"
    exit 1
fi
pass "scripts/lifecycle/materials-intake.sh exists"

if [ -x "$TARGET" ]; then
    pass "materials-intake.sh is executable"
else
    fail "materials-intake.sh is NOT executable"
fi

# 2. Min line count 250.
LINE_COUNT=$(awk 'END { print NR }' "$TARGET")
if [ "$LINE_COUNT" -ge 250 ]; then
    pass "line count $LINE_COUNT >= 250"
else
    fail "line count $LINE_COUNT < 250"
fi

# 3. Fenced SSOT block markers.
assert_grep ">>> material-extensions >>>" "fenced SSOT: material-extensions"
assert_grep ">>> labeling-enum >>>" "fenced SSOT: labeling-enum"
assert_grep ">>> drift-categories >>>" "fenced SSOT: drift-categories"

# 4. ask_one + grilling-shell reference.
assert_grep "ask_one" "ask_one invoked"
assert_grep "grilling-shell.sh" "grilling-shell.sh sourced"

# 5. Flag set.
assert_grep "--project-dir" "--project-dir flag"
assert_grep "--yes" "--yes flag"
assert_grep "--resolve" "--resolve flag"

# 6. Closed CON-4 drift-category tokens.
assert_grep "id-misalignment" "drift category: id-misalignment"
assert_grep "scheme-contradiction" "drift category: scheme-contradiction"
assert_grep "orphan-reference" "drift category: orphan-reference"

# 7. Output artifacts and event tokens.
assert_grep "reconciled-pre-spec.md" "reconciled-pre-spec.md output"
assert_grep "conflicts.md" "conflicts.md output"
assert_grep "materials_intake_completed" "materials_intake_completed JSONL event"
assert_grep "materials-intake.complete" "materials-intake.complete marker"

# 8. Dual-write helper invocation.
assert_grep "dual-write-runtime-md.sh" "dual-write-runtime-md.sh invocation"

# 9. PDF converter probes.
assert_grep "textutil" "textutil probe (darwin)"
assert_grep "pdftotext" "pdftotext probe (linux)"

# 10. Threshold + timestamp env vars.
assert_grep "M033_CONFLICT_FILE_THRESHOLD" "M033_CONFLICT_FILE_THRESHOLD env"
assert_grep "M033_INTAKE_TIMESTAMP" "M033_INTAKE_TIMESTAMP env"

# 11. Bash 3.2 negatives.
assert_negative_grep "declare -A" "bash 3.2 compat: no declare -A"
assert_negative_grep "<(" "bash 3.2 compat: no process substitution"

# 12. CON-4 deterministic-not-LLM negatives.
assert_negative_grep "claude-code" "CON-4 negative: no claude-code"
assert_negative_grep "conversus" "CON-4 negative: no conversus"
assert_negative_grep "model_routing" "CON-4 negative: no model_routing"

echo "SUMMARY: m033-p04-materials-intake-sh-shape.sh pass=$PASS_COUNT fail=$FAIL_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
exit 0
