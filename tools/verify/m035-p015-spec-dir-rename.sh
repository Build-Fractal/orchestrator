#!/usr/bin/env bash
# tools/verify/m035-p015-spec-dir-rename.sh
#
# T02 (M035 P01.5) verifier — C9 spec directory rename + content reference
# sweep. Asserts:
#   1. specs/001-orchestrator/ exists as a directory.
#   2. specs/001-speckit-orchestrator/ does NOT exist.
#   3. specs/001-orchestrator/spec.md exists (sentinel from rename).
#   4. git log --follow on the sentinel file returns at least one commit
#      hash (history preservation through the git mv).
#   5. The non-historical content-reference targets named in T02 step 2
#      (CLAUDE.md, references/file-formats.md, plus 8 fixture
#      M001-ROADMAP.md files and roadmap-sample.md) all contain ZERO
#      matches for `specs/001-speckit-orchestrator`.
#
# Allowlist (NOT checked by this verifier — preserved on purpose):
#   - references/RENAME-PLAN.md (the runbook itself)
#   - .orchestrator/milestones/M008/archive/ (archived milestone)
#   - .orchestrator/milestones/M015/phases/P04/evidence/ (archived evidence)
#   - .orchestrator/milestones/M035/M035-ROADMAP.md (narrative)
#   - .orchestrator/milestones/M035/phases/P01.5/*PLAN.md (narrative)
#   - .planning/speckit-orchestrator-playbook.md (operator playbook)
#
# Exit 0 on PASS; exit 1 on FAIL.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fail=0

if [ ! -d "$REPO_ROOT/specs/001-orchestrator" ]; then
  echo "FAIL: specs/001-orchestrator/ does not exist" >&2
  fail=1
fi

if [ -d "$REPO_ROOT/specs/001-speckit-orchestrator" ]; then
  echo "FAIL: specs/001-speckit-orchestrator/ still exists (should be gone)" >&2
  fail=1
fi

if [ ! -f "$REPO_ROOT/specs/001-orchestrator/spec.md" ]; then
  echo "FAIL: specs/001-orchestrator/spec.md missing (sentinel)" >&2
  fail=1
fi

# git log --follow history preservation check (must return >=1 commit hash).
if [ -d "$REPO_ROOT/.git" ] && [ -f "$REPO_ROOT/specs/001-orchestrator/spec.md" ]; then
  log_first_line="$(cd "$REPO_ROOT" && git log --follow --pretty=format:%H specs/001-orchestrator/spec.md 2>/dev/null | head -n 1 || true)"
  if [ -z "$log_first_line" ]; then
    echo "FAIL: git log --follow specs/001-orchestrator/spec.md returned no commits" >&2
    fail=1
  fi
fi

# Sweep targets — must contain ZERO old-path references.
for f in \
  "CLAUDE.md" \
  "references/file-formats.md" \
  "tests/fixtures/roadmap-sample.md" \
  "tests/fixtures/state-complete/M001-ROADMAP.md" \
  "tests/fixtures/state-completing/M001-ROADMAP.md" \
  "tests/fixtures/state-executing/M001-ROADMAP.md" \
  "tests/fixtures/state-replanning/M001-ROADMAP.md" \
  "tests/fixtures/state-summarizing/M001-ROADMAP.md" \
  "tests/fixtures/state-validating/M001-ROADMAP.md" \
  "tests/fixtures/state-verifying/M001-ROADMAP.md"; do
  full="$REPO_ROOT/$f"
  if [ ! -f "$full" ]; then
    echo "FAIL: $f missing (expected sweep target)" >&2
    fail=1
    continue
  fi
  if grep -qE 'specs/001-speckit-orchestrator' "$full"; then
    echo "FAIL: $f still references specs/001-speckit-orchestrator" >&2
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "PASS: m035-p015-spec-dir-rename"
  exit 0
fi
exit 1
