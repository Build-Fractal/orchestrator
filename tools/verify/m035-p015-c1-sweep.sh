#!/usr/bin/env bash
# tools/verify/m035-p015-c1-sweep.sh
#
# C1 (lowercase-hyphenated `spec-kit-orchestrator` -> `orchestrator`)
# residue check across `*.md` / `*.yml` / `*.yaml`. Allowlist covers
# historical/archived files documented in M035 P01.5 T04 plan.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

residue=$(git grep -nE 'spec-kit-orchestrator' '*.md' '*.yml' '*.yaml' 2>/dev/null \
  | grep -vE '^(references/RENAME-PLAN\.md|docs/migrating-from-speckit\.md|\.orchestrator/proposals/papercut-sweep-pre-M030\.md|\.orchestrator/milestones/M008/archive/|\.orchestrator/milestones/M0[0-9][0-9]/M0[0-9][0-9]-SUMMARY\.md|\.orchestrator/milestones/M0[0-9][0-9]/M0[0-9][0-9]-BODY\.txt|CHANGELOG\.md|\.orchestrator/DECISIONS\.md|\.orchestrator/milestones/M035/phases/P01\.5/|\.orchestrator/milestones/M035/M035-ROADMAP\.md|\.orchestrator/milestones/M035/M035-CONTEXT\.md|specs/039-packaging-distribution/spec\.md|\.orchestrator/KNOWLEDGE\.md|specs/001-orchestrator/conversus-)' || true)

if [ -n "$residue" ]; then
  echo "FAIL: residual spec-kit-orchestrator matches in non-historical *.md/*.yml/*.yaml files:" >&2
  echo "$residue" >&2
  exit 1
fi
echo "PASS: m035-p015-c1-sweep"
exit 0
