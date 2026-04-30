#!/usr/bin/env bash
# tools/verify/p05-phase-suite.sh — M030 P05 phase-close gate.
#
# Invokes all seven P05 sub-gates in literal sequence; exits 0 iff all
# pass. Bash 3.2 compatible. Straight-line — no loops, no eval, no
# compound chains. Modeled on tools/verify/p02-phase-suite.sh,
# tools/verify/p03-phase-suite.sh, and tools/verify/p04-phase-suite.sh.
#
# Sub-gates (in dependency order — fundamental SC-11 contracts first,
# then the SC-9 doctor inheritor, then the four T02 scenario gates
# covering SC-8 + FR-16):
#   1. p05-sc11-rollup-byte-equality.sh    (T01) — SC-11 rollup byte-equality
#   2. p05-sc11-footer-byte-equality.sh    (T01) — SC-11 footer byte-equality
#   3. p05-doctor-config-check.sh          (T01) — SC-9 inheritor wrapper
#   4. p05-by-model-dispatch-counts.sh     (T02) — SC-8 sentence 1
#   5. p05-by-model-cost-rates-present.sh  (T02) — SC-8 sentence 2
#   6. p05-by-model-cost-rates-absent.sh   (T02) — SC-8 sentence 3
#   7. p05-model-mix-footer-line.sh        (T02) — FR-16 model_mix: line
#
# Each sub-gate's own SUMMARY line is preserved on stdout for diagnostics;
# the suite emits a single aggregate SUMMARY line at the end.
#
# AD-19 single-script-file shape preserved throughout.

set -uo pipefail

pass=0
fail=0

# ---------- Gate 1: sc11-rollup-byte-equality ----------

bash tools/verify/p05-sc11-rollup-byte-equality.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 2: sc11-footer-byte-equality ----------

bash tools/verify/p05-sc11-footer-byte-equality.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 3: doctor-config-check ----------

bash tools/verify/p05-doctor-config-check.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 4: by-model-dispatch-counts ----------

bash tools/verify/p05-by-model-dispatch-counts.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 5: by-model-cost-rates-present ----------

bash tools/verify/p05-by-model-cost-rates-present.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 6: by-model-cost-rates-absent ----------

bash tools/verify/p05-by-model-cost-rates-absent.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 7: model-mix-footer-line ----------

bash tools/verify/p05-model-mix-footer-line.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Aggregate summary ----------

printf 'SUMMARY: p05-phase-suite.sh pass=%s fail=%s\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
