#!/usr/bin/env bash
# tools/verify/p00-phase-suite.sh — M030/P00 phase-close gate suite.
#
# Invokes all five P00 verifiers in dependency order and aggregates
# pass/fail counts. Exits 0 iff every sub-gate exits 0.
#
# Sub-gates (in order):
#   1. p00-corpus-shape.sh        (T01) — fixture file shape
#   2. p00-plans-exist.sh         (T01) — plan_path on-disk resolution
#   3. p00-class-coverage.sh      (T02) — vocabulary + per-class floor
#   4. p00-readme-shape.sh        (T03) — README structural gate
#   5. p00-d-a4-independence.sh   (T03) — D-A4 independence-by-construction
#
# Each sub-gate's own SUMMARY line is preserved on stdout for diagnostics;
# the suite emits a single aggregate SUMMARY line at the end.
#
# Bash 3.2 compatible. Straight-line invocation per AD-19 — no loops over
# arrays, no compound chains, no eval. Five literal `bash <path>`
# invocations followed by accumulator updates.

set -u

pass=0
fail=0

# ---------- Gate 1: corpus-shape ----------

bash tools/verify/p00-corpus-shape.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 2: plans-exist ----------

bash tools/verify/p00-plans-exist.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 3: class-coverage ----------

bash tools/verify/p00-class-coverage.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 4: readme-shape ----------

bash tools/verify/p00-readme-shape.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 5: d-a4-independence ----------

bash tools/verify/p00-d-a4-independence.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Aggregate summary ----------

printf 'SUMMARY: p00-phase-suite.sh pass=%s fail=%s\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
