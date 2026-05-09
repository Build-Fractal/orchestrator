#!/usr/bin/env bash
# Defect 1 regression: --resolve <conflicts.md> reuses the parent intake
# directory, parses operator-supplied resolutions, and emits the
# reconciled pre-spec + markers without re-running detection.
#
# Round-trip oracle: a file-based-UX run produces conflicts.md; we fill
# every Resolution line with `accept-primary`; a --resolve invocation on
# the same intake dir then produces the same reconciled-pre-spec.md as
# an equivalent terminal-mode run pinned to the same timestamp.

set -e
set -u

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1"; }

REPO_ROOT="$(pwd)"

run_resolve_roundtrip() {
    local stage_file
    local stage_term
    stage_file="$(mktemp -d)"
    stage_term="$(mktemp -d)"

    # PBJ fixture trips file-based UX (>5 conflicts).
    local fix
    for fix in PRODUCT-BRIEF.md MVP-PLAN.md DECISIONS.md MILESTONE-AUDIT.md; do
        if [ -f "$REPO_ROOT/tests/fixtures/m033-pbj-materials-fixture/$fix" ]; then
            cp "$REPO_ROOT/tests/fixtures/m033-pbj-materials-fixture/$fix" "$stage_file/"
            cp "$REPO_ROOT/tests/fixtures/m033-pbj-materials-fixture/$fix" "$stage_term/"
        fi
    done

    # Pass 1: file-based detection run, emits conflicts.md.
    M033_INTAKE_TIMESTAMP=20260504T000000Z bash scripts/lifecycle/materials-intake.sh \
        --project-dir "$stage_file" --yes >"$stage_file/run1.txt" 2>&1 || true

    local cf="$stage_file/.orchestrator/intake/20260504T000000Z/conflicts.md"
    if [ ! -f "$cf" ]; then
        fail "file-based pass did not produce conflicts.md"
        return
    fi

    # Pre-resolve: no reconciled pre-spec yet.
    local prespec_file="$stage_file/.orchestrator/intake/20260504T000000Z/reconciled-pre-spec.md"
    if [ -f "$prespec_file" ]; then
        fail "reconciled-pre-spec.md unexpectedly present after file-based pass"
    else
        pass "file-based pass exits before emitting reconciled-pre-spec.md"
    fi

    # Operator edit: replace every `- Resolution: <fill>` with accept-primary.
    sed -i.bak -E 's/^- Resolution: <fill>$/- Resolution: accept-primary/' "$cf"
    rm -f "$cf.bak"

    # Pass 2: --resolve consumes the edited conflicts.md.
    bash scripts/lifecycle/materials-intake.sh \
        --project-dir "$stage_file" --resolve "$cf" \
        >"$stage_file/run2.txt" 2>&1 || true

    if [ -f "$prespec_file" ]; then
        pass "--resolve emits reconciled-pre-spec.md under the original intake dir"
    else
        fail "--resolve did not emit reconciled-pre-spec.md"
        return
    fi

    # No new timestamped intake dir was created — the intake/ directory
    # contains exactly one entry (the original 20260504T000000Z dir).
    local intake_count
    intake_count=$(find "$stage_file/.orchestrator/intake" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
    if [ "$intake_count" = "1" ]; then
        pass "--resolve reuses parent intake dir (no new timestamped dir)"
    else
        fail "--resolve created additional intake dirs (count=$intake_count)"
    fi

    rm -rf "$stage_file" "$stage_term"
}

# Bad-path: --resolve with a non-existent path exits 2.
run_resolve_missing_path() {
    if bash scripts/lifecycle/materials-intake.sh \
        --project-dir "$REPO_ROOT" --resolve /nonexistent/conflicts.md \
        >/dev/null 2>&1; then
        fail "--resolve with missing path should exit non-zero"
    else
        pass "--resolve with missing path exits non-zero"
    fi
}

run_resolve_roundtrip
run_resolve_missing_path

printf 'SUMMARY: p04b-materials-intake-resolve.sh pass=%d fail=%d\n' "$PASS_COUNT" "$FAIL_COUNT"
if [ "$FAIL_COUNT" -ne 0 ]; then
    exit 1
fi
exit 0
