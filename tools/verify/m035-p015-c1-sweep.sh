#!/usr/bin/env bash
# tools/verify/m035-p015-c1-sweep.sh
#
# C1 (lowercase-hyphenated `spec-kit-orchestrator` -> `orchestrator`)
# residue check across `*.md` / `*.yml` / `*.yaml`. Allowlist covers
# historical/archived files documented in M035 P01.5 T04 plan.
#
# M035 P06 T05.5 reconciliation: extended allowlist to cover
# closed-milestone phase/archive artifacts (M035 P02/P03/P04/P06
# SUMMARY+PLAN files reference the legacy path verbatim as
# historical-state recording — same shape that operator-paths.sh
# already uses), `wiki/` (M032/M037 wiki content references the
# original repo URL by design — site_name, repo_url, etc. are
# operator-owned config), and `specs/040-wiki-readability-decorator/`
# (post-rename spec authored after the C1 sweep, references the
# legacy raw.githubusercontent.com path as a prose example).
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

residue=$(git grep -nE 'spec-kit-orchestrator' '*.md' '*.yml' '*.yaml' 2>/dev/null \
  | grep -vE '^(references/RENAME-PLAN\.md|docs/migrating-from-speckit\.md|\.orchestrator/proposals/papercut-sweep-pre-M030\.md|\.orchestrator/proposals/papercut-sweep-post-M035-HANDOFF\.md|\.orchestrator/milestones/M008/archive/|\.orchestrator/milestones/M0[0-9][0-9]/M0[0-9][0-9]-SUMMARY\.md|\.orchestrator/milestones/M0[0-9][0-9]/M0[0-9][0-9]-BODY\.txt|\.orchestrator/milestones/M0[0-9][0-9]/(phases|archive)/|CHANGELOG\.md|\.orchestrator/DECISIONS\.md|\.orchestrator/milestones/M035/M035-ROADMAP\.md|\.orchestrator/milestones/M035/M035-CONTEXT\.md|specs/039-packaging-distribution/spec\.md|specs/040-wiki-readability-decorator/|\.orchestrator/KNOWLEDGE\.md|specs/001-orchestrator/conversus-|wiki/)' || true)

if [ -n "$residue" ]; then
  echo "FAIL: residual spec-kit-orchestrator matches in non-historical *.md/*.yml/*.yaml files:" >&2
  echo "$residue" >&2
  exit 1
fi
echo "PASS: m035-p015-c1-sweep"
exit 0
