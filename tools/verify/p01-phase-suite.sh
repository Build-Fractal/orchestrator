#!/usr/bin/env bash
# tools/verify/p01-phase-suite.sh — M030 P01 phase-close gate.
#
# Invokes all seven P01 sub-gates in literal sequence; exits 0 iff all
# pass. Bash 3.2 compatible. Straight-line — no loops, no eval, no
# compound chains. Models on tools/verify/p00-phase-suite.sh.
#
# Sub-gates (in dependency order):
#   1. p01-d-a4-timeline.sh             (T01) — D-A4 timeline ordering
#   2. p01-classifier-determinism.sh    (T02) — classifier determinism
#   3. p01-classifier-perf-and-network.sh (T02) — perf + no-network
#   4. p01-classifier-ground-truth.sh   (T02) — ground-truth agreement
#   5. p01-routing-table-shape.sh       (T03) — routing-table closure
#   6. p01-doctor-config-check.sh       (T04) — doctor --config-check gate
#   7. p01-model-routing-doc-shape.sh   (T03) — operator-doc shape
#
# Each sub-gate's own SUMMARY line is preserved on stdout for diagnostics;
# the suite emits a single aggregate SUMMARY line at the end.
#
# AD-19 single-script-file shape preserved throughout.

set -uo pipefail

pass=0
fail=0

# ---------- Gate 1: d-a4-timeline ----------

bash tools/verify/p01-d-a4-timeline.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 2: classifier-determinism ----------

bash tools/verify/p01-classifier-determinism.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 3: classifier-perf-and-network ----------

bash tools/verify/p01-classifier-perf-and-network.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 4: classifier-ground-truth ----------

bash tools/verify/p01-classifier-ground-truth.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 5: routing-table-shape ----------

bash tools/verify/p01-routing-table-shape.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 6: doctor-config-check ----------

bash tools/verify/p01-doctor-config-check.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 7: model-routing-doc-shape ----------

bash tools/verify/p01-model-routing-doc-shape.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Aggregate summary ----------

printf 'SUMMARY: p01-phase-suite.sh pass=%s fail=%s\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
