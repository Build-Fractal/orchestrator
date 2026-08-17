#!/usr/bin/env bash
# tools/verify/m046-p03-shim-parity.sh
# M046/P03/T05 -- SC-2 LOAD-BEARING BYTE-EQUALITY gate.
#
# Proves that a `do`-shim invocation and the equivalent `auto` invocation
# produce BYTE-IDENTICAL dispatch artifacts on a fixed Tier-A degenerate
# fixture, and that the deprecation notice is present on the `do`-shim path
# and ABSENT on the `auto` path (SC-2 / US2 / FR-2).
#
# Method:
#   - A capture dispatch-stub receives the auto-entry.sh degenerate-branch
#     positionals (branch, task, payload, sidecar) and copies the payload
#     ($3) and sidecar ($4) into a per-run dest dir passed via $ORCH_CAP_DEST.
#   - The SAME fixed short idea ("refactor the helper" -> idea/high ->
#     tier_a_degenerate, above the 0.7 floor, deterministic; the parity
#     fixture never reaches the below-floor --ambiguity-mode fork, so the
#     ONLY behavioral difference between the two paths is the shim's stderr
#     notice).
#   - Path A: bash scripts/intake/do-entry.sh --task ... --dispatch-stub <cap>
#   - Path B: bash scripts/intake/auto-entry.sh --task ... --dispatch-stub <cap>
#   - The captured payloads are compared with `diff` for BYTE-IDENTITY; same
#     for the sidecar. NOT substring.
#
# Determinism honesty note (verified empirically at authoring time):
#   scripts/dispatch/build-context.sh --profile=quick direct mode is
#   byte-deterministic across immediate re-runs of the same input EXCEPT for
#   exactly one time-relative line the provenance header emits:
#       "  index_age: <integer-seconds-since-KNOWLEDGE-INDEX.md-mtime>"
#   (scripts/dispatch/lib/knowledge-provenance.sh kp_index_age / kp_emit_header).
#   Because the do path and the auto path run sequentially, they can straddle a
#   one-second boundary and disagree by 1 on that line alone. This verifier
#   therefore normalizes ONLY that single `  index_age:` line symmetrically on
#   BOTH sides with a documented sed before diffing. Every other byte of the
#   payload -- the frontmatter, provenance source/version/entries, the injected
#   knowledge body, the Decisions digest, and the Task Plan -- is compared
#   byte-for-byte. The load-bearing body is NEVER weakened to substring.
#
# Outer-auto-loop hygiene: build-context.sh direct mode appends one
# payload_breakdown record to the git-tracked
# .orchestrator/direct-mode-execution-log.jsonl on each run. This verifier
# snapshots that log before the runs and restores its exact bytes afterwards.
# All other scratch lives under a mktemp -d tree.
#
# Output: PASS: / FAIL: lines + a final
#   SUMMARY: m046-p03-shim-parity.sh pass=N fail=M
# Exit 0 iff fail=0.
#
# Bash 3.2 compatible (MEM001): no declare -A, no process substitution.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
cd "$PROJECT_ROOT"

DO_ENTRY="scripts/intake/do-entry.sh"
AUTO_ENTRY="scripts/intake/auto-entry.sh"

pass=0
fail=0
pass() { printf 'PASS: %s\n' "$1"; pass=$(( pass + 1 )); }
fail() { printf 'FAIL: %s\n' "$1"; fail=$(( fail + 1 )); }

SCRATCH="$( mktemp -d -t m046-p03-shim-parity.XXXXXX )"

# --- snapshot/restore the git-tracked direct-mode execution log -------------
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

# --- capture dispatch-stub --------------------------------------------------
# auto-entry.sh invokes the stub as:
#   bash <stub> "tier_a_degenerate" "$TASK" "$payload" "$sidecar"
# so $3 is the payload and $4 the sidecar. Copy both into $ORCH_CAP_DEST.
STUB="$SCRATCH/cap-stub.sh"
{
  printf '#!/usr/bin/env bash\n'
  printf 'set -u\n'
  printf 'mkdir -p "$ORCH_CAP_DEST"\n'
  printf 'cp "$3" "$ORCH_CAP_DEST/payload"\n'
  printf 'cp "$4" "$ORCH_CAP_DEST/sidecar"\n'
  printf 'exit 0\n'
} > "$STUB"
chmod +x "$STUB"

TASK="refactor the helper"

DO_ART="$SCRATCH/do-art"
AUTO_ART="$SCRATCH/auto-art"
mkdir -p "$DO_ART" "$AUTO_ART"
DO_STDERR="$SCRATCH/do.stderr"
AUTO_STDERR="$SCRATCH/auto.stderr"

# --- Path A: the do-shim ----------------------------------------------------
ORCH_CAP_DEST="$DO_ART" bash "$DO_ENTRY" \
  --task "$TASK" --dispatch-stub "$STUB" --scratch-root "$SCRATCH/do-tmp" \
  2> "$DO_STDERR"
rc_do=$?
if [ "$rc_do" -eq 0 ]; then
  pass "do-shim degenerate path exits 0"
else
  fail "do-shim degenerate path expected exit 0, got $rc_do"
fi

# --- Path B: auto directly --------------------------------------------------
ORCH_CAP_DEST="$AUTO_ART" bash "$AUTO_ENTRY" \
  --task "$TASK" --dispatch-stub "$STUB" --scratch-root "$SCRATCH/auto-tmp" \
  2> "$AUTO_STDERR"
rc_auto=$?
if [ "$rc_auto" -eq 0 ]; then
  pass "auto degenerate path exits 0"
else
  fail "auto degenerate path expected exit 0, got $rc_auto"
fi

# --- artifacts must both exist ----------------------------------------------
if [ -f "$DO_ART/payload" ] && [ -f "$AUTO_ART/payload" ]; then
  pass "both entry paths produced a captured payload"
else
  fail "missing captured payload (do=$DO_ART/payload auto=$AUTO_ART/payload)"
fi
if [ -f "$DO_ART/sidecar" ] && [ -f "$AUTO_ART/sidecar" ]; then
  pass "both entry paths produced a captured sidecar"
else
  fail "missing captured sidecar"
fi

# --- SIDECAR: byte-identical, no normalization (fully deterministic) ---------
if [ -f "$DO_ART/sidecar" ] && [ -f "$AUTO_ART/sidecar" ]; then
  if diff "$DO_ART/sidecar" "$AUTO_ART/sidecar" > "$SCRATCH/sidecar.diff" 2>&1; then
    pass "sidecar byte-identical across do-shim and auto (raw diff, no normalization)"
  else
    fail "sidecar NOT byte-identical -- diff follows:"
    sed 's/^/    /' "$SCRATCH/sidecar.diff"
  fi
fi

# --- PAYLOAD: byte-identical after symmetric index_age normalization ---------
# Normalize ONLY the single time-relative `  index_age:` line on BOTH sides.
# The load-bearing body is still compared byte-for-byte.
if [ -f "$DO_ART/payload" ] && [ -f "$AUTO_ART/payload" ]; then
  sed 's/^  index_age: .*/  index_age: <normalized>/' "$DO_ART/payload"   > "$SCRATCH/do.payload.norm"
  sed 's/^  index_age: .*/  index_age: <normalized>/' "$AUTO_ART/payload" > "$SCRATCH/auto.payload.norm"
  if diff "$SCRATCH/do.payload.norm" "$SCRATCH/auto.payload.norm" > "$SCRATCH/payload.diff" 2>&1; then
    pass "payload byte-identical across do-shim and auto (index_age line normalized symmetrically; body compared byte-for-byte)"
  else
    fail "payload NOT byte-identical after index_age normalization -- diff follows:"
    sed 's/^/    /' "$SCRATCH/payload.diff"
  fi

  # Guard the honesty note: confirm the ONLY line that ever differed raw is the
  # index_age line, i.e. the un-normalized diff (if any) touches nothing else.
  if diff "$DO_ART/payload" "$AUTO_ART/payload" > "$SCRATCH/payload.raw.diff" 2>&1; then
    pass "payload was byte-identical even WITHOUT normalization on this run (index_age happened to match)"
  else
    # A raw difference exists: every differing line MUST be an index_age line.
    non_index_age="$(grep -E '^[<>]' "$SCRATCH/payload.raw.diff" | grep -vE 'index_age:' || true)"
    if [ -z "$non_index_age" ]; then
      pass "the ONLY raw payload difference is the time-relative index_age line (honesty note holds)"
    else
      fail "raw payload differs on a NON-index_age line -- normalization would mask a real drift:"
      printf '%s\n' "$non_index_age" | sed 's/^/    /'
    fi
  fi
fi

# --- deprecation notice: present on do-shim, absent on auto ------------------
if grep -qi 'deprecat' "$DO_STDERR"; then
  pass "deprecation notice PRESENT on do-shim stderr"
else
  fail "deprecation notice missing on do-shim stderr"
fi
if grep -qi 'deprecat' "$AUTO_STDERR"; then
  fail "deprecation notice must be ABSENT on auto stderr, but it is present"
else
  pass "deprecation notice ABSENT on auto stderr"
fi

# --- Aggregate --------------------------------------------------------------
printf 'SUMMARY: m046-p03-shim-parity.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
