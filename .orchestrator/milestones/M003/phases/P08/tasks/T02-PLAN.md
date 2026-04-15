---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P08"
milestone: "M003"
name: "Build scripts/orchestrator/status.sh wrapper"
depends_on: []
---

## Prerequisites

- `scripts/state/resolve-root.sh` exists and supports `--absolute` mode (produced by M008/P04).
- `scripts/state/derive-phase.sh` exists and emits a single state word to stdout (MEM003).
- The roadmap demo sentence for P08 cites `bash scripts/orchestrator/status.sh` — a path that does not yet exist. This task creates it.

## Description

Create a thin CLI wrapper at `scripts/orchestrator/status.sh` that resolves an orchestrator root (via env var, CLI flag, or the 5-rule resolver) and emits a structured milestone summary to stdout. The primary consumer is the P08 integration test (T03); the secondary consumer is any human developer who wants a one-line answer to "what's the current state?".

This is intentionally minimal — it is not the full `speckit.orchestrator.status` command (that already exists as a command document under `commands/status.md` and operates inside a live agent context). This wrapper is the shell-level equivalent that can run unattended against any orchestrator state root.

## Steps

1. Create directory `scripts/orchestrator/` (it does not yet exist).

2. Write `scripts/orchestrator/status.sh` with the following structure:

   ```bash
   #!/usr/bin/env bash
   # scripts/orchestrator/status.sh — Emit structured milestone summary for an
   # orchestrator state root. Consumed by tests/integration/test-m003-e2e-migration.sh
   # and by developers inspecting migrated or working state.
   #
   # Usage:
   #   status.sh [--root <dir>]
   #   ORCHESTRATOR_ROOT=<dir> status.sh
   #
   # Output (stdout):
   #   MILESTONE: <ID>
   #   STATE: <state-word>
   #   PHASE: P01 <state>
   #   PHASE: P02 <state>
   #   ...
   #
   # Exit codes:
   #   0 = success (at least one milestone found)
   #   1 = no milestones found under resolved root
   #   2 = resolver failed
   #
   # Bash 3.2 compatible.

   set -euo pipefail

   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

   # --- Parse args ---
   arg_root=""
   while [ $# -gt 0 ]; do
     case "$1" in
       --root) arg_root="$2"; shift 2 ;;
       --help|-h) sed -n '2,24p' "$0"; exit 0 ;;
       *) echo "status.sh: unknown arg: $1" >&2; exit 1 ;;
     esac
   done

   # --- Resolve root ---
   # Precedence: --root flag > ORCHESTRATOR_ROOT env > resolve-root.sh fallback
   if [ -n "$arg_root" ]; then
     resolved_root="$arg_root"
   elif [ -n "${ORCHESTRATOR_ROOT:-}" ]; then
     resolved_root="$ORCHESTRATOR_ROOT"
   else
     resolved_root="$(bash "$REPO_ROOT/scripts/state/resolve-root.sh" --absolute 2>/dev/null || true)"
   fi

   if [ -z "$resolved_root" ] || [ ! -d "$resolved_root" ]; then
     echo "status.sh: could not resolve orchestrator root (tried --root, ORCHESTRATOR_ROOT, resolve-root.sh)" >&2
     exit 2
   fi

   # --- Find milestones ---
   milestones_dir="$resolved_root/milestones"
   if [ ! -d "$milestones_dir" ]; then
     echo "status.sh: no milestones/ directory under $resolved_root" >&2
     exit 1
   fi

   any_milestone=0
   for m_dir in "$milestones_dir"/M*; do
     [ -d "$m_dir" ] || continue
     any_milestone=1
     m_id="$(basename "$m_dir")"
     # Milestone ID is directory name per MEM003 (detected from M###-*.md, but
     # directory basename is authoritative for this wrapper).
     m_state="$(bash "$REPO_ROOT/scripts/state/derive-phase.sh" "$m_dir" 2>/dev/null || echo unknown)"
     echo "MILESTONE: $m_id"
     echo "STATE: $m_state"
     if [ -d "$m_dir/phases" ]; then
       for p_dir in "$m_dir/phases"/P*; do
         [ -d "$p_dir" ] || continue
         p_id="$(basename "$p_dir")"
         if [ -f "$p_dir/$p_id-SUMMARY.md" ]; then
           p_state="complete"
         elif [ -f "$p_dir/$p_id-PLAN.md" ]; then
           p_state="executing"
         else
           p_state="pending"
         fi
         echo "PHASE: $p_id $p_state"
       done
     fi
   done

   if [ "$any_milestone" -eq 0 ]; then
     echo "status.sh: no milestones found under $milestones_dir" >&2
     exit 1
   fi
   ```

3. `chmod +x scripts/orchestrator/status.sh`.

4. Smoke-test against the live repo's state and against a freshly-migrated fixture:
   ```bash
   bash scripts/orchestrator/status.sh --root .specify/orchestrator
   TMP="$(mktemp -d)"
   bash scripts/migrate/migrate.sh --source gsd2 --path tests/fixtures/m003-p08-gsd-minimal --output "$TMP" --force
   bash scripts/orchestrator/status.sh --root "$TMP"
   ```
   Both invocations must exit 0 and emit at least one `MILESTONE:` line and one `STATE:` line.

## Must-Haves

- `scripts/orchestrator/status.sh` exists, is executable, and min 40 lines.
- Supports `--root <dir>` flag, `ORCHESTRATOR_ROOT` env var, and `scripts/state/resolve-root.sh --absolute` fallback, in that precedence.
- Stdout contract: at least one `MILESTONE: <ID>` line and one `STATE: <state>` line per discovered milestone; zero or more `PHASE: <Pxx> <state>` lines.
- Exit 0 on success, 1 on no milestones, 2 on resolver failure.

## Verification

- `bash scripts/verify/m003-p08-status-wrapper-contract.sh`

The verify script (added in T03) checks: file exists, executable, min 40 lines, contains `resolve-root`, `MILESTONE:`, and handles `--root`.

## Inputs

### From Previous Tasks
- None — T02 is independent of T01.

### From Disk (Pre-existing)
- `scripts/state/resolve-root.sh` (from M008/P04)
  - Key API: `bash resolve-root.sh --absolute` → prints resolved root to stdout.
- `scripts/state/derive-phase.sh` (from M001)
  - Key API: `bash derive-phase.sh <milestone-dir>` → prints state word (one of `pre-planning|discussing|planning|executing|summarizing|validating|completing|complete`).

## Constraints

- Bash 3.2 compatibility (MEM001).
- No `declare -A`, no `${var,,}`, no pipe-ampersand (`|&`).
- Must not `source` other scripts — invoke them as subprocesses (AD-19 / P07 invoke-not-source pattern).
- No inline compound bash in the output contract — each line is a single `echo`.
- Script must be self-contained: if resolve-root.sh fails, exit 2 with a clear stderr message, do not hang.

## Expected Output

After T02 completes:
- `scripts/orchestrator/status.sh` (~60 lines, executable)
- Running `bash scripts/orchestrator/status.sh --root .specify/orchestrator` on this repo prints at least:
  ```
  MILESTONE: M001
  STATE: complete
  PHASE: P01 complete
  ...
  MILESTONE: M003
  STATE: executing
  PHASE: P07 complete
  PHASE: P08 executing
  ```
