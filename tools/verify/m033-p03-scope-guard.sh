#!/usr/bin/env bash
# m033-p03-scope-guard.sh
#
# Bidirectional P03 scope-guard. Mirrors the P02/T05 pattern. Asserts:
#   - Forbidden creations: P04/P05 surface paths must NOT exist after
#     P03 close. This catches scope overflow (P03 leaking forward).
#   - Allowed creations: the P03 deliverable whitelist enumerated below
#     must exist. This catches scope underflow (a P03 task silently
#     skipping a deliverable).
#   - P02 boundary preservation: P02 surfaces still exist (P03 did not
#     delete them).
#   - wiki/ boundary (M033-tagged): no `M033*`/`m033*` filenames newly
#     created under wiki/ during P03 (per P01 D-T05-02 narrowing —
#     the orchestrator's pre-existing wiki/ content is not scanned).
#
# Bash 3.2 compatible. Load-bearing tokens (see grep assertions inline):
# scripts/lifecycle/materials-intake.sh, scripts/lifecycle/ideation.sh,
# scripts/lifecycle/customblock-draft.sh, commands/materials-intake.md,
# commands/ideation.md, commands/customblock-draft.md,
# constitution-author.sh, ingest-codebase.sh, SC-13.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass=0
fail=0

# --- Forbidden creations (P04/P05 surfaces). ---
forbidden=(
    scripts/lifecycle/materials-intake.sh
    scripts/lifecycle/ideation.sh
    scripts/lifecycle/customblock-draft.sh
    commands/materials-intake.md
    commands/ideation.md
    commands/customblock-draft.md
)

for f in "${forbidden[@]}"; do
    if [ -e "$PROJECT_ROOT/$f" ]; then
        fail=$((fail + 1))
        echo "FAIL: P03 scope-guard violated — $f exists (belongs to P04/P05)"
    else
        pass=$((pass + 1))
        echo "PASS: forbidden $f not present (P04/P05 deliverable)"
    fi
done

# --- Allowed creations (P03 deliverable whitelist). ---
# SC-13 / scope-guard invariant — drift detection is bidirectional.
allowed=(
    commands/constitution.md
    commands/ingest-codebase.md
    scripts/lifecycle/constitution-author.sh
    scripts/lifecycle/ingest-codebase.sh
    scripts/verify/constitution-shape-lint.sh
    scripts/verify/standalone-gate.sh
    templates/constitution-starters/web-saas.md
    templates/constitution-starters/cli-tool.md
    templates/constitution-starters/library.md
    references/constitution-starter-format.md
    references/imported-context-sentinel.md
    tests/fixtures/m033-stack-fixture-ts-saas/README.md
    tests/fixtures/m033-stack-fixture-py-cli/README.md
    tests/fixtures/m033-stack-fixture-rust-library/README.md
    tests/m033-acceptance/p02-constitution-author.sh
    tests/m033-acceptance/p03-ingest-codebase.sh
    tools/verify/m033-p03-constitution-md-shape.sh
    tools/verify/m033-p03-constitution-author-sh-shape.sh
    tools/verify/m033-p03-constitution-starter-templates-shape.sh
    tools/verify/m033-p03-constitution-starter-format-ref-shape.sh
    tools/verify/m033-p03-constitution-shape-lint-shape.sh
    tools/verify/m033-p03-standalone-gate-sh-shape.sh
    tools/verify/m033-p03-ingest-codebase-md-shape.sh
    tools/verify/m033-p03-ingest-codebase-sh-shape.sh
    tools/verify/m033-p03-rich-context-import-shape.sh
    tools/verify/m033-p03-imported-context-sentinel-shape.sh
    tools/verify/m033-p03-stack-fixtures-shape.sh
    tools/verify/m033-p03-acceptance-shape-sc2.sh
    tools/verify/m033-p03-acceptance-shape-sc3.sh
    tools/verify/m033-p03-cross-phase-regression.sh
    tools/verify/m033-p03-scope-guard.sh
    tools/verify/m033-p03-phase-suite.sh
)

for f in "${allowed[@]}"; do
    if [ -e "$PROJECT_ROOT/$f" ]; then
        pass=$((pass + 1))
        echo "PASS: allowed $f present (P03 whitelist)"
    else
        fail=$((fail + 1))
        echo "FAIL: allowed $f MISSING (P03 underflow — a task silently skipped)"
    fi
done

# --- P02 boundary preservation. ---
p02_surfaces=(
    scripts/util/jsonl-event-emitter.sh
    scripts/util/start-state-markers.sh
    scripts/lifecycle/grilling-shell.sh
    references/m033-fr21-dual-write-convention.md
    scripts/lifecycle/start.sh
    tools/verify/m033-p02-phase-suite.sh
)

for f in "${p02_surfaces[@]}"; do
    if [ -e "$PROJECT_ROOT/$f" ]; then
        pass=$((pass + 1))
        echo "PASS: P02 surface $f preserved"
    else
        fail=$((fail + 1))
        echo "FAIL: P02 surface $f MISSING (P03 deleted it)"
    fi
done

# --- wiki/ boundary (M033-tagged narrowing). ---
wiki_violations=0
if [ -d "$PROJECT_ROOT/wiki" ]; then
    wiki_tmp=$(mktemp)
    find "$PROJECT_ROOT/wiki" \( -name 'M033*' -o -name 'm033*' \) -print > "$wiki_tmp" 2>/dev/null || true
    while IFS= read -r match; do
        if [ -z "$match" ]; then
            continue
        fi
        wiki_violations=$((wiki_violations + 1))
        fail=$((fail + 1))
        echo "FAIL: P03 scope-guard violated — $match (M033 wiki content is M032 territory)"
    done < "$wiki_tmp"
    rm -f "$wiki_tmp"
fi
if [ "$wiki_violations" -eq 0 ]; then
    pass=$((pass + 1))
    echo "PASS: no M033-tagged paths newly added under wiki/ (SC-13 narrow scope)"
fi

echo "SUMMARY: m033-p03-scope-guard.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
