#!/usr/bin/env bash
# tests/test-read-roadmap-mixed-depends.sh — Group 2 / paper-cut sweep
#
# Bug: read-roadmap.sh treated any non-^P[0-9] token in a phase's `Depends:`
# list as a parser-bug indicator and refused to schedule the phase. Mixed
# entries like `Depends: P03, BG-002 closure` (where BG-002 is an external
# bug-gate, not a phase) caused fatal "unparseable dependency token"
# warnings and a deps_satisfied=false verdict, even when P03 was the only
# load-bearing dep and was complete.
#
# Fix: filter dep tokens to ^P[0-9]+$. Tokens that begin with `P<digit>`
# but don't match (Pfoo, P-1, P3a) keep the load-bearing warn+refuse path
# (catches parens-in-Risk parser pollution). Other shapes (BG-###, prose
# words) are silently skipped per the documented convention.
#
# This test stages a synthetic roadmap with a mixed Depends: line and
# asserts:
#   1. active-phase resolves correctly (BG-### token does not block).
#   2. A genuinely-malformed phase token (P3a) still triggers the warn+refuse.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
READ_ROADMAP="$PROJECT_ROOT/scripts/state/read-roadmap.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1"; }

TMPDIR_FX="$(mktemp -d -t papercut-mixed-depends.XXXXXX)"
trap 'rm -rf "$TMPDIR_FX"' EXIT

# --- Test 1: Mixed Depends with BG-### → active-phase resolves ---
RM1="$TMPDIR_FX/roadmap-mixed.md"
cat >"$RM1" <<'ROADMAP'
---
milestone: M999
feature_ref: "999-mixed-depends"
feature_spec: "specs/999-mixed-depends/spec.md"
vision: "BG-### token does not block scheduling"
tier: C
created_at: "2026-04-29T10:00:00Z"
updated_at: "2026-04-29T10:00:00Z"
---

## Phases

- [x] **P01**: Foundation — "P01 demo"
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces: foundation
    - Consumes: none

- [ ] **P02**: Mixed Depends — "P02 demo"
  - Risk: low
  - Depends: P01, BG-002 closure
  - Boundary Map:
    - Produces: feature
    - Consumes: P01/foundation
ROADMAP

active="$(bash "$READ_ROADMAP" "$RM1" active-phase 2>/dev/null)" || true
if [[ "$active" = "P02" ]]; then
  pass "BG-### token in Depends: silently skipped; active-phase=P02"
else
  fail "active-phase should be P02 (got: '$active')"
fi

# --- Test 2: Malformed phase token (P3a) still triggers warn+refuse ---
RM2="$TMPDIR_FX/roadmap-malformed.md"
cat >"$RM2" <<'ROADMAP'
---
milestone: M999
feature_ref: "999-malformed-phase-token"
feature_spec: "specs/999-malformed-phase-token/spec.md"
vision: "Malformed phase token preserves warn+refuse path"
tier: C
created_at: "2026-04-29T10:00:00Z"
updated_at: "2026-04-29T10:00:00Z"
---

## Phases

- [x] **P01**: Foundation — "P01 demo"
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces: foundation
    - Consumes: none

- [ ] **P02**: Malformed Dep — "P02 demo"
  - Risk: low
  - Depends: P3a
  - Boundary Map:
    - Produces: feature
    - Consumes: P01/foundation
ROADMAP

stderr="$(bash "$READ_ROADMAP" "$RM2" active-phase 2>&1 >/dev/null)" || true
active2="$(bash "$READ_ROADMAP" "$RM2" active-phase 2>/dev/null)" || true
if printf '%s\n' "$stderr" | grep -qE "unparseable dependency token 'P3a'"; then
  pass "malformed phase token (P3a) emits warn-and-refuse"
else
  fail "malformed phase token should emit warn (stderr: $stderr)"
fi
if [[ "$active2" = "none" ]]; then
  pass "malformed phase token blocks scheduling (active=none)"
else
  fail "malformed phase token should block scheduling (got active='$active2')"
fi

echo "----"
echo "PASS: $PASS_COUNT  FAIL: $FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
