---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M045"
name: "Author scripts/lifecycle/self-continue-branch.sh (deterministic directive) + SC-5 truth-table"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `detect-capabilities.sh` emits `headless_reentry`.

## Description

Author the deterministic decision core (spec FR-3): given the rotation-monitor status, the armed flag, and the headless-reentry capability, print exactly one machine-readable directive. This is the substrate-agnostic heart of self-continue — it decides *whether* to self-continue; P03 decides that the `AUTO:SELF_CONTINUE` directive triggers a fresh `claude -p` spawn. Policy lives in shell (Principle X); the agent only acts on the directive.

## Steps

1. Create `scripts/lifecycle/self-continue-branch.sh`:
   ```bash
   #!/usr/bin/env bash
   # self-continue-branch.sh — deterministic self-continue decision (M045 FR-3).
   # Given the rotation-monitor status + armed flag + headless_reentry capability,
   # emit exactly one directive:
   #   AUTO:SELF_CONTINUE          — rotation AND armed AND headless-capable
   #   AUTO:ROTATE_EXIT reason=... — rotation but not(armed AND capable) → legacy exit
   #   AUTO:NO_ROTATION            — monitor did not report rotation
   # Substrate-agnostic: the caller (commands/auto.md, wired in P03) turns
   # AUTO:SELF_CONTINUE into a process-fresh `claude -p` re-entry (D015).
   #
   # Usage: self-continue-branch.sh --monitor-status "<CONTEXT:OK...|CONTEXT:ROTATE...>"
   #          --armed <true|false> [--headless <true|false>]
   #          [--capabilities-file <path>]
   # If --headless is omitted, the capability is read from `detect-capabilities.sh`
   # (or from --capabilities-file if provided, a key=value dump for tests).
   set -euo pipefail
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
   MONITOR_STATUS=""; ARMED="false"; HEADLESS=""; CAP_FILE=""
   while [[ $# -gt 0 ]]; do
     case "$1" in
       --monitor-status) MONITOR_STATUS="$2"; shift 2 ;;
       --armed) ARMED="$2"; shift 2 ;;
       --headless) HEADLESS="$2"; shift 2 ;;
       --capabilities-file) CAP_FILE="$2"; shift 2 ;;
       *) shift ;;
     esac
   done
   # Resolve headless capability if not explicitly provided.
   if [[ -z "$HEADLESS" ]]; then
     if [[ -n "$CAP_FILE" && -f "$CAP_FILE" ]]; then
       HEADLESS="$(grep -E '^headless_reentry=' "$CAP_FILE" | head -n1 | sed 's/^headless_reentry=//')"
     else
       HEADLESS="$(bash "$REPO_ROOT/dispatch/detect-capabilities.sh" 2>/dev/null | grep -E '^headless_reentry=' | head -n1 | sed 's/^headless_reentry=//')"
     fi
     [[ -n "$HEADLESS" ]] || HEADLESS="false"
   fi
   # Decide.
   case "$MONITOR_STATUS" in
     *CONTEXT:ROTATE*)
       if [[ "$ARMED" == "true" && "$HEADLESS" == "true" ]]; then
         echo "AUTO:SELF_CONTINUE substrate=process-fresh"
       elif [[ "$ARMED" != "true" ]]; then
         echo "AUTO:ROTATE_EXIT reason=not-armed"
       else
         echo "AUTO:ROTATE_EXIT reason=headless-unavailable"
       fi
       ;;
     *)
       echo "AUTO:NO_ROTATION"
       ;;
   esac
   ```
   Note the `detect-capabilities.sh` path is `$REPO_ROOT/dispatch/detect-capabilities.sh` because `REPO_ROOT` here is `scripts/` (parent of `scripts/lifecycle/`). Confirm the path resolves during the Step-3 self-test; adjust if the truth-table run cannot find it (the tests pass `--headless` explicitly, so path resolution only matters for the default branch).
2. `chmod +x scripts/lifecycle/self-continue-branch.sh`.
3. Author `tools/verify/m045-p02-branch-truth-table.sh` — the SC-5 fixture. It drives the branch across every row with explicit `--headless` (so it is hermetic, no dependency on the host's real `claude` CLI):
   ```sh
   #!/usr/bin/env sh
   # SC-5: self-continue-branch.sh truth table (M045 P02).
   set -eu
   B="scripts/lifecycle/self-continue-branch.sh"
   ROT="CONTEXT:ROTATE weight=9 limit=3"
   OK="CONTEXT:OK weight=1 limit=3"
   assert() { # <expected-substr> <actual>
     case "$2" in *"$1"*) : ;; *) echo "FAIL: expected '$1' in '$2'"; exit 1 ;; esac
   }
   assert "AUTO:SELF_CONTINUE"  "$(bash "$B" --monitor-status "$ROT" --armed true  --headless true)"
   assert "reason=not-armed"    "$(bash "$B" --monitor-status "$ROT" --armed false --headless true)"
   assert "reason=headless-unavailable" "$(bash "$B" --monitor-status "$ROT" --armed true  --headless false)"
   assert "reason=not-armed"    "$(bash "$B" --monitor-status "$ROT" --armed false --headless false)"
   assert "AUTO:NO_ROTATION"    "$(bash "$B" --monitor-status "$OK"  --armed true  --headless true)"
   echo "PASS: truth table (5 rows)"
   ```
4. `chmod +x tools/verify/m045-p02-branch-truth-table.sh` and run it.

## Must-Haves

- `self-continue-branch.sh` emits `AUTO:SELF_CONTINUE` only for armed=true & headless=true & rotation; `AUTO:ROTATE_EXIT` otherwise on rotation; `AUTO:NO_ROTATION` when no rotation.
- The truth-table verifier passes all 5 rows.

## Verification

`bash tools/verify/m045-p02-branch-truth-table.sh`

## Inputs

### From Previous Tasks
- `scripts/dispatch/detect-capabilities.sh` (from T01)
  - Key API: emits `headless_reentry=true|false` in its `key=value` text output.

## Constraints

- Deterministic + hermetic: the truth-table verifier must pass regardless of whether the host has the `claude` CLI (achieved by passing `--headless` explicitly).
- Do NOT wire this into `commands/auto.md`'s live rotation behavior — that is P03. P02 only produces the branch + tests.
- The `## Verification` block contains ONLY the check command (AD-19 / section discipline).

## Expected Output

`scripts/lifecycle/self-continue-branch.sh` + a passing 5-row SC-5 truth-table verifier.
