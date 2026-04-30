#!/usr/bin/env bash
# tests/test-check-must-haves-keylinks.sh — Group 4 / paper-cut sweep
#
# Bug: check-must-haves.sh:240 set from_full="$PROJECT_ROOT/$from_path"
# unconditionally. Plan-relative bare filenames in Key Links (e.g.
# `M066-CATALOG.md → spec.md` written without the
# .orchestrator/milestones/<MID>/phases/<PID>/ prefix) report FAIL
# because the actual file lives at the phase directory.
#
# Bug: check-must-haves.sh:249 grepped for the literal target basename
# including .ts/.tsx extension. TS/TSX module specifiers omit the
# extension (`from '@/lib/x'`, not `from '@/lib/x.ts'`), so key-links
# `StatusBar.test.ts → StatusBar.ts` produce false FAILs against
# TypeScript projects.
#
# Fix: bilateral path resolution (try PHASE_DIR first, fall back to
# PROJECT_ROOT) + .ts/.tsx extension stripping when the literal grep
# misses.
#
# This test stages two cases:
#   1. plan-relative key-link `T01-PLAN.md → spec.md` where spec.md
#      lives at PHASE_DIR — assert PASS post-patch.
#   2. extensionless TS import: key-link `StatusBar.test.ts → StatusBar.ts`
#      where the test file imports `from './StatusBar'` — assert PASS post-patch.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECK_MH="$PROJECT_ROOT/scripts/verify/check-must-haves.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1"; }

# --- Test 1: PHASE_DIR fallback for plan-relative source paths ---
TMPROOT1="$(mktemp -d -t papercut-cmh-phasedir.XXXXXX)"
trap 'rm -rf "$TMPROOT1" "${TMPROOT2:-/dev/null}"' EXIT
PHASE_DIR1="$TMPROOT1/.orchestrator/milestones/M999/phases/P01"
mkdir -p "$PHASE_DIR1"
# Mark project root so PROJECT_ROOT walk-up resolves cleanly.
mkdir -p "$TMPROOT1/.git"
# spec.md lives at PHASE_DIR (plan-relative), not PROJECT_ROOT.
cat >"$PHASE_DIR1/spec.md" <<'SPEC'
# Phase Spec
This phase produces M066-CATALOG.md.
SPEC
# Plan with a Must-Haves / Key Links entry pointing to plan-relative spec.md.
cat >"$PHASE_DIR1/P01-PLAN.md" <<'PLAN'
# P01 Plan

## Must-Haves

### Key Links
- `spec.md` → `M066-CATALOG.md` (catalog produced by phase)

## Notes
(trailing section so the Must-Haves section extractor sees a closing `## ` header)
PLAN

out1="$(bash "$CHECK_MH" "$PHASE_DIR1" 2>&1)" && rc1=$? || rc1=$?
if [[ "$rc1" -eq 0 ]] && printf '%s\n' "$out1" | grep -qE 'PASS: key-link spec.md → M066-CATALOG.md'; then
  pass "plan-relative source resolves via PHASE_DIR fallback"
else
  fail "plan-relative source should PASS via PHASE_DIR (rc=$rc1, output: $out1)"
fi

# --- Test 2: .ts extension stripping for extensionless module specifiers ---
TMPROOT2="$(mktemp -d -t papercut-cmh-tsstrip.XXXXXX)"
PHASE_DIR2="$TMPROOT2/.orchestrator/milestones/M999/phases/P01"
mkdir -p "$PHASE_DIR2"
mkdir -p "$TMPROOT2/.git"
mkdir -p "$TMPROOT2/src/components"
# StatusBar.test.ts imports from './StatusBar' (no extension).
cat >"$TMPROOT2/src/components/StatusBar.test.ts" <<'TEST'
import { StatusBar } from './StatusBar';

describe('StatusBar', () => {
  it('renders', () => {});
});
TEST
cat >"$TMPROOT2/src/components/StatusBar.ts" <<'IMPL'
export const StatusBar = () => null;
IMPL
# Plan key-link uses the literal `.ts` extension on both sides.
cat >"$PHASE_DIR2/P01-PLAN.md" <<'PLAN'
# P01 Plan

## Must-Haves

### Key Links
- `src/components/StatusBar.test.ts` → `src/components/StatusBar.ts` (test imports impl)

## Notes
(trailing section so the Must-Haves section extractor sees a closing `## ` header)
PLAN

out2="$(bash "$CHECK_MH" "$PHASE_DIR2" 2>&1)" && rc2=$? || rc2=$?
if [[ "$rc2" -eq 0 ]] && printf '%s\n' "$out2" | grep -qE 'PASS: key-link src/components/StatusBar\.test\.ts → src/components/StatusBar\.ts'; then
  pass ".ts extension stripped for extensionless module specifier"
else
  fail "extensionless TS import should PASS (rc=$rc2, output: $out2)"
fi

echo "----"
echo "PASS: $PASS_COUNT  FAIL: $FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
