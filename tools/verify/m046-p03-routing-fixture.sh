#!/usr/bin/env bash
# tools/verify/m046-p03-routing-fixture.sh
# M046/P03/T01 -- routing-fixture verifier (SC-1 / FR-1).
#
# Asserts the three-way routing decision of scripts/intake/auto-entry.sh:
#
#   input                         expected route line                exit
#   ---------------------------   --------------------------------   ----
#   (empty arg)                   AUTO:ROUTE tier=c mode=loop         0
#                                   target=active
#   <existing milestone dir>      AUTO:ROUTE tier=c mode=loop         0
#                                   target=<dir>
#   Tier-A idea description       AUTO:ROUTE tier=a mode=one-shot     0
#   below-floor ambiguous desc    AUTO:BLOCK_AMBIGUITY                0
#
# The Tier-A one-shot case exercises the real degenerate fast-path, which
# invokes scripts/dispatch/build-context.sh. That helper appends one
# payload_breakdown record to the git-tracked
# .orchestrator/direct-mode-execution-log.jsonl. To keep the working tree
# clean (outer-auto-loop hygiene: scratch/mktemp only, never repo state),
# this verifier snapshots that log before the Tier-A run and restores its
# exact bytes afterwards. All other scratch (dispatch-stub, temp payloads)
# lives under a mktemp -d tree.
#
# Output: PASS: / FAIL: lines + a final
#   SUMMARY: m046-p03-routing-fixture.sh pass=N fail=M
# Exit 0 iff fail=0.
#
# Bash 3.2 compatible (MEM001): no declare -A, no process substitution.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
cd "$PROJECT_ROOT"

ENTRY="scripts/intake/auto-entry.sh"

pass=0
fail=0

pass() { printf 'PASS: %s\n' "$1"; pass=$(( pass + 1 )); }
fail() { printf 'FAIL: %s\n' "$1"; fail=$(( fail + 1 )); }

SCRATCH="$( mktemp -d -t m046-p03-routing.XXXXXX )"
DMLOG=".orchestrator/direct-mode-execution-log.jsonl"
DMLOG_BAK="$SCRATCH/dmlog.bak"
DMLOG_EXISTED=0
if [ -f "$DMLOG" ]; then
  DMLOG_EXISTED=1
  cp "$DMLOG" "$DMLOG_BAK"
fi

restore_dmlog() {
  if [ "$DMLOG_EXISTED" -eq 1 ]; then
    cp "$DMLOG_BAK" "$DMLOG"
  else
    rm -f "$DMLOG"
  fi
}

cleanup() {
  restore_dmlog
  rm -rf "$SCRATCH"
}
trap cleanup EXIT

# --- Case 1: empty arg -> Tier-C loop route ---------------------------------
out1="$SCRATCH/case1.out"
bash "$ENTRY" > "$out1" 2>&1
rc1=$?
if [ "$rc1" -eq 0 ]; then
  pass "empty arg exits 0"
else
  fail "empty arg expected exit 0, got $rc1"
fi
if grep -q 'AUTO:ROUTE tier=c mode=loop target=active' "$out1"; then
  pass "empty arg routes to Tier-C loop (target=active)"
else
  fail "empty arg missing AUTO:ROUTE tier=c mode=loop target=active"
fi

# --- Case 2: existing milestone dir -> Tier-C loop route --------------------
DIR_ARG=".orchestrator/milestones/M046"
out2="$SCRATCH/case2.out"
bash "$ENTRY" "$DIR_ARG" > "$out2" 2>&1
rc2=$?
if [ "$rc2" -eq 0 ]; then
  pass "dir arg exits 0"
else
  fail "dir arg expected exit 0, got $rc2"
fi
if grep -q "AUTO:ROUTE tier=c mode=loop target=$DIR_ARG" "$out2"; then
  pass "dir arg routes to Tier-C loop (target=$DIR_ARG)"
else
  fail "dir arg missing AUTO:ROUTE tier=c mode=loop target=$DIR_ARG"
fi

# --- Case 3: below-floor ambiguous description -> AUTO:BLOCK_AMBIGUITY -------
# An 8-word idea classifies as idea/low (below the 0.7 floor), non-tier_a_plus.
# Default --ambiguity-mode block refuses without dispatching.
AMB_DESC="add a retry flag to config loader now"
out3="$SCRATCH/case3.out"
bash "$ENTRY" "$AMB_DESC" > "$out3" 2>&1
rc3=$?
if [ "$rc3" -eq 0 ]; then
  pass "ambiguous arg exits 0"
else
  fail "ambiguous arg expected exit 0, got $rc3"
fi
if grep -q 'AUTO:BLOCK_AMBIGUITY' "$out3"; then
  pass "ambiguous arg emits AUTO:BLOCK_AMBIGUITY (default block mode)"
else
  fail "ambiguous arg missing AUTO:BLOCK_AMBIGUITY"
fi
if grep -q 'AUTO:ROUTE' "$out3"; then
  fail "ambiguous arg must NOT emit AUTO:ROUTE (below-floor block)"
else
  pass "ambiguous arg emits no AUTO:ROUTE line"
fi

# --- Case 4: Tier-A idea description -> one-shot route -----------------------
# A short (<= 7 word) idea classifies as idea/high, clears the floor, and
# routes to the degenerate one-shot fast-path. A no-op dispatch-stub stands
# in for the agent runtime so the temp payload is cleaned up.
STUB="$SCRATCH/noop-stub.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$STUB"
chmod +x "$STUB"
TIER_A_DESC="add retry flag to config loader"
out4="$SCRATCH/case4.out"
bash "$ENTRY" "$TIER_A_DESC" --dispatch-stub "$STUB" > "$out4" 2>&1
rc4=$?
if [ "$rc4" -eq 0 ]; then
  pass "Tier-A description exits 0"
else
  fail "Tier-A description expected exit 0, got $rc4"
fi
if grep -q 'AUTO:ROUTE tier=a mode=one-shot' "$out4"; then
  pass "Tier-A description routes to one-shot (tier=a)"
else
  fail "Tier-A description missing AUTO:ROUTE tier=a mode=one-shot"
fi

# --- Aggregate --------------------------------------------------------------
printf 'SUMMARY: m046-p03-routing-fixture.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
