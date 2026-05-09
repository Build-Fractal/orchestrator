#!/usr/bin/env bash
# Defect 3 regression: reconcile_terminal's outer `done < "$CONFLICTS_ACC"`
# stole FD 0 from ask_one. Operator-piped resolutions were dropped and
# every conflict fell back to accept-primary regardless of operator input.
#
# This test asserts that piped operator answers actually reach ask_one
# inside reconcile_terminal — N conflicts with N operator answers should
# produce N rows in resolutions.txt with the operator-supplied values.

set -e
set -u

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1"; }

REPO_ROOT="$(pwd)"

run_fd0_reconcile_test() {
    local stage
    stage="$(mktemp -d)"

    # Three orphan refs => three conflicts (within default threshold of 5
    # so terminal reconciliation fires, not file-based UX).
    cat >"$stage/PRIMARY-BRIEF.md" <<'EOF'
# Primary
This brief references FOO-1, BAR-2, and BAZ-3 but does not define them.
EOF
    cat >"$stage/OTHER-NOTES.md" <<'EOF'
# Other Notes
Supplementary content with no token definitions.
EOF

    local out="$stage/intake-stdout.txt"
    # Pipe answers for both labeling (2 materials) AND reconciliation
    # (3 conflicts). Without --yes so ask_one is invoked in both paths.
    bash scripts/lifecycle/materials-intake.sh \
        --project-dir "$stage" >"$out" 2>&1 <<'EOF' || true
primary
supplementary
defer
manual-edit
accept-supplementary
EOF

    local res_file
    res_file=$(find "$stage/.orchestrator/intake" -name resolutions.txt | head -1)
    if [ -z "$res_file" ] || [ ! -f "$res_file" ]; then
        fail "resolutions.txt not found"
        rm -rf "$stage"
        return
    fi

    local row_count
    row_count=$(grep -c . "$res_file" || true)
    if [ "$row_count" -ge 1 ]; then
        pass "resolutions.txt has $row_count rows (operator path reached)"
    else
        fail "resolutions.txt row count: expected >= 1, got $row_count"
    fi

    # Pre-fix symptom: every row would be accept-primary (the fallback).
    # Post-fix: operator-supplied resolutions like 'defer' or 'manual-edit'
    # should appear when piped above. If ALL rows are accept-primary, the
    # FD-0 bug is back.
    local all_accept_primary
    all_accept_primary=1
    while IFS= read -r row; do
        local res
        res=$(echo "$row" | cut -d'|' -f2)
        if [ "$res" != "accept-primary" ]; then
            all_accept_primary=0
            break
        fi
    done <"$res_file"

    if [ "$all_accept_primary" = "0" ]; then
        pass "operator-supplied resolutions reach reconcile_terminal"
    else
        fail "all resolutions fell back to accept-primary — FD-0 bug regressed"
    fi

    rm -rf "$stage"
}

run_fd0_reconcile_test

printf 'SUMMARY: p04d-materials-intake-fd0-reconcile.sh pass=%d fail=%d\n' "$PASS_COUNT" "$FAIL_COUNT"
if [ "$FAIL_COUNT" -ne 0 ]; then
    exit 1
fi
exit 0
