---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M031"
name: "Tier A+ router (FR-7) + JSONL unit_close schema additions + SC-6 end-to-end flow test"
depends_on: ["T03"]
---

## Prerequisites

- T01 complete: classifier emits `tier_a_plus` (verified via SC-5 test).
- T02 complete: `scripts/intake/lib/task-slug.sh` + three role templates on disk.
- T03 complete: `scripts/intake/lib/tier-a-plus-prompt.sh` + SC-16 test on disk.
- Active dispatch surface for the orchestrator is the existing `commands/dispatch.md` flow (one-shot, single-context dispatch; the agent runtime is the adapter per MEM018). T04's router does NOT replace dispatch; it sequences three calls into the existing dispatch surface.
- `scripts/intake/route-to-dispatch.sh` (54 lines pre-T04) currently handles a single `orchestrator:dispatch` invocation derived from a proposal frontmatter. T04 extends this surface — it does NOT replace the existing single-dispatch path.

## Description

T04 amends `scripts/intake/route-to-dispatch.sh` to recognize a `tier_a_plus` verdict and chain exactly three sequential dispatches in this order:

1. **research dispatch** — invoked with `templates/dispatch-role-research.md` as the role payload, `--profile=quick` per the P01 reconciled `commands/dispatch.md`. Output: `.orchestrator/tier-a-plus/<task-slug>/research.md`. Emits one JSONL `unit_close` record with `tier_a_plus_role: research` and `aborted: false` on success (or `aborted: true` if the dispatch itself fails).
2. **operator prompt gate** — `bash scripts/intake/lib/tier-a-plus-prompt.sh --research-path <path> --task-slug <slug> [--yes] [--session-id <id>]` (T03 helper). Exit codes: 0 = proceed, 1 = re-run research (router exits non-zero, no plan/build dispatch), 2 = abort flow (router exits non-zero, no plan/build dispatch).
3. **plan dispatch** (only if prompt exit 0) — invoked with `templates/dispatch-role-plan.md` as the role payload, `--profile=quick`. Output: `.orchestrator/tier-a-plus/<task-slug>/plan.md`. Emits one `unit_close` record with `tier_a_plus_role: plan`.
4. **build dispatch** (only if plan dispatch succeeded) — invoked with `templates/dispatch-role-build.md` as the role payload, `--profile=quick`. The build agent reads `<task-slug>/plan.md`, executes the steps, and runs the plan's `## Verification` commands inline. Build dispatch exits non-zero on any verifier failure (no implicit retry per spec edge case). Emits one `unit_close` record with `tier_a_plus_role: build` and `aborted: <true|false>` reflecting verifier-pass result.

The router MUST honor every CON-4 / DC-4 / Principle XIV invariant:
- MUST NOT invoke `orchestrator:auto`, `orchestrator:roadmap`, or `orchestrator:consolidate`.
- MUST NOT acquire any auto-loop lock file under any path.
- MUST NOT write any `.orchestrator/milestones/M###/` scaffolding.
- MUST NOT introduce a new state machine, lock file, or roadmap surface.
- MAY write the per-flow scratch directory `.orchestrator/tier-a-plus/<task-slug>/` (research.md, plan.md, .session-id sidecar). This is NOT a state-machine surface — it's an output directory consistent with `.orchestrator/observability/` from P01.

T04 ships:

1. The amended `scripts/intake/route-to-dispatch.sh`.
2. JSONL `unit_close` schema additions: two new optional fields `tier_a_plus_role` (enum `research|plan|build`) and `aborted` (boolean). Existing records without these fields stay valid (additive schema per the M031 cross-cutting invariant).
3. `tests/m031-acceptance/test-tier-a-plus-flow.sh` — SC-6 end-to-end test.
4. `tools/verify/m031-p02-router-shape.sh` — shape verifier for the router.
5. `tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh` — shape verifier for the SC-6 test.

## Steps

1. **Read the existing `scripts/intake/route-to-dispatch.sh`** (54 lines pre-T04). Identify (a) the proposal-frontmatter parsing, (b) the `recommended_command` switch, (c) the single-dispatch invocation shape `invoke=orchestrator:dispatch --proposal $PROPOSAL`.

2. **Extend the router CLI surface.** Add a new invocation mode that accepts a `--verdict tier_a_plus --task <description>` flag pair (the dispatched-by-classifier flow) AND a `--role <research|plan|build>` flag for sub-dispatch entry points. The existing single-dispatch path (proposal-frontmatter → recommended_command) MUST keep working byte-equal — the Tier A+ chain is a NEW branch in the existing switch, not a rewrite.

3. **Implement the Tier A+ chain.** Concrete sequence the router executes:
   - Source `scripts/intake/lib/task-slug.sh`. Compute `<task-slug>` via `derive_task_slug "$task_description"`.
   - Create `.orchestrator/tier-a-plus/<task-slug>/` (mkdir -p) if absent.
   - Write `.orchestrator/tier-a-plus/<task-slug>/.session-id` with the current session-id (a generated unique ID; e.g., `date -u +%Y%m%dT%H%M%S` plus a 4-character random hex). The T03 prompt helper reads this sidecar to derive the resume-vs-rerun marker.
   - **Research dispatch**. Invoke the dispatch surface with the research role payload + `--profile=quick`. Concrete shape (the `dispatch_one_role` helper internal to the router):
     - Build a research-role task plan from `templates/dispatch-role-research.md` plus the operator's task description.
     - Invoke `bash scripts/dispatch/build-context.sh --profile=quick --task-plan <tmp-plan> --out <payload> --meta-out <meta-sidecar>`.
     - Hand the resulting payload to the agent runtime per the existing single-dispatch convention (the agent IS the adapter per MEM018).
     - On dispatch success, the agent writes `<task-slug>/research.md`. On dispatch failure, the router emits a `unit_close` JSONL record with `tier_a_plus_role: research`, `aborted: true` and exits non-zero.
   - **Prompt gate**. Invoke `bash scripts/intake/lib/tier-a-plus-prompt.sh --research-path .orchestrator/tier-a-plus/<task-slug>/research.md --task-slug <task-slug> [--yes] --session-id <id>`. Read exit code:
     - 0 → proceed to plan dispatch.
     - 1 or 2 → emit `unit_close` for the research dispatch with `aborted: false`, no further records, router exits non-zero.
   - **Plan dispatch** (only if prompt exit 0). Same shape as research dispatch but with `dispatch-role-plan.md`. Plan agent reads upstream `<task-slug>/research.md` (the role template declares this in its `## Inputs` block) and writes `<task-slug>/plan.md`. Emits `unit_close` with `tier_a_plus_role: plan`, `aborted: false` on success.
   - **Build dispatch** (only if plan dispatch succeeded). Same shape with `dispatch-role-build.md`. Build agent reads `<task-slug>/plan.md`, executes its steps, runs its `## Verification` commands inline. On any verifier failure the build dispatch exits non-zero and emits `unit_close` with `tier_a_plus_role: build`, `aborted: true`. On full success emits `unit_close` with `aborted: false`.

4. **JSONL `unit_close` schema additions.** The two new optional fields ride on every Tier A+ `unit_close` record:
   - `tier_a_plus_role` — string enum: `research` | `plan` | `build`. Absent on non-Tier-A+ records.
   - `aborted` — boolean. Defaults to `false` on success paths; `true` on cancel/abort/verifier-failure paths. May appear on non-Tier-A+ records too (advisory; future milestones may consume).

   Use the existing JSONL emitter in the router/dispatch surface; do not introduce a new emitter. Bash 3.2 string concatenation is sufficient — quote-escape the role/aborted values per existing conventions.

5. **Author `tests/m031-acceptance/test-tier-a-plus-flow.sh`** (executable, bash 3.2). SC-6 contract:
   - Set up a temp scratch dir for `.orchestrator/tier-a-plus/<test-slug>/` (under `.orchestrator/observability/` prefix-equivalent or under `tmp/` per AP-009 / `run-probe.sh` discipline; the SC-6 test does not need to exercise the real `.orchestrator/` tree).
   - Invoke `bash scripts/intake/route-to-dispatch.sh --verdict tier_a_plus --task "<fixture-task-description>" --yes` (with `--yes` to skip the interactive prompt) against a stub dispatch surface. The stub MAY be a fake `build-context.sh` that emits canned payloads (the SC-6 test does not need to exercise real LLM dispatch — it needs to verify the router's shape).
   - Assert exactly 3 `unit_close` JSONL records appear with `tier_a_plus_role: research`, `tier_a_plus_role: plan`, `tier_a_plus_role: build` (one each).
   - Assert `<task-slug>/research.md` exists.
   - Assert `<task-slug>/plan.md` exists.
   - Assert ZERO files are created under any path matching `.orchestrator/milestones/M*/`.
   - Assert ZERO files are created matching the literal substring `lock` anywhere outside the test scratch tree.
   - Under `--yes` mode: assert ZERO interactive prompt was emitted (no characters consumed from stdin) and exactly one `research: <path>` line on stderr.
   - Output: `RESULT: SC-6 pass` / `RESULT: SC-6 fail`. Exit 0 iff pass.

6. **Author `tools/verify/m031-p02-router-shape.sh`** (executable, bash 3.2). Contract:
   - Assert `scripts/intake/route-to-dispatch.sh` exists, executable, ≥ 100 lines (the pre-T04 baseline + the new chain logic).
   - Assert the file contains the literal substrings `tier_a_plus`, `tier_a_plus_role`, `aborted`, `research`, `plan`, `build`, `--profile=quick`, `task-slug.sh`, `tier-a-plus-prompt.sh`.
   - Assert the file does NOT contain the literal substrings `orchestrator:auto`, `orchestrator:roadmap`, or `orchestrator:consolidate` (CON-4 grep — the router MUST NOT invoke any of those three commands).
   - Assert the file does NOT introduce any `mkdir -p .orchestrator/milestones/` line (no milestone scaffolding write).
   - Assert the file does NOT introduce any `lock` file write under `.orchestrator/auto/`.
   - Output: a single final stdout line `SUMMARY: m031-p02-router-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

7. **Author `tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh`** (executable, bash 3.2). Contract:
   - Assert `tests/m031-acceptance/test-tier-a-plus-flow.sh` exists, executable, ≥ 60 lines.
   - Assert the file contains the literal substrings `SC-6`, `tier_a_plus_role`, `research`, `plan`, `build`, `aborted`, `--yes`.
   - Output: a single final stdout line `SUMMARY: m031-p02-test-tier-a-plus-flow-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

8. **Run the two new shape verifiers + the SC-6 acceptance test** to confirm exit 0:

   ```bash
   bash tools/verify/m031-p02-router-shape.sh
   ```

   ```bash
   bash tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh
   ```

   ```bash
   bash tests/m031-acceptance/test-tier-a-plus-flow.sh
   ```

9. **Confirm the existing single-dispatch path unchanged.** Sanity-check by invoking the router with the pre-T04 invocation form (`bash scripts/intake/route-to-dispatch.sh --proposal <fixture-proposal>`) and confirming the `invoke=orchestrator:dispatch --proposal <path>` stdout line still emits byte-equal.

## Must-Haves

This task addresses the following Must-Haves from `P02-PLAN.md`:
- "scripts/intake/route-to-dispatch.sh recognizes tier_a_plus verdict and chains three sequential dispatches" (Truth #7; Check via `m031-p02-router-shape.sh`)
- "tests/m031-acceptance/test-tier-a-plus-flow.sh (SC-6) exists, executable, exits 0" (Truth #9; Check via `m031-p02-test-tier-a-plus-flow-shape.sh`)

## Verification

```bash
bash tools/verify/m031-p02-router-shape.sh
```

```bash
bash tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh
```

```bash
bash tests/m031-acceptance/test-tier-a-plus-flow.sh
```

## Notes

- The router stub-vs-real-dispatch question: SC-6 verifies router *shape* (three records, two markdown outputs, no scaffolding, no locks, no prompts under `--yes`). It does NOT need to exercise real LLM dispatch — a stub `build-context.sh` writing canned payloads to the configured `--out` and `--meta-out` paths suffices. Future P04 acceptance-battery aggregator runs the SC-6 test under the same stub regime.
- JSONL `unit_close` records emit through whatever path the existing dispatch surface already uses (per the single-dispatch baseline). T04 does NOT introduce a new emitter — the two new fields ride on existing records.
- The `--yes` flag flows from the router's CLI through to the prompt helper. Under `--yes` the router MUST NOT consume any byte from stdin; the prompt helper exits 0 immediately after emitting the `research: <path>` audit line.
- Bash 3.2 compatibility (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.
- D020 token hygiene (CON-7): comments and prose in the router MUST NOT embed the scaffold-placeholder marker bracket-TODO byte pattern; paraphrase or escape.
- The existing `auto_proceeded: true` proposal-frontmatter side-effect (router mutates `proceeded_at`) is preserved verbatim — the Tier A+ chain is an additive branch, not a replacement.

## Inputs

### From Previous Tasks

- `scripts/intake/shape-detect.sh` (modified by T01) — emits `input_shape=tier_a_plus`. The router's verdict-recognition reads this line. Key API: `bash scripts/intake/shape-detect.sh --input <string>` emits two stdout lines.
- `scripts/intake/lib/task-slug.sh` (created by T02) — sourceable; exposes `derive_task_slug <description>` returning `<40-char-lower-hyphen-alnum>[-<sha1-4>]`. Router sources the file and calls the function once per Tier A+ flow.
- `templates/dispatch-role-research.md`, `templates/dispatch-role-plan.md`, `templates/dispatch-role-build.md` (created by T02) — prescriptive role templates. Router invokes the dispatch surface with the corresponding template path per role.
- `scripts/intake/lib/tier-a-plus-prompt.sh` (created by T03) — sourceable + invokable; exit codes 0 (proceed) / 1 (re-run) / 2 (abort). Router invokes with `--research-path`, `--task-slug`, `--session-id`, optional `--yes`. Key API: see T03 plan for the full invocation contract.

### From Disk (Pre-existing)

- `scripts/intake/route-to-dispatch.sh` (54 lines) — existing M024/P03/T03 single-dispatch router. T04 amends additively. Key API today: `bash scripts/intake/route-to-dispatch.sh --proposal <path>`; emits `invoke=orchestrator:dispatch --proposal <path>` stdout line and (when proposal carries `auto_proceeded: true`) emits `auto_proceed=1` line + mutates `proceeded_at`.
- `scripts/dispatch/build-context.sh` (modified by P01) — accepts `--profile=quick|standard|full`, `--task-plan`, `--out`, `--meta-out`. Router invokes with `--profile=quick` for every Tier A+ sub-dispatch.
- `commands/dispatch.md` (modified by P01) — Quick row reads "knowledge + compression with the Quick profile" (FR-4). The router's invocation shape complies with this contract.
- `templates/orchestrator-config-default.yml` — declares `tier_a_plus_prompt_summary_lines: 8` (P00 default). The router does not read this knob directly — it passes the read-responsibility to T03's prompt helper.

## Constraints

- **Bash 3.2 compatibility** (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.
- **Strictly additive** to `scripts/intake/route-to-dispatch.sh`: existing single-dispatch path (proposal-frontmatter → `invoke=orchestrator:dispatch --proposal <path>`) MUST keep working byte-equal.
- **No edits to `scripts/intake/shape-detect.sh` / `paragraph-classify.sh`** in T04 (T01 owns those edits).
- **No edits to `scripts/intake/lib/`** in T04 (T02 + T03 own the lib helpers; T04 sources/invokes them).
- **No edits to `templates/dispatch-role-*.md`** in T04 (T02 owns those templates).
- **No edits to `templates/orchestrator-config-default.yml`** in T04.
- **No `orchestrator:auto` / `orchestrator:roadmap` / `orchestrator:consolidate` invocations** anywhere in the router (CON-4 / DC-4 — verified by `m031-p02-router-shape.sh` grep).
- **No new lock files** under any path (CON-4 — verified by router-shape grep).
- **No `.orchestrator/milestones/M###/` scaffolding writes** (CON-4 — verified by router-shape grep for `mkdir -p .orchestrator/milestones/`).
- **SC-12 scope-guard**: T04 MUST NOT touch `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`.
- **Verifier path discipline** (AD-19 + [M032](../../../../../milestones/M032/index.md) Finding A): project-owned slug-bearing verifiers live under `tools/verify/`, NOT `scripts/verify/`.

## Expected Output

After T04 completes:

1. `scripts/intake/route-to-dispatch.sh` recognizes `--verdict tier_a_plus` and chains three sequential dispatches (research → prompt → plan → build) emitting JSONL `unit_close` records with `tier_a_plus_role` and `aborted` fields.
2. The pre-T04 single-dispatch path (`--proposal <path>`) remains byte-equal in stdout output.
3. `tests/m031-acceptance/test-tier-a-plus-flow.sh` exists, executable, exits 0 (`RESULT: SC-6 pass`).
4. `tools/verify/m031-p02-router-shape.sh` exists, executable, exits 0.
5. `tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh` exists, executable, exits 0.
6. No `.orchestrator/milestones/M###/` scaffolding written; no lock file written; no parallel routing implementation introduced (CON-3 grep clean).

T04 closes the Tier A+ middle flow on disk. T05 ships the phase-suite aggregator + SC-12 scope-guard that close the phase mechanically.
