#!/usr/bin/env bash
# tests/m029-acceptance/p03-sc10-auto-chain.sh
#
# M029 / P03 / SC-10 acceptance script.
#
# SC-10 contract: orchestrator:start --auto-chain walks the four
# entry stages (evaluate -> discuss -> roadmap -> plan-phase) one stage
# at a time, writing .orchestrator/start-state/<STAGE>.complete after
# each successful stage. On re-invocation, stages with their .complete
# marker present are SKIP'd (idempotent resume); stages with absent
# markers are re-executed.
#
# Assertions (end-to-end against a fresh greenfield fixture under
# mktemp -d):
#   1. First invocation writes all four canonical .complete markers.
#   2. First invocation emits OK: <stage> for each, plus
#      START_AUTO_CHAIN_COMPLETE.
#   3. After deleting roadmap.complete + plan-phase.complete, re-invoke.
#      evaluate.complete and discuss.complete mtimes are UNCHANGED
#      (idempotent skip).
#   4. roadmap.complete and plan-phase.complete are re-written.
#   5. Re-invocation stdout contains SKIP: evaluate (marker present)
#      and SKIP: discuss (marker present) and OK: roadmap and OK:
#      plan-phase.
#
# The fixture's auto-chain-stage-stub.sh is wired via AUTO_CHAIN_STAGE
# _STUB env var (FR-10 fixture-only escape hatch); each stage invocation
# is a no-op that returns 0, exercising the chain-driver gate-and-mark
# semantics without invoking deep skill behavior.
#
# Bash 3.2 (MEM001). MEM004 carve-out: pipes inside body OK.
# CON-1 / FR-14 read-only: writes confined to /tmp/m029-p03-sc10.$$/.
# The fixture itself stays read-only; we copy it to a fresh mktemp -d
# and run start.sh against the copy.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_SRC="$PROJECT_ROOT/tests/m029-acceptance/fixtures/auto-chain-greenfield.fixture"
START_SH="$PROJECT_ROOT/scripts/lifecycle/start.sh"

pass=0
fail=0
ok() { printf 'PASS: %s\n' "$1"; pass=$(( pass + 1 )); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$(( fail + 1 )); }

TMP="${TMPDIR:-/tmp}/m029-p03-sc10.$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP" 2>/dev/null || true' EXIT

# Gate: source fixture exists.
if [ -d "$FIXTURE_SRC" ] && [ -x "$FIXTURE_SRC/auto-chain-stage-stub.sh" ]; then
    ok "SC-10 source fixture + stub script exist"
else
    bad "SC-10 fixture missing or stub not executable at $FIXTURE_SRC"
    printf 'SUMMARY: p03-sc10-auto-chain.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# Gate: start.sh exists.
if [ -f "$START_SH" ]; then
    ok "scripts/lifecycle/start.sh exists"
else
    bad "scripts/lifecycle/start.sh missing"
    printf 'SUMMARY: p03-sc10-auto-chain.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# Stage-1: copy fixture to a fresh project dir and run start.sh
# --auto-chain --yes. The fixture's stub is the AUTO_CHAIN_STAGE_STUB
# target; chain-driver invokes it for each stage with the stage name
# as $1. The stub returns 0 for every stage.
PROJ="$TMP/proj"
mkdir -p "$PROJ"
cp -R "$FIXTURE_SRC/." "$PROJ/"

# Locate the copied stub. Use ABS path for AUTO_CHAIN_STAGE_STUB.
STUB="$PROJ/auto-chain-stage-stub.sh"
chmod +x "$STUB" 2>/dev/null || true

# Run from the project root (start.sh resolves scripts/* relative to
# CWD). The fixture's $PROJECT_DIR is the temp project copy.
RUN1_OUT="$TMP/run1.out"
RUN1_ERR="$TMP/run1.err"
cd "$PROJECT_ROOT"
AUTO_CHAIN_STAGE_STUB="$STUB" bash "$START_SH" --project-dir "$PROJ" --auto-chain --yes >"$RUN1_OUT" 2>"$RUN1_ERR"
RUN1_RC=$?

if [ "$RUN1_RC" -eq 0 ]; then
    ok "SC-10 first invocation exited 0"
else
    bad "SC-10 first invocation exited $RUN1_RC"
    cat "$RUN1_OUT"
    cat "$RUN1_ERR"
fi

# Assertion 1+2: all four canonical markers exist; chain-complete token
# emitted on stdout.
SS_DIR="$PROJ/.orchestrator/start-state"
for STAGE in evaluate discuss roadmap plan-phase; do
    if [ -f "$SS_DIR/${STAGE}.complete" ]; then
        ok "SC-10 first run wrote ${STAGE}.complete"
    else
        bad "SC-10 first run did NOT write ${STAGE}.complete"
    fi
done

if grep -F -q -e 'START_AUTO_CHAIN_COMPLETE' "$RUN1_OUT"; then
    ok "SC-10 first run emitted START_AUTO_CHAIN_COMPLETE"
else
    bad "SC-10 first run did NOT emit START_AUTO_CHAIN_COMPLETE"
fi

for STAGE in evaluate discuss roadmap plan-phase; do
    if grep -F -q -e "OK: $STAGE" "$RUN1_OUT"; then
        ok "SC-10 first run emitted OK: $STAGE"
    else
        bad "SC-10 first run did NOT emit OK: $STAGE"
    fi
done

# Capture mtimes of evaluate.complete and discuss.complete BEFORE the
# resume-style re-invocation. Use stat -f %m on macOS, stat -c %Y on
# Linux (discriminate via uname).
case "$(uname -s 2>/dev/null || true)" in
    Darwin) STAT_MTIME='stat -f %m' ;;
    *) STAT_MTIME='stat -c %Y' ;;
esac

EVAL_MTIME_BEFORE="$($STAT_MTIME "$SS_DIR/evaluate.complete" 2>/dev/null || true)"
DISC_MTIME_BEFORE="$($STAT_MTIME "$SS_DIR/discuss.complete" 2>/dev/null || true)"

# Sleep so any subsequent re-write would have a strictly-greater mtime.
sleep 2

# Stage-2: simulate mid-chain interruption -- delete roadmap.complete
# and plan-phase.complete. Re-invoke start.sh --auto-chain --yes.
rm -f "$SS_DIR/roadmap.complete" "$SS_DIR/plan-phase.complete"

RUN2_OUT="$TMP/run2.out"
RUN2_ERR="$TMP/run2.err"
AUTO_CHAIN_STAGE_STUB="$STUB" bash "$START_SH" --project-dir "$PROJ" --auto-chain --yes >"$RUN2_OUT" 2>"$RUN2_ERR"
RUN2_RC=$?

if [ "$RUN2_RC" -eq 0 ]; then
    ok "SC-10 second invocation exited 0 (resume path)"
else
    bad "SC-10 second invocation exited $RUN2_RC"
    cat "$RUN2_OUT"
    cat "$RUN2_ERR"
fi

# Assertion 3: evaluate.complete + discuss.complete mtimes UNCHANGED.
EVAL_MTIME_AFTER="$($STAT_MTIME "$SS_DIR/evaluate.complete" 2>/dev/null || true)"
DISC_MTIME_AFTER="$($STAT_MTIME "$SS_DIR/discuss.complete" 2>/dev/null || true)"

if [ -n "$EVAL_MTIME_BEFORE" ] && [ "$EVAL_MTIME_BEFORE" = "$EVAL_MTIME_AFTER" ]; then
    ok "SC-10 evaluate.complete mtime unchanged on resume (idempotent skip)"
else
    bad "SC-10 evaluate.complete mtime changed: $EVAL_MTIME_BEFORE -> $EVAL_MTIME_AFTER"
fi
if [ -n "$DISC_MTIME_BEFORE" ] && [ "$DISC_MTIME_BEFORE" = "$DISC_MTIME_AFTER" ]; then
    ok "SC-10 discuss.complete mtime unchanged on resume (idempotent skip)"
else
    bad "SC-10 discuss.complete mtime changed: $DISC_MTIME_BEFORE -> $DISC_MTIME_AFTER"
fi

# Assertion 4: roadmap.complete and plan-phase.complete re-written.
for STAGE in roadmap plan-phase; do
    if [ -f "$SS_DIR/${STAGE}.complete" ]; then
        ok "SC-10 resume re-wrote ${STAGE}.complete"
    else
        bad "SC-10 resume did NOT re-write ${STAGE}.complete"
    fi
done

# Assertion 5: stdout contains SKIP: evaluate / discuss + OK: roadmap /
# plan-phase tokens.
if grep -F -q -e 'SKIP: evaluate (marker present)' "$RUN2_OUT"; then
    ok "SC-10 resume emitted SKIP: evaluate (marker present)"
else
    bad "SC-10 resume did NOT emit SKIP: evaluate"
fi
if grep -F -q -e 'SKIP: discuss (marker present)' "$RUN2_OUT"; then
    ok "SC-10 resume emitted SKIP: discuss (marker present)"
else
    bad "SC-10 resume did NOT emit SKIP: discuss"
fi
if grep -F -q -e 'OK: roadmap' "$RUN2_OUT"; then
    ok "SC-10 resume emitted OK: roadmap"
else
    bad "SC-10 resume did NOT emit OK: roadmap"
fi
if grep -F -q -e 'OK: plan-phase' "$RUN2_OUT"; then
    ok "SC-10 resume emitted OK: plan-phase"
else
    bad "SC-10 resume did NOT emit OK: plan-phase"
fi

if grep -F -q -e 'START_AUTO_CHAIN_COMPLETE' "$RUN2_OUT"; then
    ok "SC-10 resume emitted START_AUTO_CHAIN_COMPLETE"
else
    bad "SC-10 resume did NOT emit START_AUTO_CHAIN_COMPLETE"
fi

printf 'SUMMARY: p03-sc10-auto-chain.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
