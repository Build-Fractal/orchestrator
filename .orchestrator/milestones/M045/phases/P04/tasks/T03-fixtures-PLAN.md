---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M045"
name: "SC-1 continuity fixture + SC-7 stall fixture"
depends_on: ["T02"]
---

## Prerequisites

- T01 (driver log emission) + T02 (status reader) complete.

## Description

Two hermetic verifiers: SC-1 proves a completed multi-segment run is auditable as ONE continuous execution from the log; SC-7 proves an unresolved segment surfaces as `SELF_CONTINUE:STALLED` via both the driver and the status reader.

## Steps

1. Author `tools/verify/m045-p04-continuity.sh` (SC-1):
   ```sh
   #!/usr/bin/env sh
   # SC-1: a completed multi-segment run is auditable as one continuous execution.
   set -eu
   D="scripts/lifecycle/self-continue-drive.sh"
   TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
   MDIR="$TMP/M"; mkdir -p "$MDIR"; LOG="$TMP/sc.log"
   # Stub: rotate on advancing phases for 2 segments, then complete.
   STUB="$TMP/stub.sh"
   printf '#!/usr/bin/env sh\nN=$(cat "%s/n" 2>/dev/null || echo 0); N=$((N+1)); echo "$N" > "%s/n"\nif [ "$N" -le 2 ]; then printf "rotation P%%s" "$N" > "%s/.self-continue-outcome"; else printf "complete" > "%s/.self-continue-outcome"; fi\n' "$TMP" "$TMP" "$MDIR" "$MDIR" > "$STUB"
   chmod +x "$STUB"
   sh "$D" "$MDIR" --min-interval 0 --log "$LOG" --auto-cmd "sh $STUB" >/dev/null
   SCHED="$(grep -c 'self_continue_scheduled' "$LOG" 2>/dev/null || echo 0)"
   [ "$SCHED" -ge 2 ] || { echo "FAIL: expected >=2 self_continue_scheduled, got $SCHED"; exit 1; }
   grep -q 'self_continue_terminal' "$LOG" || { echo "FAIL: no terminal record"; exit 1; }
   grep -q 'human' "$LOG" && { echo "FAIL: unexpected human-reinvoke marker in continuous log"; exit 1; }
   echo "PASS: multi-segment run auditable as one continuous execution ($SCHED scheduled + terminal)"
   ```
2. Author `tools/verify/m045-p04-stall.sh` (SC-7):
   ```sh
   #!/usr/bin/env sh
   # SC-7: a segment that produces no outcome surfaces as SELF_CONTINUE:STALLED.
   set -eu
   D="scripts/lifecycle/self-continue-drive.sh"
   S="scripts/diagnostics/self-continue-status.sh"
   TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
   MDIR="$TMP/M"; mkdir -p "$MDIR"; LOG="$TMP/sc.log"
   # Stub that never writes an outcome marker (simulates a crashed fresh segment).
   NOOP="$TMP/noop.sh"
   printf '#!/usr/bin/env sh\nexit 0\n' > "$NOOP"; chmod +x "$NOOP"
   RES="$(sh "$D" "$MDIR" --min-interval 0 --log "$LOG" --auto-cmd "sh $NOOP")"
   case "$RES" in
     *"SELF_CONTINUE:STALLED"*) : ;;
     *) echo "FAIL: expected SELF_CONTINUE:STALLED from driver, got: $RES"; exit 1 ;;
   esac
   ST="$(sh "$S" "$LOG")"
   case "$ST" in
     *"SELF_CONTINUE:STALLED"*) : ;;
     *) echo "FAIL: status reader did not report STALLED, got: $ST"; exit 1 ;;
   esac
   echo "PASS: stall surfaced by driver and status reader"
   ```
3. `chmod +x` both; run them. Then re-run the full P03 + P04 verifier set to confirm no regressions.

## Must-Haves

- SC-1 verifier: a 2-rotation-then-complete run logs ≥2 `self_continue_scheduled` + a terminal, no human marker.
- SC-7 verifier: a no-outcome segment yields `SELF_CONTINUE:STALLED` from BOTH the driver stdout and the status reader.

## Verification

`bash tools/verify/m045-p04-continuity.sh`
`bash tools/verify/m045-p04-stall.sh`

## Inputs

### From Previous Tasks
- `scripts/lifecycle/self-continue-drive.sh --log <path>` (T01).
- `scripts/diagnostics/self-continue-status.sh <log>` (T02) — emits `SELF_CONTINUE:STALLED|OK|NO_LOG`.

## Constraints

- Fully hermetic (stubs, mktemp, `--min-interval 0`); POSIX sh.

## Expected Output

Two passing verifiers proving FR-9 continuity (SC-1) and FR-10 stall (SC-7).
