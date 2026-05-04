#!/usr/bin/env bash
# tools/verify/m033-p05-customblock-draft-functional-smoke.sh
#
# M033/P05/T01 functional smoke verifier for the FR-13/FR-14 customblock-draft
# driver (scripts/lifecycle/customblock-draft.sh). Exercises the strict-
# aggregation driver end-to-end against a self-contained temp-dir project
# fixture (no test-env coupling, mktemp + trap cleanup).
#
# Six checked-in scenarios (translation of the out-of-tree exploratory smoke
# referenced in T01-customblock-draft-SUMMARY.md):
#
#   t1: missing-constitution -> exit 1 with US-7 AS-5 diagnostic on stderr.
#   t2: greenfield -> entry-points variant + CLAUDE.md created with marker
#       block + FR-20 customblock-drafted.complete marker on disk + FR-22
#       customblock_drafted JSONL event appended to execution-log.jsonl.
#   t3: no-force re-run -> byte-identical CLAUDE.md preservation +
#       'no changes' diagnostic on stdout.
#   t4: --force re-run -> '--force discards prior operator edits' warning
#       on stderr.
#   t5: source-docs variant -> when an intake reconciled-pre-spec.md is
#       present, ## Source-Docs renders and ## Entry Points is absent.
#   t6: floor-not-ceiling -> operator-added ## Notes section preserved
#       across --force regeneration (US-7 AS-2).
#
# Constitution XV: NO LLM / conversus / model invocation -- the driver under
# test is strict-aggregation, and so is this smoke verifier.
#
# Bash 3.2 compatible (MEM001): no associative arrays, no process
# substitution, no $()-with-pipes on assignment paths.
#
# AD-19 single-script-file shape; AD-15 cross-phase regression -- this file
# touches ONLY the temp fixture under mktemp.

set -u

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

# Resolve repo root: this verifier lives at <repo>/tools/verify/ and the
# driver at <repo>/scripts/lifecycle/customblock-draft.sh. Honor cwd if it
# already contains the driver (matches the auto-loop's invocation pattern of
# `bash tools/verify/...` from the repo root); otherwise derive from $0.
REPO_ROOT=""
if [ -f "scripts/lifecycle/customblock-draft.sh" ]; then
    REPO_ROOT="$PWD"
else
    SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
    REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
fi

DRIVER="$REPO_ROOT/scripts/lifecycle/customblock-draft.sh"
if [ ! -f "$DRIVER" ]; then
    printf 'FAIL: driver not found at %s\n' "$DRIVER"
    printf 'SUMMARY: m033-p05-customblock-draft-functional-smoke.sh pass=0 fail=1\n'
    exit 1
fi

# Self-contained fixture root under mktemp. Single trap covers all six
# scenarios so no leakage on early exit.
FIXTURE_ROOT=$(mktemp -d 2>/dev/null || mktemp -d -t m033-p05-smoke)
cleanup() {
    if [ -n "${FIXTURE_ROOT:-}" ] && [ -d "$FIXTURE_ROOT" ]; then
        rm -rf "$FIXTURE_ROOT"
    fi
}
trap cleanup EXIT INT TERM

# ---------------------------------------------------------------------------
# Helper: seed a fresh project fixture with constitution + optional MEMs.
#
# Args: <project-dir> <variant>
#   variant=greenfield      -> constitution only, no intake, no MEMs
#   variant=with-mems       -> constitution + 1 architecture MEM (entry-points)
#   variant=with-intake     -> constitution + intake reconciled-pre-spec.md
#   variant=no-constitution -> empty .orchestrator/, no constitution
# ---------------------------------------------------------------------------
seed_fixture() {
    proj_dir="$1"
    variant="$2"
    mkdir -p "$proj_dir/.orchestrator/memory"
    mkdir -p "$proj_dir/.orchestrator/knowledge/architecture"
    mkdir -p "$proj_dir/.orchestrator/knowledge/conventions"
    mkdir -p "$proj_dir/.orchestrator/knowledge/decisions"
    if [ "$variant" != "no-constitution" ]; then
        printf '# Test Fixture Constitution\n\nGoverning principles for the smoke fixture.\n' \
            > "$proj_dir/.orchestrator/memory/constitution.md"
    fi
    if [ "$variant" = "with-mems" ] || [ "$variant" = "with-intake" ]; then
        # One architecture MEM so emit_mem_bullets has content; YAML frontmatter
        # parsed by the driver's awk extractor.
        cat > "$proj_dir/.orchestrator/knowledge/architecture/MEM-001.md" <<'EOF'
---
id: MEM-001
type: architecture
---
Test fixture entry point: src/main.sh
EOF
    fi
    if [ "$variant" = "with-intake" ]; then
        mkdir -p "$proj_dir/.orchestrator/intake/2026-05-04T00-00-00Z"
        cat > "$proj_dir/.orchestrator/intake/2026-05-04T00-00-00Z/reconciled-pre-spec.md" <<'EOF'
# Reconciled Pre-Spec Fixture

## Goals

Smoke fixture goal section.

## Scope

Smoke fixture scope section.
EOF
    fi
}

# Run driver from REPO_ROOT (it invokes scripts/util/* via relative paths).
# EDITOR=true so the editor pass is a no-op even without --yes; --yes is also
# passed on every call to be belt-and-suspenders.
run_driver() {
    proj_dir="$1"
    extra_flag="${2:-}"
    (
        cd "$REPO_ROOT" || exit 99
        EDITOR=true bash "$DRIVER" --project-dir "$proj_dir" --yes $extra_flag
    )
}

# ---------------------------------------------------------------------------
# t1: missing-constitution -> exit 1 + US-7 AS-5 diagnostic on stderr.
# ---------------------------------------------------------------------------
T1_DIR="$FIXTURE_ROOT/t1-no-constitution"
mkdir -p "$T1_DIR"
seed_fixture "$T1_DIR" no-constitution
T1_STDERR="$FIXTURE_ROOT/t1.stderr"
T1_RC=0
run_driver "$T1_DIR" "" >/dev/null 2>"$T1_STDERR" || T1_RC=$?
if [ "$T1_RC" -eq 1 ]; then
    pass "t1 missing-constitution exit code is 1"
else
    fail "t1 missing-constitution expected rc=1 got rc=$T1_RC"
fi
if grep -qF 'constitution not present' "$T1_STDERR"; then
    pass "t1 US-7 AS-5 diagnostic on stderr"
else
    fail "t1 missing 'constitution not present' diagnostic"
fi
if [ ! -f "$T1_DIR/CLAUDE.md" ]; then
    pass "t1 no CLAUDE.md created on gate failure"
else
    fail "t1 CLAUDE.md unexpectedly created"
fi

# ---------------------------------------------------------------------------
# t2: greenfield -> entry-points variant + CLAUDE.md + FR-20 marker + FR-22
#      JSONL.
# ---------------------------------------------------------------------------
T2_DIR="$FIXTURE_ROOT/t2-greenfield"
mkdir -p "$T2_DIR"
seed_fixture "$T2_DIR" greenfield
T2_STDOUT="$FIXTURE_ROOT/t2.stdout"
T2_STDERR="$FIXTURE_ROOT/t2.stderr"
T2_RC=0
run_driver "$T2_DIR" "" >"$T2_STDOUT" 2>"$T2_STDERR" || T2_RC=$?
if [ "$T2_RC" -eq 0 ]; then
    pass "t2 greenfield exit code is 0"
else
    fail "t2 greenfield expected rc=0 got rc=$T2_RC stderr=$(cat "$T2_STDERR")"
fi
if [ -f "$T2_DIR/CLAUDE.md" ]; then
    pass "t2 CLAUDE.md created"
else
    fail "t2 CLAUDE.md not created"
fi
if grep -qF '<!-- BEGIN CUSTOM -->' "$T2_DIR/CLAUDE.md" 2>/dev/null && \
   grep -qF '<!-- END CUSTOM -->' "$T2_DIR/CLAUDE.md" 2>/dev/null; then
    pass "t2 marker block bounds present"
else
    fail "t2 marker block bounds missing"
fi
if grep -qF '## Entry Points' "$T2_DIR/CLAUDE.md" 2>/dev/null; then
    pass "t2 entry-points variant rendered"
else
    fail "t2 ## Entry Points header missing"
fi
if grep -qF '## Source-Docs' "$T2_DIR/CLAUDE.md" 2>/dev/null; then
    fail "t2 ## Source-Docs unexpectedly present in greenfield variant"
else
    pass "t2 ## Source-Docs absent in greenfield variant"
fi
if [ -f "$T2_DIR/.orchestrator/start-state/customblock-drafted.complete" ]; then
    pass "t2 FR-20 customblock-drafted.complete marker on disk"
else
    fail "t2 FR-20 marker missing"
fi
if [ -f "$T2_DIR/.orchestrator/execution-log.jsonl" ] && \
   grep -qF '"event_type":"customblock_drafted"' "$T2_DIR/.orchestrator/execution-log.jsonl" 2>/dev/null; then
    pass "t2 FR-22 customblock_drafted JSONL appended"
else
    fail "t2 FR-22 JSONL event missing"
fi

# ---------------------------------------------------------------------------
# t3: no-force re-run -> byte-identical preservation + 'no changes' on stdout.
# ---------------------------------------------------------------------------
T3_PRE_HASH=""
T3_POST_HASH=""
if command -v shasum >/dev/null 2>&1; then
    T3_PRE_HASH=$(shasum "$T2_DIR/CLAUDE.md" | awk '{print $1}')
elif command -v sha256sum >/dev/null 2>&1; then
    T3_PRE_HASH=$(sha256sum "$T2_DIR/CLAUDE.md" | awk '{print $1}')
fi
T3_STDOUT="$FIXTURE_ROOT/t3.stdout"
T3_RC=0
run_driver "$T2_DIR" "" >"$T3_STDOUT" 2>/dev/null || T3_RC=$?
if [ "$T3_RC" -eq 0 ]; then
    pass "t3 idempotent re-run rc=0"
else
    fail "t3 idempotent re-run rc=$T3_RC"
fi
if grep -qF 'no changes' "$T3_STDOUT"; then
    pass "t3 'no changes' diagnostic on stdout"
else
    fail "t3 'no changes' diagnostic missing"
fi
if command -v shasum >/dev/null 2>&1; then
    T3_POST_HASH=$(shasum "$T2_DIR/CLAUDE.md" | awk '{print $1}')
elif command -v sha256sum >/dev/null 2>&1; then
    T3_POST_HASH=$(sha256sum "$T2_DIR/CLAUDE.md" | awk '{print $1}')
fi
if [ -n "$T3_PRE_HASH" ] && [ "$T3_PRE_HASH" = "$T3_POST_HASH" ]; then
    pass "t3 byte-identical CLAUDE.md preservation"
else
    fail "t3 CLAUDE.md mutated on no-force re-run (pre=$T3_PRE_HASH post=$T3_POST_HASH)"
fi

# ---------------------------------------------------------------------------
# t4: --force re-run -> '--force discards prior operator edits' on stderr.
# ---------------------------------------------------------------------------
T4_STDOUT="$FIXTURE_ROOT/t4.stdout"
T4_STDERR="$FIXTURE_ROOT/t4.stderr"
T4_RC=0
run_driver "$T2_DIR" "--force" >"$T4_STDOUT" 2>"$T4_STDERR" || T4_RC=$?
if [ "$T4_RC" -eq 0 ]; then
    pass "t4 --force re-run rc=0"
else
    fail "t4 --force re-run rc=$T4_RC"
fi
if grep -qF -- '--force discards prior operator edits' "$T4_STDERR"; then
    pass "t4 --force warning emitted on stderr"
else
    fail "t4 --force warning missing"
fi

# ---------------------------------------------------------------------------
# t5: source-docs variant -- intake reconciled-pre-spec.md present.
# ---------------------------------------------------------------------------
T5_DIR="$FIXTURE_ROOT/t5-source-docs"
mkdir -p "$T5_DIR"
seed_fixture "$T5_DIR" with-intake
T5_RC=0
run_driver "$T5_DIR" "" >/dev/null 2>"$FIXTURE_ROOT/t5.stderr" || T5_RC=$?
if [ "$T5_RC" -eq 0 ]; then
    pass "t5 source-docs branch rc=0"
else
    fail "t5 source-docs branch rc=$T5_RC stderr=$(cat "$FIXTURE_ROOT/t5.stderr")"
fi
if grep -qF '## Source-Docs' "$T5_DIR/CLAUDE.md" 2>/dev/null; then
    pass "t5 ## Source-Docs rendered"
else
    fail "t5 ## Source-Docs missing"
fi
if grep -qF '## Entry Points' "$T5_DIR/CLAUDE.md" 2>/dev/null; then
    fail "t5 ## Entry Points unexpectedly present in source-docs variant"
else
    pass "t5 ## Entry Points absent in source-docs variant"
fi

# ---------------------------------------------------------------------------
# t6: floor-not-ceiling -- operator-added ## Notes preserved across --force.
# ---------------------------------------------------------------------------
T6_DIR="$FIXTURE_ROOT/t6-floor"
mkdir -p "$T6_DIR"
seed_fixture "$T6_DIR" greenfield
T6_RC=0
run_driver "$T6_DIR" "" >/dev/null 2>"$FIXTURE_ROOT/t6a.stderr" || T6_RC=$?
if [ "$T6_RC" -ne 0 ]; then
    fail "t6 initial draft rc=$T6_RC stderr=$(cat "$FIXTURE_ROOT/t6a.stderr")"
fi
# Operator-edits the custom block to add a non-prescribed ## Notes section
# inside the marker region.
T6_TMP="$FIXTURE_ROOT/t6.claude.md.tmp"
awk '
    /<!-- END CUSTOM -->/ {
        print "\n## Notes\n\n- operator-added note that must survive --force regeneration\n"
        print
        next
    }
    { print }
' "$T6_DIR/CLAUDE.md" > "$T6_TMP"
mv "$T6_TMP" "$T6_DIR/CLAUDE.md"
if grep -qF '## Notes' "$T6_DIR/CLAUDE.md"; then
    pass "t6 operator ## Notes section seeded"
else
    fail "t6 operator ## Notes seed failed"
fi
T6F_RC=0
run_driver "$T6_DIR" "--force" >/dev/null 2>"$FIXTURE_ROOT/t6b.stderr" || T6F_RC=$?
if [ "$T6F_RC" -eq 0 ]; then
    pass "t6 --force regeneration rc=0"
else
    fail "t6 --force regeneration rc=$T6F_RC stderr=$(cat "$FIXTURE_ROOT/t6b.stderr")"
fi
if grep -qF '## Notes' "$T6_DIR/CLAUDE.md" && \
   grep -qF 'operator-added note that must survive --force regeneration' "$T6_DIR/CLAUDE.md"; then
    pass "t6 floor-not-ceiling -- ## Notes preserved across --force"
else
    fail "t6 ## Notes lost across --force regeneration"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf 'SUMMARY: m033-p05-customblock-draft-functional-smoke.sh pass=%s fail=%s\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
