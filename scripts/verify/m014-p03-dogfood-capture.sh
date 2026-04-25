#!/usr/bin/env bash
# scripts/verify/m014-p03-dogfood-capture.sh
# Gate: M014/P03/T05 — dogfood data file from T02 exists with the
# required sections and cites D023 (FR-9 baseline + retune trigger).
# AD-19 single-script-file shape; CON-6 / MEM001 Bash 3.2.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOGFOOD="${PROJECT_ROOT}/specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f "$DOGFOOD" ] || fail "inbox-dogfood.md missing at $DOGFOOD"

# Required sections.
grep -qE '^## Status' "$DOGFOOD"                         || fail "Status section missing"
grep -qE '^## Snapshot' "$DOGFOOD"                       || fail "Snapshot section missing"
grep -qE '^## Per-class counts' "$DOGFOOD"               || fail "Per-class counts section missing"
grep -qE '^## FR-9 shape pinned' "$DOGFOOD"              || fail "FR-9 shape pinned section missing"
grep -qE '^## Retune trigger' "$DOGFOOD"                 || fail "Retune trigger section missing"
grep -qE '^## Cross-references' "$DOGFOOD"               || fail "Cross-references section missing"

# Must cite D023.
grep -qF 'D023' "$DOGFOOD"                               || fail "D023 cross-reference missing"

# Per-class counts table covers all four classes.
grep -qF 'uat-bug' "$DOGFOOD"                            || fail "uat-bug class missing from counts"
grep -qF 'decision-append' "$DOGFOOD"                    || fail "decision-append class missing from counts"
grep -qF 'spec-amendment' "$DOGFOOD"                     || fail "spec-amendment class missing from counts"
grep -qF 'ambiguous' "$DOGFOOD"                          || fail "ambiguous class missing from counts"

# Retune trigger names both volume + calibration triggers.
grep -qE 'Volume trigger' "$DOGFOOD"                     || fail "Volume trigger language missing"
grep -qE 'Calibration trigger' "$DOGFOOD"                || fail "Calibration trigger language missing"

echo "PASS: $(basename "$0")"
exit 0
