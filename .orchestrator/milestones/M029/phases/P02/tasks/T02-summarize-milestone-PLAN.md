---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M029"
name: "summarize-milestone.sh: read-only milestone summary helper (AD-4 oracle interface)"
depends_on: []
---

## Prerequisites

- `scripts/diagnostics/` exists and holds sibling read-only helpers (`metrics-rollup.sh`, `efficiency-footer.sh`, `render-status-json.sh`); verify `[ -d scripts/diagnostics ]`.
- No file currently lives at `scripts/diagnostics/summarize-milestone.sh` (path-collision rule 6 already checked at plan-authoring time — clean).
- `scripts/state/find-active-milestone.sh` exists and resolves the active milestone via the canonical state-derivation rules.
- `scripts/state/derive-phase.sh` exists and emits the current phase state.
- The milestone-directory tree convention is `.orchestrator/milestones/M###/{M###-ROADMAP.md, phases/P##/{P##-PLAN.md, P##-SUMMARY.md, tasks/T##-*-{PLAN,SUMMARY}.md}}`.
- `tools/verify/` exists; existing M029 P01 verifiers are the shape precedent.
- The M029 spec (`specs/037-roadmap-visibility-cli-ux/spec.md` SC-8) and context draft (`.orchestrator/milestones/M029/M029-CONTEXT.md` AD-4) define the SC-8 oracle interface; restated inline below.

## Description

T02 ships **`scripts/diagnostics/summarize-milestone.sh`**: a read-only deterministic milestone summary helper. Two consumers:

1. **`render-position.sh` (T03)** — emits one summary line per inactive milestone in the cross-milestone feature view (collapsed shape per #Q-5: `<glyph> M### <name>  ▓░ X% (k/n phases)`). The renderer calls `summarize-milestone.sh --milestone M### --format=keys` and reads the emitted `phase_count`, `phases_complete`, and `intensity` keys.

2. **AD-4 SC-8 oracle wrapper (P03)** — SC-8 was originally specified to use `bash scripts/dispatch/predictive-surface.sh --milestone <M###>` as the byte-identical oracle. The conversus-gate finding #Q-G2 surfaced that `predictive-surface.sh` does **not** ship a `--milestone` flag (M027 is closed; extending M027 would breach the knowledge-layer boundary in CON-3). AD-4 resolves this by introducing `summarize-milestone.sh` as M029's own helper that wraps the M027 surfaces it needs without modifying them; SC-8's oracle becomes `summarize-milestone.sh --milestone <M###>` invoked through P03's preflight glue.

Output contract (fixed-order key=value lines on stdout, mirrors the AD-1 resolver's three-line convention):

```
phase_count=<integer>
phases_complete=<integer>
tasks_remaining=<integer>
intensity=<quick|standard|full|unknown>
```

`intensity` is read from `.orchestrator/milestones/M###/M###-EVALUATION.md` (the `intensity:` field in YAML frontmatter); `unknown` is the fallback when EVALUATION is absent or malformed.

CLI surface:
- `--milestone <M###>` (required; if omitted, defaults to `find-active-milestone.sh` output).
- `--format=keys` (default; the four-line key=value block above).
- `--format=text` (one-line human-readable summary: `M029 Roadmap Visibility & CLI UX — 1/3 phases complete, 5 tasks remaining, intensity=full`).
- `--help` / `-h` prints usage to stdout, exit 0.

Read-only (CON-1 / FR-14 / Principle XV): no writes, no log emission, no state mutation. Mirrors `metrics-rollup.sh`'s sourceable+CLI dual-shape (MEM004 pure-lib pattern).

## Steps

1. **Create `scripts/diagnostics/summarize-milestone.sh`** (≥60 lines, executable, bash 3.2 compatible per MEM001). Required structure:

   ```bash
   #!/usr/bin/env bash
   # scripts/diagnostics/summarize-milestone.sh -- M029 / AD-4 milestone summary helper.
   #
   # Read-only deterministic helper that emits a fixed-order key=value block
   # describing a milestone's progress: phase_count, phases_complete,
   # tasks_remaining, intensity. Consumed by render-position.sh (T03) for the
   # cross-milestone feature view and by P03's SC-8 oracle wrapper.
   #
   # Read-only (CON-1 / FR-14): no writes, no log emission, no state mutation.
   # Bash 3.2 compatible (MEM001): no associative arrays, no process substitution,
   # no $() containing pipes inside the public surface.
   #
   # Sourceable as a library AND runnable as a CLI.

   set -u

   # Re-source guard.
   if [ -n "${_SUMMARIZE_MILESTONE_SH_SOURCED:-}" ]; then
       return 0 2>/dev/null || exit 0
   fi
   _SUMMARIZE_MILESTONE_SH_SOURCED=1

   _SM_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   _SM_PROJECT_ROOT="$(cd "$_SM_SCRIPT_DIR/../.." && pwd)"

   # --- Argument parser ---
   _sm_format="keys"
   _sm_milestone=""
   while [ $# -gt 0 ]; do
       case "$1" in
           --milestone) shift; _sm_milestone="$1"; shift ;;
           --milestone=*) _sm_milestone="${1#--milestone=}"; shift ;;
           --format) shift; _sm_format="$1"; shift ;;
           --format=*) _sm_format="${1#--format=}"; shift ;;
           -h|--help)
               # Print usage to stdout, exit 0.
               printf 'Usage: summarize-milestone.sh [--milestone <M###>] [--format keys|text]\n'
               printf '\n'
               printf 'Read-only milestone summary helper (M029 / AD-4 oracle interface).\n'
               printf '\n'
               printf 'Options:\n'
               printf '  --milestone <M###>   Milestone ID; defaults to find-active-milestone.sh.\n'
               printf '  --format keys|text   Output format; default keys.\n'
               printf '  -h, --help           Show this message.\n'
               exit 0
               ;;
           *) printf 'summarize-milestone.sh: unknown flag: %s\n' "$1" >&2; exit 2 ;;
       esac
   done
   ```

2. **Implement default-milestone resolution**:

   ```bash
   if [ -z "$_sm_milestone" ]; then
       _sm_milestone="$(bash "$_SM_PROJECT_ROOT/scripts/state/find-active-milestone.sh" 2>/dev/null || true)"
       _sm_milestone="${_sm_milestone%% *}"  # strip any trailing whitespace tokens
   fi
   if [ -z "$_sm_milestone" ]; then
       printf 'summarize-milestone.sh: no milestone specified and no active milestone resolved\n' >&2
       exit 2
   fi
   ```

3. **Implement phase enumeration** (count `P##/P##-PLAN.md` for total; count `P##/P##-SUMMARY.md` for complete). Use a simple `for` loop that does NOT trip AD-19 — the loop is INSIDE the script body, not on a Check: line:

   ```bash
   _sm_milestone_dir="$_SM_PROJECT_ROOT/.orchestrator/milestones/$_sm_milestone"
   _sm_phase_count=0
   _sm_phases_complete=0
   _sm_tasks_remaining=0

   if [ -d "$_sm_milestone_dir/phases" ]; then
       for _phase_dir in "$_sm_milestone_dir"/phases/P*; do
           [ -d "$_phase_dir" ] || continue
           _sm_phase_count=$(( _sm_phase_count + 1 ))
           _phase_id="$(basename "$_phase_dir")"
           if [ -f "$_phase_dir/$_phase_id-SUMMARY.md" ]; then
               _sm_phases_complete=$(( _sm_phases_complete + 1 ))
           else
               # Count remaining tasks in this in-flight phase.
               if [ -d "$_phase_dir/tasks" ]; then
                   for _task_plan in "$_phase_dir/tasks"/T*-PLAN.md; do
                       [ -f "$_task_plan" ] || continue
                       _task_summary="${_task_plan%-PLAN.md}-SUMMARY.md"
                       if [ ! -f "$_task_summary" ]; then
                           _sm_tasks_remaining=$(( _sm_tasks_remaining + 1 ))
                       fi
                   done
               fi
           fi
       done
   fi
   ```

4. **Implement intensity read** (from `M###-EVALUATION.md` YAML frontmatter):

   ```bash
   _sm_intensity="unknown"
   _sm_eval_file="$_sm_milestone_dir/$_sm_milestone-EVALUATION.md"
   if [ -f "$_sm_eval_file" ]; then
       # grep for `intensity:` in the YAML frontmatter; awk to strip the value.
       _line="$(grep -m1 -E '^intensity:' "$_sm_eval_file" 2>/dev/null || true)"
       if [ -n "$_line" ]; then
           # Strip "intensity:" prefix + whitespace + quotes; lowercase via tr.
           _sm_intensity="${_line#intensity:}"
           _sm_intensity="${_sm_intensity# }"
           _sm_intensity="${_sm_intensity#\"}"
           _sm_intensity="${_sm_intensity%\"}"
           _sm_intensity="$(printf '%s' "$_sm_intensity" | tr '[:upper:]' '[:lower:]')"
           case "$_sm_intensity" in
               quick|standard|full) ;;
               *) _sm_intensity="unknown" ;;
           esac
       fi
   fi
   ```

5. **Emit output** (fixed-order keys for `--format=keys`, single-line for `--format=text`):

   ```bash
   case "$_sm_format" in
       keys)
           printf 'phase_count=%d\n' "$_sm_phase_count"
           printf 'phases_complete=%d\n' "$_sm_phases_complete"
           printf 'tasks_remaining=%d\n' "$_sm_tasks_remaining"
           printf 'intensity=%s\n' "$_sm_intensity"
           ;;
       text)
           # Read milestone name from M###-ROADMAP.md or fall back to milestone ID.
           _sm_name="$_sm_milestone"
           _sm_roadmap="$_sm_milestone_dir/$_sm_milestone-ROADMAP.md"
           if [ -f "$_sm_roadmap" ]; then
               _line="$(grep -m1 -E '^# ' "$_sm_roadmap" 2>/dev/null || true)"
               if [ -n "$_line" ]; then
                   _sm_name="${_line#\# }"
               fi
           fi
           printf '%s — %d/%d phases complete, %d tasks remaining, intensity=%s\n' \
               "$_sm_name" "$_sm_phases_complete" "$_sm_phase_count" \
               "$_sm_tasks_remaining" "$_sm_intensity"
           ;;
       *)
           printf 'summarize-milestone.sh: unknown --format value: %s\n' "$_sm_format" >&2
           exit 2
           ;;
   esac

   exit 0
   ```

6. **`chmod +x scripts/diagnostics/summarize-milestone.sh`**.

7. **Author `tools/verify/m029-p02-summarize-milestone-shape.sh`** (≥35 lines, executable, AD-19 single-script-file shape). The verifier:
   - Asserts `[ -f scripts/diagnostics/summarize-milestone.sh ]`.
   - Asserts `[ -x scripts/diagnostics/summarize-milestone.sh ]`.
   - Asserts (via `grep -F`) the script declares the four output keys: `phase_count=`, `phases_complete=`, `tasks_remaining=`, `intensity=`.
   - Asserts the script declares the AD-4 reference (`AD-4` or `summarize-milestone` in a comment block).
   - Asserts the read-only contract token (`Read-only` or `CON-1` or `FR-14`) appears in the header comment.
   - Asserts the bash 3.2 token (`Bash 3.2` or `MEM001`) appears in the header comment.
   - Asserts the `--milestone` and `--format` flags are documented in the help text (grep for both literals in the script body).
   - Behavioral spot-check: invoke `bash scripts/diagnostics/summarize-milestone.sh --milestone M029 --format=keys` and assert the four expected keys appear in fixed order on stdout. Use a `tools/verify/lib/`-style helper script for the line-by-line check if needed, or capture stdout to a file via `> /tmp/sm-out.$$` then `grep -E '^phase_count=' /tmp/sm-out.$$` per AD-19 (no `$(…)` containing pipes).
   - Emits `PASS:` per assertion + final `SUMMARY: m029-p02-summarize-milestone-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.
   - Cleans up `/tmp/sm-out.$$` on exit.

8. **`chmod +x tools/verify/m029-p02-summarize-milestone-shape.sh`**.

## Must-Haves

This task addresses these P02 phase truths:
- `scripts/diagnostics/summarize-milestone.sh` exists, is executable, emits a fixed-order key=value block read-only against the active milestone, and accepts `--milestone <M###>` as the AD-4 SC-8 oracle interface.

This task creates these P02 phase artifacts:
- Milestone summary helper at `scripts/diagnostics/summarize-milestone.sh` — read-only AD-4 oracle interface for the cross-milestone view and P03 SC-8 wrapper.
- Helper shape verifier at `tools/verify/m029-p02-summarize-milestone-shape.sh` — mechanical enforcement of the output contract + read-only contract.

## Verification

```bash
bash tools/verify/m029-p02-summarize-milestone-shape.sh
```

## Inputs

### From Previous Tasks

None. T02 is independent of T01; both run before T03.

### From Disk (Pre-existing)

- `scripts/diagnostics/metrics-rollup.sh` — sourceable+CLI dual-shape precedent (MEM004 pure-lib pattern); T02 mirrors its `_*_SH_SOURCED` re-source guard, `_SCRIPT_DIR`/`_PROJECT_ROOT` resolution, and CLI argument parser shape.
- `scripts/diagnostics/efficiency-footer.sh` — read-only sibling helper; T02 mirrors its read-only header comment shape.
- `scripts/state/find-active-milestone.sh` — active-milestone resolver; T02 invokes via `bash <path>` (no `$(…)` pipe).
- `.orchestrator/milestones/M029/M029-EVALUATION.md` (if present) — `intensity:` source. If absent, T02 returns `intensity=unknown`.
- `.orchestrator/milestones/M029/M029-ROADMAP.md` — milestone name source for `--format=text`.
- `tools/verify/m029-p01-headline-shape-contract.sh` — verifier shape precedent (straight-line bash, `grep -F` per assertion, parallel indexed arrays).

## Constraints

- **Read-only (CON-1 / FR-14)**: no writes to `.orchestrator/`, no log emission, no state mutation. The only file system mutation in T02 is the verifier's `/tmp/sm-out.$$` capture (allowed under `run-probe.sh` scope rule 4 — `/tmp/` is the staged probe domain).
- **Bash 3.2 compatible (MEM001)**: no `declare -A`, no process substitution, no `<<<` herestring, no `$(…)` containing pipes (in the public surface; awk/sed/grep pipes are permitted INSIDE the script body per the metrics-rollup.sh MEM004 carve-out, but Check: lines must remain straight-line bash).
- **AD-19 verifier shape**: the gate verifier MUST be straight-line bash. NO inline compound chains, NO plain subshells, NO `$(cmd | grep …)`, NO process substitution.
- **Per CON-7 + AD-8**: T02 introduces NO new schema additions to M013 sidecar, M019 JSONL, M020 KNOWLEDGE.md, or M027 surfaces. The new `scripts/diagnostics/*.sh` and `tools/verify/*.sh` files are the only artifacts.
- **No M027 modification**: `summarize-milestone.sh` does NOT extend `predictive-surface.sh`, `metrics-rollup.sh`, or `efficiency-footer.sh`. Per AD-4, the wrapper lives in M029's surface; M027 stays closed.

## Expected Output

After T02 completes:
- `scripts/diagnostics/summarize-milestone.sh` exists, is executable (`-x`), and emits the four-line key=value block when invoked with `--milestone M029 --format=keys`.
- `tools/verify/m029-p02-summarize-milestone-shape.sh` exists, is executable, and exits 0 when run from project root.
- A summary file at `.orchestrator/milestones/M029/phases/P02/tasks/T02-summarize-milestone-SUMMARY.md` documents the deliverables.

## Notes

Expected verifier output: `PASS:` lines for each assertion (≈9–11 assertions), ending with `SUMMARY: m029-p02-summarize-milestone-shape.sh pass=N fail=0`. The phase-suite aggregator (T05) chains this verifier as gate 2.

Why the helper does NOT extend M027 surfaces (AD-4): M027 is closed and any extension would breach CON-3's knowledge-layer boundary (M029 explicitly does NOT introduce new metrics; consumes existing M027 surfaces read-only). The wrapper lives in `scripts/diagnostics/` next to its M027 siblings as a peer composition layer, not a modification.

Note for P03: SC-8's oracle interface (`bash scripts/dispatch/predictive-surface.sh --milestone <M###>`) is **amended** at AD-4 to wrap `summarize-milestone.sh` instead. The byte-identity assertion in SC-8 reads `summarize-milestone.sh` output, not `predictive-surface.sh`. P03's plan-phase will document the amendment record entry per #Q-G2 resolution.
