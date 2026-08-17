#!/usr/bin/env bash
# tools/verify/m046-p03-phase-suite.sh
# M046/P03 -- phase-suite aggregator + CON-2 reuse assertion.
#
# Runs the four P03 member verifiers in dependency order and reports a
# SUITE: line per member plus a final SUMMARY: line. Also asserts the CON-2 /
# FR-2 reuse invariant directly against scripts/intake/auto-entry.sh.
#
# Members (dependency order):
#   1. m046-p03-routing-fixture.sh   (SC-1 / FR-1 -- three-way routing)
#   2. m046-p03-shim-parity.sh       (SC-2       -- byte-equality gate)
#   3. m046-p03-shim-forward.sh      (FR-3       -- six-flag forward)
#   4. m046-p03-update-restage.sh    (FR-4       -- bundle re-stage wiring)
#
# CON-2 / FR-2 reuse assertion (in-suite, presence/absence grep):
#   - auto-entry.sh invokes shape-detect.sh, route-to-dispatch.sh, and
#     build-context.sh BY PATH.
#   - auto-entry.sh never invokes / writes / re-implements auto-loop.sh
#     (at most an inert prose reference in comments -- never a `bash ...
#     auto-loop.sh` invocation or a redirect into it).
#
# Output: SUITE: <member> result=<pass|fail> per member, PASS:/FAIL: for the
# CON-2 checks, and a final
#   SUMMARY: m046-p03-phase-suite.sh pass=N fail=M
# Exit 0 iff every member passed AND the CON-2 assertions hold.
#
# Bash 3.2 compatible (MEM001): no declare -A, no process substitution.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
cd "$PROJECT_ROOT"

pass=0
fail=0
pass() { printf 'PASS: %s\n' "$1"; pass=$(( pass + 1 )); }
fail() { printf 'FAIL: %s\n' "$1"; fail=$(( fail + 1 )); }

AUTO_ENTRY="scripts/intake/auto-entry.sh"

# --- Members (dependency order) ---------------------------------------------
MEMBERS="m046-p03-routing-fixture.sh
m046-p03-shim-parity.sh
m046-p03-shim-forward.sh
m046-p03-update-restage.sh"

for member in $MEMBERS; do
  member_path="$SCRIPT_DIR/$member"
  if [ ! -f "$member_path" ]; then
    fail "member missing: $member"
    printf 'SUITE: %s result=fail (missing)\n' "$member"
    continue
  fi
  # Run the member; forward its own PASS:/FAIL:/SUMMARY: lines, indented.
  if bash "$member_path" > "/tmp/.m046-p03-$member.$$" 2>&1; then
    sed 's/^/    /' "/tmp/.m046-p03-$member.$$"
    printf 'SUITE: %s result=pass\n' "$member"
    pass "member passed: $member"
  else
    sed 's/^/    /' "/tmp/.m046-p03-$member.$$"
    printf 'SUITE: %s result=fail\n' "$member"
    fail "member failed: $member"
  fi
  rm -f "/tmp/.m046-p03-$member.$$"
done

# --- CON-2 / FR-2 reuse assertion -------------------------------------------
# auto-entry.sh must consume the three helpers BY PATH.
for helper in 'scripts/intake/shape-detect.sh' \
              'scripts/intake/route-to-dispatch.sh' \
              'scripts/dispatch/build-context.sh'; do
  if grep -qF "$helper" "$AUTO_ENTRY"; then
    pass "CON-2: auto-entry.sh references $helper by path"
  else
    fail "CON-2: auto-entry.sh does NOT reference $helper"
  fi
done

# auto-entry.sh must never INVOKE or write auto-loop.sh (inert comment refs are
# fine; a `bash ... auto-loop.sh` invocation or a redirect into it is not).
if grep -qE 'bash[^#]*auto-loop\.sh|>[[:space:]]*[^ ]*auto-loop\.sh|sed[^#]*-i[^#]*auto-loop\.sh' "$AUTO_ENTRY"; then
  fail "CON-2: auto-entry.sh invokes/writes auto-loop.sh (must ROUTE only, never run/edit the loop)"
else
  pass "CON-2: auto-entry.sh never invokes/writes auto-loop.sh (at most inert comment references)"
fi

# --- Aggregate --------------------------------------------------------------
printf 'SUMMARY: m046-p03-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
