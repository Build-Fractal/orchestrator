#!/usr/bin/env bash
# tools/verify/m035-p015-c2-c3-prose.sh
#
# C2 (title-case prose `Spec-Kit Orchestrator` -> `Orchestrator`) + C3
# (lowercase-spaced prose `spec-kit orchestrator` / `spec kit orchestrator`
# -> `orchestrator`) residue check across `*.md`. Allowlist mirrors the
# T04/C1 sweep allowlist plus M035-ROADMAP.md / M035-CONTEXT.md (the
# Boundary Map enumerates the rename mappings as literal source tokens
# and must preserve them). Upstream `spec-kit` framework references
# (the Anthropic project the orchestrator originally migrated from) are
# C4-classification scope (T07), not C2/C3.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

residue=$(git grep -niE 'Spec-Kit Orchestrator|spec-kit orchestrator|spec kit orchestrator' '*.md' 2>/dev/null \
  | grep -vE '^(references/RENAME-PLAN\.md|docs/migrating-from-speckit\.md|\.orchestrator/proposals/papercut-sweep-pre-M030\.md|\.orchestrator/milestones/M008/archive/|\.orchestrator/milestones/M0[0-9][0-9]/M0[0-9][0-9]-SUMMARY\.md|\.orchestrator/milestones/M0[0-9][0-9]/M0[0-9][0-9]-BODY\.txt|CHANGELOG\.md|\.orchestrator/DECISIONS\.md|\.orchestrator/milestones/M035/phases/P01\.5/|\.orchestrator/milestones/M035/M035-ROADMAP\.md|\.orchestrator/milestones/M035/M035-CONTEXT\.md|specs/039-packaging-distribution/spec\.md|\.orchestrator/KNOWLEDGE\.md|specs/001-orchestrator/conversus-)' || true)

if [ -n "$residue" ]; then
  echo "FAIL: residual C2/C3 prose matches in non-historical *.md files:" >&2
  echo "$residue" >&2
  exit 1
fi
echo "PASS: m035-p015-c2-c3-prose"
exit 0
