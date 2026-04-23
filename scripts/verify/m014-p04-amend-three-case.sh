#!/usr/bin/env bash
# Gate: T06 — FR-14 --amend three-case body + SC-14 invariant.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SPECIFY="${PROJECT_ROOT}/scripts/specify/specify.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -x "$SPECIFY" ] || fail "specify.sh not executable"

# P01 stub language gone.
grep -qF 'P01 ships the surface; full three-case semantics land in P04' "$SPECIFY" \
  && fail "P01 amend stub message still present"

# Full body markers present.
grep -qF 'amend-section' "$SPECIFY"              || fail "amend-section action_type missing"
grep -qF 'case (a)' "$SPECIFY"                   || fail "case (a) handling missing"
grep -qF 'case (b)' "$SPECIFY"                   || fail "case (b) handling missing"
grep -qF 'shasum -a 256' "$SPECIFY"              || fail "shasum invariant check missing"

# Hermetic scratch amend.
SCRATCH="$(mktemp -d)"
mkdir -p "${SCRATCH}/.orchestrator"
# Seed spec with (a) all-placeholder, (b) partial, (c) fully-authored sections.
cat > "${SCRATCH}/seed-spec.md" <<'SPEC'
# Feature Specification: Amend Seed

## Problem Statement
<TODO: describe>

## User Scenarios
<TODO: describe>
Some authored prose lives here.

## Functional Requirements
- FR-1: A fully-authored requirement with no placeholders.
- FR-2: Another authored line.

## Success Criteria
- SC-1: Authored success criterion.
SPEC

PRE_SHA="$(shasum -a 256 "${SCRATCH}/seed-spec.md" | awk '{print $1}')"

# Run amend.
OUT="$(bash "$SPECIFY" --amend "${SCRATCH}/seed-spec.md" 2>&1)"
RC=$?
if [ "$RC" -ne 0 ]; then fail "amend exited $RC (expected 0)"; fi

# Diagnostic for case (a) + case (b) printed to stderr.
echo "$OUT" | grep -qF "case (a)" || fail "amend output missing case (a) diagnostic"
echo "$OUT" | grep -qF "case (b)" || fail "amend output missing case (b) diagnostic"

POST_SHA="$(shasum -a 256 "${SCRATCH}/seed-spec.md" | awk '{print $1}')"

# SC-14: case (b) + (c) bytes are unchanged; case (a) no-ops in P04 (LLM-fill deferred).
# Entire file shasum must match.
if [ "$PRE_SHA" != "$POST_SHA" ]; then
  fail "SC-14 byte-preservation violated: pre=${PRE_SHA} post=${POST_SHA}"
fi

# --dry-run emits amend-section records.
DRY_OUT="$(bash "$SPECIFY" --amend "${SCRATCH}/seed-spec.md" --dry-run 2>/dev/null)"
if ! echo "$DRY_OUT" | grep -qF 'amend-section'; then
  rm -rf "$SCRATCH"
  fail "--dry-run missing amend-section records"
fi

rm -rf "$SCRATCH"
echo "PASS: --amend three-case body + SC-14 invariant verified"
exit 0
