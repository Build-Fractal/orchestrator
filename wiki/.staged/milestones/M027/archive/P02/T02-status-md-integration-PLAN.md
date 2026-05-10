---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M027"
name: "commands/status.md integration + status-quiet baseline fixture"
depends_on: ["T01"]
---

## Prerequisites

- T01 has shipped `scripts/diagnostics/efficiency-footer.sh` (≥ 80 lines, executable, sourceable). CLI accepts `--milestone <Mxxx>`, `--project`, `--quiet`, `--config-defaults <path>`, `--help`. Default emits a footer block titled `Efficiency (Tier 1 rollup)`; `--quiet` (or `efficiency_footer=false`) emits zero stdout, exit 0.
- T01 has added `efficiency_footer` and `predictive_cost_surface` to the `VALID_KEYS` list in `scripts/state/read-config.sh`.
- Pre-existing `commands/status.md` (171 lines, MEM012-shaped). Sections in current order: frontmatter / Title / State Derivation / Progress Overview / Blockers / Execution History / Telemetry Metrics / Next Action / Concurrent Safety / Idempotency / Error Handling / Gotchas / Reference Files.
- Project commands convention (MEM012): canonical sections; integration tests verify cross-references resolve to existing files.
- AD-19 (single-script-file `Check:` shape): this task's `## Verification` block is a SINGLE bash invocation of T02's own deliverable. Per the M027/P00 + M027/P01 parser-shape lesson, it must NOT reference future tasks' artifacts (T04's canonical verifier ships later); T02 ships its own scoped precheck.

## Description

Update `commands/status.md` to invoke the T01 efficiency-footer helper at a stable, documented attach point (after the `## Telemetry Metrics` section, before `## Next Action`) and document the suppression semantics (`--quiet` flag and `config.efficiency_footer: false`). The pre-footer output (every existing section above the footer attach point) MUST remain structurally unchanged — no re-ordering, no rewording of existing prose. The footer is governed by `--quiet` (passed through to the helper) and by `config.efficiency_footer` (default `true`).

Also create the byte-identity baseline fixture `tests/fixtures/m027-p02/status-quiet-baseline.txt` — this is the load-bearing fixture that T04's `m027-p02-status-quiet-byte-identity.sh` verifier diffs against. The fixture captures the deterministic post-`## Next Action` tail of `orchestrator:status` output (since `commands/status.md` is a markdown command document interpreted by an agent runtime, not a shell script that emits stdout directly, the fixture captures the *prose tail* of the document — specifically the verbatim content of the Next Action / Concurrent Safety / Idempotency / Error Handling / Gotchas / Reference Files sections that an agent following the document instructions would surface verbatim under `--quiet`). The fixture is human-curated from the post-edit `commands/status.md`; T04 re-verifies on every run.

Per CON-3 / SC-3 byte-identity contract: the goal is operator + CI compatibility — `orchestrator:status --quiet` output must remain byte-identical to pre-M027 from any caller's perspective. Since the agent renders the markdown command, the most reliable proxy is to assert (a) the document still contains the same canonical sections in the same order; (b) the footer attach-point is the only structural addition; (c) the suppression-knob documentation is present and unambiguous so the rendering agent always suppresses correctly under `--quiet`. The T04 verifier asserts (a) + (b) + (c) statically (markdown source check) — actual runtime byte-identity is enforced upstream by the agent's contract honoring `--quiet` per the documented semantics.

## Steps

1. **Edit `commands/status.md`** — insert ONE new section between the existing `## Telemetry Metrics` section and the existing `## Next Action` section. The new section is titled `## Efficiency Footer` and reads:

   ```markdown
   ## Efficiency Footer

   After the telemetry block, render a one-block efficiency footer summarizing milestone-to-date cost + paired quality metrics from the [M019](../../../../milestones/M019/index.md) Tier 1 JSONL stream. The footer is governed by two suppression conditions; under EITHER, render NOTHING for this section and proceed directly to `## Next Action`.

   ### Suppression Conditions

   The efficiency footer is suppressed (zero output for this section, output remains byte-identical to pre-M027 `orchestrator:status`) when ANY of:

   1. The `--quiet` flag is passed to `orchestrator:status`.
   2. The config knob `efficiency_footer` resolves to `false`. Resolution chain: env `ORCH_EFFICIENCY_FOOTER` → local config → project config → defaults. Default is `true`.

   Otherwise, render the footer.

   ### Render

   Invoke the helper:

   ```bash
   bash scripts/diagnostics/efficiency-footer.sh --milestone <active-milestone-id>
   ```

   When no active milestone exists, fall back to the project-granularity rollup:

   ```bash
   bash scripts/diagnostics/efficiency-footer.sh --project
   ```

   The helper handles both forms — passing `--quiet` propagates the suppression to the helper. Helper output is a one-block efficiency footer (≤ 6 lines) prefixed with the literal title `Efficiency (Tier 1 rollup)`. When the JSONL stream is empty or absent, the helper emits a single-line `Efficiency: no Tier 1 records yet` (US-3 AS-3) — never an error, never a crash (CON-5 carry-forward).

   ### Read-Only

   The efficiency footer is a read-only consumer of `execution-log.jsonl` — it never writes to or rewrites the log (FR-12 / CON-1). The helper is bash-only; zero LLM tokens (FR-21 / CON-6).
   ```

2. **Add `scripts/diagnostics/efficiency-footer.sh` to the `## Reference Files` section** at the end of `commands/status.md`. Insert as a new bullet after the existing `scripts/telemetry/aggregate-metrics.sh` line:

   ```markdown
   - `scripts/diagnostics/efficiency-footer.sh` — efficiency footer helper (M027/P02). Sources or forks `scripts/diagnostics/metrics-rollup.sh` for milestone-to-date paired cost+quality aggregates. Read-only.
   ```

3. **Verify NO existing sections were re-ordered or re-worded.** The exact pre-edit shape (frontmatter / Title / State Derivation / Progress Overview / Blockers / Execution History / Telemetry Metrics / Next Action / Concurrent Safety / Idempotency / Error Handling / Gotchas / Reference Files) must be preserved with the single insertion of `## Efficiency Footer` between Telemetry Metrics and Next Action, plus the one new bullet under Reference Files.

4. **Create `tests/fixtures/m027-p02/`** directory if it does not exist.

5. **Create `tests/fixtures/m027-p02/status-quiet-baseline.txt`** — captures the verbatim tail of `commands/status.md` from the `## Next Action` section onward (post-edit, since this fixture is the post-M027 byte-identity baseline; the verifier asserts that under `--quiet`, no NEW content appears between the telemetry block and Next Action). Concretely, the fixture body is the literal copy of the `## Next Action` section through the end of `commands/status.md` (Next Action / Concurrent Safety / Idempotency / Error Handling / Gotchas / Reference Files), as a multi-line text fixture. The verifier in T04 extracts the same range from the live `commands/status.md` (using `awk` to pluck lines from `## Next Action` through end-of-file) and `diff`s against this fixture. Failure if the diff is non-zero.

6. **Create `tests/fixtures/m027-p02/README.md`** — a short note (10–20 lines) explaining the fixture's role: "Baseline for the M027/P02/T04 `m027-p02-status-quiet-byte-identity.sh` verifier. Captures the verbatim post-`## Next Action` tail of `commands/status.md`. Updated only when intentional changes to those sections land via a follow-up commit; the verifier rejects accidental drift."

7. **Markdown-only discipline.** This task ships markdown only (commands/status.md edit + fixture text + fixture README). No shell code; CON-7 (bash 3.2) does not apply directly, but the T04 `m027-p02-bash32-compat.sh` verifier still scans `commands/status.md` (and the README) for forbidden tokens — the markdown body must NOT contain literal forbidden constructs (`<<<`, `<(`, `>(`, `&>`, `${var^^}`, `declare -A`, `mapfile`). The example `bash` fenced blocks above use only `--milestone`, `--project`, `--quiet` flags — no forbidden tokens.

8. **No edits to T01's helper or to `read-config.sh`.** This task is purely document-shaped; T01 owns the helper / config-key edits.

## Must-Haves

- File `commands/status.md` exists, ≥ 170 lines (post-edit; current is 171, footer addition adds ~30 lines so post-edit ≥ 200 — but the artifact min-line check in P02-PLAN is 170, conservative).
- File `commands/status.md` contains the literal string `efficiency-footer` (referencing the helper).
- File `commands/status.md` contains a `## Efficiency Footer` heading.
- File `commands/status.md` contains a reference to the `--quiet` suppression flag in the new section.
- File `commands/status.md` contains a reference to the `efficiency_footer` config knob in the new section.
- File `commands/status.md` references `scripts/diagnostics/efficiency-footer.sh` in the `## Reference Files` section.
- File `commands/status.md` retains its pre-edit canonical sections in the pre-edit order (no re-ordering of State Derivation / Progress Overview / Blockers / Execution History / Telemetry Metrics / Next Action / Concurrent Safety / Idempotency / Error Handling / Gotchas / Reference Files).
- File `tests/fixtures/m027-p02/status-quiet-baseline.txt` exists, ≥ 1 line, contains the literal `Next Action`.
- File `tests/fixtures/m027-p02/README.md` exists.

## Verification

```bash
bash scripts/verify/m027-p02-t02-shape-precheck.sh
```

This T02-scoped precheck verifier (ships with T02) asserts T02's nine must-haves: `commands/status.md` exists ≥ 170 lines, contains `efficiency-footer`, contains `## Efficiency Footer`, contains `--quiet` and `efficiency_footer` references in the new section, references `scripts/diagnostics/efficiency-footer.sh` in `## Reference Files`, retains the pre-edit canonical section order (verified by `grep -n` line-position assertions: State Derivation < Progress Overview < Blockers < Execution History < Telemetry Metrics < Efficiency Footer < Next Action < Concurrent Safety < Idempotency < Error Handling < Gotchas < Reference Files), the fixture file `tests/fixtures/m027-p02/status-quiet-baseline.txt` exists ≥ 1 line and contains `Next Action`, and the fixture README exists.

T04 ships the canonical phase-level verifier `m027-p02-status-md-shape.sh` (which subsumes this precheck) AND `m027-p02-status-quiet-byte-identity.sh` (the byte-identity diff verifier consuming this fixture). The phase-level `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M027/phases/P02` runs at the phase boundary, not at T02 task verification.

The precheck script is created as part of T02 (its body is a small shell script that performs the nine assertions). T04 may delete this precheck once the canonical verifiers ship, mirroring the M027/P01/T03 + T04 pattern. The precheck lives at `scripts/verify/m027-p02-t02-shape-precheck.sh` and follows the standard verifier skeleton (PROJECT_ROOT via `BASH_SOURCE`; `PASS:` / `FAIL:` to stdout / stderr; exit 0/1).

## Inputs

### From Previous Tasks

- T01: `scripts/diagnostics/efficiency-footer.sh` — referenced from the new `## Efficiency Footer` section of `commands/status.md` and added to the `## Reference Files` bullet list. Not invoked from this task's code (this task is markdown-only); the helper is documented for the agent runtime to invoke at command-execution time.

### From Disk (Pre-existing)

- `commands/status.md` (171 lines) — modified in place. Pre-edit canonical sections must be preserved in pre-edit order.
- `commands/init.md`, `commands/dispatch.md`, `commands/cost.md` (P01) — reference shapes for MEM012 canonical commands convention. Read these to mirror the styling of new section headers / bullet lists.

## Constraints

- **MEM012 (command structure)**: New section follows the canonical sub-bullet style; new entry in `## Reference Files` follows the existing bullet shape (script path + one-line description).
- **CON-3 / SC-3 (back-compat byte-identity)**: Pre-edit sections preserved in pre-edit order. Footer is the ONLY structural addition (plus one bullet under Reference Files). Suppression semantics are unambiguous so an agent rendering the document under `--quiet` deterministically omits the footer.
- **CON-5 (never-abort)**: The new section explicitly documents `Efficiency: no Tier 1 records yet` for the empty-log path; never errors.
- **CON-7 (bash 3.2)**: Markdown body uses no forbidden constructs (`<<<`, `<(`, `>(`, `&>`, `${var^^}`, `declare -A`, `mapfile`). Example fenced bash blocks use plain flag-style invocations only.
- **AD-19 (single-script-file Check shape)**: This task's `Check:` invokes a single helper script (the T02-scoped precheck). T04 ships the canonical phase-level Truth `Check:` invocations.
- **FR-12 / CON-1 (read-only)**: This task is document-shaped; the documented helper invocation is read-only.

## Expected Output

After this task:

1. `commands/status.md` exists, ≥ 200 lines (post-edit), contains the new `## Efficiency Footer` section between Telemetry Metrics and Next Action, contains the new `efficiency-footer.sh` bullet under Reference Files, retains the pre-edit canonical sections in pre-edit order.
2. `tests/fixtures/m027-p02/status-quiet-baseline.txt` exists, contains the verbatim post-`## Next Action` tail of `commands/status.md`.
3. `tests/fixtures/m027-p02/README.md` exists with the short fixture-role note.
4. `scripts/verify/m027-p02-t02-shape-precheck.sh` exists, executable, exits 0 against the post-T02 codebase.
5. `git diff --quiet` is non-zero (this task creates and modifies files); however, no `execution-log.jsonl` file is touched.
