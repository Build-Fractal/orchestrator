#!/usr/bin/env bash
# tests/m031-acceptance/run-acceptance-battery.sh
# M031/P04/T04 -- SC-14 acceptance battery runner.
#
# Invokes every M031 SC verifier in literal sequence. Mirrors the M030
# convention at tests/m030-acceptance/run-acceptance-battery.sh.
# AD-19 single-script-file shape: each verifier is invoked as
# `bash <path>` with rc captured per-call; no compound chains, no
# loops, no eval.
#
# Final stdout line: `BATTERY: pass=N fail=M`. Exits 0 iff fail=0.
#
# Sub-gate inventory (15 entries under Option A; see SC13-OPTION.md):
#   SC-1, SC-2, SC-3, SC-5, SC-6, SC-7, SC-8, SC-9, SC-10, SC-11,
#   SC-12, SC-15, SC-16, AD-9, AD-19.
#
# SC-13 (verify-baseline-ordering.sh) is dropped per Option A: at
# acceptance-battery evaluation time the M031 baseline corpus did not
# yet have committed git history covering its own path, so Option B's
# `corpus_first_commit_ct < protected_first_commit_ct` assertion has no
# defined left-hand side. Option A reclassifies SC-13 as a P00 protocol
# note. See tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md.
#
# Bash 3.2 compatible (parallel scalars, `local` inside the helper, no
# associative arrays). The runner only INVOKES existing P00..P04 SC
# scripts -- zero modifications to upstream deliverables.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass=0
fail=0

run_sc() {
  # $1 SC label  $2 verifier path  $3 (optional) trailing flags
  local label="$1"
  local path="$2"
  local extra="${3:-}"
  if [ -n "$extra" ]; then
    bash "$path" $extra
  else
    bash "$path"
  fi
  local rc=$?
  if [ "$rc" -eq 0 ]; then
    pass=$((pass + 1))
    printf 'BATTERY-PASS: %s (%s)\n' "$label" "$path"
  else
    fail=$((fail + 1))
    printf 'BATTERY-FAIL: %s (%s) exited %d\n' "$label" "$path" "$rc"
  fi
}

# ---------- P01 SCs (foundation: build-context profile + Quick path) ----------
run_sc "SC-1"  "$PROJECT_ROOT/tests/m031-acceptance/test-quick-injects-knowledge.sh"
run_sc "SC-2"  "$PROJECT_ROOT/tests/m031-acceptance/test-build-context-profile.sh"
run_sc "SC-3"  "$PROJECT_ROOT/tests/m031-acceptance/test-compression-applies-to-quick.sh"

# ---------- P02 SCs (Tier A+ classifier + flow + prompt UX) ----------
run_sc "SC-5"  "$PROJECT_ROOT/tests/m031-acceptance/test-tier-a-plus-classifier.sh"
run_sc "SC-6"  "$PROJECT_ROOT/tests/m031-acceptance/test-tier-a-plus-flow.sh"
run_sc "SC-16" "$PROJECT_ROOT/tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh"

# ---------- P03 SCs (universal-entry skill: trivial + low-confidence) ----------
run_sc "SC-7"  "$PROJECT_ROOT/tests/m031-acceptance/test-universal-entry-trivial.sh"
run_sc "SC-8"  "$PROJECT_ROOT/tests/m031-acceptance/test-universal-entry-lowconf.sh"

# ---------- P04 SCs (drift fix + auto-proceed + scope-guard + AD-9 + AD-19) ----------
run_sc "SC-9"  "$PROJECT_ROOT/tests/m031-acceptance/doc-drift-verifier.sh"
run_sc "SC-10" "$PROJECT_ROOT/tests/m031-acceptance/test-auto-proceed-default.sh"
run_sc "SC-12" "$PROJECT_ROOT/tests/m031-acceptance/scope-guard.sh"
run_sc "AD-9"  "$PROJECT_ROOT/tests/m031-acceptance/test-doctor-compound-change.sh"
run_sc "AD-19" "$PROJECT_ROOT/tests/m031-acceptance/test-budget-drift-warning.sh"

# ---------- P01 budget median + P00 baseline tail ----------
run_sc "SC-15" "$PROJECT_ROOT/tests/m031-acceptance/test-quick-budget-median.sh"
run_sc "SC-11" "$PROJECT_ROOT/tests/m031-acceptance/empirical-baseline.sh" "--compare"

# SC-13 omitted under Option A (see SC13-OPTION.md).

# ---------- Aggregate ----------
printf 'BATTERY: pass=%s fail=%s\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
