#!/usr/bin/env bash
# tests/m033-acceptance/p06-customblock-draft.sh
# SC-7: FR-13 + FR-14 customblock-draft acceptance.
#
# Exercises scripts/lifecycle/customblock-draft.sh against staged fixtures.
# Asserts:
#   - 5 prescribed sections rendered (## Project / ## Stack / ## Entry Points
#     OR ## Source-Docs / ## Conventions / ## Decisions).
#   - Strict aggregation (Constitution XV): each section body contains
#     verbatim substrings from the seeded MEM content -- no LLM-invented strings.
#   - JSONL event 'customblock_drafted' emitted; start-state marker written.
#   - Idempotency without --force: re-run is byte-identical with 'no changes'
#     diagnostic.
#   - --force regenerates with 'discards prior operator edits' stderr warning.
#   - Floor-not-ceiling (US-7 AS-2): operator-added ## Notes section is
#     preserved verbatim across --force regeneration.
#   - Structurally-downstream-of-US-2 gate (US-7 AS-5): missing
#     constitution.md exits non-zero with 'constitution not present' diagnostic.
#   - Branch-dependent variant rule: ## Source-Docs fires when intake
#     pre-spec exists; ## Entry Points correctly omitted in that case.
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

# --- Test 1: existing-codebase fixture with constitution + ingest MEMs.
seed_existing_codebase_fixture() {
    local stage="$1"
    mkdir -p "$stage/.orchestrator/memory" \
             "$stage/.orchestrator/knowledge/architecture" \
             "$stage/.orchestrator/knowledge/conventions" \
             "$stage/.orchestrator/knowledge/decisions" \
             "$stage/.orchestrator/start-state"
    # Constitution stub.
    cat > "$stage/.orchestrator/memory/constitution.md" <<'EOF'
# Project Constitution -- web-saas

## Constitution Check

### Principle I -- Idempotent Deploys
Every deploy is repeatable.
EOF
    # Architecture MEM.
    cat > "$stage/.orchestrator/knowledge/architecture/MEM-A1.md" <<'EOF'
---
id: MEM-A1
category: architecture
---
WebApp uses TypeScript + Node 20 with React 19 frontend.
EOF
    # Convention MEM.
    cat > "$stage/.orchestrator/knowledge/conventions/MEM-C1.md" <<'EOF'
---
id: MEM-C1
category: conventions
---
ESLint with prettier-plugin runs on pre-commit.
EOF
    # Decision MEM.
    cat > "$stage/.orchestrator/knowledge/decisions/MEM-D1.md" <<'EOF'
---
id: MEM-D1
category: decisions
---
Postgres chosen over MongoDB for transactional integrity (2026-04-15).
EOF
    # Empty CLAUDE.md with marker region.
    cat > "$stage/CLAUDE.md" <<'EOF'
# CLAUDE.md

<!-- BEGIN CUSTOM -->
<!-- END CUSTOM -->
EOF
}

STAGE1=$(mktemp -d)
seed_existing_codebase_fixture "$STAGE1"
EDITOR=cat bash scripts/lifecycle/customblock-draft.sh --project-dir "$STAGE1" --yes \
    > "$STAGE1/stdout" 2> "$STAGE1/stderr"
RC1=$?
if [ "$RC1" -eq 0 ]; then
    pass "T1 customblock-draft exit 0"
else
    fail "T1 exit $RC1"
fi

# Assert all 5 prescribed sections present (Entry Points variant since no intake).
for h in '## Project' '## Stack' '## Entry Points' '## Conventions' '## Decisions'; do
    if grep -qF "$h" "$STAGE1/CLAUDE.md"; then
        pass "T1 section: $h"
    else
        fail "T1 missing: $h"
    fi
done

# Assert strict aggregation: each section's body contains a verbatim substring
# from the seeded MEM (no LLM-invented strings).
if grep -qF 'TypeScript + Node 20' "$STAGE1/CLAUDE.md"; then
    pass "T1 ## Stack body verbatim from MEM-A1"
else
    fail "T1 ## Stack body lost MEM-A1 content"
fi
if grep -qF 'ESLint with prettier-plugin' "$STAGE1/CLAUDE.md"; then
    pass "T1 ## Conventions body verbatim from MEM-C1"
else
    fail "T1 ## Conventions body lost MEM-C1 content"
fi
if grep -qF 'Postgres chosen over MongoDB' "$STAGE1/CLAUDE.md"; then
    pass "T1 ## Decisions body verbatim from MEM-D1"
else
    fail "T1 ## Decisions body lost MEM-D1 content"
fi

# JSONL event + start-state marker.
if grep -qF '"customblock_drafted"' "$STAGE1/.orchestrator/execution-log.jsonl" 2>/dev/null; then
    pass "T1 customblock_drafted JSONL emitted"
else
    fail "T1 JSONL event missing"
fi
# Marker name: the FR-20 closed enum uses 'customblock-drafted' (past tense).
# Doc-prose alias 'customblock-draft.complete' is a semantic alias for the same
# surface (same alias-mapping pattern as FR-7 ingest-codebase per M033/P03/T05).
if [ -f "$STAGE1/.orchestrator/start-state/customblock-drafted.complete" ] \
   || [ -f "$STAGE1/.orchestrator/start-state/customblock-draft.complete" ]; then
    pass "T1 start-state marker written"
else
    fail "T1 marker missing"
fi

# --- Test 2: idempotency without --force.
cp "$STAGE1/CLAUDE.md" "$STAGE1/CLAUDE.md.before"
EDITOR=cat bash scripts/lifecycle/customblock-draft.sh --project-dir "$STAGE1" --yes \
    > "$STAGE1/stdout2" 2> "$STAGE1/stderr2"
RC2=$?
if [ "$RC2" -eq 0 ]; then
    pass "T2 idempotent re-run exit 0"
else
    fail "T2 exit $RC2"
fi
if diff -q "$STAGE1/CLAUDE.md.before" "$STAGE1/CLAUDE.md" > /dev/null; then
    pass "T2 file byte-identical without --force"
else
    fail "T2 file changed without --force"
fi
if grep -qF 'no changes' "$STAGE1/stdout2"; then
    pass "T2 'no changes' diagnostic"
else
    fail "T2 missing 'no changes'"
fi

# --- Test 3: --force regenerates with stderr warning.
EDITOR=cat bash scripts/lifecycle/customblock-draft.sh --project-dir "$STAGE1" --yes --force \
    > "$STAGE1/stdout3" 2> "$STAGE1/stderr3"
RC3=$?
if [ "$RC3" -eq 0 ]; then
    pass "T3 --force exit 0"
else
    fail "T3 --force exit $RC3"
fi
if grep -qF 'discards prior operator edits' "$STAGE1/stderr3"; then
    pass "T3 --force stderr warning emitted"
else
    fail "T3 --force stderr warning missing"
fi

# --- Test 4: floor-not-ceiling preserves operator additions.
STAGE2=$(mktemp -d)
seed_existing_codebase_fixture "$STAGE2"
EDITOR=cat bash scripts/lifecycle/customblock-draft.sh --project-dir "$STAGE2" --yes \
    > /dev/null 2>&1
# Inject an operator-added ## Notes section into the custom block.
# Use awk because `sed -i.bak` with literal '\n' is unportable across BSD/GNU sed.
awk '
    /<!-- END CUSTOM -->/ {
        print "## Notes"
        print ""
        print "- Test note line 1"
        print ""
    }
    { print }
' "$STAGE2/CLAUDE.md" > "$STAGE2/CLAUDE.md.new"
mv "$STAGE2/CLAUDE.md.new" "$STAGE2/CLAUDE.md"
EDITOR=cat bash scripts/lifecycle/customblock-draft.sh --project-dir "$STAGE2" --yes --force \
    > /dev/null 2>&1
if grep -qF '## Notes' "$STAGE2/CLAUDE.md"; then
    pass "T4 floor-not-ceiling preserves ## Notes"
else
    fail "T4 ## Notes section lost on --force"
fi
if grep -qF 'Test note line 1' "$STAGE2/CLAUDE.md"; then
    pass "T4 ## Notes body preserved verbatim"
else
    fail "T4 ## Notes body lost"
fi

# --- Test 5: structurally-downstream-of-US-2 gate.
STAGE3=$(mktemp -d)
mkdir -p "$STAGE3/.orchestrator/start-state"
# NO constitution.md.
EDITOR=cat bash scripts/lifecycle/customblock-draft.sh --project-dir "$STAGE3" --yes \
    > "$STAGE3/stdout" 2> "$STAGE3/stderr"
RC5=$?
if [ "$RC5" -ne 0 ]; then
    pass "T5 missing-constitution exit non-zero"
else
    fail "T5 expected non-zero exit"
fi
if grep -qF 'constitution not present' "$STAGE3/stderr"; then
    pass "T5 missing-constitution diagnostic"
else
    fail "T5 missing-constitution diagnostic absent"
fi

# --- Test 6: branch-dependent variant rule (## Source-Docs when intake exists).
STAGE4=$(mktemp -d)
seed_existing_codebase_fixture "$STAGE4"
mkdir -p "$STAGE4/.orchestrator/intake/20260504T000000Z"
cat > "$STAGE4/.orchestrator/intake/20260504T000000Z/ideation-pre-spec.md" <<'EOF'
## Problem

Test problem statement.

## MVP

Test MVP boundary.
EOF
EDITOR=cat bash scripts/lifecycle/customblock-draft.sh --project-dir "$STAGE4" --yes \
    > /dev/null 2>&1
if grep -qF '## Source-Docs' "$STAGE4/CLAUDE.md"; then
    pass "T6 ## Source-Docs variant fires"
else
    fail "T6 ## Source-Docs variant absent"
fi
if grep -qF '## Entry Points' "$STAGE4/CLAUDE.md"; then
    fail "T6 ## Entry Points should NOT appear when intake exists"
else
    pass "T6 ## Entry Points correctly omitted"
fi

# Cleanup.
rm -rf "$STAGE1" "$STAGE2" "$STAGE3" "$STAGE4"

printf 'SUMMARY: p06-customblock-draft.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
    exit 0
fi
exit 1
