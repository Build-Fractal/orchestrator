---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M033"
name: "commands/ideation.md + scripts/lifecycle/ideation.sh 7-question grilling flow + MIT-007 partial-answers wiring + opt-in conversus stress-test (FR-10)"
depends_on: []
---

## Prerequisites

T02 ships the FR-10 ideation surface. It has **no intra-phase prerequisites**; it consumes only previously-shipped P02 surfaces.

Files that MUST exist on disk at task-start:

- `scripts/lifecycle/grilling-shell.sh` (P02/T03+T04 — `ask_one` API; `_GRILLING_CURRENT_QKEY` caller-set var; closed 9-pair `_GRILLING_CONTRADICTION_PAIRS` SSOT covering `target-user`, `deployment-target`, `auth-model`)
- `scripts/util/jsonl-event-emitter.sh` (P02/T01 — `emit ideation_completed <payload_json>` subcommand)
- `scripts/util/start-state-markers.sh` (P02/T02 — `write ideation <project-dir>` subcommand; `ideation` is in the closed 7-name sub-flow enum)
- `scripts/util/dual-write-runtime-md.sh` (M014 closed; P03/T05 SSOT-harmonized API)
- `references/m033-fr21-dual-write-convention.md` (P02/T05)
- `scripts/dispatch/adapters/tool/conversus.sh` (M011/P07 conversus adapter — invoked optionally under `--with-conversus-stress-test`; missing-binary path falls through to a `conversus adapter not available` diagnostic, NOT an error)

## Description

T02 ships the FR-10 ideation surface — the 7-question grilling-protocol-shaped flow that walks the operator through structured pre-spec authoring for greenfield-empty branch projects. The flow consumes P02's `ask_one` API, persists partial answers to `partial-answers.yml` after each question per CON-6 (resume-on-interrupt), and per the MIT-007 amendment to FR-10 passes the partial-answers file as the `[<context-file>]` argument on EVERY `ask_one` invocation (not just on resume) so live contradiction detection fires during normal sessions.

The two deliverables are:

1. **`commands/ideation.md`** — canonical command-doc per MEM012. Documents the FR-10 contract, names the closed 7-question key set in execution order, names the `partial-answers.yml` resume convention per CON-6, names the MIT-007 wiring invariant, names the opt-in `--with-conversus-stress-test` default-OFF discipline per #Q-7.

2. **`scripts/lifecycle/ideation.sh`** — the FR-10 driver, bash 3.2 compatible.

Co-authored:

3. **`tools/verify/m033-p04-ideation-md-shape.sh`** — shape verifier for the command doc.
4. **`tools/verify/m033-p04-ideation-sh-shape.sh`** — shape verifier for the driver.

## Steps

1. **Author `commands/ideation.md`** following the MEM012 canonical command-doc structure. Include:
   - YAML frontmatter `description: "Use when starting a project with no materials and no codebase — runs a 7-question grilling-protocol-shaped flow producing an orchestrator:specify-consumable structured pre-spec."`
   - `# orchestrator:ideation` title.
   - Prerequisites — names the greenfield-empty branch as the triggering condition (US-5).
   - Core Workflow — numbered sections covering: (a) timestamp resolution + intake-directory creation, (b) `partial-answers.yml` initialization or resume-detection per CON-6, (c) the 7-question loop with the closed `<qkey>` enum (`problem-statement`, `target-user`, `mvp-boundary`, `top-user-stories`, `success-metric`, `top-risks`, `top-non-goals`), (d) MIT-007 `[<context-file>]` wiring (passed on EVERY ask_one call), (e) `ideation-pre-spec.md` emission with 7 H2 sections, (f) optional `--with-conversus-stress-test` adversarial pass, (g) marker write + JSONL emit + dual-write fragment.
   - Output section — names `ideation-pre-spec.md`, `partial-answers.yml`, `ideation.complete` marker, `ideation_completed` JSONL event.
   - Idempotency — re-invocation against the same `<timestamp>` directory resumes from the first unanswered key.
   - Error Handling — names the contradiction-unresolved exit-3 path (when grilling-shell's contradiction detector returns 3 after retry); names the missing-conversus-binary fall-through.
   - Referenced Scripts — lists `scripts/lifecycle/ideation.sh`, `scripts/lifecycle/grilling-shell.sh`, `scripts/util/jsonl-event-emitter.sh`, `scripts/util/start-state-markers.sh`, `scripts/util/dual-write-runtime-md.sh`, `scripts/dispatch/adapters/tool/conversus.sh`.

2. **Author `scripts/lifecycle/ideation.sh`** — bash 3.2 compatible. Top-level structure:
   - Shebang `#!/usr/bin/env bash`, then `set -e`, `set -u`, `set -o pipefail`.
   - File header naming FR-10, MIT-007, CON-6, MEM001, spec ref.
   - Fenced SSOT comment block:
     - `# >>> ideation-question-keys >>>` containing the 7 keys in execution order, one per line.
   - Four parallel indexed arrays (bash 3.2 — no `declare -A`) declaring the question text + recommendation default per qkey:
     ```
     QKEYS_0="problem-statement";       QQUESTIONS_0="What problem does this project solve?";       QRECS_0="(operator-supplied)"
     QKEYS_1="target-user";             QQUESTIONS_1="Who is the primary target user?";             QRECS_1="(operator-supplied)"
     QKEYS_2="mvp-boundary";            QQUESTIONS_2="What is the MVP boundary?";                   QRECS_2="(operator-supplied)"
     QKEYS_3="top-user-stories";        QQUESTIONS_3="What are the top 3 user stories?";            QRECS_3="(operator-supplied)"
     QKEYS_4="success-metric";          QQUESTIONS_4="What is the primary success metric?";         QRECS_4="(operator-supplied)"
     QKEYS_5="top-risks";               QQUESTIONS_5="What are the top 3 risks?";                   QRECS_5="(operator-supplied)"
     QKEYS_6="top-non-goals";           QQUESTIONS_6="What are the top 3 non-goals?";               QRECS_6="(operator-supplied)"
     ```
   - Flag parsing: `--project-dir <path>` (default `pwd`), `--yes` (auto-accept defaults — note: defaults are placeholder `(operator-supplied)`; under `--yes` the flow reads stdin lines directly bypassing the recommendation), `--with-conversus-stress-test` (opt-in flag; default OFF per #Q-7).
   - Helper `resolve_timestamp <project-dir>` — checks for an existing `<project-dir>/.orchestrator/intake/<*>` directory containing a `partial-answers.yml`; if found and the partial-answers is non-complete (fewer than 7 keys), returns that timestamp (resume path); else honors `M033_IDEATION_TIMESTAMP` env override; else generates new `date -u +%Y%m%dT%H%M%SZ`.
   - Helper `read_partial_answers <yaml-path>` — emits one `<qkey>` per line for keys already present (used to skip-already-answered).
   - Helper `ideate_one <qkey> <question> <recommendation> <yaml-path>` — sets `_GRILLING_CURRENT_QKEY="$qkey"`, then invokes `ask_one "$question" "$recommendation" "$yaml-path"` — the third arg is the partial-answers file path, passed on EVERY call per MIT-007. After ask_one returns 0, the answer is already appended to the yaml-path by ask_one itself (P02 wiring). Returns ask_one's exit code.
   - Source the grilling-shell:
     ```bash
     . scripts/lifecycle/grilling-shell.sh
     ```
   - Main flow:
     - Parse flags.
     - `proj=<project-dir>`; `ts=$(resolve_timestamp "$proj")`; `intake_dir="$proj/.orchestrator/intake/$ts"`; `mkdir -p "$intake_dir"`.
     - `pa="$intake_dir/partial-answers.yml"`; `touch "$pa"` (idempotent).
     - For each qkey index 0..6:
       - Skip if already in `$pa` (resume).
       - Set `_GRILLING_CURRENT_QKEY` to the qkey.
       - Invoke `ideate_one "$qkey" "$question" "$rec" "$pa"`.
       - Check exit code: 0 → continue; 2 → exit 2 (bad usage); 3 → exit 3 (contradiction-unresolved per ask_one).
     - Compose `ideation-pre-spec.md` from `partial-answers.yml`:
       - H1 title: `# Ideation Pre-Spec`.
       - 7 H2 sections in execution order: `## Problem`, `## Target User`, `## MVP`, `## User Stories`, `## Success Metric`, `## Risks`, `## Non-Goals`. Each section's body is the resolved answer for the corresponding qkey, optionally with `<!-- Recommended-default-accepted -->` comment when the answer matches the recommendation default verbatim.
     - When `--with-conversus-stress-test`: probe `command -v conversus` or test for `scripts/dispatch/adapters/tool/conversus.sh`; if available, invoke `bash scripts/dispatch/adapters/tool/conversus.sh stress-test "$intake_dir/ideation-pre-spec.md"` and append the output as `## Adversarial Findings (deferred to specify)` section; if unavailable, emit `conversus adapter not available — skipping stress-test` to stderr (non-fatal).
     - `bash scripts/util/start-state-markers.sh write ideation "$proj"`.
     - `PROJECT_DIR="$proj" bash scripts/util/jsonl-event-emitter.sh emit ideation_completed '{"questions_answered":7,"with_stress_test":<true|false>}'`.
     - `bash scripts/util/dual-write-runtime-md.sh --root "$proj" --marker recent-changes --append-entry "ideation: 7-question pre-spec authored"`.

3. **Author `tools/verify/m033-p04-ideation-md-shape.sh`** — bash 3.2 verifier:
   - Asserts file exists, ≥50 lines.
   - Contains `orchestrator:ideation`, `FR-10`, `ideation.sh`, the 7 closed qkeys (`problem-statement`, `target-user`, `mvp-boundary`, `top-user-stories`, `success-metric`, `top-risks`, `top-non-goals`), `partial-answers.yml`, `with-conversus-stress-test`, `MIT-007`, `ideation_completed`, `CON-6`.
   - PASS/FAIL/SUMMARY lines.

4. **Author `tools/verify/m033-p04-ideation-sh-shape.sh`** — bash 3.2 verifier:
   - Asserts file exists, executable, ≥200 lines.
   - Contains the fenced SSOT block marker `>>> ideation-question-keys >>>`.
   - Contains `ask_one`, `grilling-shell.sh`, `--project-dir`, `--yes`, `--with-conversus-stress-test`, all 7 qkeys, `_GRILLING_CURRENT_QKEY`, `partial-answers.yml`, `ideation-pre-spec.md`, `ideation.complete`, `ideation_completed`, `Adversarial Findings`, `dual-write-runtime-md.sh`, `M033_IDEATION_TIMESTAMP`.
   - Negative grep: no `declare -A`, no `<(`.
   - **MIT-007 wiring assertion (load-bearing)**: greps for the literal pattern that proves the partial-answers path is passed as the third arg on every `ideate_one` / `ask_one` call. The verifier asserts the script body contains a call shape like `ask_one .* "$pa"` or `ideate_one .* "$pa"` (the third-arg-is-yaml-path form). The test-shape: count the occurrences of `ask_one ` (with a trailing space) and assert each non-comment occurrence has at least 3 token-segments after the function name. (Implementation: extract lines containing `ask_one ` not starting with `#`; for each, awk-count whitespace-separated tokens; assert ≥4 — function name + 3 args.)
   - PASS/FAIL/SUMMARY.

## Must-Haves

- `commands/ideation.md` exists, ≥50 lines, satisfies the shape verifier.
- `scripts/lifecycle/ideation.sh` exists, executable, ≥200 lines, satisfies the shape verifier (FR-10 driver per spec; bash 3.2 compatible; MIT-007 third-arg wiring on every ask_one call).
- `tools/verify/m033-p04-ideation-md-shape.sh` exists, executable, exits 0.
- `tools/verify/m033-p04-ideation-sh-shape.sh` exists, executable, exits 0.

## Verification

```bash
bash tools/verify/m033-p04-ideation-md-shape.sh
```

```bash
bash tools/verify/m033-p04-ideation-sh-shape.sh
```

```bash
bash scripts/diagnostics/check-plans.sh
```

## Inputs

### From Previous Tasks

- `scripts/lifecycle/grilling-shell.sh` (from M033/P02/T03+T04)
  - Key API: `ask_one <question> <recommendation> [<context-file>]`. With third arg present, contradiction-detection fires via the closed 9-pair `_GRILLING_CONTRADICTION_PAIRS` SSOT. Returns 3 on contradiction-unresolved (after one retry). Caller-set var `_GRILLING_CURRENT_QKEY` is consulted by the contradiction detector to identify which question-key the answer belongs to.
  - Key types: `_GRILLING_CONTRADICTION_PAIRS` SSOT format is `qkey:value-a:value-b`; T02's qkeys (`target-user`, etc.) overlap with the SSOT's qkeys (`target-user`, `deployment-target`, `auth-model`) so contradictions actually fire on `target-user` answers.
- `scripts/util/jsonl-event-emitter.sh` (from M033/P02/T01)
  - Key API: `bash scripts/util/jsonl-event-emitter.sh emit ideation_completed <payload_json>`.
- `scripts/util/start-state-markers.sh` (from M033/P02/T02)
  - Key API: `bash scripts/util/start-state-markers.sh write ideation <project-dir>`. `ideation` is in the closed 7-name sub-flow enum.

### From Disk (Pre-existing)

- `scripts/dispatch/adapters/tool/conversus.sh` — adapter binary; T02 invokes via `stress-test <pre-spec-path>` subcommand under `--with-conversus-stress-test`. Missing-binary path emits `conversus adapter not available` diagnostic, non-fatal.
- `references/m033-fr21-dual-write-convention.md` (from M033/P02/T05) — FR-21 SSOT.

## Constraints

- **MIT-007 (load-bearing)**: every `ask_one` invocation in ideation.sh MUST pass the `partial-answers.yml` path as the third argument. The verifier asserts via token-count grep. Skipping the third arg on any call is a contract violation.
- **CON-6 (resume-on-interrupt)**: re-invocation against the same `<timestamp>` directory MUST resume from the first unanswered key, NOT restart from question 1.
- **CON-5 (sequential-never-batched)**: each `ask_one` invocation awaits its answer before the next fires.
- **#Q-7 (opt-in stress-test)**: `--with-conversus-stress-test` is OFF by default. The verifier asserts the conversus invocation is gated on the flag (a `if [ "$WITH_STRESS_TEST" = "1" ]` style branch).
- **MEM001**: bash 3.2 compat; no `declare -A`; no process substitution; no `$(...)` containing pipes.
- **Path discipline**: command doc → `commands/`; driver → `scripts/lifecycle/`; verifiers → `tools/verify/m033-p04-*`.
- **Path-collision check**: at task-start, `ls -la commands/ideation.md scripts/lifecycle/ideation.sh tools/verify/m033-p04-ideation-md-shape.sh tools/verify/m033-p04-ideation-sh-shape.sh` MUST report no existing files.
- **Scope**: T02 does NOT touch start.sh, materials-intake.sh, ingest-codebase.sh, or any P05 / customblock surface.

## Expected Output

After T02 completes:

- `commands/ideation.md` (new file, ≥50 lines)
- `scripts/lifecycle/ideation.sh` (new file, ≥200 lines, executable)
- `tools/verify/m033-p04-ideation-md-shape.sh` (new file, ≥25 lines, executable)
- `tools/verify/m033-p04-ideation-sh-shape.sh` (new file, ≥35 lines, executable)
- Both T02 verifiers exit 0 with `SUMMARY: <name> pass=N fail=0`.

## Notes

- T02 OPTIONALLY rewires P01's `ideation_stub` in `start.sh` to invoke the real driver. Per the same scope-guard discipline as T01, this rewiring is execution-time-decided based on whether SC-1's assertions are token-shape-tolerant.
- The `M033_IDEATION_TIMESTAMP` env override is documented as TEST-ONLY in the driver header, parallel to T01's `M033_INTAKE_TIMESTAMP`.
- Functional verification (the actual MIT-007 contradiction-detection-during-normal-session test) lives in T05's SC-5 acceptance script. T02's shape verifier asserts the WIRING is present (third-arg pattern); T05 asserts the wiring FIRES correctly against scripted contradicting answers.
- The `(operator-supplied)` placeholder recommendations are intentional: ideation has no domain-specific recommendation (every project is unique), so the recommendation slot defers to operator input. Under `--yes`, ask_one's empty-input branch returns the placeholder verbatim — the caller's `<!-- Recommended-default-accepted -->` provenance comment surfaces this.
