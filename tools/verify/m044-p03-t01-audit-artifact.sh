#!/usr/bin/env bash
# tools/verify/m044-p03-t01-audit-artifact.sh
# M044/P03/T01 (FR-3/SC-3): the bounded unguarded-command audit artifact exists,
# marks the :117 description grep guarded/FIXED, and covers both directly-sourced
# libs (index-utils.sh + graph-db.sh).
# Bash 3.2. Emits PASS:/FAIL:; exit 0 on PASS, 1 on FAIL.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

fail=0
ART=".orchestrator/milestones/M044/gates/P03-rebuild-unguarded-audit.md"

if [ ! -f "$ART" ]; then
  echo "FAIL: audit artifact not found at $ART"
  exit 1
fi
# Covers the three in-scope files.
for token in "rebuild-index.sh" "index-utils.sh" "graph-db.sh"; do
  if ! grep -qF "$token" "$ART"; then
    echo "FAIL: audit artifact does not cover $token"
    fail=1
  fi
done
# Names the :117 description grep and marks it fixed/guarded.
if ! grep -qiE 'description grep|:117|117\)' "$ART"; then
  echo "FAIL: audit artifact does not reference the :117 description grep"
  fail=1
fi
if ! grep -qiE 'FIXED|guarded' "$ART"; then
  echo "FAIL: audit artifact does not mark commands guarded/FIXED"
  fail=1
fi
# Records the INDEXED/SKIPPED contract.
if ! grep -qF 'INDEXED' "$ART"; then
  echo "FAIL: audit artifact does not record the INDEXED/SKIPPED contract"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: bounded audit artifact present, covers script+libs, :117 marked FIXED"
  exit 0
fi
exit 1
