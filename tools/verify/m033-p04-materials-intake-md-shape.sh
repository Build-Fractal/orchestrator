#!/usr/bin/env bash
# tools/verify/m033-p04-materials-intake-md-shape.sh
#
# Static shape verifier for commands/materials-intake.md (M033/P04/T01).
# Asserts the FR-9 contract is documented per MEM012 and that the closed
# vocabulary tokens (labeling enum, drift categories, threshold env var,
# CON-4 invariant, fixture reference) all appear verbatim.
#
# Bash 3.2 compatible (MEM001).

set -e
set -u

REPO_ROOT=""
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

TARGET="$REPO_ROOT/commands/materials-intake.md"

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

# 1. File exists.
if [ ! -f "$TARGET" ]; then
    echo "FAIL: $TARGET does not exist"
    echo "SUMMARY: m033-p04-materials-intake-md-shape.sh pass=0 fail=1"
    exit 1
fi
pass "commands/materials-intake.md exists"

# 2. Min line count 60.
LINE_COUNT=$(awk 'END { print NR }' "$TARGET")
if [ "$LINE_COUNT" -ge 60 ]; then
    pass "line count $LINE_COUNT >= 60"
else
    fail "line count $LINE_COUNT < 60"
fi

# 3. YAML frontmatter description: field.
if head -5 "$TARGET" | grep -qE '^description:'; then
    pass "YAML frontmatter description: field present"
else
    fail "YAML frontmatter description: field missing"
fi

# 4. Title.
assert_grep "# orchestrator:materials-intake" "title # orchestrator:materials-intake"

# 5. FR / CON / spec references.
assert_grep "FR-9" "FR-9 reference"
assert_grep "CON-4" "CON-4 reference"
assert_grep "deterministic" "deterministic-not-LLM invariant stated"

# 6. Driver reference.
assert_grep "materials-intake.sh" "scripts/lifecycle/materials-intake.sh referenced"

# 7. Closed labeling enum tokens.
assert_grep "primary" "labeling enum: primary"
assert_grep "supplementary" "labeling enum: supplementary"
assert_grep "decision-history" "labeling enum: decision-history"
assert_grep "out-of-scope" "labeling enum: out-of-scope"

# 8. Closed CON-4 detection-category enum tokens.
assert_grep "id-misalignment" "drift category: id-misalignment"
assert_grep "scheme-contradiction" "drift category: scheme-contradiction"
assert_grep "orphan-reference" "drift category: orphan-reference"

# 9. Threshold env var (default 5 per #Q-6).
assert_grep "M033_CONFLICT_FILE_THRESHOLD" "M033_CONFLICT_FILE_THRESHOLD env var named"

# 10. Output artifact names.
assert_grep "reconciled-pre-spec.md" "reconciled-pre-spec.md output named"
assert_grep "materials_intake_completed" "materials_intake_completed JSONL event named"

# 11. Fixture reference.
assert_grep "m033-pbj-materials-fixture" "PBJ fixture referenced"

echo "SUMMARY: m033-p04-materials-intake-md-shape.sh pass=$PASS_COUNT fail=$FAIL_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
exit 0
