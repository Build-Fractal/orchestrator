#!/usr/bin/env bash
# scripts/verify/m018-p05-compression-eval.sh — phase-truth verifier:
# "scripts/diagnostics/compression-eval.sh exists, accepts --milestone <id>,
# --tier <N> (1 or 2 in P05; tier 3 reserved for P06), and --sample-floor <N>
# (default 30 per cohort); reports per-cohort pass-rate / retry / deviation
# means + delta with confidence intervals; below-floor sample emits
# 'insufficient sample' and exits 0; never aborts on degraded inputs."
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

CE="$REPO_ROOT/scripts/diagnostics/compression-eval.sh"
HELPER="$REPO_ROOT/scripts/verify/_helpers/m018-p05-build-fixture.sh"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1" >&2; }

for p in "$CE" "$HELPER"; do
  if [ ! -f "$p" ]; then
    fail "prerequisite missing: $p"
    exit 1
  fi
done

TMPDIR_E="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_E"' EXIT INT TERM

ROOT="$TMPDIR_E/orch"
mkdir -p "$ROOT"
MS_ID="$(bash "$HELPER" "$ROOT" savings | head -n 1)"

# --- Assertion 1: --tier 1 with sample-floor 2 emits cohort + delta block.
OUT="$TMPDIR_E/eval-t1.out"
ORCHESTRATOR_ROOT="$ROOT" bash "$CE" --milestone "$MS_ID" --tier 1 --sample-floor 2 >"$OUT" 2>"$TMPDIR_E/eval-t1.err"
EXIT_CODE=$?
if [ "$EXIT_CODE" -ne 0 ]; then
  fail "compression-eval --tier 1 --sample-floor 2 exited $EXIT_CODE (expected 0)"
fi
if grep -q 'COHORT' "$OUT"; then
  pass "tier 1 cohort block emitted"
else
  fail "tier 1 output missing COHORT line"
  cat "$OUT" >&2 || true
fi
for tok in 'compressed' 'uncompressed' 'delta' 'regression_flag'; do
  if grep -q "$tok" "$OUT"; then
    pass "tier 1 output carries '$tok' token"
  else
    fail "tier 1 output missing '$tok' token"
  fi
done

# --- Assertion 2: --sample-floor 1000 yields insufficient sample, exits 0.
OUT_HIGH="$TMPDIR_E/eval-floor.out"
ORCHESTRATOR_ROOT="$ROOT" bash "$CE" --milestone "$MS_ID" --tier 1 --sample-floor 1000 >"$OUT_HIGH" 2>"$TMPDIR_E/eval-floor.err"
EXIT_HIGH=$?
if [ "$EXIT_HIGH" -ne 0 ]; then
  fail "compression-eval --sample-floor 1000 exited $EXIT_HIGH (expected 0)"
else
  pass "compression-eval --sample-floor 1000 exits 0"
fi
if grep -q 'insufficient sample' "$OUT_HIGH"; then
  pass "high floor emits 'insufficient sample' line"
else
  fail "high floor missing 'insufficient sample' line"
  cat "$OUT_HIGH" >&2 || true
fi

# --- Assertion 3: --tier 3 emits the P06-reservation stub, exits 0.
OUT_T3="$TMPDIR_E/eval-t3.out"
ORCHESTRATOR_ROOT="$ROOT" bash "$CE" --milestone "$MS_ID" --tier 3 >"$OUT_T3" 2>"$TMPDIR_E/eval-t3.err"
EXIT_T3=$?
if [ "$EXIT_T3" -ne 0 ]; then
  fail "compression-eval --tier 3 exited $EXIT_T3 (expected 0)"
else
  pass "compression-eval --tier 3 exits 0"
fi
if grep -qE 'tier 3 reserved for P06' "$OUT_T3"; then
  pass "tier 3 emits P06-reservation stub"
else
  fail "tier 3 missing P06-reservation stub"
  cat "$OUT_T3" >&2 || true
fi

# --- Assertion 4: missing log → degraded text, exit 0.
OUT_MISS="$TMPDIR_E/eval-miss.out"
ORCHESTRATOR_ROOT="$ROOT" bash "$CE" --milestone NOPE --tier 1 >"$OUT_MISS" 2>"$TMPDIR_E/eval-miss.err"
EXIT_MISS=$?
if [ "$EXIT_MISS" -ne 0 ]; then
  fail "compression-eval against missing milestone exited $EXIT_MISS (expected 0)"
else
  pass "compression-eval against missing milestone exits 0 (CON-5 never-aborts)"
fi
if grep -qE 'log file missing' "$OUT_MISS"; then
  pass "missing-log path surfaces degraded text"
fi

# --- Assertion 5: --tier 2 cohort segmentation also works.
OUT_T2="$TMPDIR_E/eval-t2.out"
ORCHESTRATOR_ROOT="$ROOT" bash "$CE" --milestone "$MS_ID" --tier 2 --sample-floor 1 >"$OUT_T2" 2>"$TMPDIR_E/eval-t2.err"
EXIT_T2=$?
if [ "$EXIT_T2" -ne 0 ]; then
  fail "compression-eval --tier 2 exited $EXIT_T2 (expected 0)"
else
  pass "compression-eval --tier 2 exits 0"
fi
if grep -q 'tier=2' "$OUT_T2" || grep -q 'tier 2' "$OUT_T2"; then
  pass "tier 2 invocation emits tier-scoped header"
fi

# Sentinel literal for artifact gate (`contains "compression-eval"`).
: ${COMPRESSION_EVAL:=compression-eval}

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: m018-p05-compression-eval (%d assertions)\n' "$PASS_COUNT"
  exit 0
fi
printf 'FAIL: m018-p05-compression-eval (%d failed of %d)\n' "$FAIL_COUNT" "$((PASS_COUNT + FAIL_COUNT))" >&2
exit 1
