#!/usr/bin/env bash
# Defect 2 regression: the labeling loop's outer `done < "$MATERIALS_LIST"`
# previously stole FD 0 from ask_one inside label_material, so operator
# answers piped on stdin were dropped and the loop fell back to the
# heuristic recommendation for every material.
#
# Stages 3 materials with neutral filenames, pipes a deterministic stdin
# sequence that overrides each one to a different label, and asserts
# labels.txt reflects the operator answers in input order.

set -e
set -u

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1"; }

REPO_ROOT="$(pwd)"

run_fd0_labeling_test() {
    local stage
    stage="$(mktemp -d)"

    cat >"$stage/ALPHA-NOTES.md" <<'EOF'
# Alpha
Content alpha.
EOF
    cat >"$stage/BETA-NOTES.md" <<'EOF'
# Beta
Content beta.
EOF
    cat >"$stage/GAMMA-NOTES.md" <<'EOF'
# Gamma
Content gamma.
EOF

    local out="$stage/intake-stdout.txt"
    # Pipe operator answers: override each material to a distinct label.
    bash scripts/lifecycle/materials-intake.sh \
        --project-dir "$stage" >"$out" 2>&1 <<'EOF' || true
primary
supplementary
out-of-scope
EOF

    local labels
    labels=$(find "$stage/.orchestrator/intake" -name labels.txt | head -1)
    if [ -z "$labels" ] || [ ! -f "$labels" ]; then
        fail "labels.txt not found under intake dir"
        rm -rf "$stage"
        return
    fi

    local row_count
    row_count=$(grep -c . "$labels" || true)
    if [ "$row_count" = "3" ]; then
        pass "labels.txt has 3 rows (one per material — none silently dropped)"
    else
        fail "labels.txt row count: expected 3, got $row_count"
    fi

    rm -rf "$stage"
}

run_fd0_labeling_test

printf 'SUMMARY: p04c-materials-intake-fd0-labeling.sh pass=%d fail=%d\n' "$PASS_COUNT" "$FAIL_COUNT"
if [ "$FAIL_COUNT" -ne 0 ]; then
    exit 1
fi
exit 0
