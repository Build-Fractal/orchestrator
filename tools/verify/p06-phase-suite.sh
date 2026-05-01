#!/usr/bin/env bash
# tools/verify/p06-phase-suite.sh — M030 P06 phase-close gate.
#
# Invokes all eight P06 sub-gates in literal sequence; exits 0 iff all
# pass. Bash 3.2 compatible. Straight-line — no loops, no eval, no
# compound chains. Modeled on tools/verify/p02-phase-suite.sh,
# tools/verify/p03-phase-suite.sh, tools/verify/p04-phase-suite.sh,
# and tools/verify/p05-phase-suite.sh.
#
# Sub-gates (in dependency order — fundamental SC-11 contracts first,
# then the four T02 regression scenario gates covering FR-18, then the
# negative + sample-floor gates, then the SC-9 doctor inheritor):
#   1. p06-sc11-byte-equality.sh           (T01) — SC-11 check-anomalies byte-equality
#   2. p06-shadow-off-byte-equality.sh     (T02) — SC-11 dispatch-interface shadow-off byte-equality
#   3. p06-mechanical-regression.sh        (T02) — FR-18 class=mechanical
#   4. p06-standard-regression.sh          (T02) — FR-18 class=standard
#   5. p06-novel-regression.sh             (T02) — FR-18 class=novel
#   6. p06-no-regression.sh                (T02) — FR-18 negative case
#   7. p06-below-min-sample.sh             (T02) — FR-18 sample-floor guard
#   8. p06-doctor-surfaces-anomaly.sh      (T02) — doctor-surface integration
#
# Each sub-gate's own SUMMARY line is preserved on stdout for diagnostics;
# the suite emits a single aggregate SUMMARY line at the end.
#
# AD-19 single-script-file shape preserved throughout.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass=0
fail=0

# ---------- Gate 1: sc11-byte-equality ----------

bash "$PROJECT_ROOT/tools/verify/p06-sc11-byte-equality.sh"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "GATE FAIL: p06-sc11-byte-equality.sh exited $rc"
fi

# ---------- Gate 2: shadow-off-byte-equality ----------

bash "$PROJECT_ROOT/tools/verify/p06-shadow-off-byte-equality.sh"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "GATE FAIL: p06-shadow-off-byte-equality.sh exited $rc"
fi

# ---------- Gate 3: mechanical-regression ----------

bash "$PROJECT_ROOT/tools/verify/p06-mechanical-regression.sh"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "GATE FAIL: p06-mechanical-regression.sh exited $rc"
fi

# ---------- Gate 4: standard-regression ----------

bash "$PROJECT_ROOT/tools/verify/p06-standard-regression.sh"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "GATE FAIL: p06-standard-regression.sh exited $rc"
fi

# ---------- Gate 5: novel-regression ----------

bash "$PROJECT_ROOT/tools/verify/p06-novel-regression.sh"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "GATE FAIL: p06-novel-regression.sh exited $rc"
fi

# ---------- Gate 6: no-regression ----------

bash "$PROJECT_ROOT/tools/verify/p06-no-regression.sh"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "GATE FAIL: p06-no-regression.sh exited $rc"
fi

# ---------- Gate 7: below-min-sample ----------

bash "$PROJECT_ROOT/tools/verify/p06-below-min-sample.sh"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "GATE FAIL: p06-below-min-sample.sh exited $rc"
fi

# ---------- Gate 8: doctor-surfaces-anomaly ----------

bash "$PROJECT_ROOT/tools/verify/p06-doctor-surfaces-anomaly.sh"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "GATE FAIL: p06-doctor-surfaces-anomaly.sh exited $rc"
fi

# ---------- Aggregate summary ----------

printf 'SUMMARY: p06-phase-suite.sh pass=%s fail=%s\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
