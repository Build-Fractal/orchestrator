---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M033"
name: "scripts/util/start-state-markers.sh + start.sh resume-extension + SC-12 acceptance (FR-20 / CON-6)"
depends_on: []
---

## Prerequisites

- `scripts/util/` exists.
- `scripts/lifecycle/start.sh` exists and is the P01-shipped surface — verified by `[ -f scripts/lifecycle/start.sh ]`.
- `scripts/util/start-state-markers.sh` does NOT yet exist — verified by `[ ! -f scripts/util/start-state-markers.sh ]`.
- `tests/m033-acceptance/` exists.
- `tools/verify/` exists.
- Spec context: FR-20 codifies the `.orchestrator/start-state/<sub-flow-name>.complete` marker convention. CON-6 makes resume-on-partial-state required for milestone close. The closed sub-flow-name enum is `init-invoked, ideation, materials-intake, ingest-codebase, migrate-routed, constitution-authored, customblock-drafted` (7 names — matches the load-bearing events from FR-22's emit set, minus the wiki/github/friendly-tester pass-through events that are not sub-flows in the start-state sense).

## Description

T02 ships two coupled deliverables:

1. **`scripts/util/start-state-markers.sh`** — the marker-file primitives library exposing `write`, `read`, `next`, `clear` subcommands. This is a stdlib for FR-20: P03/P04/P05 sub-flow real-implementation tasks invoke `write <sub-flow-name> <project-dir>` at completion; `start.sh` invokes `read` and `next` to determine resume point.

2. **`scripts/lifecycle/start.sh` resume-extension** — additive extension preserving all P01 behavior. After init invocation but before sub-flow dispatch, start.sh queries `start-state-markers.sh read <project-dir>`; if the dispatched sub-flow's marker is already present, start.sh emits `start-state: resuming from <next sub-flow>` and skips that sub-flow. A `--no-resume` flag forces re-execution (escape valve). The diagnostic line is the load-bearing token SC-12 greps for.

The SC-12 acceptance script (`tests/m033-acceptance/p07-resume-on-partial-state.sh`) exercises the full read+resume path against synthetic markers.

**Bash 3.2 compatibility (MEM001):** No `declare -A`, no process substitution. The marker-file enumeration uses `find` or `ls` with conservative globbing.

**Idempotent writes:** Re-writing an existing marker MUST be a no-op (touch the file, preserve content). The marker file content is the ISO 8601 UTC timestamp of the FIRST write; subsequent writes preserve it. This is the on-disk truth (MEM003: state derived from file presence) plus a recovery aid (timestamp tells the operator when each sub-flow completed).

**P01 sub-flow stubs do NOT yet write markers.** The marker-write happens in P03/P04/P05 when sub-flow real implementations land. P02's start.sh extension is the **read-side** of the marker contract, ensuring the framing is in place when the write-side lands. This is documented in T02's verifier: the verifier checks that start.sh queries the markers, NOT that the stubs write them.

## Steps

1. **Author `scripts/util/start-state-markers.sh`** (≥80 lines, executable, `chmod +x`, bash 3.2 compatible).

   1a. **Header.** Hashbang, `set -e -u -o pipefail`, brief comment block naming the script (FR-20 / CON-6), the spec reference, the sub-flow-execution-order documented in the closed enum.

   1b. **Closed enum block.** A fenced `# >>> subflow-names >>>` ... `# <<< subflow-names <<<` block (SSOT) listing all 7 sub-flow names in execution order: `init-invoked`, `ideation`, `materials-intake`, `ingest-codebase`, `migrate-routed`, `constitution-authored`, `customblock-drafted`. The verifier greps this block.

   1c. **`write` subcommand:**

   ```bash
   write_marker() {
     local subflow="$1"
     local project_dir="$2"
     # Validate subflow against closed enum
     case "$subflow" in
       init-invoked|ideation|materials-intake|ingest-codebase|migrate-routed|constitution-authored|customblock-drafted) ;;
       *) echo "unknown sub-flow name: $subflow" >&2
          echo "valid: init-invoked ideation materials-intake ingest-codebase migrate-routed constitution-authored customblock-drafted" >&2
          return 2 ;;
     esac
     local marker_dir="$project_dir/.orchestrator/start-state"
     local marker_path="$marker_dir/$subflow.complete"
     mkdir -p "$marker_dir"
     # Idempotent: only write if absent
     if [ ! -f "$marker_path" ]; then
       date -u +%Y-%m-%dT%H:%M:%SZ > "$marker_path"
     fi
     return 0
   }
   ```

   1d. **`read` subcommand:** lists all completed sub-flow names, one per line, sorted by completion-order (using `find -newer` is fragile under bash 3.2; instead, list files and sort by mtime via `ls -t`, mapping back to sub-flow names). Simplest implementation: enumerate the closed enum in execution order; for each, check if the marker exists; print only the present ones.

   ```bash
   read_markers() {
     local project_dir="$1"
     local marker_dir="$project_dir/.orchestrator/start-state"
     local subflow
     for subflow in init-invoked ideation materials-intake ingest-codebase migrate-routed constitution-authored customblock-drafted; do
       if [ -f "$marker_dir/$subflow.complete" ]; then
         echo "$subflow"
       fi
     done
   }
   ```

   1e. **`next` subcommand:** prints the first sub-flow in execution-order whose marker is absent; empty string if all are present.

   ```bash
   next_marker() {
     local project_dir="$1"
     local marker_dir="$project_dir/.orchestrator/start-state"
     local subflow
     for subflow in init-invoked ideation materials-intake ingest-codebase migrate-routed constitution-authored customblock-drafted; do
       if [ ! -f "$marker_dir/$subflow.complete" ]; then
         echo "$subflow"
         return 0
       fi
     done
     # All complete
     echo ""
     return 0
   }
   ```

   1f. **`clear` subcommand:** removes a single named marker; used by tests to reset state. Validates the name against the closed enum.

   1g. **Top-level dispatcher:** `case "${1:-}" in write|read|next|clear) ...; *) usage; exit 2 ;; esac`.

2. **Extend `scripts/lifecycle/start.sh`** (additive — preserves all P01 behavior; ≥250 lines after extension).

   2a. **Add `--no-resume` flag** to the existing flag-parsing block. Boolean default `false`. Documented in usage line.

   2b. **After init invocation, before sub-flow dispatch:** insert a resume-detection block:

   ```bash
   # FR-20 / CON-6 resume-on-partial-state
   if [ "${NO_RESUME:-0}" -eq 0 ]; then
     completed_subflows="$(bash scripts/util/start-state-markers.sh read "$PROJECT_DIR")"
     # Determine the sub-flow this branch would dispatch
     case "$BRANCH" in
       greenfield-empty)         this_subflow="ideation" ;;
       greenfield-with-materials) this_subflow="materials-intake" ;;
       existing-codebase)        this_subflow="ingest-codebase" ;;
       migrating)                this_subflow="migrate-routed" ;;
       *) this_subflow="" ;;
     esac
     if [ -n "$this_subflow" ]; then
       # Check if this branch's sub-flow is already complete
       if echo "$completed_subflows" | grep -qx "$this_subflow"; then
         next_subflow="$(bash scripts/util/start-state-markers.sh next "$PROJECT_DIR")"
         printf 'start-state: resuming from %s\n' "$next_subflow"
         # Skip the sub-flow dispatch for this run; future P03/P04/P05
         # implementations will hand off to the next_subflow at this point.
         exit 0
       fi
     fi
   fi
   ```

   The block is gated by `NO_RESUME=0` (default — resume enabled); `--no-resume` sets `NO_RESUME=1`. The existing branch-detection-and-stub-dispatch logic from P01 is preserved verbatim below this block; if no marker is present, control falls through to it as in P01 baseline.

   2c. **Update usage line** to include `[--no-resume]`.

3. **Author `tests/m033-acceptance/p07-resume-on-partial-state.sh`** (≥80 lines, executable, exits 0 → SC-12).

   3a. **Setup.** `mktemp -d` for a staging project; `cd` into it (or use `--project-dir <staging>`). Trap EXIT for cleanup.

   3b. **Pre-condition:** invoke `bash scripts/util/start-state-markers.sh write init-invoked <staging>` and `bash scripts/util/start-state-markers.sh write ideation <staging>` — establishes two completed sub-flow markers.

   3c. **Marker enumeration assertion:** invoke `bash scripts/util/start-state-markers.sh read <staging>` and assert output is exactly two lines: `init-invoked` then `ideation`.

   3d. **Next-marker assertion:** invoke `bash scripts/util/start-state-markers.sh next <staging>` and assert output is `materials-intake` (next in documented execution order after `ideation`).

   3e. **Resume diagnostic assertion:** create a fixture that detects as `greenfield-with-materials` (drop 3 PBJ-shape `.md` files into `<staging>`); set `<staging>/.orchestrator/config.yml` to skip init re-invocation; invoke `bash scripts/lifecycle/start.sh --project-dir <staging> --yes` and assert `start-state: resuming from materials-intake` appears in stdout. Wait — `materials-intake` IS what this branch would dispatch. Adjust: write the `materials-intake.complete` marker BEFORE invoking; assert the resume diagnostic AND that `would-execute: materials-intake-stub` does NOT appear (sub-flow skipped).

   Actually, per the resume-detection block in step 2b: the resume fires when THIS BRANCH'S sub-flow is already complete. So the test scenario:
   - Drop PBJ-shape `.md` files (triggers `greenfield-with-materials` branch → dispatches `materials-intake-stub`).
   - Pre-write `materials-intake.complete` marker.
   - Run `start --yes`.
   - Assert: `start-state: resuming from <next>` appears (where `<next>` is `ingest-codebase` per execution order).
   - Assert: `would-execute: materials-intake-stub` does NOT appear (skip happened).

   3f. **`--no-resume` escape-valve assertion:** with the same `materials-intake.complete` marker in place, invoke `bash scripts/lifecycle/start.sh --project-dir <staging> --yes --no-resume` and assert `start-state: resuming from` does NOT appear AND `would-execute: materials-intake-stub` DOES appear (full P01 baseline behavior restored).

   3g. **Default no-marker assertion:** clear all markers via `clear`; re-run `start --yes` and assert `start-state: resuming from` does NOT appear (no markers, no resume) AND `would-execute: materials-intake-stub` appears (P01 baseline).

   3h. **Cleanup mandatory.** `rm -rf "$staging"` in the EXIT trap.

4. **Author `tools/verify/m033-p02-start-state-markers-shape.sh`** (≥30 lines, executable). Asserts:
   - `scripts/util/start-state-markers.sh` exists and is executable.
   - The four subcommand tokens appear: `write`, `read`, `next`, `clear`.
   - The closed-enum SSOT block markers `# >>> subflow-names >>>` and `# <<< subflow-names <<<` appear.
   - All 7 sub-flow names appear: `init-invoked`, `ideation`, `materials-intake`, `ingest-codebase`, `migrate-routed`, `constitution-authored`, `customblock-drafted`.
   - The marker path pattern `.orchestrator/start-state` appears.
   - The `.complete` suffix appears.
   - **Functional smoke test:** create `mktemp -d` staging; invoke `write ideation <staging>`; assert `<staging>/.orchestrator/start-state/ideation.complete` exists. Invoke `read <staging>` and assert output is `ideation`. Invoke `next <staging>` and assert output is `materials-intake`. Invoke `clear ideation <staging>` and assert the marker file is removed. Clean up.
   - **Negative path:** invoke `write unknown-flow <staging>` and assert non-zero exit + closed enum echoed to stderr.
   - Emits PASS/SUMMARY lines per MEM001.

5. **Author `tools/verify/m033-p02-start-sh-resume-extension.sh`** (≥30 lines, executable). Asserts:
   - `scripts/lifecycle/start.sh` exists and is executable (P01 surface preserved).
   - The `--no-resume` flag token appears.
   - The literal `start-state:` token appears.
   - The literal `resuming from` token appears.
   - The cross-reference to `start-state-markers.sh` appears.
   - The branch-to-sub-flow case mapping appears (token check: at least one of `greenfield-with-materials)` or `materials-intake` appears in proximity to a `case`/`esac` construct).
   - **P01-preservation gate:** the P01 verifier `tools/verify/m033-p01-start-md-shape.sh` is invoked as a sub-step and MUST exit 0 (asserts the start.sh changes are additive, not destructive of P01 contracts). This is the AD-15 cross-phase regression precedent (per M036a).
   - Emits PASS/SUMMARY lines.

6. **Author `tools/verify/m033-p02-acceptance-shape-sc12.sh`** (≥25 lines, executable). Asserts:
   - `tests/m033-acceptance/p07-resume-on-partial-state.sh` exists, is executable.
   - The literal SC-12 + FR-20 tokens appear.
   - The `start-state-markers.sh` cross-reference appears.
   - The `resuming from` and `--no-resume` tokens appear.
   - Emits PASS/SUMMARY lines.

## Must-Haves

This task addresses these P02 phase truths:
- `scripts/util/start-state-markers.sh` exists with `write`, `read`, `next`, `clear` subcommands and the 7-name closed enum.
- `scripts/lifecycle/start.sh` is extended (additive) with `--no-resume` and the `start-state: resuming from` diagnostic.

This task creates these P02 phase artifacts:
- Library: `scripts/util/start-state-markers.sh` (FR-20 marker primitives).
- Driver extension: `scripts/lifecycle/start.sh` (resume-on-partial-state read of markers; `--no-resume` escape valve).
- Acceptance script: `tests/m033-acceptance/p07-resume-on-partial-state.sh` (SC-12).
- Verifiers: `tools/verify/m033-p02-start-state-markers-shape.sh`, `tools/verify/m033-p02-start-sh-resume-extension.sh`, `tools/verify/m033-p02-acceptance-shape-sc12.sh`.

## Verification

```bash
bash tools/verify/m033-p02-start-state-markers-shape.sh
```

```bash
bash tools/verify/m033-p02-start-sh-resume-extension.sh
```

```bash
bash tools/verify/m033-p02-acceptance-shape-sc12.sh
```

```bash
bash tests/m033-acceptance/p07-resume-on-partial-state.sh
```

## Inputs

### From Previous Tasks

None. T02 has no intra-phase prerequisites; it can run in parallel with T01 and T03.

### From Disk (Pre-existing)

- `scripts/lifecycle/start.sh` (P01 — T03 task) — additively extended by T02. T02 MUST preserve all P01 behavior (verified by re-running the P01 verifier as a sub-step in T02's resume-extension verifier).
- `scripts/util/` — directory exists.

## Constraints

- Bash 3.2 compatibility (MEM001) — no `declare -A`, no process substitution, no `$(...)` containing pipes.
- The 7 sub-flow names are a **closed enum**; unknown names exit non-zero with the enum echoed.
- The `.complete` marker filename suffix is load-bearing; do NOT abbreviate to `.done` or other variant. Downstream `run-doctor.sh` (per the spec's Downstream Consumers) will consume `.complete` as the literal token.
- Marker-write idempotency: re-write of an existing marker is a no-op (preserves first-completion timestamp).
- The start.sh extension MUST be additive — verified by re-running the P01 verifier in T02's resume-extension verifier.
- The `start-state: resuming from <next sub-flow>` diagnostic is load-bearing for SC-12; the literal substring must appear verbatim.
- T02 MUST NOT touch `scripts/lifecycle/grilling-shell.sh` (T03 deliverable), `scripts/util/jsonl-event-emitter.sh` (T01 deliverable), or any P03/P04/P05 surface.
- Verifier scripts use single-script-file shape per AD-19.

## Expected Output

After T02 completes:
- `scripts/util/start-state-markers.sh` exists, is executable.
- `scripts/lifecycle/start.sh` is extended (additive).
- `tests/m033-acceptance/p07-resume-on-partial-state.sh` exists, is executable, exits 0.
- All three new T02 verifiers exist, are executable, exit 0.
- A summary file at [`.orchestrator/milestones/M033/phases/P02/tasks/T02-start-state-markers-and-resume-SUMMARY.md`](../../../../../milestones/M033/phases/P02/tasks/T02-start-state-markers-and-resume-SUMMARY.md) documents the deliverables.

## Notes

The P01 sub-flow stubs do NOT yet write markers — that is P03/P04/P05 territory (each sub-flow real implementation calls `bash scripts/util/start-state-markers.sh write <its-name> <project-dir>` at completion). T02 ships the read-side of the contract so the framing is in place when the write-side lands.

The `init-invoked` marker is a special case: P01's start.sh already invokes init exactly once and skips on re-invocation. P02 can OPTIONALLY add a `start-state-markers.sh write init-invoked <project-dir>` call after init successfully runs (post-extension), but the existing `init already complete` diagnostic + `.orchestrator/config.yml` presence already serves the same idempotency semantics. Adding the marker write is a small ergonomic improvement (gives `read` the symmetric view) but NOT a hard requirement for SC-12 — the test directly writes `init-invoked.complete` via the primitive. **Recommendation:** include the `init-invoked` marker write in start.sh as part of T02 for symmetry, but only after the existing init-invocation block (additive, preserves P01 idempotency).

The resume-detection block in start.sh exits 0 after the `start-state: resuming from <next>` diagnostic. P03/P04/P05 will eventually replace this `exit 0` with real next-sub-flow dispatch logic; for P02, exit-0-after-diagnostic is the correct framing (P02 has no real sub-flows to dispatch yet — the stubs are vacuous per P01).
