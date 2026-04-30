#!/usr/bin/env bash
# tools/verify/p02-phase-suite.sh — M030 P02 phase-close gate.
#
# Invokes all nine P02 sub-gates in literal sequence; exits 0 iff all
# pass. Bash 3.2 compatible. Straight-line — no loops, no eval, no
# compound chains. Modeled on tools/verify/p01-phase-suite.sh.
#
# Sub-gates (in dependency order):
#   1. p02-fixture-shape.sh                 (T01) — fixture corpus shape
#   2. p02-additive-schema.sh               (T01) — SC-11 byte-equality
#   3. p02-shadow-emit.sh                   (T02) — dispatch shadow hook
#   4. p02-con3-closure.sh                  (T02) — symbolic-tier closure
#   5. p02-append-only.sh                   (T02) — CON-6 append-only
#   6. p02-shadow-compare-verdicts.sh       (T03) — 4-verdict aggregator
#   7. p02-partial-flip-enum.sh             (T03) — partial-flip enum
#   8. p02-stability-metric-traceability.sh (T03) — 0.10/N=20/50 traced
#   9. p02-sc3a-roundtrip.sh                (T03) — SC-3a roundtrip
#
# Each sub-gate's own SUMMARY line is preserved on stdout for diagnostics;
# the suite emits a single aggregate SUMMARY line at the end.
#
# AD-19 single-script-file shape preserved throughout.

set -uo pipefail

pass=0
fail=0

# ---------- Gate 1: fixture-shape ----------

bash tools/verify/p02-fixture-shape.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 2: additive-schema ----------

bash tools/verify/p02-additive-schema.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 3: shadow-emit ----------

bash tools/verify/p02-shadow-emit.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 4: con3-closure ----------

bash tools/verify/p02-con3-closure.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 5: append-only ----------

bash tools/verify/p02-append-only.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 6: shadow-compare-verdicts ----------

bash tools/verify/p02-shadow-compare-verdicts.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 7: partial-flip-enum ----------

bash tools/verify/p02-partial-flip-enum.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 8: stability-metric-traceability ----------

bash tools/verify/p02-stability-metric-traceability.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 9: sc3a-roundtrip ----------

bash tools/verify/p02-sc3a-roundtrip.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Aggregate summary ----------

printf 'SUMMARY: p02-phase-suite.sh pass=%s fail=%s\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
