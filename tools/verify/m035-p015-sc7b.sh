#!/usr/bin/env bash
# tools/verify/m035-p015-sc7b.sh -- SC-7b spec-kit-orchestrator grep-zero-match assertion.
#
# Asserts that CLAUDE.md, README.md, and (if present) package.json
# contain zero residual references to the legacy 'spec-kit-orchestrator'
# repository basename. Activated under #Q-G1 Option A per the M035
# roadmap line 91 amendment. package.json is conditional -- P02 authors
# it; pre-P02 the check is a no-op for that file.
#
# Single-script-file shape per AD-19. No compound chains (CON-3 / AP-009).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

fail=0

for f in "CLAUDE.md" "README.md"; do
  if [ -f "$REPO_ROOT/$f" ]; then
    if grep -qE 'spec-kit-orchestrator' "$REPO_ROOT/$f"; then
      echo "FAIL: SC-7b -- $f still references spec-kit-orchestrator" >&2
      fail=1
    fi
  fi
done

# package.json optional -- only check if exists (P02 authors it).
if [ -f "$REPO_ROOT/package.json" ]; then
  if grep -qE 'spec-kit-orchestrator' "$REPO_ROOT/package.json"; then
    echo "FAIL: SC-7b -- package.json still references spec-kit-orchestrator" >&2
    fail=1
  fi
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: m035-p015-sc7b"
  exit 0
fi
exit 1
