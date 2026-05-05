---
description: "Use when starting a project with no materials and no codebase — runs a 7-question grilling-protocol-shaped flow producing an orchestrator:specify-consumable structured pre-spec."
---

# orchestrator:ideation

FR-10 deliverable for M033 (036-project-onboarding-experience). The
orchestrator-native ideation front door for the **greenfield-empty**
branch (no materials, no codebase). Walks the operator through a
7-question grilling-protocol-shaped flow, persists partial answers to
`partial-answers.yml` after each question per CON-6 (resume-on-interrupt),
and per the MIT-007 amendment to FR-10 passes the partial-answers file
as the `[<context-file>]` argument on EVERY `ask_one` invocation (not
just on resume) so contradiction detection fires during normal sessions.

The driver is `scripts/lifecycle/ideation.sh`. The grilling-shell is
`scripts/lifecycle/grilling-shell.sh` (P02 / FR-17). Output is written
under `<project-dir>/.orchestrator/intake/<timestamp>/`.

## Prerequisites / State Check

- Greenfield-empty branch (US-5): the project directory contains no
  primary spec materials and no inhabited codebase. The `start.sh`
  branch detector (P01 / FR-2) routes here when both conditions hold.
- `orchestrator:init` has run for the target project (either same
  invocation context or upstream sub-flow); at minimum the project
  directory exists. The driver creates `<project-dir>/.orchestrator/`
  on demand if absent.
- Stdin is a terminal (or test harness feeding scripted input) — the
  grilling-shell reads exactly one line per question per CON-5
  (sequential never batched).

## Core Workflow

The driver runs a fixed pipeline. Each question writes to
`partial-answers.yml` immediately after resolution per CON-6, so
Ctrl+C mid-flow is recoverable: re-invoking against the same
`<timestamp>` directory resumes from the first unanswered key.

### 1. Timestamp resolution + intake-directory creation

The driver resolves a `<timestamp>` for the run. Resolution order:

1. If `<project-dir>/.orchestrator/intake/<*>/partial-answers.yml`
   exists with fewer than 7 keys, that timestamp is reused (resume
   path per CON-6).
2. Else `M033_IDEATION_TIMESTAMP` (TEST-ONLY env override) is honored
   when set.
3. Else `date -u +%Y%m%dT%H%M%SZ`.

The intake directory `<project-dir>/.orchestrator/intake/<timestamp>/`
is created with `mkdir -p`. The accumulator
`<project-dir>/.orchestrator/intake/<timestamp>/partial-answers.yml`
is touched (idempotent).

### 2. `partial-answers.yml` initialization or resume-detection (CON-6)

The driver reads any pre-existing `partial-answers.yml` and extracts
the set of answered question-keys. The 7-question loop skips any
qkey already present in the accumulator — re-invocation against the
same `<timestamp>` directory resumes from the first unanswered key,
NOT restart from question 1.

### 3. The 7-question loop (closed `<qkey>` enum, in execution order)

1. `problem-statement` — What problem does this project solve?
2. `target-user` — Who is the primary target user?
3. `mvp-boundary` — What is the MVP boundary?
4. `top-user-stories` — What are the top 3 user stories?
5. `success-metric` — What is the primary success metric?
6. `top-risks` — What are the top 3 risks?
7. `top-non-goals` — What are the top 3 non-goals?

The loop sets `_GRILLING_CURRENT_QKEY` before each `ask_one`
invocation (consulted by the contradiction detector to identify which
question-key the answer belongs to per the closed
`_GRILLING_CONTRADICTION_PAIRS` SSOT — `target-user` overlaps with
the SSOT so contradictions actually fire on `target-user` answers).

### 4. MIT-007 `[<context-file>]` wiring (passed on EVERY ask_one call)

Every `ask_one` invocation passes the `partial-answers.yml` path as
the third argument. This is **load-bearing** — skipping the third arg
on any call breaks live contradiction detection during normal
sessions and is a contract violation (FR-10 / MIT-007 amendment).
The shape verifier asserts the wiring via token-count grep on every
non-comment `ask_one ` call.

### 5. `ideation-pre-spec.md` emission with 7 H2 sections

After the 7-question loop completes, the driver composes
`<project-dir>/.orchestrator/intake/<timestamp>/ideation-pre-spec.md`
with one H1 title and 7 H2 sections in execution order:

- `# Ideation Pre-Spec`
- `## Problem` — body is the resolved `problem-statement` answer.
- `## Target User` — body is the resolved `target-user` answer.
- `## MVP` — body is the resolved `mvp-boundary` answer.
- `## User Stories` — body is the resolved `top-user-stories` answer.
- `## Success Metric` — body is the resolved `success-metric` answer.
- `## Risks` — body is the resolved `top-risks` answer.
- `## Non-Goals` — body is the resolved `top-non-goals` answer.

### 6. Optional `--with-conversus-stress-test` adversarial pass (#Q-7 OFF by default)

When the operator passes `--with-conversus-stress-test`, the driver
probes for the conversus adapter (`scripts/dispatch/adapters/tool/conversus.sh`)
and invokes `bash scripts/dispatch/adapters/tool/conversus.sh stress-test
"$intake_dir/ideation-pre-spec.md"`. The adversarial output is
appended to `ideation-pre-spec.md` as a final
`## Adversarial Findings (deferred to specify)` section.

If the conversus adapter is unavailable, the driver emits
`conversus adapter not available — skipping stress-test` to stderr
and continues — non-fatal. Per #Q-7 the flag is **OFF by default**;
the `if [ "$WITH_STRESS_TEST" = "1" ]` branch gates the invocation.

### 7. Marker write + JSONL emit + dual-write fragment

- `bash scripts/util/start-state-markers.sh write ideation <project-dir>`
  records the `ideation` partial-state marker (FR-20).
- `PROJECT_DIR=<project-dir> bash scripts/util/jsonl-event-emitter.sh
  emit ideation_completed <payload_json>` emits the FR-22 observability
  record. Payload includes `questions_answered` and `with_stress_test`.
- `bash scripts/util/dual-write-runtime-md.sh --root <project-dir>
  --marker recent-changes --append-entry "ideation: 7-question pre-spec
  authored"` appends the FR-21 dual-write fragment.

## Output

- `<project-dir>/.orchestrator/intake/<timestamp>/ideation-pre-spec.md` — the structured pre-spec consumable by `orchestrator:specify`.
- `<project-dir>/.orchestrator/intake/<timestamp>/partial-answers.yml` — the resume accumulator (CON-6).
- `<project-dir>/.orchestrator/start-state/ideation.complete` — the FR-20 partial-state marker.
- `ideation_completed` JSONL event under `<project-dir>/.orchestrator/execution-log.jsonl` (FR-22).
- A one-line FR-21 Recent Changes fragment appended to the project's
  runtime instruction file via `dual-write-runtime-md.sh`.

## Idempotency

Re-invocation against the same `<timestamp>` directory resumes from
the first unanswered key (CON-6). Already-answered keys are read from
`partial-answers.yml` and skipped — no double-prompting.

A new `<timestamp>` (no resume path matched) starts fresh.

## Error Handling

- `ask_one` returns 2 (bad-usage / no explicit answer) → driver exits 2.
- `ask_one` returns 3 (contradiction-unresolved after one retry per
  MIT-007) → driver exits 3 with a `contradiction-unresolved` diagnostic.
- Missing conversus adapter under `--with-conversus-stress-test` →
  stderr diagnostic `conversus adapter not available — skipping
  stress-test`; non-fatal, driver continues.
- Bash 3.2 compatibility per MEM001 (no `declare -A`, no process
  substitution `<(...)`, no `$(...)` containing pipes).

## Referenced Scripts

- `scripts/lifecycle/ideation.sh` — the FR-10 driver (this command's
  primary implementation).
- `scripts/lifecycle/grilling-shell.sh` — the P02 `ask_one` API; sourced
  by the driver. Closed `_GRILLING_CONTRADICTION_PAIRS` SSOT covers
  `target-user`, `deployment-target`, `auth-model`.
- `scripts/util/jsonl-event-emitter.sh` — `emit ideation_completed`
  subcommand (FR-22).
- `scripts/util/start-state-markers.sh` — `write ideation <project-dir>`
  subcommand (FR-20; `ideation` is in the closed 7-name sub-flow enum).
- `scripts/util/dual-write-runtime-md.sh` — `--marker recent-changes
  --append-entry <fragment>` shape (FR-21 / spec 035).
- `scripts/dispatch/adapters/tool/conversus.sh` — invoked optionally
  under `--with-conversus-stress-test` (#Q-7); missing-binary path
  falls through to a `conversus adapter not available` diagnostic,
  NOT an error.
