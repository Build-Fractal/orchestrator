#!/usr/bin/env bash
# m033-p02-scope-guard.sh
#
# Bidirectional P02 scope-guard. Asserts:
#   - Forbidden creations: P03/P04/P05 surface paths must NOT exist
#     after P02 close. This catches scope overflow (P02 leaking forward).
#   - Allowed creations: the 20 P02 whitelist deliverables enumerated
#     in P02-PLAN.md "Files Likely Touched" must exist. This catches
#     scope underflow (a P02 task silently skipping a deliverable).
#   - No M033-tagged paths newly created under wiki/ during P02.
#
# Combined, the two halves mirror the M033/P01/m033-p01-scope-guard.sh
# bidirectional pattern.
#
# Bash 3.2 compatible (MEM001).

set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass=0
fail=0

# --- Forbidden creations (P03/P04/P05 surfaces). ---
forbidden=(
    scripts/lifecycle/constitution-author.sh
    scripts/lifecycle/ingest-codebase.sh
    scripts/lifecycle/materials-intake.sh
    scripts/lifecycle/ideation.sh
    scripts/lifecycle/customblock-draft.sh
    templates/constitution-starters/web-saas.md
    templates/constitution-starters/cli-tool.md
    templates/constitution-starters/library.md
    commands/constitution.md
    commands/ingest-codebase.md
    commands/materials-intake.md
    commands/ideation.md
    commands/customblock-draft.md
    references/constitution-starter-format.md
    references/customblock-format.md
)

for f in "${forbidden[@]}"; do
    if [ -e "$PROJECT_ROOT/$f" ]; then
        fail=$((fail + 1))
        echo "FAIL: P02 scope-guard violated — $f exists (belongs to P03/P04/P05)"
    else
        pass=$((pass + 1))
        echo "PASS: forbidden $f not present (P03/P04/P05 deliverable)"
    fi
done

# --- Wiki write boundary. ---
# P02 must not author M033-tagged content under wiki/. The wiki/ dir
# itself predates M033 (M012); only M033-prefixed basenames are flagged.
wiki_violations=0
if [ -d "$PROJECT_ROOT/wiki" ]; then
    while IFS= read -r match; do
        [ -z "$match" ] && continue
        wiki_violations=$((wiki_violations + 1))
        fail=$((fail + 1))
        echo "FAIL: P02 scope-guard violated — $match (M033 wiki content is P05/M032 territory)"
    done <<EOF
$(find "$PROJECT_ROOT/wiki" \( -name 'M033*' -o -name 'm033*' \) -print 2>/dev/null)
EOF
fi
if [ "$wiki_violations" -eq 0 ]; then
    pass=$((pass + 1))
    echo "PASS: no M033-tagged paths newly added under wiki/"
fi

# --- Allowed creations (P02 whitelist — 20 deliverables). ---
allowed=(
    scripts/lifecycle/grilling-shell.sh
    scripts/util/jsonl-event-emitter.sh
    scripts/util/start-state-markers.sh
    scripts/lifecycle/start.sh
    references/m033-fr21-dual-write-convention.md
    tests/m033-acceptance/p07-grilling-shell.sh
    tests/m033-acceptance/p07-resume-on-partial-state.sh
    tests/m033-acceptance/p07-observability-records.sh
    tools/verify/m033-p02-grilling-shell-shape.sh
    tools/verify/m033-p02-grilling-shell-contradiction-detection.sh
    tools/verify/m033-p02-glossary-writer-shape.sh
    tools/verify/m033-p02-jsonl-event-schema.sh
    tools/verify/m033-p02-start-state-markers-shape.sh
    tools/verify/m033-p02-start-sh-resume-extension.sh
    tools/verify/m033-p02-fr21-convention-shape.sh
    tools/verify/m033-p02-acceptance-shape-sc11.sh
    tools/verify/m033-p02-acceptance-shape-sc12.sh
    tools/verify/m033-p02-acceptance-shape-sc13.sh
    tools/verify/m033-p02-phase-suite.sh
    tools/verify/m033-p02-scope-guard.sh
)

for f in "${allowed[@]}"; do
    if [ -e "$PROJECT_ROOT/$f" ]; then
        pass=$((pass + 1))
        echo "PASS: allowed $f present (P02 whitelist)"
    else
        fail=$((fail + 1))
        echo "FAIL: allowed $f MISSING (P02 underflow — a task silently skipped)"
    fi
done

echo "SUMMARY: m033-p02-scope-guard.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
