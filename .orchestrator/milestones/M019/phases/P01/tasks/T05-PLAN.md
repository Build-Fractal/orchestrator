---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P01"
milestone: "M019"
name: "Fixtures + per-gate verify scripts"
depends_on: ["T04"]
---

## Prerequisites

- T01–T04 complete: pricing lib, schema validator, all three emitters (`payload_breakdown`, `dispatch_usage`, `unit_close`) are live. T01's `m019-schema.sh` accepts `source` enum values `estimate | runtime | aggregate`.
- P00 fixture patterns exist at `tests/fixtures/` but no M019-specific fixtures yet.

## Description

Create the fixture tree and the five per-gate verify scripts (the sixth through ninth gates — bash32-compat, phase-suite, no-pre-p00-emission, fixture-rollup — are deferred to T06). This task ships:

- `tests/fixtures/m019-p01/pre-m019-execution-log.jsonl` — a pre-M019 log (no `record_type` field) so SC-10 additive-compat is testable.
- `tests/fixtures/m019-p01/post-m019-rollup-demo.jsonl` — ~10 records (a mix of `payload_breakdown`, `dispatch_usage`, `unit_close` at task/phase/milestone granularity) for the T06 fixture-rollup demo and for emitter-presence assertions.
- `tests/fixtures/m019-p01/fixture-milestone/` — minimal `M999` milestone directory the emitters can target end-to-end. Contains `M999-ROADMAP.md`, `phases/P01/P01-PLAN.md`, `phases/P01/tasks/T01-PLAN.md`, and an empty `execution-log.jsonl`.
- `scripts/verify/m019-p01-emitter-presence.sh` — fixture-driven: runs build-context → dispatch-interface → write-summary in sequence and asserts exactly one of each record_type appears.
- `scripts/verify/m019-p01-pricing-degradation.sh` — moves pricing.yml aside, runs a fixture dispatch, asserts `estimated_cost_usd: null` + `pricing_warning` fields, asserts exit 0.
- `scripts/verify/m019-p01-source-enum.sh` — feeds three synthetic records to m019-schema.sh: `estimate` accepted, `runtime` accepted, `fabricated` rejected.
- `scripts/verify/m019-p01-zero-token-growth.sh` — runs build-context.sh twice on the same inputs: once with emitter disabled (`ORCH_M019_EMIT=0` env flag), once with it enabled. Diffs the stdout bytes; FAIL if non-identical.
- `scripts/verify/m019-p01-additive-compat.sh` — replays `pre-m019-execution-log.jsonl` against `scripts/state/derive-phase.sh` and confirms current log consumers still function.

## Steps

1. **Create fixture tree** under `tests/fixtures/m019-p01/`:

   ```
   tests/fixtures/m019-p01/
     pre-m019-execution-log.jsonl
     post-m019-rollup-demo.jsonl
     fixture-milestone/
       M999-ROADMAP.md
       phases/P01/P01-PLAN.md
       phases/P01/tasks/T01-PLAN.md
       execution-log.jsonl    # starts empty
     bad-records/
       missing-cost-block.jsonl
       missing-quality-block.jsonl
       bad-source-enum.jsonl
       bad-granularity.jsonl
   ```

2. **Populate `pre-m019-execution-log.jsonl`** — copy a representative real execution-log slice (~5 records) from an existing M### milestone and strip any M019-era fields. Example line shape (pre-M019):

   ```
   {"unitId":"M001/P01/T01","attempt":1,"duration_s":120,"outcome":"success","verification_result":"pass","timestamp":"2026-04-14T10:00:00Z"}
   ```

   No `record_type`. No `source`. These must continue to validate against `m019-schema.sh` (additivity case).

3. **Populate `post-m019-rollup-demo.jsonl`** — ~10 records matching the M019 Tier 1 schema, with a mix:
   - 2× `payload_breakdown` (one task, one PHASE_PLAN)
   - 2× `dispatch_usage` (one with cost, one with `estimated_cost_usd: null` + `pricing_warning: "stale:124d"`)
   - 3× `unit_close` at `granularity: "task"` (two pass, one fail)
   - 1× `unit_close` at `granularity: "phase"` (source=aggregate)
   - 1× `unit_close` at `granularity: "milestone"` (source=aggregate)
   - 1× pre-M019 record (no `record_type`) for the additivity mix

4. **Populate `bad-records/*.jsonl`** — one record per file. Each is deliberately invalid:
   - `missing-cost-block.jsonl`: a `unit_close` without `estimated_cost_usd`.
   - `missing-quality-block.jsonl`: a `unit_close` without `verification_pass_rate`.
   - `bad-source-enum.jsonl`: a `dispatch_usage` with `source: "fabricated"`.
   - `bad-granularity.jsonl`: a `unit_close` with `granularity: "sprint"`.

   These are fed to `m019-schema.sh` by the source-enum + emitter-presence gates.

5. **Populate fixture-milestone** — minimal M999 with a single-phase / single-task plan sufficient for build-context + dispatch + write-summary to run against. The task plan is a stub (10–20 lines, valid frontmatter). The phase plan references the task. The roadmap declares P01.

6. **Write `scripts/verify/m019-p01-emitter-presence.sh`** (bash 3.2, single-script-file shape):

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m019-p01-emitter-presence.sh — M019/P01 emitter presence gate.
   #
   # Runs build-context + dispatch (stub adapter) + write-summary against the
   # M999 fixture milestone, then counts the three record_type values in the
   # fixture's execution-log.jsonl. Asserts:
   #   - exactly one payload_breakdown record for the dispatched task
   #   - exactly one dispatch_usage record for the dispatched task
   #   - exactly one unit_close record at granularity=task
   #   - every unit_close record carries both cost-block and quality-block keys
   #
   # Emits PASS: lines on success, FAIL: lines with line numbers on failure.
   # Exit 0 on all-pass, 1 otherwise.
   set -u
   REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
   FIXTURE="$REPO_ROOT/tests/fixtures/m019-p01/fixture-milestone"
   # ... reset the log, invoke the three emitters, grep-count the record_type
   #     values, invoke m019-schema.sh to enforce field presence, report.
   ```

   Implementation: reset `execution-log.jsonl` to empty; invoke `scripts/dispatch/build-context.sh "$FIXTURE/.." M999 P01 T01`; stub the dispatch adapter (point `--backend` at a `tests/fixtures/m019-p01/stub-adapter.sh` that echoes a minimal `dispatch-result.md`); then invoke `scripts/knowledge/write-summary.sh task - ...` against a throwaway path. Grep-count `"record_type":"payload_breakdown"`, etc.

7. **Write `scripts/verify/m019-p01-pricing-degradation.sh`**:

   ```bash
   #!/usr/bin/env bash
   # Renames .orchestrator/config/pricing.yml aside, runs a fixture dispatch,
   # asserts the emitted dispatch_usage record has `"estimated_cost_usd":null`
   # and a `"pricing_warning":` field, and dispatch exits 0. Restores pricing.yml
   # in a trap so test runs never leave the workspace in a degraded state.
   set -u
   ```

   Key detail: the restore MUST run even on failure. Use `trap 'mv "$BACKUP" "$ORIG" 2>/dev/null || true' EXIT INT TERM`.

8. **Write `scripts/verify/m019-p01-source-enum.sh`**:

   ```bash
   #!/usr/bin/env bash
   # Feeds bad-source-enum.jsonl to m019-schema.sh: must FAIL.
   # Feeds a record with source=estimate: must PASS.
   # Feeds a record with source=runtime: must PASS.
   # Feeds a record with source=aggregate (post-T04 extension): must PASS.
   set -u
   ```

9. **Write `scripts/verify/m019-p01-zero-token-growth.sh`**:

   ```bash
   #!/usr/bin/env bash
   # Builds the fixture payload twice: once with ORCH_M019_EMIT=0 (emitter
   # no-ops), once with ORCH_M019_EMIT=1 (emitter active). Diffs the stdout
   # bytes. FAIL if `diff` reports any difference.
   set -u
   ```

   Implementation hook: add an `ORCH_M019_EMIT=${ORCH_M019_EMIT:-1}` gate at the top of `_bc_emit_payload_breakdown` (T02) and `_di_emit_dispatch_usage` (T03): early-return when the env var is `0`. This is the test seam — production always runs with the default `1`.

10. **Write `scripts/verify/m019-p01-additive-compat.sh`**:

    ```bash
    #!/usr/bin/env bash
    # Copies pre-m019-execution-log.jsonl into a temp milestone dir, runs
    # scripts/state/derive-phase.sh on the dir, asserts exit 0 AND output is
    # one of the valid state words {pre-planning, planning, executing, verifying,
    # verified, blocked, paused, crashed, completed}.
    # Also runs m019-schema.sh against the pre-M019 fixture: must PASS because
    # records without record_type are accepted (SC-10 additivity).
    set -u
    ```

11. **Provide a stub dispatch adapter** at `tests/fixtures/m019-p01/stub-adapter.sh` that accepts `--task-plan --payload --intensity-metadata` and prints a minimal conforming `dispatch-result.md`:

    ```bash
    #!/usr/bin/env bash
    cat <<'EOF'
    ---
    schema_version: "1.0"
    type: "dispatch-result"
    outcome: "ok"
    ---
    # Stub dispatch result
    EOF
    ```

    Make executable. Register in `scripts/dispatch/adapters/backend/stub.sh` (copy) OR pass via `--backend stub` and drop the file at `scripts/dispatch/adapters/backend/stub.sh`. Simpler: drop at `scripts/dispatch/adapters/backend/stub.sh` — the dispatch-interface.sh filename router picks it up with zero new code.

## Must-Haves

- Every fixture file exists with the expected record count / shape.
- The five gate scripts exist, are executable (`chmod +x`), and each emits exactly one `PASS:` or `FAIL:` summary line on its own stdout.
- The stub adapter exists at `scripts/dispatch/adapters/backend/stub.sh` and is invoked from the presence + degradation gates by passing `--backend stub`.
- Running each gate against a post-T04 clean build produces `PASS:` with exit 0.
- Running the source-enum gate with a deliberately-bad fixture produces `FAIL:` with exit 1 — negative-case coverage.

## Verification

- `bash scripts/verify/m019-p01-emitter-presence.sh` — exit 0.
- `bash scripts/verify/m019-p01-pricing-degradation.sh` — exit 0, pricing.yml restored.
- `bash scripts/verify/m019-p01-source-enum.sh` — exit 0.
- `bash scripts/verify/m019-p01-zero-token-growth.sh` — exit 0.
- `bash scripts/verify/m019-p01-additive-compat.sh` — exit 0.
- `bash scripts/verify/m019-schema.sh tests/fixtures/m019-p01/bad-records/missing-cost-block.jsonl` — exit 1 (validator correctly rejects).

## Inputs

### From Previous Tasks

- `scripts/lib/pricing.sh` (from T01) — sourced indirectly by the emitters the gates exercise.
- `scripts/verify/m019-schema.sh` (from T01) — invoked by the source-enum + emitter-presence gates for field-presence enforcement.
- `scripts/dispatch/build-context.sh` (from T02) — target of the zero-token-growth diff; honors `ORCH_M019_EMIT=0` seam.
- `scripts/dispatch/dispatch-interface.sh` (from T03) — target of the pricing-degradation + emitter-presence gates; honors `ORCH_M019_EMIT=0` seam.
- `scripts/knowledge/write-summary.sh` (from T04) — target of the emitter-presence gate at `unit_close` granularity.

### From Disk (Pre-existing)

- `scripts/state/derive-phase.sh` — consumed by the additive-compat gate. Current behavior: exits 0 on any valid milestone dir, prints a single state word.
- `scripts/dispatch/adapters/backend/` — directory where the stub adapter drops. Filename-routed per MEM018 / FR-011.
- `.orchestrator/config/pricing.yml` — backed up/restored by the degradation gate.
- Existing `tests/fixtures/` patterns — mirror the shape (scenario-named subdir with minimal valid files).

## Constraints

- **Single-script-file Check shape (AD-19).** Every gate is a single `bash scripts/verify/m019-p01-<name>.sh` invocation. No inline compound bash in the phase-plan Check lines.
- **Trap-safe degradation test.** The pricing-degradation gate MUST restore `.orchestrator/config/pricing.yml` via `trap ... EXIT INT TERM` so a failed run does not leave the workspace in a degraded state.
- **Hermetic-first.** Every gate operates on its fixture tree, never on the live `.orchestrator/milestones/*` tree. Writes land under `tests/fixtures/m019-p01/fixture-milestone/execution-log.jsonl`.
- **Bash 3.2.** No `declare -A`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`.
- **MEM004 carve-out applies** — gates are verification-script-internal; pipes / `$()` / awk permitted.
- **No Tier 2/3 surface** — no new user-facing command, no `orchestrator:cost`, no rollup script (the fixture-rollup demo ships in T06 as a verification asset only).

## Expected Output

- Five new executable scripts under `scripts/verify/m019-p01-*.sh`.
- One stub adapter at `scripts/dispatch/adapters/backend/stub.sh`.
- Fixture tree under `tests/fixtures/m019-p01/` with two JSONL fixtures, one bad-records subdir (four invalid examples), one minimal M999 milestone tree.
- Each gate: exit 0 on green against the post-T04 code state.
- Running the gates against a deliberately regressed emitter (e.g., a temporary revert of T02) produces a clear `FAIL:` line and exit 1.
