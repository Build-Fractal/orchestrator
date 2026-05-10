---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P04"
milestone: "M033"
name: "FR-11 migrate-routing real implementation in scripts/lifecycle/start.sh (replaces P01 stub) + unsupported-tooling diagnostic"
depends_on: ["T03"]
---

## Prerequisites

T04 replaces P01's vacuous `migrate_routing_stub` in `scripts/lifecycle/start.sh` with the FR-11 real implementation. Depends on T03 (the migrate-then-ingest invocation in T04 relies on T03's dup-prevention sentinel handling).

Files that MUST exist on disk at task-start:

- `scripts/lifecycle/start.sh` (P01/T03; P02/T02 extension) — contains `migrate_routing_stub` at the slot replaced by T04; contains `DETECTED_FROM` global populated by `detect_branch` for migrating fixtures.
- `scripts/migrate/migrate.sh` ([M015](../../../../../milestones/M015/index.md) closed) — accepts `--path <project-dir> --source <gsd1|gsd2|speckit>` flags. T04 invokes this; does NOT modify it.
- `scripts/lifecycle/ingest-codebase.sh` (P03; T03-extended) — invoked post-migrate when `src/` present, dup-prevention sentinel handling shipped in T03.
- `scripts/util/jsonl-event-emitter.sh` (P02/T01) — emits `migrate_routed` event.
- `scripts/util/start-state-markers.sh` (P02/T02) — `migrate-routed` is in the closed 7-name sub-flow enum.
- `references/branch-detection.md` (P01/T02) — SSOT for the migrating-rule patterns.
- `tests/m033-acceptance/p01-start-branch-routing.sh` (P01/T05) — SC-1 acceptance; T04 MUST NOT regress this. If SC-1's assertions hard-code `would-execute: migrate-routing-stub`, T04 updates SC-1 to accept the post-replacement token shape (`migrate-routed: from=<kind>`).

## Description

T04 replaces P01's `migrate_routing_stub` function in `scripts/lifecycle/start.sh` with the real FR-11 implementation:

1. Detect the prior-tooling shape (P01/T03's `detect_branch` already populates `DETECTED_FROM` with `gsd-v1 | gsd-v2 | spec-kit` when the migrating branch fires).
2. Print the proposed `orchestrator:migrate --from <kind> --project-dir <fixture>` command line to stdout with the load-bearing token `migrate-routed: from=<kind>`.
3. Under `--yes` (or operator one-keystroke `Y` accept), invoke the migration via `bash scripts/migrate/migrate.sh --path <project-dir> --source <translated-kind>` — translating the spec-shape `gsd-v1|gsd-v2|spec-kit` into migrate.sh's implementation-shape `gsd1|gsd2|speckit`.
4. For unsupported tooling shapes (when `detect_branch` did NOT match any of the three SSOT migrating-rule patterns despite a prior-tooling sniff in the project — e.g., an `.aider/` directory exists), emit the US-6 AS-5 diagnostic `no orchestrator:migrate adapter for this tooling — please file a request` to stderr and exit 0 with the migrating branch refusing to silently fall through to greenfield-empty.
5. After successful migration, when `<project-dir>/src/` exists (FR-12 trigger), invoke `bash scripts/lifecycle/ingest-codebase.sh --project-dir <project-dir>` exactly once. Per T03's dup-prevention sentinel handling, this is safe.
6. Emit the `migrate_routed` JSONL event via P02's emitter with the resolved `--from` value in the payload.
7. Write the `migrate-routed` start-state marker via P02's start-state-markers.

The single deliverable is the modified `scripts/lifecycle/start.sh` plus its shape verifier.

## Steps

1. **Read the existing `scripts/lifecycle/start.sh`** to locate:
   - The `migrate_routing_stub` function (around line 111 in the P01-shipped file).
   - The `DETECTED_FROM` global variable (populated by `detect_branch` for migrating fixtures).
   - The flag-parsing block (so we can verify `--yes` / `YES` is in scope).
   - The branch-dispatch case in `main()` that calls `migrate_routing_stub`.

2. **Author a helper `translate_from_to_source <from-kind>`** (placed near the existing helpers, before the function being replaced):
   ```bash
   # ---------------------------------------------------------------------------
   # FR-11 spec-shape → impl-shape translation.
   # The operator-facing flag is `--from gsd-v1|gsd-v2|spec-kit` per spec.
   # The underlying scripts/migrate/migrate.sh accepts `--source gsd1|gsd2|speckit`.
   # The translation layer is the orchestrator-spec layer; migrate.sh internals
   # are M015-closed and not modified.
   # ---------------------------------------------------------------------------
   translate_from_to_source() {
       case "$1" in
           gsd-v1)   echo "gsd1" ;;
           gsd-v2)   echo "gsd2" ;;
           spec-kit) echo "speckit" ;;
           *)        echo "" ;;
       esac
   }
   ```

3. **Author a new function `migrate_routing`** that replaces `migrate_routing_stub`:
   ```bash
   # ---------------------------------------------------------------------------
   # FR-11 / FR-12 migrate-routing real implementation (M033/P04/T04).
   # Replaces P01's vacuous migrate_routing_stub.
   #
   # Behavior:
   #   - When DETECTED_FROM is one of (gsd-v1, gsd-v2, spec-kit), print the
   #     proposed orchestrator:migrate command line and (under YES=1 or
   #     operator one-keystroke 'Y') invoke scripts/migrate/migrate.sh with
   #     the translated --source flag.
   #   - When DETECTED_FROM is empty (migrating branch fired but no SSOT
   #     pattern matched — e.g., .aider/), emit the US-6 AS-5 diagnostic
   #     and exit 0 (no silent fall-through).
   #   - After successful migration, when <project-dir>/src/ exists,
   #     invoke scripts/lifecycle/ingest-codebase.sh once. T03 ships the
   #     dup-prevention sentinel handling that makes this safe.
   #   - Emit migrate_routed JSONL event + write migrate-routed start-state
   #     marker.
   # ---------------------------------------------------------------------------
   migrate_routing() {
       # Unsupported tooling: DETECTED_FROM empty despite migrating branch.
       if [ -z "${DETECTED_FROM:-}" ]; then
           printf 'no orchestrator:migrate adapter for this tooling — please file a request\n' 1>&2
           return 0
       fi

       local from_kind="$DETECTED_FROM"
       local source_kind
       source_kind="$(translate_from_to_source "$from_kind")"
       if [ -z "$source_kind" ]; then
           printf 'no orchestrator:migrate adapter for this tooling — please file a request\n' 1>&2
           return 0
       fi

       # Print the proposed operator-facing command line + load-bearing token.
       printf 'migrate-routed: from=%s\n' "$from_kind"
       printf 'proposed: orchestrator:migrate --from %s --project-dir %s\n' \
           "$from_kind" "$PROJECT_DIR"

       # One-keystroke accept under YES=1; otherwise read a single line.
       local accept=""
       if [ "${YES:-0}" = "1" ]; then
           accept="Y"
       else
           printf 'accept [Y/n]: '
           IFS= read -r accept || accept=""
       fi
       case "$accept" in
           ""|Y|y) ;;
           *)
               printf 'skipped — re-invoke with --yes or accept the prompt\n'
               return 0
               ;;
       esac

       # Invoke migrate.sh with the translated --source.
       bash scripts/migrate/migrate.sh --path "$PROJECT_DIR" --source "$source_kind"

       # FR-12 migrate-then-ingest: when src/ exists, invoke ingest-codebase.
       if [ -d "$PROJECT_DIR/src" ]; then
           bash scripts/lifecycle/ingest-codebase.sh --project-dir "$PROJECT_DIR"
       fi

       # Emit migrate_routed JSONL + write marker.
       PROJECT_DIR="$PROJECT_DIR" bash scripts/util/jsonl-event-emitter.sh emit migrate_routed "{\"from\":\"$from_kind\"}"
       bash scripts/util/start-state-markers.sh write migrate-routed "$PROJECT_DIR"

       return 0
   }
   ```

4. **Replace the call site** — wherever `main()` invokes `migrate_routing_stub`, change it to invoke `migrate_routing`. Keep `migrate_routing_stub` itself as a deprecated alias (or remove entirely) — the safer path per the additive-extension discipline is to KEEP `migrate_routing_stub` as a one-liner forwarding to `migrate_routing` so any other callers are not broken.
   ```bash
   # P01 stub kept as deprecated alias forwarding to the real implementation.
   migrate_routing_stub() {
       migrate_routing
   }
   ```

5. **Verify SC-1 cross-phase regression**: run `bash tests/m033-acceptance/p01-start-branch-routing.sh`. If it exits 0, no SC-1 changes needed. If it fails because the post-replacement `start.sh` no longer emits the `would-execute: migrate-routing-stub` token (SC-1's assertion was hard-coded against this literal), update SC-1 in lockstep:
   - Find the SC-1 assertion line that asserts the `would-execute: migrate-routing-stub` token for the migrating branch fixture.
   - Replace the assertion with one that accepts EITHER `would-execute: migrate-routing-stub` (legacy) OR `migrate-routed: from=` (post-T04). The simplest shape: assert that the migrating-branch fixture run produces stdout containing the substring `migrate-rout` (covers both `migrate-routed:` and `migrate-routing-stub`); for the load-bearing semantic, assert the `from=<kind>` substring is present.
   - Document the SC-1 update in T04's summary (the AD-15 cross-phase regression discipline made concrete).

6. **Author `tools/verify/m033-p04-migrate-routing-shape.sh`** — bash 3.2 verifier:
   - Asserts file `scripts/lifecycle/start.sh` exists.
   - Contains the new function name `migrate_routing` (without the `_stub` suffix).
   - Contains the helper name `translate_from_to_source`.
   - Contains the load-bearing tokens: `migrate-routed: from=`, `proposed: orchestrator:migrate --from`, `no orchestrator:migrate adapter for this tooling`, `migrate_routed`, `--source`, `gsd1`, `gsd2`, `speckit`, `gsd-v1`, `gsd-v2`, `spec-kit`, `scripts/migrate/migrate.sh`, `scripts/lifecycle/ingest-codebase.sh`, `start-state-markers.sh write migrate-routed`.
   - Negative grep: no `declare -A`, no process substitution `<(`, no `$(...)` containing pipes (visual scan: search for `$(.*|.*)`).
   - Min line count delta: assert `wc -l scripts/lifecycle/start.sh` reports ≥`<P02-extended-baseline>+60` lines (the verifier hard-codes a floor based on the post-T04 expected size; baseline 850 + 60 = 910 as a conservative floor — implementing agent verifies actual P02-baseline at task time and adjusts).
   - PASS/FAIL/SUMMARY.

## Must-Haves

- `scripts/lifecycle/start.sh` modified — `migrate_routing` function shipped with the FR-11/FR-12 contract; `translate_from_to_source` helper shipped; `migrate_routing_stub` kept as a deprecated alias forwarding to the real function.
- All four load-bearing tokens present in `start.sh`: `migrate-routed: from=`, `proposed: orchestrator:migrate --from`, `no orchestrator:migrate adapter for this tooling`, `migrate_routed`.
- The translation `gsd-v1` → `gsd1`, `gsd-v2` → `gsd2`, `spec-kit` → `speckit` is implemented in `translate_from_to_source`.
- SC-1 acceptance still passes (either unchanged or updated in lockstep per AD-15 cross-phase regression discipline).
- `tools/verify/m033-p04-migrate-routing-shape.sh` exists, executable, exits 0.

## Verification

```bash
bash tools/verify/m033-p04-migrate-routing-shape.sh
```

```bash
bash tests/m033-acceptance/p01-start-branch-routing.sh
```

```bash
bash scripts/diagnostics/check-plans.sh
```

## Inputs

### From Previous Tasks

- `scripts/lifecycle/start.sh` (from M033/P01/T03 + M033/P02/T02)
  - Key API: `main()` parses flags, runs `detect_branch` (populates `DETECTED_BRANCH` and — for migrating fixtures — `DETECTED_FROM`), invokes `init-project.sh` once, dispatches to per-branch sub-flow function. T04 replaces the migrating branch's dispatch target.
  - Key types: `DETECTED_FROM` is a global string set to `gsd-v1`, `gsd-v2`, `spec-kit`, or empty (migrating branch fired but no SSOT pattern matched). `YES` is `1` or `0`. `PROJECT_DIR` is the absolute project path.
  - Side-channel-tempfile-for-subshell-globals pattern (from D-T05-01 in P01/T05): T04's modifications run in `main()` directly (NOT a subshell), so no tempfile relay is needed. T04 reads `DETECTED_FROM` directly.
- `scripts/lifecycle/ingest-codebase.sh` (T03-extended)
  - Key API: `bash scripts/lifecycle/ingest-codebase.sh --project-dir <path>`. Per T03, dup-prevention sentinel handling is live; the migrate-then-ingest invocation is safe.
- `scripts/migrate/migrate.sh` (M015 closed)
  - Key API: `bash scripts/migrate/migrate.sh --path <project-dir> --source <gsd1|gsd2|speckit>`. Returns 0 on success, non-zero on failure. T04 propagates migrate.sh's exit code.

### From Disk (Pre-existing)

- `references/branch-detection.md` (from M033/P01/T02) — the SSOT for the three migrating-rule patterns. T04 does not modify it; relies on `detect_branch`'s population of `DETECTED_FROM`.
- `tests/m033-acceptance/p01-start-branch-routing.sh` (from M033/P01/T05) — the SC-1 acceptance. T04 may need to update this in lockstep.
- `references/m033-fr21-dual-write-convention.md` (from M033/P02/T05) — informational; T04 does not introduce a new dual-write fragment for migrate-routing in this task (FR-21 lists FR-3/FR-7/FR-9/FR-10/FR-13 as the dual-write callsites; FR-11 is not in the FR-21 closed list).

## Constraints

- **Additive-extension discipline**: T04's modifications to `start.sh` MUST preserve P01's behavior for the three non-migrating branches (greenfield-empty, greenfield-with-materials, existing-codebase). The cross-phase regression check is SC-1.
- **No M015 surface modifications**: `scripts/migrate/migrate.sh` is closed. T04 invokes it via the documented `--path / --source` flags; does NOT modify migrate.sh internals.
- **MEM001 (bash 3.2 compat)**: no `declare -A`; no process substitution; no `$(...)` containing pipes. The `translate_from_to_source` helper uses plain `case` and `echo`.
- **One-keystroke contract**: under `--yes` (YES=1), auto-accept; otherwise read one line of stdin via `IFS= read -r`. Match P02's `ask_one` one-keystroke convention without sourcing grilling-shell (migrate-routing is a single accept-or-skip prompt, not a recommendation-not-interrogation flow).
- **Path discipline**: only `scripts/lifecycle/start.sh` is modified; no writes to `scripts/migrate/`, `scripts/verify/`, or any P05 surface. The verifier writes to `tools/verify/m033-p04-*`.
- **Path-collision check**: `ls -la tools/verify/m033-p04-migrate-routing-shape.sh` MUST report no existing file before authoring.
- **AD-15 cross-phase regression**: SC-1 must still pass. If updating SC-1 to accept the new token shape, the change is documented as a P04/T04 lockstep amendment in T04's summary.

## Expected Output

After T04 completes:

- `scripts/lifecycle/start.sh` (modified, +60 lines net; new `translate_from_to_source` helper; new `migrate_routing` function; `migrate_routing_stub` kept as deprecated alias)
- `tests/m033-acceptance/p01-start-branch-routing.sh` (modified ONLY IF SC-1's assertions were hard-coded against the legacy `would-execute: migrate-routing-stub` token; otherwise unchanged)
- `tools/verify/m033-p04-migrate-routing-shape.sh` (new file, ≥30 lines, executable)
- The T04 verifier exits 0.
- `bash tests/m033-acceptance/p01-start-branch-routing.sh` exits 0 (SC-1 cross-phase regression preserved).

## Notes

- The translation layer is small but load-bearing: the operator types `--from gsd-v1`, the spec documents `--from gsd-v1`, but migrate.sh accepts `--source gsd1`. The dual surface is acceptable: spec-shape is the operator contract; impl-shape is internal. Both forms appear in start.sh as load-bearing tokens for the SC-6 acceptance to verify.
- T04 does NOT add an FR-21 dual-write Recent Changes fragment for migrate-routing — FR-21's closed callsite list per the spec covers FR-3 / FR-7 / FR-9 / FR-10 / FR-13 (constitution / ingest-codebase / materials-intake / ideation / customblock-draft). FR-11 (migrate-routing) is glue, not a content-authoring surface; the JSONL `migrate_routed` event provides the audit trail.
- The functional verification of the migrate-routing path against the three `--from` fixtures + the `.aider/` unsupported-tooling fixture lives in T05's SC-6 acceptance (`tests/m033-acceptance/p05-migrate-routing.sh`). T04's verifier is shape-only.
- The `migrate_routing_stub` deprecated alias is kept (rather than deleted) as a defensive measure: P01/T05's phase-suite verifier may reference the symbol; keeping the alias forwarding to the real implementation preserves backward compatibility without polluting the post-T04 behavior.
