#!/usr/bin/env bash
# tools/verify/p04-phase-suite.sh — M030 P04 phase-close gate.
#
# Invokes all twelve P04 sub-gates in literal sequence; exits 0 iff all
# pass. Bash 3.2 compatible. Straight-line — no loops, no eval, no
# compound chains. Modeled on tools/verify/p02-phase-suite.sh and
# tools/verify/p03-phase-suite.sh.
#
# Sub-gates (in dependency order — fundamental contract first, then
# enum-closure, then CON-3 closure, then the four T02 scenario gates,
# then the five T03 escalation gates):
#   1.  p04-additive-schema.sh                  (T01) — SC-11 byte-equality
#   2.  p04-override-source-enum-extended.sh    (T01) — closed-enum gate
#   3.  p04-con3-live-closure.sh                (T02) — no-new-model-IDs
#   4.  p04-sc2a-shadow-gate-block.sh           (T02) — live-flip-gate
#   5.  p04-sc3-live-mechanical.sh              (T02) — live-routed mechanical
#   6.  p04-partial-flip-routing.sh             (T02) — D-A3 partial-flip
#   7.  p04-con4-live-killswitch.sh             (T02) — kill-switch supersedes
#   8.  p04-sc4-escalation-sequence.sh          (T03) — fast→balanced→smart
#   9.  p04-sc5-escalation-cap.sh               (T03) — CON-5 cap
#   10. p04-con5-no-fourth-record.sh            (T03) — CON-5 defence-in-depth
#   11. p04-con6-prior-records-bit-identical.sh (T03) — CON-6 append-only
#   12. p04-escalation-fields-enum.sh           (T03) — escalation_count/reason
#
# Each sub-gate's own SUMMARY line is preserved on stdout for diagnostics;
# the suite emits a single aggregate SUMMARY line at the end.
#
# AD-19 single-script-file shape preserved throughout.

set -uo pipefail

pass=0
fail=0

# ---------- Gate 1: additive-schema ----------

bash tools/verify/p04-additive-schema.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 2: override-source-enum-extended ----------

bash tools/verify/p04-override-source-enum-extended.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 3: con3-live-closure ----------

bash tools/verify/p04-con3-live-closure.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 4: sc2a-shadow-gate-block ----------

bash tools/verify/p04-sc2a-shadow-gate-block.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 5: sc3-live-mechanical ----------

bash tools/verify/p04-sc3-live-mechanical.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 6: partial-flip-routing ----------

bash tools/verify/p04-partial-flip-routing.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 7: con4-live-killswitch ----------

bash tools/verify/p04-con4-live-killswitch.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 8: sc4-escalation-sequence ----------

bash tools/verify/p04-sc4-escalation-sequence.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 9: sc5-escalation-cap ----------

bash tools/verify/p04-sc5-escalation-cap.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 10: con5-no-fourth-record ----------

bash tools/verify/p04-con5-no-fourth-record.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 11: con6-prior-records-bit-identical ----------

bash tools/verify/p04-con6-prior-records-bit-identical.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 12: escalation-fields-enum ----------

bash tools/verify/p04-escalation-fields-enum.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Aggregate summary ----------

printf 'SUMMARY: p04-phase-suite.sh pass=%s fail=%s\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
