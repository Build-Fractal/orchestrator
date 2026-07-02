---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M045"
name: "Author the process-fresh driver scripts/lifecycle/self-continue-drive.sh"
depends_on: []
---

## Prerequisites

- P02 complete: `scripts/lifecycle/self-continue-branch.sh` (directive) + `detect-capabilities.sh` `headless_reentry` exist.

## Description

Author the outer process-fresh self-continue driver (spec FR-2/4/5/5a/6, D015). It loops: run one fresh `claude -p` auto segment → read the segment's outcome marker from disk → consult `self-continue-branch.sh` → on `AUTO:SELF_CONTINUE`, re-spawn after a min-interval; on any terminal outcome or the cap or a stop-file, halt. Each auto segment is a genuinely new process (process-fresh context reset — the property P01 proved in-session re-entry lacks).

## Steps

1. Create `scripts/lifecycle/self-continue-drive.sh`:
   ```sh
   #!/usr/bin/env sh
   # self-continue-drive.sh <milestone-dir> [options]
   # Outer process-fresh self-continue loop (M045 FR-2/4/5/5a/6, decision D015).
   # Each iteration runs ONE fresh auto segment (default: claude -p), reads the
   # segment's outcome marker, and re-spawns only while rotation continues under
   # the safety envelope. The child auto MUST run single-segment (no --self-continue)
   # so it does not nest a second driver.
   #
   # Outcome marker: <milestone-dir>/.self-continue-outcome, written by the auto
   # segment as "<outcome> [<phase>]" where <outcome> is rotation|complete|blocked|
   # budget|stuck|pause. Word 2 (phase) drives forward-progress (thrash detection).
   set -eu
   MILESTONE_DIR="$1"; shift
   MAX_CONT=20; MIN_INTERVAL=2; ARMED=true; STOP_FILE=""; AUTO_CMD=""
   while [ $# -gt 0 ]; do
     case "$1" in
       --max-continuations) MAX_CONT="$2"; shift 2 ;;
       --min-interval) MIN_INTERVAL="$2"; shift 2 ;;
       --armed) ARMED="$2"; shift 2 ;;
       --stop-file) STOP_FILE="$2"; shift 2 ;;
       --auto-cmd) AUTO_CMD="$2"; shift 2 ;;
       *) shift ;;
     esac
   done
   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
   BRANCH="$SCRIPT_DIR/self-continue-branch.sh"
   OUTCOME_FILE="$MILESTONE_DIR/.self-continue-outcome"
   [ -n "$AUTO_CMD" ] || AUTO_CMD="claude -p \"orchestrator:auto $MILESTONE_DIR\""
   HEADLESS="$(bash "$REPO_ROOT/dispatch/detect-capabilities.sh" 2>/dev/null | grep -E '^headless_reentry=' | head -n1 | sed 's/^headless_reentry=//')"
   [ -n "$HEADLESS" ] || HEADLESS=false
   cont=0; progress=0; last_phase=""
   while :; do
     if [ -n "$STOP_FILE" ] && [ -f "$STOP_FILE" ]; then
       echo "SELF_CONTINUE:STOPPED reason=stop-file continuations=$cont progress=$progress"; exit 0
     fi
     if [ "$cont" -ge "$MAX_CONT" ]; then
       echo "SELF_CONTINUE:CAP_REACHED continuations=$cont progress=$progress"; exit 0
     fi
     rm -f "$OUTCOME_FILE"
     sh -c "$AUTO_CMD" >/dev/null 2>&1 || true
     OUTCOME_RAW="$(cat "$OUTCOME_FILE" 2>/dev/null || echo unknown)"
     OUTCOME="$(printf '%s' "$OUTCOME_RAW" | awk '{print $1}')"
     PHASE="$(printf '%s' "$OUTCOME_RAW" | awk '{print $2}')"
     if [ "$OUTCOME" = "rotation" ]; then STATUS="CONTEXT:ROTATE"; else STATUS="CONTEXT:OK"; fi
     DECISION="$(bash "$BRANCH" --monitor-status "$STATUS" --armed "$ARMED" --headless "$HEADLESS")"
     case "$DECISION" in
       *AUTO:SELF_CONTINUE*)
         cont=$((cont+1))
         if [ -n "$PHASE" ] && [ "$PHASE" != "$last_phase" ]; then
           progress=$((progress+1)); last_phase="$PHASE"
         fi
         echo "SELF_CONTINUE:SCHEDULED continuation=$cont progress=$progress phase=$PHASE"
         [ "$MIN_INTERVAL" = "0" ] || sleep "$MIN_INTERVAL"
         ;;
       *)
         echo "SELF_CONTINUE:TERMINAL outcome=$OUTCOME decision=$DECISION continuations=$cont progress=$progress"
         exit 0
         ;;
     esac
   done
   ```
2. `chmod +x scripts/lifecycle/self-continue-drive.sh`.
3. Smoke-test hermetically with an inline stub auto-cmd that emits `rotation P01` once then `complete`. Create a scratch milestone dir + a stub script under `/tmp` (or the scratchpad) that writes the outcome marker based on a counter, and confirm the driver emits one `SELF_CONTINUE:SCHEDULED` then `SELF_CONTINUE:TERMINAL outcome=complete`. (T03 formalizes this as fixtures.)

## Must-Haves

- Driver re-spawns on `rotation` + armed + headless, stops on terminal/cap/stop-file.
- `SELF_CONTINUE:CAP_REACHED` and `SELF_CONTINUE:SCHEDULED` carry `continuations=` and `progress=` (progress increments only on phase change → thrash detection).

## Verification

`test -x scripts/lifecycle/self-continue-drive.sh`
`grep -q "SELF_CONTINUE:CAP_REACHED" scripts/lifecycle/self-continue-drive.sh`

## Inputs

### From Previous Tasks
- `scripts/lifecycle/self-continue-branch.sh` (P02) — `--monitor-status <s> --armed <b> --headless <b>` → `AUTO:SELF_CONTINUE` / `AUTO:ROTATE_EXIT reason=...` / `AUTO:NO_ROTATION`.
- `scripts/dispatch/detect-capabilities.sh` (P02) — `headless_reentry=`.

## Constraints

- POSIX sh; Bash 3.2 safe. `awk`/`sed`/`grep` internal to the script are fine (AD-19 is about the harness Bash command line, not script internals).
- Default `--auto-cmd` runs `claude -p` — but ALL P03 verification uses injected stub `--auto-cmd` (no real LLM calls). Tests pass `--min-interval 0`.
- The child auto invocation must be single-segment (no `--self-continue`) to avoid nested drivers.

## Expected Output

`scripts/lifecycle/self-continue-drive.sh` — the process-fresh outer loop with cap + terminal + interrupt + progress, verified hermetically.
