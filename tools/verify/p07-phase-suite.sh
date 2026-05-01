#!/usr/bin/env bash
# tools/verify/p07-phase-suite.sh — M030 P07 phase-close gate aggregator.
#
# Invokes all nine P07 sub-gates in literal sequence; exits 0 iff all
# pass. Bash 3.2 compatible. Straight-line — no loops, no eval, no
# compound chains. Modeled on tools/verify/p02-phase-suite.sh through
# tools/verify/p06-phase-suite.sh (no shape change across the M030 chain).
#
# Sub-gates (in dependency order — synthesizer first, then per-verdict
# corpus gates, then the at-scale partial-flip + cross-surface gates,
# then the acceptance-battery wrapper, then the evidence-ledger gate
# that consumes T03's ledger):
#   1. p07-corpus-synthesizer-idempotent.sh   (T01) — synthesizer idempotency
#   2. p07-corpus-50-per-class-ready.sh        (T01) — SC-2 verdict ready
#   3. p07-corpus-zero-evidence-insufficient.sh (T01) — SC-2 verdict evidence_insufficient
#   4. p07-corpus-2-class-partially-ready.sh   (T01) — SC-2 verdict partially_ready
#   5. p07-corpus-block.sh                     (T01) — SC-2 verdict block
#   6. p07-partial-flip-jsonl-fields.sh        (T02) — at-scale FR-9 partial-flip JSONL fields
#   7. p07-cross-surface-coherence.sh          (T02) — roadmap line 64 cross-surface coherence
#   8. p07-acceptance-battery-pass.sh          (T02) — full 22-invocation battery wrapper
#   9. p07-acceptance-evidence-ledger.sh       (T03) — one-shot evidence ledger shape gate
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

# ---------- Gate 1: corpus-synthesizer-idempotent ----------

bash "$PROJECT_ROOT/tools/verify/p07-corpus-synthesizer-idempotent.sh"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "GATE FAIL: p07-corpus-synthesizer-idempotent.sh exited $rc"
fi

# ---------- Gate 2: corpus-50-per-class-ready ----------

bash "$PROJECT_ROOT/tools/verify/p07-corpus-50-per-class-ready.sh"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "GATE FAIL: p07-corpus-50-per-class-ready.sh exited $rc"
fi

# ---------- Gate 3: corpus-zero-evidence-insufficient ----------

bash "$PROJECT_ROOT/tools/verify/p07-corpus-zero-evidence-insufficient.sh"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "GATE FAIL: p07-corpus-zero-evidence-insufficient.sh exited $rc"
fi

# ---------- Gate 4: corpus-2-class-partially-ready ----------

bash "$PROJECT_ROOT/tools/verify/p07-corpus-2-class-partially-ready.sh"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "GATE FAIL: p07-corpus-2-class-partially-ready.sh exited $rc"
fi

# ---------- Gate 5: corpus-block ----------

bash "$PROJECT_ROOT/tools/verify/p07-corpus-block.sh"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "GATE FAIL: p07-corpus-block.sh exited $rc"
fi

# ---------- Gate 6: partial-flip-jsonl-fields ----------

bash "$PROJECT_ROOT/tools/verify/p07-partial-flip-jsonl-fields.sh"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "GATE FAIL: p07-partial-flip-jsonl-fields.sh exited $rc"
fi

# ---------- Gate 7: cross-surface-coherence ----------

bash "$PROJECT_ROOT/tools/verify/p07-cross-surface-coherence.sh"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "GATE FAIL: p07-cross-surface-coherence.sh exited $rc"
fi

# ---------- Gate 8: acceptance-battery-pass ----------

bash "$PROJECT_ROOT/tools/verify/p07-acceptance-battery-pass.sh"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "GATE FAIL: p07-acceptance-battery-pass.sh exited $rc"
fi

# ---------- Gate 9: acceptance-evidence-ledger ----------

bash "$PROJECT_ROOT/tools/verify/p07-acceptance-evidence-ledger.sh"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "GATE FAIL: p07-acceptance-evidence-ledger.sh exited $rc"
fi

# ---------- Aggregate summary ----------

printf 'SUMMARY: p07-phase-suite.sh pass=%s fail=%s\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
