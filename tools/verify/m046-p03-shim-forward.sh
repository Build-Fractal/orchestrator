#!/usr/bin/env bash
# tools/verify/m046-p03-shim-forward.sh
# M046/P03/T05 -- FR-3: the do-shim forwards ALL SIX legacy `do` flags.
#
# scripts/intake/do-entry.sh is a thin forwarding shim. It forwards every flag
# to scripts/intake/auto-entry.sh by construction:
#   bash scripts/intake/auto-entry.sh --ambiguity-mode prompt "$@"
# The `"$@"` pass-through carries all six flags (--task, --yes, --config,
# --dispatch-stub, --scratch-root, --no-prompt-mode) verbatim. This verifier
# proves the pass-through structurally, then functionally spot-checks two flags
# that exercise distinct code paths: --task (high-conf degenerate) and
# --no-prompt-mode (below-floor prompt path).
#
# The --no-prompt-mode spot-check is load-bearing: it proves the shim forwards
# --no-prompt-mode AND preserves the LEGACY do prompt path (--ambiguity-mode
# prompt), NOT the auto-native AUTO:BLOCK_AMBIGUITY default. An 8-word idea is
# below the 0.7 floor; under prompt mode + `--no-prompt-mode B` it must NOT hang
# and must take branch B (route=tier_bc). Under the auto-native block default it
# would instead emit AUTO:BLOCK_AMBIGUITY -- so `route=tier_bc` is the
# discriminating evidence that the shim rides the do-compat prompt path.
#
# Outer-auto-loop hygiene: the --task degenerate spot-check drives
# build-context.sh, which appends one payload_breakdown record to the
# git-tracked .orchestrator/direct-mode-execution-log.jsonl. This verifier
# snapshots/restores that log. The --no-prompt-mode spot-check emits a
# unit_close record via ORCH_DO_ENTRY_LOG; that env var is redirected to a
# scratch file so no observability log is dirtied. All other scratch is mktemp.
#
# Output: PASS: / FAIL: lines + a final
#   SUMMARY: m046-p03-shim-forward.sh pass=N fail=M
# Exit 0 iff fail=0.
#
# Bash 3.2 compatible (MEM001): no declare -A, no process substitution.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
cd "$PROJECT_ROOT"

DO_ENTRY="scripts/intake/do-entry.sh"

pass=0
fail=0
pass() { printf 'PASS: %s\n' "$1"; pass=$(( pass + 1 )); }
fail() { printf 'FAIL: %s\n' "$1"; fail=$(( fail + 1 )); }

SCRATCH="$( mktemp -d -t m046-p03-shim-forward.XXXXXX )"

DMLOG=".orchestrator/direct-mode-execution-log.jsonl"
DMLOG_BAK="$SCRATCH/dmlog.bak"
DMLOG_EXISTED=0
if [ -f "$DMLOG" ]; then
  DMLOG_EXISTED=1
  cp "$DMLOG" "$DMLOG_BAK"
fi
restore_dmlog() {
  if [ "$DMLOG_EXISTED" -eq 1 ]; then
    cp "$DMLOG_BAK" "$DMLOG"
  else
    rm -f "$DMLOG"
  fi
}
cleanup() {
  restore_dmlog
  rm -rf "$SCRATCH"
}
trap cleanup EXIT

# --- 1. Structural: shim forwards to auto-entry with --ambiguity-mode prompt "$@"
if grep -q 'scripts/intake/auto-entry.sh' "$DO_ENTRY"; then
  pass "do-shim forwards to scripts/intake/auto-entry.sh"
else
  fail "do-shim does NOT reference scripts/intake/auto-entry.sh"
fi
if grep -q -- '--ambiguity-mode prompt' "$DO_ENTRY"; then
  pass "do-shim forwards with --ambiguity-mode prompt (preserves do-compat prompt path)"
else
  fail "do-shim missing --ambiguity-mode prompt"
fi
# The forward line must pass "$@" through (all six flags by construction).
if grep -qE 'auto-entry\.sh --ambiguity-mode prompt "\$@"' "$DO_ENTRY"; then
  pass 'do-shim forwards "$@" verbatim (all six flags ride the pass-through)'
else
  fail 'do-shim forward line does not pass "$@" through'
fi

# --- 2. Header/usage documents all six legacy flags -------------------------
missing_flags=""
for flag in --task --yes --config --dispatch-stub --scratch-root --no-prompt-mode; do
  if ! grep -q -- "$flag" "$DO_ENTRY"; then
    missing_flags="$missing_flags $flag"
  fi
done
if [ -z "$missing_flags" ]; then
  pass "do-shim documents all six legacy flags (--task --yes --config --dispatch-stub --scratch-root --no-prompt-mode)"
else
  fail "do-shim missing documentation for flag(s):$missing_flags"
fi

# --- 3. Functional spot-check --task (high-conf degenerate) -----------------
# "fix typo" -> idea/high -> above floor -> tier=a degenerate one-shot.
STUB="$SCRATCH/noop-stub.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$STUB"
chmod +x "$STUB"
out_task="$SCRATCH/task.stderr"
bash "$DO_ENTRY" --task "fix typo" --dispatch-stub "$STUB" 2> "$out_task"
rc_task=$?
if [ "$rc_task" -eq 0 ]; then
  pass "do-shim --task spot-check exits 0"
else
  fail "do-shim --task spot-check expected exit 0, got $rc_task"
fi
if grep -q 'AUTO:ROUTE tier=a mode=one-shot' "$out_task"; then
  pass "do-shim forwards --task: routes to Tier-A one-shot (proves --task reached auto-entry)"
else
  fail "do-shim --task did not produce AUTO:ROUTE tier=a mode=one-shot"
fi

# --- 4. Functional spot-check --no-prompt-mode on the below-floor path -------
# 8-word idea -> idea/low -> below floor. Under the shim's forwarded
# --ambiguity-mode prompt, --no-prompt-mode B must (a) NOT hang and (b) take
# branch B (route=tier_bc), which is the do-compat behavior -- NOT the
# auto-native AUTO:BLOCK_AMBIGUITY.
LOWCONF="alpha beta gamma delta epsilon zeta eta theta"
out_np="$SCRATCH/noprompt.stderr"
ORCH_DO_ENTRY_LOG="$SCRATCH/unit-close.jsonl" \
  bash "$DO_ENTRY" --task "$LOWCONF" --no-prompt-mode B 2> "$out_np"
rc_np=$?
if [ "$rc_np" -eq 0 ]; then
  pass "do-shim --no-prompt-mode B below-floor exits 0 (did not hang)"
else
  fail "do-shim --no-prompt-mode B below-floor expected exit 0, got $rc_np"
fi
if grep -q 'route=tier_bc' "$out_np"; then
  pass "do-shim forwards --no-prompt-mode AND preserves do prompt path (branch B -> route=tier_bc)"
else
  fail "do-shim --no-prompt-mode B did not take branch B (route=tier_bc)"
fi
if grep -q 'AUTO:BLOCK_AMBIGUITY' "$out_np"; then
  fail "do-shim below-floor emitted AUTO:BLOCK_AMBIGUITY -- it must ride the do-compat prompt path, not the auto-native block default"
else
  pass "do-shim below-floor did NOT emit AUTO:BLOCK_AMBIGUITY (rides do-compat prompt path, per --ambiguity-mode prompt)"
fi

# --- Aggregate --------------------------------------------------------------
printf 'SUMMARY: m046-p03-shim-forward.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
