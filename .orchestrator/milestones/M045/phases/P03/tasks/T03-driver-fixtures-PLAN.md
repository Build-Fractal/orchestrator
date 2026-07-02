---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M045"
name: "Driver safety fixtures — SC-2 (terminal) + SC-3 (cap + progress)"
depends_on: ["T02"]
---

## Prerequisites

- T01 driver + T02 wiring complete.

## Description

Hermetic fixtures that exercise the driver's safety envelope with a STUB auto-cmd (no real `claude -p`): terminal outcomes never re-spawn (SC-2 / FR-4), the cap halts with a forward-progress field that distinguishes healthy advance from thrash (SC-3 / FR-5).

Both verifiers create a scratch milestone dir under the scratchpad/tmp and a stub script that writes the `.self-continue-outcome` marker, then run the driver with `--min-interval 0` and injected `--auto-cmd`.

## Steps

1. Author `tools/verify/m045-p03-driver-terminal.sh` (SC-2 / FR-4):
   ```sh
   #!/usr/bin/env sh
   # SC-2: the driver STOPS (no re-spawn) on every terminal outcome.
   set -eu
   D="scripts/lifecycle/self-continue-drive.sh"
   TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
   MDIR="$TMP/M"; mkdir -p "$MDIR"
   STUB="$TMP/stub.sh"
   # Stub writes whatever outcome is in $TMP/outcome to the marker.
   printf '#!/usr/bin/env sh\ncat "%s/outcome" > "%s/.self-continue-outcome"\n' "$TMP" "$MDIR" > "$STUB"
   chmod +x "$STUB"
   for OUT in complete blocked budget stuck pause; do
     echo "$OUT" > "$TMP/outcome"
     RES="$(sh "$D" "$MDIR" --min-interval 0 --auto-cmd "sh $STUB")"
     case "$RES" in
       *"SELF_CONTINUE:TERMINAL"*"continuations=0"*) : ;;
       *) echo "FAIL: outcome=$OUT expected TERMINAL w/ 0 continuations, got: $RES"; exit 1 ;;
     esac
   done
   echo "PASS: all 5 terminal outcomes stop with no re-spawn"
   ```
2. Author `tools/verify/m045-p03-driver-cap.sh` (SC-3 / FR-5):
   ```sh
   #!/usr/bin/env sh
   # SC-3: cap halts the loop; forward-progress distinguishes advance vs thrash.
   set -eu
   D="scripts/lifecycle/self-continue-drive.sh"
   TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
   MDIR="$TMP/M"; mkdir -p "$MDIR"
   # Thrash stub: always rotation on the SAME phase P01.
   THRASH="$TMP/thrash.sh"
   printf '#!/usr/bin/env sh\nprintf "rotation P01" > "%s/.self-continue-outcome"\n' "$MDIR" > "$THRASH"; chmod +x "$THRASH"
   RES="$(sh "$D" "$MDIR" --min-interval 0 --max-continuations 3 --auto-cmd "sh $THRASH")"
   case "$RES" in
     *"SELF_CONTINUE:CAP_REACHED continuations=3 progress=1"*) : ;;
     *) echo "FAIL: thrash expected CAP_REACHED continuations=3 progress=1, got: $RES"; exit 1 ;;
   esac
   # Healthy stub: rotation advancing phase each call (P + a counter file).
   HEALTHY="$TMP/healthy.sh"
   printf '#!/usr/bin/env sh\nN=$(cat "%s/n" 2>/dev/null || echo 0); N=$((N+1)); echo "$N" > "%s/n"; printf "rotation P%%s" "$N" > "%s/.self-continue-outcome"\n' "$TMP" "$TMP" "$MDIR" > "$HEALTHY"; chmod +x "$HEALTHY"
   RES2="$(sh "$D" "$MDIR" --min-interval 0 --max-continuations 3 --auto-cmd "sh $HEALTHY")"
   case "$RES2" in
     *"SELF_CONTINUE:CAP_REACHED continuations=3 progress=3"*) : ;;
     *) echo "FAIL: healthy expected CAP_REACHED continuations=3 progress=3, got: $RES2"; exit 1 ;;
   esac
   echo "PASS: cap halts; progress=1 on thrash, progress=3 on healthy advance"
   ```
3. `chmod +x` both; run them.

## Must-Haves

- SC-2 verifier: all 5 terminal outcomes yield `SELF_CONTINUE:TERMINAL` with `continuations=0` (no re-spawn).
- SC-3 verifier: cap halts at max-continuations; thrash yields `progress=1` (flat) while healthy yields `progress=3` (advancing) — both at `continuations=3`.

## Verification

`bash tools/verify/m045-p03-driver-terminal.sh`
`bash tools/verify/m045-p03-driver-cap.sh`

## Inputs

### From Previous Tasks
- `scripts/lifecycle/self-continue-drive.sh` (T01) — `<milestone-dir> [--max-continuations N] [--min-interval S] [--auto-cmd "<cmd>"] [--stop-file <p>]`; emits `SELF_CONTINUE:SCHEDULED|TERMINAL|CAP_REACHED|STOPPED` with `continuations=`/`progress=`.

## Constraints

- Fully hermetic — stub auto-cmd, no real `claude`; `--min-interval 0`; scratch dirs under `mktemp`.
- POSIX sh.

## Expected Output

Two passing driver safety verifiers proving FR-4 (terminal) and FR-5 (cap + progress/thrash).
