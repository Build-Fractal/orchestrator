#!/usr/bin/env bash
# tests/test-check-must-haves-vacuity.sh — Tier 1 vacuity gate regression
#
# Bug: check-must-haves.sh emitted PASS/FAIL only from a `- Check:` sub-item. A
# top-level truth carrying no sub-item set PENDING_TRUTH and was then silently
# overwritten by the next truth — no PASS, no FAIL, no warning, no count. A
# Must-Haves block whose truths carried no checks therefore produced ZERO output
# and exit 0: Tier 1 static verification reporting success having executed
# nothing.
#
# Observed before the fix, on a plan declaring "The authentication layer is
# fully implemented and secure", "All payment flows are correct and audited",
# and "No data is lost on concurrent writes":
#
#     $ check-must-haves.sh <dir>
#     EXIT=0        # no output at all
#
# Fix: count declared truths, executed checks, and unchecked truths. Always
# report unchecked truths. When a Truths block ran zero checks the result is
# vacuous and fails loud; ALLOW_UNCHECKED_TRUTHS=1 downgrades to a warning.
#
# A static sweep of all 183 phase plans in this repo at the time of the fix
# found 181 clean / 1 partial / 0 vacuous — the hole was latent, never
# exploited — so failing loud breaks no existing plan.
#
# Asserts:
#   1. all-unchecked truths  → VACUOUS + exit 1 (was: silent exit 0)
#   2. mixed                 → UNCHECKED reported per truth, real checks still run
#   3. mixed, all checks pass→ exit 0 (unchecked alone must not fail a run that
#                              did verify something)
#   4. fully-checked plan    → no UNCHECKED, no VACUOUS, exit 0 (no false alarm)
#   5. ALLOW_UNCHECKED_TRUTHS=1 downgrades the vacuous case to exit 0

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CMH="$PROJECT_ROOT/scripts/verify/check-must-haves.sh"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1"; }

TMPDIR_FX="$(mktemp -d -t cmh-vacuity.XXXXXX)"
trap 'rm -rf "$TMPDIR_FX"' EXIT

mkplan() {
  local dir="$TMPDIR_FX/$1"
  mkdir -p "$dir"
  cat > "$dir/P01-PLAN.md"
  printf '%s' "$dir"
}

# --- Case 1: every truth unchecked → vacuous ---
D1="$(mkplan vacuous <<'PLAN'
# P01
## Must-Haves
### Truths
- The authentication layer is fully implemented and secure
- All payment flows are correct and audited
### Artifacts
### Key Links
PLAN
)"
OUT1="$(bash "$CMH" "$D1" 2>&1)"; RC1=$?
if [ "$RC1" -ne 0 ]; then
  pass "all-unchecked truths exit non-zero (was silent exit 0)"
else
  fail "all-unchecked truths still exit 0 — vacuous pass"
fi
if printf '%s' "$OUT1" | grep -q '^VACUOUS:'; then
  pass "all-unchecked truths emit VACUOUS"
else
  fail "no VACUOUS line emitted"
fi
if [ "$(printf '%s\n' "$OUT1" | grep -c '^UNCHECKED: ')" -eq 2 ]; then
  pass "each unchecked truth reported individually"
else
  fail "expected 2 UNCHECKED lines, got $(printf '%s\n' "$OUT1" | grep -c '^UNCHECKED: ')"
fi

# --- Case 2/3: mixed, all real checks pass → unchecked reported, exit 0 ---
D2="$(mkplan mixed <<'PLAN'
# P01
## Must-Haves
### Truths
- This one is checked
  - Check: `test 1 -eq 1`
- This one is not checked
### Artifacts
### Key Links
PLAN
)"
OUT2="$(bash "$CMH" "$D2" 2>&1)"; RC2=$?
if printf '%s' "$OUT2" | grep -q "^UNCHECKED: truth 'This one is not checked'"; then
  pass "mixed plan names the unchecked truth"
else
  fail "mixed plan did not report the unchecked truth"
fi
if printf '%s' "$OUT2" | grep -q "^PASS: truth 'This one is checked'"; then
  pass "mixed plan still runs the real check"
else
  fail "mixed plan lost the real check"
fi
if printf '%s' "$OUT2" | grep -q '^VACUOUS:'; then
  fail "mixed plan wrongly flagged VACUOUS (a check DID run)"
else
  pass "mixed plan not flagged VACUOUS"
fi
if [ "$RC2" -eq 0 ]; then
  pass "unchecked truths alone do not fail a run that verified something"
else
  fail "mixed plan exited $RC2 — unchecked alone must not fail the run"
fi

# --- Case 4: fully checked → no false alarm ---
D3="$(mkplan clean <<'PLAN'
# P01
## Must-Haves
### Truths
- Fully checked truth
  - Check: `test 1 -eq 1`
### Artifacts
### Key Links
PLAN
)"
OUT3="$(bash "$CMH" "$D3" 2>&1)"; RC3=$?
if printf '%s' "$OUT3" | grep -qE '^(UNCHECKED|VACUOUS)'; then
  fail "fully-checked plan raised a false alarm"
else
  pass "fully-checked plan raises no UNCHECKED/VACUOUS"
fi
if [ "$RC3" -eq 0 ]; then
  pass "fully-checked plan exits 0"
else
  fail "fully-checked plan exited $RC3"
fi

# --- Case 5: explicit opt-out downgrades to warning ---
OUT5="$(ALLOW_UNCHECKED_TRUTHS=1 bash "$CMH" "$D1" 2>&1)"; RC5=$?
if [ "$RC5" -eq 0 ]; then
  pass "ALLOW_UNCHECKED_TRUTHS=1 downgrades vacuous to warning"
else
  fail "ALLOW_UNCHECKED_TRUTHS=1 did not downgrade (rc=$RC5)"
fi
if printf '%s' "$OUT5" | grep -q '^VACUOUS:'; then
  pass "opt-out still leaves a VACUOUS trace"
else
  fail "opt-out suppressed the VACUOUS trace entirely"
fi

echo ""
echo "$PASS_COUNT/$((PASS_COUNT + FAIL_COUNT)) checks passed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "$FAIL_COUNT checks FAILED"
  exit 1
fi
