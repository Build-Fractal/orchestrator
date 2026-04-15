#!/usr/bin/env bash
set -eu
# Verify: wider P03-reserved docs (all 11 non-primary docs in
# ALLOW_P03_DOCS from P02's sweep) no longer contain literal
# .specify/orchestrator/ or .specify/memory/constitution references
# outside explicit historical/migration callouts.
#
# "Explicit historical/migration callout" is defined as: the reference
# appears within 3 lines of the marker string "HISTORICAL", "MIGRATION",
# or a section heading containing "Migrat" or "Histor". For simplicity,
# this check counts occurrences per file and compares against a baseline
# of zero allowed; any file needing preserved historical references
# must graduate to the secondary ALLOW list maintained below.
WIDER_DOCS="references/engine.md references/events.md references/errors.md references/recipes.md references/file-formats.md references/state-machine.md references/tier-definitions.md references/constitution-walkthrough.md references/verification-ladder.md docs/knowledge-management.md docs/recipe-authoring.md docs/hook-development.md scripts/AGENTS.md"
fail=0
for f in $WIDER_DOCS; do
  test -f "$f" || { echo "FAIL: $f missing"; fail=1; continue; }
  legacy_count=$(grep -cE "\.specify/orchestrator|\.specify/memory/constitution" "$f" || true)
  if [ "$legacy_count" -gt 0 ]; then
    echo "FAIL: '$f' still has $legacy_count legacy path reference(s)"
    fail=1
  fi
done
if [ "$fail" -ne 0 ]; then exit 1; fi
echo "PASS: wider P03-reserved docs swept clean of legacy path references"
