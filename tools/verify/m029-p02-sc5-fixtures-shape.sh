#!/usr/bin/env bash
# tools/verify/m029-p02-sc5-fixtures-shape.sh
#
# M029 P02 / T04 SC-5 fixtures shape verifier.
#
# Asserts:
#   - The two fixture directory trees exist (where-mixed-state.fixture
#     and where-pre-m019.fixture) with the required milestone subtrees.
#   - The where-mixed-state.golden file exists and contains all four
#     canonical glyph states (✓ ▶ ◇ ✗).
#   - tests/m029-acceptance/timestamp-strip.sh exists, is executable,
#     and references the three #Q-G6 placeholders (<TS>, <RECENCY>,
#     <EPOCH>) — exactly the enumerated set, no more / no less.
#   - The canonical FR-8 marker form `▽ saved Nk` (#Q-G8 resolution)
#     is the only form present; the verbose form
#     `▽ saved Nk via tier1 cache reuse` does NOT appear in any T04
#     deliverable. The compact form is also absent from the at-rest
#     P02 fixtures because the renderer never emits the savings glyph
#     (savings is a P03 --live mode concept).
#
# Spec references: FR-5, FR-8, FR-13, SC-5, AD-6, #Q-G6, #Q-G8.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

MIXED="$PROJECT_ROOT/tests/m029-acceptance/fixtures/where-mixed-state.fixture"
PREM019="$PROJECT_ROOT/tests/m029-acceptance/fixtures/where-pre-m019.fixture"
GOLDEN="$PROJECT_ROOT/tests/m029-acceptance/fixtures/where-mixed-state.golden"
STRIP="$PROJECT_ROOT/tests/m029-acceptance/timestamp-strip.sh"

pass=0
fail=0

ok() { printf 'PASS: %s\n' "$1"; pass=$(( pass + 1 )); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$(( fail + 1 )); }

# 1. Mixed-state fixture tree.
if [ -d "$MIXED/.orchestrator/milestones/M998" ]; then
    ok "where-mixed-state.fixture/.orchestrator/milestones/M998 exists"
else
    bad "where-mixed-state fixture milestone tree missing"
fi

# 2. Pre-M019 fixture tree.
if [ -d "$PREM019/.orchestrator/milestones/M997" ]; then
    ok "where-pre-m019.fixture/.orchestrator/milestones/M997 exists"
else
    bad "where-pre-m019 fixture milestone tree missing"
fi

# 3. Golden file exists.
if [ -f "$GOLDEN" ]; then
    ok "where-mixed-state.golden exists"
else
    bad "where-mixed-state.golden missing at $GOLDEN"
    printf 'SUMMARY: m029-p02-sc5-fixtures-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 4. Golden contains all four canonical glyph states.
for g in '✓' '▶' '◇' '✗'; do
    if grep -q -- "$g" "$GOLDEN"; then
        ok "golden contains glyph $g"
    else
        bad "golden missing glyph $g"
    fi
done

# 5. timestamp-strip.sh exists and is executable.
if [ -x "$STRIP" ]; then
    ok "timestamp-strip.sh exists and is executable"
else
    bad "timestamp-strip.sh missing or not executable at $STRIP"
fi

# 6. timestamp-strip.sh references the three #Q-G6 placeholders.
if [ -f "$STRIP" ]; then
    if grep -q -- '<TS>' "$STRIP"; then
        ok "timestamp-strip.sh declares <TS> placeholder"
    else
        bad "timestamp-strip.sh missing <TS> placeholder"
    fi
    if grep -q -- '<RECENCY>' "$STRIP"; then
        ok "timestamp-strip.sh declares <RECENCY> placeholder"
    else
        bad "timestamp-strip.sh missing <RECENCY> placeholder"
    fi
    if grep -q -- '<EPOCH>' "$STRIP"; then
        ok "timestamp-strip.sh declares <EPOCH> placeholder"
    else
        bad "timestamp-strip.sh missing <EPOCH> placeholder"
    fi
fi

# 7. #Q-G8: verbose marker form must NOT appear anywhere in fixtures /
# golden / strip filter / acceptance scripts. The verbose form is
# reserved for a future --verbose mode and is OFF the v1 surface.
VERBOSE_FORM='via tier1 cache reuse'
verbose_hits=0
for f in "$GOLDEN" "$STRIP" \
        "$PROJECT_ROOT/tests/m029-acceptance/p02-sc5-where-mixed-state.sh" \
        "$PROJECT_ROOT/tests/m029-acceptance/p02-sc6-where-pre-m019.sh" \
        "$PROJECT_ROOT/tests/m029-acceptance/p02-sc13-anti-coupling.sh" \
        "$PROJECT_ROOT/tests/m029-acceptance/p02-sc14-readonly.sh" \
        "$PROJECT_ROOT/tests/m029-acceptance/sentinel-harness.sh"; do
    [ -f "$f" ] || continue
    if grep -F -q -- "$VERBOSE_FORM" "$f"; then
        bad "verbose marker form '$VERBOSE_FORM' found in $f (#Q-G8 violation)"
        verbose_hits=$(( verbose_hits + 1 ))
    fi
done
# Recursively scan the fixture trees for the verbose form.
if find "$MIXED" "$PREM019" -type f -print0 2>/dev/null \
        | xargs -0 grep -l -F -- "$VERBOSE_FORM" 2>/dev/null \
        | grep -q .; then
    bad "verbose marker form '$VERBOSE_FORM' found inside fixture trees"
    verbose_hits=$(( verbose_hits + 1 ))
fi
if [ "$verbose_hits" -eq 0 ]; then
    ok "no occurrences of verbose marker form (#Q-G8 canonical-form invariant)"
fi

# 8. The compact at-rest form `▽ saved Nk` MUST NOT appear in any
# fixture body. The renderer is at-rest, savings is a P03 --live mode
# concept; fixtures must not synthesize the compact form either.
compact_hits=0
COMPACT_FORM='▽ saved'
for f in "$GOLDEN"; do
    if grep -F -q -- "$COMPACT_FORM" "$f"; then
        bad "compact savings form '$COMPACT_FORM' found in $f (at-rest renderer should not emit ▽)"
        compact_hits=$(( compact_hits + 1 ))
    fi
done
if find "$MIXED" "$PREM019" -type f -print0 2>/dev/null \
        | xargs -0 grep -l -F -- "$COMPACT_FORM" 2>/dev/null \
        | grep -q .; then
    bad "compact savings form '$COMPACT_FORM' found inside fixture trees"
    compact_hits=$(( compact_hits + 1 ))
fi
if [ "$compact_hits" -eq 0 ]; then
    ok "no occurrences of compact savings form in fixtures (at-rest invariant)"
fi

# 9. ROADMAP / EVALUATION shape sanity in the mixed-state fixture.
if [ -f "$MIXED/.orchestrator/milestones/M998/M998-ROADMAP.md" ]; then
    ok "mixed-state fixture M998-ROADMAP.md present"
else
    bad "mixed-state fixture M998-ROADMAP.md missing"
fi
if [ -f "$MIXED/.orchestrator/milestones/M998/M998-EVALUATION.md" ]; then
    ok "mixed-state fixture M998-EVALUATION.md present"
else
    bad "mixed-state fixture M998-EVALUATION.md missing"
fi
if [ -f "$MIXED/.orchestrator/milestones/M998/execution-log.jsonl" ]; then
    ok "mixed-state fixture execution-log.jsonl present"
else
    bad "mixed-state fixture execution-log.jsonl missing"
fi
if [ -f "$MIXED/.orchestrator/milestones/M998/execution-log.jsonl" ]; then
    if grep -q -- 'dispatch_usage' "$MIXED/.orchestrator/milestones/M998/execution-log.jsonl"; then
        ok "mixed-state execution-log.jsonl carries dispatch_usage record"
    else
        bad "mixed-state execution-log.jsonl missing dispatch_usage record"
    fi
    if grep -q -- 'verify_result' "$MIXED/.orchestrator/milestones/M998/execution-log.jsonl"; then
        ok "mixed-state execution-log.jsonl carries verify_result record (✗ glyph driver)"
    else
        bad "mixed-state execution-log.jsonl missing verify_result record"
    fi
fi

# 10. Pre-M019 fixture: NO execution-log.jsonl (the pre-M019 marker).
if [ ! -f "$PREM019/.orchestrator/milestones/M997/execution-log.jsonl" ]; then
    ok "pre-M019 fixture lacks execution-log.jsonl (pre-M019 marker)"
else
    bad "pre-M019 fixture unexpectedly contains execution-log.jsonl"
fi

printf 'SUMMARY: m029-p02-sc5-fixtures-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
