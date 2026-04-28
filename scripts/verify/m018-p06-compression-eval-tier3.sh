#!/usr/bin/env bash
# scripts/verify/m018-p06-compression-eval-tier3.sh — phase-truth verifier:
# "`compression-eval.sh --tier 3` replaces the P05 reservation stub with
# real cohort logic against `tier3_compression_savings_tokens`; reports
# per-cohort + delta means with 95% CIs; emits `regression_flag:` advisory;
# below-floor emits `insufficient sample` and exits 0; sourceable + CLI
# shape preserved (FR-12 always-exit-0; AD-19 single-script-file Check shape)."
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

CE="$REPO_ROOT/scripts/diagnostics/compression-eval.sh"
HELPER="$REPO_ROOT/scripts/verify/_helpers/m018-p06-build-fixture.sh"

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

# --- Assertion 1: bash -n syntax check.
if bash -n "$CE" 2>/dev/null; then
  pass "bash -n compression-eval.sh exits 0"
else
  fail "bash -n compression-eval.sh syntax errors"
fi

# --- Assertion 2: source-level — tier 3 cohort branch reads
# tier3_compression_savings_tokens (NOT a stub).
if grep -q 'tier3_compression_savings_tokens' "$CE"; then
  pass "compression-eval.sh references tier3_compression_savings_tokens"
else
  fail "compression-eval.sh missing tier3_compression_savings_tokens reference"
fi

# --- Assertion 3: regression-check — the P05 reservation-stub literal is
# absent. The P05 stub printed something like "tier 3 reserved for P06"
# or similar. Confirm no such text remains.
if grep -qiE 'tier 3 reserved|tier3 stub|reservation' "$CE"; then
  fail "compression-eval.sh still contains stub literal"
else
  pass "compression-eval.sh has no stub literal"
fi

# --- Stage the tier3-fired fixture.
TMPDIR_E="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_E"' EXIT INT TERM
ROOT="$TMPDIR_E/orch"
mkdir -p "$ROOT"
MS_ID="$(bash "$HELPER" "$ROOT" tier3-fired | head -n 1)"
if [ -z "$MS_ID" ]; then
  fail "fixture-staging helper emitted no milestone id"
  exit 1
fi
pass "fixture root staged (milestone=$MS_ID)"

# --- Assertion 4: --tier 3 with --sample-floor 1 emits a cohort + delta
# block. Header line names tier=3.
EVAL_OUT="$(ORCHESTRATOR_ROOT="$ROOT" bash "$CE" --milestone "$MS_ID" --tier 3 --sample-floor 1 2>/dev/null; printf '\nEXIT=%d\n' "$?")"
EVAL_EXIT="$(printf '%s' "$EVAL_OUT" | grep -E '^EXIT=' | tail -n 1 | sed 's/EXIT=//')"
if [ "$EVAL_EXIT" = "0" ]; then
  pass "compression-eval --tier 3 exits 0"
else
  fail "compression-eval --tier 3 exit code $EVAL_EXIT (expected 0)"
fi
if printf '%s' "$EVAL_OUT" | grep -qE '^# compression-eval — milestone='"$MS_ID"' tier=3'; then
  pass "header names milestone=$MS_ID tier=3"
else
  fail "missing/incorrect header (output: $EVAL_OUT)"
fi
if printf '%s' "$EVAL_OUT" | grep -qE '^COHORT'; then
  pass "COHORT line present"
else
  fail "COHORT line missing (output: $EVAL_OUT)"
fi
if printf '%s' "$EVAL_OUT" | grep -qE '^compressed[[:space:]]+'; then
  pass "compressed cohort row present"
else
  fail "compressed cohort row missing (output: $EVAL_OUT)"
fi
if printf '%s' "$EVAL_OUT" | grep -qE '^uncompressed[[:space:]]+'; then
  pass "uncompressed cohort row present"
else
  fail "uncompressed cohort row missing (output: $EVAL_OUT)"
fi
if printf '%s' "$EVAL_OUT" | grep -qE '^delta'; then
  pass "delta row present"
else
  fail "delta row missing (output: $EVAL_OUT)"
fi

# --- Assertion 5: regression_flag advisory line. Pass-rates are 1.0/1.0
# across cohorts in the fixture, so the flag should be 'none'.
if printf '%s' "$EVAL_OUT" | grep -qE '^regression_flag:'; then
  pass "regression_flag advisory line present"
  if printf '%s' "$EVAL_OUT" | grep -qE '^regression_flag:[[:space:]]+none'; then
    pass "regression_flag = none on fixture (pass-rates 1.0/1.0)"
  else
    fail "regression_flag != none (output: $EVAL_OUT)"
  fi
else
  fail "regression_flag line missing (output: $EVAL_OUT)"
fi

# --- Assertion 6: regression check — confirm the P05 stub literal
# "tier 3 reserved for P06" is NOT present in output.
if printf '%s' "$EVAL_OUT" | grep -qiE 'tier 3 reserved'; then
  fail "output still contains 'tier 3 reserved' stub literal"
else
  pass "output does not contain 'tier 3 reserved' stub literal"
fi

# --- Assertion 7: --sample-floor 1000 yields insufficient sample.
EVAL_HIGH="$(ORCHESTRATOR_ROOT="$ROOT" bash "$CE" --milestone "$MS_ID" --tier 3 --sample-floor 1000 2>/dev/null; printf '\nEXIT=%d\n' "$?")"
EVAL_HIGH_EXIT="$(printf '%s' "$EVAL_HIGH" | grep -E '^EXIT=' | tail -n 1 | sed 's/EXIT=//')"
if [ "$EVAL_HIGH_EXIT" = "0" ]; then
  pass "compression-eval --sample-floor 1000 exits 0"
else
  fail "compression-eval --sample-floor 1000 exit $EVAL_HIGH_EXIT"
fi
if printf '%s' "$EVAL_HIGH" | grep -q 'insufficient sample'; then
  pass "high floor emits 'insufficient sample'"
else
  fail "high floor missing 'insufficient sample' (output: $EVAL_HIGH)"
fi

# --- Assertion 8: missing log emits a degraded-input line and exits 0
# (FR-12 / CON-5 always-exit-0 contract).
EMPTY_ROOT="$TMPDIR_E/empty"
mkdir -p "$EMPTY_ROOT/milestones/M999"
DEGRADED="$(ORCHESTRATOR_ROOT="$EMPTY_ROOT" bash "$CE" --milestone M999 --tier 3 2>/dev/null; printf '\nEXIT=%d\n' "$?")"
DEGR_EXIT="$(printf '%s' "$DEGRADED" | grep -E '^EXIT=' | tail -n 1 | sed 's/EXIT=//')"
if [ "$DEGR_EXIT" = "0" ]; then
  pass "compression-eval missing-log exits 0"
else
  fail "compression-eval missing-log exit $DEGR_EXIT"
fi
if printf '%s' "$DEGRADED" | grep -qE 'log file missing|no records'; then
  pass "missing-log emits degraded-input text"
else
  fail "missing-log missing degraded text (output: $DEGRADED)"
fi

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: m018-p06-compression-eval-tier3 (%d assertions)\n' "$PASS_COUNT"
  exit 0
fi
printf 'FAIL: m018-p06-compression-eval-tier3 (%d failed of %d)\n' "$FAIL_COUNT" "$((PASS_COUNT + FAIL_COUNT))" >&2
exit 1
