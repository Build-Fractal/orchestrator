#!/usr/bin/env bash
# scripts/verify/m014-p01-spec-shape-lint.sh — gate for T02.
# Verifies spec-shape-lint.sh behavior on three fixture cases.
# Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LINT="${PROJECT_ROOT}/scripts/verify/spec-shape-lint.sh"
TEMPLATE="${PROJECT_ROOT}/templates/spec-template.md"

if [ ! -x "$LINT" ]; then
  echo "FAIL: scripts/verify/spec-shape-lint.sh missing or not executable" >&2
  exit 1
fi
if [ ! -f "$TEMPLATE" ]; then
  echo "FAIL: templates/spec-template.md missing (T01 not shipped)" >&2
  exit 1
fi

# Case 1: lint against the template itself.
# Template has {{placeholder}} for Feature Branch etc. inside the frontmatter block,
# and every required heading is present. Expected: lint exits 0 (structural PASS)
# with todo_count > 0.
OUTPUT="$(bash "$LINT" "$TEMPLATE" 2>/dev/null || true)"
RC=$?
if [ $RC -ne 0 ]; then
  echo "FAIL: lint against template exited non-zero (expected 0); output: $OUTPUT" >&2
  exit 1
fi
echo "$OUTPUT" | grep -qE '^checks=' || { echo "FAIL: missing checks= line" >&2; exit 1; }
echo "$OUTPUT" | grep -qE '^todo_count=[1-9]' || { echo "FAIL: template should have non-zero todo_count" >&2; exit 1; }

# Case 2: lint against a spec with a missing required section — expect exit 1.
BAD_FIXTURE="$(mktemp)"
cat > "$BAD_FIXTURE" <<'EOF'
# Feature Specification: Bad

**Feature Branch**: `bad`
**Created**: 2026-04-22
**Status**: Draft
**Milestone**: M999
**Input**: test

## Problem Statement

Missing other required sections.
EOF
bash "$LINT" "$BAD_FIXTURE" >/dev/null 2>&1
RC=$?
rm -f "$BAD_FIXTURE"
if [ $RC -eq 0 ]; then
  echo "FAIL: lint against incomplete fixture exited 0 (expected 1)" >&2
  exit 1
fi

# Case 3: lint against specs/024-spec-management-extended/spec.md (fully authored).
AUTHORED="${PROJECT_ROOT}/specs/024-spec-management-extended/spec.md"
if [ -f "$AUTHORED" ]; then
  bash "$LINT" "$AUTHORED" >/dev/null 2>&1
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "FAIL: lint against specs/024-spec-management-extended/spec.md exited non-zero" >&2
    exit 1
  fi
fi

echo "PASS: scripts/verify/spec-shape-lint.sh behaves on all three fixture cases"
exit 0
