#!/usr/bin/env bash
# tools/verify/p03-phase-suite.sh — M030 P03 phase-close gate.
#
# Invokes all eight P03 sub-gates in literal sequence; exits 0 iff all
# pass. Bash 3.2 compatible. Straight-line — no loops, no eval, no
# compound chains. Modeled on tools/verify/p02-phase-suite.sh.
#
# Sub-gates (in dependency order — fundamental contract first, then
# enum-closure, then CON-3 closure, then the four scenario-specific
# gates SC-6 / SC-7 / SC-7a / min-tier-floor, then FR-14 conflict last):
#   1. p03-additive-schema.sh             (T01 preflight) — SC-11 pass-through
#   2. p03-override-source-enum.sh        (T01)           — closed-enum gate
#   3. p03-con3-closure.sh                (T02)           — no-new-model-IDs
#   4. p03-sc6-frontmatter-override.sh    (T03)           — plan_frontmatter
#   5. p03-sc7-kill-switch.sh             (T02)           — disabled overlay
#   6. p03-sc7a-compound.sh               (T02)           — kill-switch+floor
#   7. p03-min-tier-floor.sh              (T02)           — milestone_floor
#   8. p03-override-conflict.sh           (T03)           — FR-14 floor-wins
#
# Each sub-gate's own SUMMARY line is preserved on stdout for diagnostics;
# the suite emits a single aggregate SUMMARY line at the end.
#
# AD-19 single-script-file shape preserved throughout.

set -uo pipefail

pass=0
fail=0

# ---------- Gate 1: additive-schema ----------

bash tools/verify/p03-additive-schema.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 2: override-source-enum ----------

bash tools/verify/p03-override-source-enum.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 3: con3-closure ----------

bash tools/verify/p03-con3-closure.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 4: sc6-frontmatter-override ----------

bash tools/verify/p03-sc6-frontmatter-override.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 5: sc7-kill-switch ----------

bash tools/verify/p03-sc7-kill-switch.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 6: sc7a-compound ----------

bash tools/verify/p03-sc7a-compound.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 7: min-tier-floor ----------

bash tools/verify/p03-min-tier-floor.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 8: override-conflict ----------

bash tools/verify/p03-override-conflict.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Aggregate summary ----------

printf 'SUMMARY: p03-phase-suite.sh pass=%s fail=%s\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
