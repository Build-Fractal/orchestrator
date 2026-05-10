#!/usr/bin/env bash
# tools/verify/m035-p015-operator-paths.sh
#
# M035 P01.5 T03 (C6) verifier.
#
# Asserts: every in-tree match for `~/Sites/spec-kit-orchestrator` or
# `/Sites/spec-kit-orchestrator` outside the historical allowlist has
# been rewritten to the new `~/Sites/orchestrator` form.
#
# Historical allowlist (paths whose matches are intentionally preserved):
#
#   - references/RENAME-PLAN.md
#       Documents the rename runbook.
#   - .orchestrator/milestones/M008/archive/
#       Archived milestone payloads.
#   - .orchestrator/milestones/M0[0-9][0-9]/ (M018, M020, M024, M028,
#     M030, M031, M032, M033, M036, M037 plan/payload/summary files)
#       Closed-milestone authoring artifacts that hardcoded local paths
#       in their plan recipes; rewriting would corrupt historical state.
#   - .orchestrator/milestones/M035/M035-ROADMAP.md
#       Boundary-Map narrative explaining the C6 rename.
#   - .orchestrator/milestones/M035/phases/P01.5/
#       This phase's planning + task-plan artifacts (document the rename).
#   - .orchestrator/milestones/M035/phases/P01/tasks/T01-,T03- PLAN.md
#       P01 fixture-data references (also unchanged in the fixture).
#   - .orchestrator/DECISIONS.md
#       D-RN-5..D-RN-7 narrative (records the rename decision).
#   - .orchestrator/proposals/
#       Pre-rename proposal text (M035 brief, papercut sweeps, etc.).
#   - .orchestrator/scratch/
#       Operator scratch scripts (historical).
#   - .orchestrator/handoffs/
#       Historical dogfood handoff documents.
#   - .orchestrator/KNOWLEDGE.md
#       Historical knowledge entries (re-built via knowledge-rebuild).
#   - CHANGELOG.md
#       Archived release-note entries reference the old path.
#   - tests/m035-acceptance/fixtures/
#       Fixture data exercised by P01 verifiers (drift detection).
#   - tests/fixtures/m036-live-llm-smoke/
#       Live-LLM smoke regression artifacts (pre-rename absolute paths).
#   - tools/verify/m035-p015-operator-paths.sh
#       This verifier itself — its top-of-file comment + impl regex +
#       FAIL message all literally contain `~/Sites/spec-kit-orchestrator`
#       as part of the contract definition. Self-match added under
#       M035 P06 T05.5 reconciliation.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

# Single-line regex: alternations of allowlisted path prefixes / files.
# Each alternative is anchored at start of line. Matches the prefix of a
# `git grep -n` line (`<path>:<lineno>:<content>`) — the `:` separator
# comes after the filename, not after a directory prefix, so we don't
# anchor a trailing `:` here.
allowlist_re='^(references/RENAME-PLAN\.md:|\.orchestrator/milestones/M008/archive/|\.orchestrator/milestones/M0[0-9][0-9]/(phases|archive)/|\.orchestrator/milestones/M035/M035-ROADMAP\.md:|\.orchestrator/milestones/M035/phases/P01\.5/|\.orchestrator/milestones/M035/phases/P01/tasks/T0[13]-|\.orchestrator/DECISIONS\.md:|\.orchestrator/proposals/|\.orchestrator/scratch/|\.orchestrator/handoffs/|\.orchestrator/KNOWLEDGE\.md:|CHANGELOG\.md:|tests/m035-acceptance/fixtures/|tests/fixtures/m036-live-llm-smoke/|tools/verify/m035-p015-operator-paths\.sh:|wiki/)'

residue=$(git grep -nE '~?/Sites/spec-kit-orchestrator' 2>/dev/null \
  | grep -vE "$allowlist_re" || true)

if [ -n "$residue" ]; then
  echo "FAIL: residual ~/Sites/spec-kit-orchestrator matches in non-historical files:" >&2
  echo "$residue" >&2
  exit 1
fi

echo "PASS: m035-p015-operator-paths"
exit 0
