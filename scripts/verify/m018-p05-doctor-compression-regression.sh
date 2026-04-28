#!/usr/bin/env bash
# scripts/verify/m018-p05-doctor-compression-regression.sh — phase-truth verifier:
# "scripts/diagnostics/check-anomalies.sh flags a milestone whose moving-window
# savings ratio falls below the SC-9 calibrated 34.7% floor against the
# milestone's prior baseline; the flag is one stable line in the existing
# anomaly block (e.g., 'FLAGGED <task> ... savings_ratio=<pct> ...
# reasons=... compression-regression'); suppression matrix preserved."
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

CA="$REPO_ROOT/scripts/diagnostics/check-anomalies.sh"
HELPER="$REPO_ROOT/scripts/verify/_helpers/m018-p05-build-fixture.sh"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1" >&2; }

for p in "$CA" "$HELPER"; do
  if [ ! -f "$p" ]; then
    fail "prerequisite missing: $p"
    exit 1
  fi
done

TMPDIR_E="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_E"' EXIT INT TERM

# --- Assertion 1: savings-bearing fixture flags compression-regression.
# T01 has tier1=200 fdrop=100 tokens=1000 -> ratio=0.300 (< 0.347 with
# savings>0). High pass_thresh and retry_thresh defaults will not trip
# alongside it; we use --sample-floor 1 to ensure the awk pass runs.
ROOT="$TMPDIR_E/orch"
mkdir -p "$ROOT"
MS_ID="$(bash "$HELPER" "$ROOT" savings | head -n 1)"

OUT="$TMPDIR_E/anom.out"
ORCHESTRATOR_ROOT="$ROOT" bash "$CA" --milestone "$MS_ID" --sample-floor 1 >"$OUT" 2>"$TMPDIR_E/anom.err" || true
if grep -q 'compression-regression' "$OUT"; then
  pass "savings-bearing fixture flags compression-regression"
else
  fail "savings-bearing fixture missing compression-regression flag"
  cat "$OUT" >&2 || true
fi

# Assert the flagged row carries the savings_ratio= token.
if grep -E 'FLAGGED .* savings_ratio=[0-9.]+' "$OUT" >/dev/null; then
  pass "flagged row carries savings_ratio= token"
else
  fail "flagged row missing savings_ratio= token"
fi

# --- Assertion 2: ORCHESTRATOR_AUTO=1 suppresses the entire anomaly block.
OUT_AUTO="$TMPDIR_E/anom-auto.out"
ORCHESTRATOR_AUTO=1 ORCHESTRATOR_ROOT="$ROOT" bash "$CA" --milestone "$MS_ID" --sample-floor 1 >"$OUT_AUTO" 2>"$TMPDIR_E/anom-auto.err" || true
if [ ! -s "$OUT_AUTO" ]; then
  pass "ORCHESTRATOR_AUTO=1 emits zero stdout (suppression matrix preserved)"
else
  fail "ORCHESTRATOR_AUTO=1 emitted $(wc -c < "$OUT_AUTO") bytes (expected zero)"
fi

# --- Assertion 3: --no-anomaly suppresses the anomaly block.
OUT_NO="$TMPDIR_E/anom-no.out"
ORCHESTRATOR_ROOT="$ROOT" bash "$CA" --milestone "$MS_ID" --no-anomaly --sample-floor 1 >"$OUT_NO" 2>"$TMPDIR_E/anom-no.err" || true
if [ ! -s "$OUT_NO" ]; then
  pass "--no-anomaly emits zero stdout"
else
  fail "--no-anomaly emitted bytes"
fi

# --- Assertion 4: legacy log (no savings fields) does NOT flag
# compression-regression (sav_total > 0 guard distinguishes "compression
# ran and underperformed" from "compression did not run at all").
ROOT_L="$TMPDIR_E/orch_legacy"
mkdir -p "$ROOT_L"
MS_L="$(bash "$HELPER" "$ROOT_L" no-savings | head -n 1)"
OUT_L="$TMPDIR_E/anom-legacy.out"
ORCHESTRATOR_ROOT="$ROOT_L" bash "$CA" --milestone "$MS_L" --sample-floor 1 >"$OUT_L" 2>"$TMPDIR_E/anom-legacy.err" || true
if grep -q 'compression-regression' "$OUT_L"; then
  fail "legacy log unexpectedly flagged compression-regression (sav_total>0 guard broken)"
  cat "$OUT_L" >&2 || true
else
  pass "legacy log does NOT flag compression-regression (CON-5 sav_total>0 guard intact)"
fi

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: m018-p05-doctor-compression-regression (%d assertions)\n' "$PASS_COUNT"
  exit 0
fi
printf 'FAIL: m018-p05-doctor-compression-regression (%d failed of %d)\n' "$FAIL_COUNT" "$((PASS_COUNT + FAIL_COUNT))" >&2
exit 1
