# Tasks: Speckit-Orchestrator Extension

**Input**: Design documents from `specs/001-speckit-orchestrator/`
**Prerequisites**: plan.md (required), spec.md (required), data-model.md, contracts/, research.md, quickstart.md
**Branch**: `001-speckit-orchestrator`

**Organization**: Tasks follow the plan's 7-phase dependency chain (Phase 1→2→3→4→(5∥6)→7), mapped to the spec's 8 user stories. Each phase includes GSD-2 bridging metadata (Boundary Map + Must-Haves) for downstream orchestration.

### Phase Mapping (tasks.md → plan.md)

| Tasks Phase | Plan Phase | Name |
|-------------|-----------|------|
| Phase 1 | Phase 1 | Setup |
| Phase 2 | Phase 2 | Foundation — State Machine & Config |
| Phase 3 | Phase 3 | Design Artifacts — Templates & References |
| Phase 4 | Phase 4 | Core Commands (US1+US2) |
| Phase 5 | Phase 5 | Autonomous Mode (US3+US5) |
| Phase 6 | Phase 6 | Knowledge & Lifecycle (US4+US6) |
| Phase 7 | Phase 7 | Distribution & Testing (US7+US8) |

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks in same phase)
- **[Story]**: Which user story this task serves (US1–US8, maps to spec.md priorities P1–P8)
- **Numbering**: T### (3-digit, e.g., T001) = implementation tasks in this file. T## (2-digit, e.g., T01) = orchestrator domain tasks per phase. "Phase N" in this file = implementation phase, matching plan.md numbering. "P##" = orchestrator domain phase within a milestone.
- All file paths are relative to repository root

## Path Conventions

```text
commands/           — spec-kit command markdown files (10 commands)
scripts/state/      — state machine, config, roadmap parsing
scripts/dispatch/   — context construction, capability detection
scripts/verify/     — must-haves, boundary maps, scope, external mods
scripts/knowledge/  — summaries, decisions, knowledge, consolidation
scripts/lifecycle/  — scaffolding, locks, completion, rollback
templates/          — structural output templates (12 files)
references/         — progressive disclosure docs (4 files)
tests/              — integration tests (BATS or bash assert)
docs/               — extension documentation
```

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the directory structure and validate the extension manifest that all subsequent phases depend on.

Boundary Map:
Produces: [directory tree per plan.md Project Structure, validated extension.yml, config default template]
Consumes: [nothing — this is the first phase]

Must-Haves:
Truths: [all directories from plan.md Project Structure exist on disk; extension.yml passes YAML lint; config template contains all 7 config keys from spec FR-072]
Artifacts: [scripts/state/ (dir), scripts/dispatch/ (dir), scripts/verify/ (dir), scripts/knowledge/ (dir), scripts/lifecycle/ (dir), templates/ (dir), references/ (dir), docs/ (dir), tests/ (dir), tests/fixtures/ (dir), templates/orchestrator-config-default.yml]
Key Links: [extension.yml provides.config.template → templates/orchestrator-config-default.yml; extension.yml provides.scripts entries → scripts/*/ directories exist]

### Implementation

- [ ] T001 Create full directory structure: `scripts/state/`, `scripts/dispatch/`, `scripts/verify/`, `scripts/knowledge/`, `scripts/lifecycle/`, `templates/`, `references/`, `docs/`, `tests/`, `tests/fixtures/`
- [ ] T002 Validate and finalize `extension.yml` — verify all 10 command registrations, 5 hook declarations, config_schema with 7 properties, 21 script entries, and requires.commands list match plan.md and contracts/extension-manifest.md
- [ ] T003 [P] Create `templates/orchestrator-config-default.yml` with all 7 config keys (default_tier, verification_commands, context_verbosity, git_isolation, dispatch_budget, duration_budget, budget_enforcement) matching extension.yml defaults section

**Checkpoint**: Directory tree matches plan.md Project Structure. Extension manifest is valid and complete.

---

## Phase 2: Foundation — State Machine & Config

**Purpose**: Implement the state machine core and config resolution that every command depends on.

**Independent Test**: Run `bash scripts/state/derive-phase.sh M001` against a test fixture directory with files representing each of the 9 states and verify correct output for each. Run `bash scripts/state/read-config.sh default_tier` and verify 4-layer resolution precedence.

Boundary Map:
Produces: [scripts/state/read-config.sh (config resolution API), scripts/state/derive-phase.sh (state derivation API), scripts/state/read-roadmap.sh (roadmap parsing API), scripts/lifecycle/scaffold.sh (directory scaffolding)]
Consumes: [extension.yml defaults section (factory defaults), templates/orchestrator-config-default.yml (config template)]

Must-Haves:
Truths: [derive-phase.sh outputs correct state string for all 9 states; derive-phase.sh completes in <1s; read-config.sh resolves 4 precedence layers correctly; scaffold.sh is idempotent — running twice produces same output]
Artifacts: [scripts/state/read-config.sh (min 25 lines), scripts/state/derive-phase.sh (min 40 lines, handles all 9 states), scripts/state/read-roadmap.sh (min 20 lines), scripts/lifecycle/scaffold.sh (min 30 lines)]
Key Links: [derive-phase.sh → read-roadmap.sh (calls for phase completion status); scaffold.sh → read-config.sh (reads git_isolation setting); derive-phase.sh reads {M###}-TIER.md for tier-conditional state transitions]

### Implementation

- [ ] T004 [P] Implement `scripts/state/read-config.sh` — 4-layer config resolution: env vars (`SPECKIT_ORCHESTRATOR_*`) → local overrides (`orchestrator-config.local.yml`) → project overrides (`orchestrator-config.yml`) → extension defaults (`extension.yml` defaults). Accept key name as argument, output resolved value. Handle missing files gracefully. Use `set -euo pipefail`. When no project-level config file exists, output a structured prompt (key names, descriptions, default values) to stdout; the calling command presents it to the developer and writes responses to `orchestrator-config.yml`.
- [ ] T005 [P] Implement `scripts/state/read-roadmap.sh` — parse roadmap YAML frontmatter (milestone, tier, feature_ref, success_criteria) and phase checkboxes (`[x]`/`[ ]`). Accept milestone ID as argument. Output phase list with status, risk, dependencies, boundary maps. When queried for success_criteria (e.g., `read-roadmap.sh M001 success_criteria`), output the criteria list for use by `mark-complete.sh` (T038) when generating M###-VALIDATION.md. Parse per contracts/state-files.md Roadmap Format.
- [ ] T006 Implement `scripts/state/derive-phase.sh` — 9-state file-presence derivation per data-model.md State Derivation Rules. Accept milestone ID as argument. Check priority-ordered conditions: milestone dir exists → context draft status → roadmap exists → stale phases → active task status → phase summaries → milestone validation (check for `M###-VALIDATION.md` per state rule #7) → milestone summary. Apply tier-conditional logic from `{M###}-TIER.md` (Tier B skips discussing, replanning, validating, completing). Depends on `read-roadmap.sh` for phase completion parsing.
- [ ] T007 [P] Implement `scripts/lifecycle/scaffold.sh` — create `.specify/orchestrator/milestones/{M###}/phases/` directory tree. Create global files if missing: `DECISIONS.md` (with header row), `KNOWLEDGE.md` (empty), `execution-log.jsonl` (empty). When `git_isolation: true`, create worktree: `git worktree add .worktrees/{M###} -b orchestrator/{M###}`. Must be idempotent (FR-066). Accept milestone ID and feature ref as arguments.

**Checkpoint**: State machine core functional. `derive-phase.sh` returns correct state for test fixtures representing all 9 states. Config resolution works across all 4 layers.

---

## Phase 3: Design Artifacts — Templates & References

> **Note**: Design artifacts (data-model.md, contracts/, quickstart.md) already exist from the planning phase. This phase creates the 12 templates (`templates/*.md`) and 4 reference documents (`references/*.md`).

**Purpose**: Create all output templates and reference documents that commands reference via `{TEMPLATE:name}`. Templates are structural shells — layout, headings, frontmatter fields, placeholder markers — with NO embedded orchestrator context (FR-074).

**Independent Test**: Each template validates as markdown with proper YAML frontmatter. Templates contain no hardcoded milestone/phase IDs. Reference docs cover all concepts they claim to document.

Boundary Map:
Produces: [12 templates in templates/*.md, 4 reference docs in references/*.md]
Consumes: [data-model.md (entity schemas for frontmatter fields), contracts/state-files.md (file format specs)]

Must-Haves:
Truths: [all 12 templates listed in plan.md Template Resolution section exist; all templates contain YAML frontmatter with schema_version field; no template contains hardcoded milestone/phase/task IDs; all 4 reference docs exist]
Artifacts: [templates/roadmap.md, templates/phase-plan.md, templates/task-plan.md, templates/task-summary.md, templates/phase-summary.md, templates/milestone-summary.md, templates/dispatch-prompt.md, templates/recovery-briefing.md, templates/continue-file.md, templates/context-draft.md, templates/verification-report.md, templates/spec-compliance-review.md, references/state-machine.md, references/verification-ladder.md, references/tier-definitions.md, references/file-formats.md]
Key Links: [templates/* frontmatter schemas ↔ data-model.md entity definitions; references/state-machine.md ↔ derive-phase.sh state derivation rules; references/file-formats.md ↔ contracts/state-files.md]

### Implementation

- [ ] T008 [P] Create planning templates: `templates/roadmap.md` (frontmatter: schema_version, milestone, feature_ref, feature_spec, vision, tier, success_criteria, timestamps; body: phase list with checkboxes, risk, depends, boundary maps per contracts/state-files.md Roadmap Format), `templates/phase-plan.md` (frontmatter: schema_version, phase, milestone, goal, demo_sentence, risk, depends_on; body: Must-Haves sections for truths/artifacts/key_links, Tasks section), `templates/task-plan.md` (frontmatter: schema_version, task, phase, milestone, name; body: plan with exact paths, verification criteria, expected outputs)
- [ ] T009 [P] Create summary templates: `templates/task-summary.md` (14-field YAML frontmatter per data-model.md Task Summary: schema_version, id, parent, milestone, provides, requires, affects, key_files, key_decisions, patterns_established, drill_down_paths, duration, verification_result, completed_at; body: one-liner, What Happened, Deviations, Files Created/Modified), `templates/phase-summary.md` (same schema, id=phase, parent=milestone, compressed rollup body), `templates/milestone-summary.md` (same schema, id=milestone, parent=null, full rollup body)
- [ ] T010 [P] Create dispatch and verification templates: `templates/dispatch-prompt.md` (sections: Task header, Task Plan, Phase Context, Upstream Dependencies, Relevant Decisions, Relevant Knowledge, Constitution Principles, Verification Criteria — per research.md R-005), `templates/verification-report.md` (frontmatter: schema_version, unit_id, unit_type, tier, timestamp; body: tier-by-tier results per R-013 4-tier model), `templates/spec-compliance-review.md` (prompt template for two-stage review: spec compliance checks per FR-059, code quality checks per FR-060)
- [ ] T011 [P] Create lifecycle templates: `templates/recovery-briefing.md` (frontmatter: schema_version, milestone, phase, task, crash_detected_at; body: What Was Attempted, What Completed, What Failed, Git State, Recovery Plan — per R-007), `templates/continue-file.md` (frontmatter: schema_version, milestone, phase, task, step, total_steps, saved_at; body: Completed Work, Remaining Work, Decisions Made, Context, Next Action — per data-model.md Continue File), `templates/context-draft.md` (frontmatter: schema_version, milestone, status, created_at, finalized_at; body: Architectural Decisions, Scope Boundaries, Design Constraints, Open Questions — per data-model.md Context Draft)
- [ ] T012 [P] Create reference documents: `references/state-machine.md` (full 9-state definition, transition rules, tier-conditional behavior, dispatch table per R-002), `references/verification-ladder.md` (4-tier model: static→command→behavioral→human, trigger conditions, failure dispositions per R-006/R-013), `references/tier-definitions.md` (Tier A/B/C capability matrix, state subsets, file counts per R-009), `references/file-formats.md` (all file format specs consolidated from data-model.md and contracts/state-files.md)

**Checkpoint**: All 12 templates and 4 reference documents exist. Templates contain proper frontmatter with placeholder markers. No hardcoded orchestrator context in any template.

---

## Phase 4: Core Commands — US1 Scope Triage + US2 Phase-by-Phase Execution (Priority: P1, P2) 🎯 MVP

**Goal**: Implement the Tier B command surface — scope classification, roadmap generation, phase planning, task dispatch, verification, and status. After this phase, a developer can orchestrate a Tier B project end-to-end using manual phase transitions.

**Independent Test**: Create a test project with a multi-phase spec. Run `/speckit.orchestrator.evaluate` → verify tier classification and scaffolding. Run `/speckit.orchestrator.roadmap` → verify roadmap with phases and boundary maps. Run `/speckit.orchestrator.plan-phase` → verify task decomposition with must-haves. Run `/speckit.orchestrator.dispatch` → verify context payload construction. Run `/speckit.orchestrator.verify` → verify must-have checks pass/fail correctly. Run `/speckit.orchestrator.status` → verify progress dashboard.

Boundary Map:
Produces: [commands/evaluate.md, commands/roadmap.md, commands/plan-phase.md, commands/dispatch.md, commands/verify.md, commands/status.md, scripts/dispatch/build-context.sh, scripts/dispatch/scope-filter.sh, scripts/dispatch/detect-capabilities.sh, scripts/verify/check-must-haves.sh, scripts/verify/check-boundary-map.sh, scripts/verify/check-scope.sh, scripts/verify/run-commands.sh]
Consumes: [scripts/state/derive-phase.sh (state derivation), scripts/state/read-roadmap.sh (roadmap parsing), scripts/state/read-config.sh (config resolution), scripts/lifecycle/scaffold.sh (directory creation), all templates from Phase 3, all reference docs from Phase 3]

Must-Haves:
Truths: [evaluate.md classifies Tier A/B/C and scaffolds milestone directory for B/C; roadmap.md generates phases with boundary maps and dependency graph; plan-phase.md produces task plans with zero-context enforcement; dispatch.md constructs scope-filtered context payload; detect-capabilities.sh outputs correct adapter name for each runtime environment (local-sequential, local-subprocess, gh-aw-ci, or override); verify.md runs 4-tier verification ladder; status.md derives progress entirely from disk state; all commands include $ARGUMENTS handling, scripts frontmatter, handoffs, and Gotchas section]
Artifacts: [commands/evaluate.md (min 80 lines), commands/roadmap.md (min 100 lines), commands/plan-phase.md (min 120 lines), commands/dispatch.md (min 100 lines), commands/verify.md (min 100 lines), commands/status.md (min 60 lines), scripts/dispatch/build-context.sh (min 40 lines), scripts/dispatch/scope-filter.sh (min 30 lines), scripts/dispatch/detect-capabilities.sh (min 20 lines), scripts/verify/check-must-haves.sh (min 50 lines), scripts/verify/check-boundary-map.sh (min 30 lines), scripts/verify/check-scope.sh (min 25 lines), scripts/verify/run-commands.sh (min 20 lines)]
Key Links: [evaluate.md → scaffold.sh (invokes for directory creation); roadmap.md → templates/roadmap.md (references via {TEMPLATE:roadmap}); plan-phase.md → templates/phase-plan.md + templates/task-plan.md; dispatch.md → build-context.sh + scope-filter.sh (constructs payload) + detect-capabilities.sh (selects runtime adapter); verify.md → check-must-haves.sh + check-boundary-map.sh + check-scope.sh + run-commands.sh; status.md → derive-phase.sh + read-roadmap.sh; all commands → extension.yml provides.commands (registered)]

### Verification & Dispatch Scripts

- [ ] T013 [P] [US2] Implement `scripts/dispatch/build-context.sh` — construct minimal dispatch payload per research.md R-005. Accept milestone ID, phase ID, task ID, and verbosity level. Assemble sections: task plan (full text), phase context (goal, demo sentence, must-haves), upstream dependency summaries (scope-filtered), relevant decisions, relevant knowledge, constitution principles, verification criteria. Enforce payload size guard (FR-050): measure line count, downgrade verbosity if exceeds 40% of context window estimate. Log verbosity downgrades to execution-log.jsonl.
- [ ] T014 [P] [US2] Implement `scripts/dispatch/scope-filter.sh` — filter KNOWLEDGE.md and DECISIONS.md entries by scope. Accept current milestone ID and phase ID. For KNOWLEDGE.md: include `[project]` + `[milestone:{current}]` + `[phase:{current}]` entries (FR-062). For DECISIONS.md: include current milestone + current phase + upstream deps + `scope: arch` entries (FR-063). Output filtered entries to stdout.
- [ ] T015 [P] [US2] Implement `scripts/verify/check-must-haves.sh` — mechanical verification of must-haves from phase/task plan. Accept plan file path. Parse must-haves YAML: check truths (grep for expected content), check artifacts (file exists, min_lines met, contains patterns), check key_links (from-file references to-file). Output structured results: pass/fail per check, overall status. Exit 0 on pass, exit 1 on fail.
- [ ] T016 [P] [US2] Implement `scripts/verify/check-boundary-map.sh` — verify cross-phase interface contracts. Accept milestone ID and phase ID. Read phase's boundary map from roadmap. For each `produces` entry: verify file exists, verify declared exports/types are present. For each `consumes` entry: verify upstream phase produced the artifact. Output structured report.
- [ ] T017 [P] [US2] Implement `scripts/verify/check-scope.sh` — enforce phase scope per FR-044/FR-045. Accept phase plan path. Compare `git diff --name-only` against phase plan's "files likely touched" list. Files outside scope → WARNING. Destructive operations (deletions, force-pushes) → BLOCK unless `destructive_ops_authorized` is set in plan. Output changed-file list with in-scope/out-of-scope classification.
- [ ] T018 [P] [US2] Implement `scripts/verify/run-commands.sh` — execute configurable verification commands from `orchestrator-config.yml` `verification_commands` list (FR-017). Read config via `read-config.sh`. Run each command, capture exit code and output. Output structured results: command, status (pass/fail), output snippet. Exit 0 if all pass, exit 1 if any fail.
- [ ] T028 [P] [US3] Implement `scripts/dispatch/detect-capabilities.sh` — detect active runtime adapter per contracts/runtime-adapter.md Adapter Selection. Check: (1) `GITHUB_ACTIONS` env var → output `gh-aw-ci`, (2) `SPECKIT_ORCHESTRATOR_ADAPTER` env var → output its value, (3) detect Agent tool availability → output `local-subprocess`, (4) default → output `local-sequential`. Output adapter name to stdout.

### Commands

- [ ] T019 [US1] Implement `commands/evaluate.md` — replace placeholder with full command. Frontmatter: description (trigger-phrased per FR-029), scripts (derive-phase.sh, scaffold.sh, read-config.sh), handoffs (→ discuss for Tier C, → roadmap for Tier B). User Input section: accept natural language project description via $ARGUMENTS. Workflow: (1) read config for default_tier override, (2) if $ARGUMENTS provided, classify scope as Tier A/B/C per FR-001 criteria, (3) Tier A → route to standard spec-kit with message, exit, (4) Tier B/C → invoke scaffold.sh to create milestone directory, (5) write {M###}-TIER.md with tier, feature_ref, classified_at, override fields, (6) output tier classification with rationale. Include tier override handling (FR-002). Gotchas section: known failure modes (scaffold exists, no spec found), context pollution (over-specifying tier criteria), anti-patterns (always defaulting to Tier C).
- [ ] T020 [P] [US2] Implement `commands/roadmap.md` — replace placeholder. Frontmatter: description, scripts (derive-phase.sh, read-config.sh), handoffs (→ plan-phase). Workflow: (1) verify state is `planning` via derive-phase.sh, (2) read spec from feature_ref, (3) decompose into phases with demo sentences (FR-006), dependency declarations, risk classifications (FR-043), boundary maps (FR-007/FR-008), (4) extract milestone-level success criteria from spec's Success Criteria section and populate `success_criteria` frontmatter list — these are consumed by `mark-complete.sh` (T038) to generate M###-VALIDATION.md, (5) output using {TEMPLATE:roadmap}, (6) write to `.specify/orchestrator/milestones/{M###}/M###-ROADMAP.md`. For Tier C: require finalized context draft. For Tier B: boundary maps optional, phases sequential by default. Include reassessment mode (FR-009/FR-061): when run on existing roadmap, compare completed phase outputs against downstream boundary maps; detect invalidation per FR-073 by comparing actual outputs vs downstream `consumes` declarations — mark stale any downstream phase whose plan references an interface or artifact that has changed. Gotchas section per plan Command Design Requirements.
- [ ] T021 [P] [US2] Implement `commands/plan-phase.md` — replace placeholder. Frontmatter: description, scripts (derive-phase.sh, read-roadmap.sh), handoffs (→ dispatch). Workflow: (1) identify next unplanned phase from roadmap, (2) read phase boundary map (produces/consumes), (3) load upstream phase summaries for consumed interfaces, (4) generate task decomposition (1-7 tasks per phase, FR-004), (5) each task must fit one context window (FR-005), (6) write must-haves per task (truths, artifacts, key_links), (7) enforce zero-context planning (FR-011): every file ref is absolute from repo root, every code ref includes file path + line range, phrases like "as before" PROHIBITED unless accompanied by specific path + excerpt, verification criteria must be copy-pasteable into fresh terminal, (8) output using {TEMPLATE:phase-plan} + {TEMPLATE:task-plan}, (9) write to `.specify/orchestrator/milestones/{M###}/phases/P##/P##-PLAN.md`. Gotchas section.
- [ ] T022 [US2] Implement `commands/dispatch.md` — replace placeholder. Frontmatter: description, scripts (build-context.sh, scope-filter.sh, derive-phase.sh, write-lock.sh), handoffs (→ verify). Workflow: (1) identify next incomplete task from phase plan, (2) invoke build-context.sh to construct payload (task plan + phase context + upstream summaries + decisions + knowledge + constitution + verification criteria), (3) detect runtime via detect-capabilities.sh, (4) dispatch via runtime adapter (local-sequential: print instructions inline, local-subprocess: invoke Agent tool), (5) on completion: collect result artifacts from working directory. Reference runtime adapter contract (contracts/runtime-adapter.md) for dispatch-task, await-completion, collect-result operations. Gotchas section: payload too large (verbosity downgrade), dispatch to wrong context (stale state), task exceeds context window.
- [ ] T023 [US2] Implement `commands/verify.md` — replace placeholder. Frontmatter: description, scripts (check-must-haves.sh, check-boundary-map.sh, check-scope.sh, run-commands.sh, check-external-mods.sh), handoffs (→ status or → auto). Workflow: (1) determine verification scope from $ARGUMENTS (task-level or phase-level), (2) per-task: run check-must-haves.sh + run-commands.sh (FR-016), (3) per-phase (after all tasks pass): run two-stage review — first spec compliance (FR-059: demo sentence achieved, boundary map contracts satisfied, no scope creep, aggregate must-haves), then code quality (FR-060: naming consistency, error handling patterns, test coverage, no TODO/FIXME), (4) output using {TEMPLATE:verification-report}, (5) log result to execution-log.jsonl with verification tier breakdown. Spec compliance must pass before code quality begins (FR-015). When invoked via hook (no $ARGUMENTS), infer verification scope from disk state: if active phase has all tasks done but no phase summary → phase-level review; if before_commit hook context → task-level static checks only (tier-1). Gotchas section: false positives from check-scope on generated files, two-stage review run out of order.
- [ ] T024 [US2] Implement `commands/status.md` — replace placeholder. Frontmatter: description, scripts (derive-phase.sh, read-roadmap.sh, read-config.sh). No handoffs (informational only). Workflow: (1) derive current state via derive-phase.sh, (2) read roadmap for phase completion counts, (3) read execution-log.jsonl for dispatch count and cumulative duration, (4) display: current state, milestone progress (phases done/total), active phase progress (tasks done/total), active blockers, next recommended action, budget status (dispatches used/budget, duration used/budget), tier classification. Must be derivable entirely from disk state (FR-039). Must support concurrent read access (FR-053). Offer rollback option for completed phases (FR-057). Gotchas section.

**Checkpoint**: All 6 Tier B commands functional. A developer can run evaluate → roadmap → plan-phase → dispatch → verify → status to orchestrate a multi-phase project with manual transitions. Scope triage correctly classifies A/B/C. Status reads disk state without side effects.

---

## Phase 5: Autonomous Mode — US3 Autonomous Dispatch + US5 Crash Recovery (Priority: P3, P5)

**Goal**: Implement the Tier C command surface — autonomous state machine loop, pre-planning discussion, crash recovery, and supporting scripts. After this phase, a developer can start autonomous execution and walk away.

**Independent Test**: Start autonomous mode on a project with a completed roadmap. Verify tasks dispatch sequentially, each in a fresh context, with must-have verification between each. Simulate a crash mid-phase (kill process). Restart and verify the orchestrator detects the stale lock, synthesizes a recovery briefing, and resumes from the correct point. Test graceful pause (write continue file) and resume.

Boundary Map:
Produces: [commands/auto.md, commands/discuss.md, commands/resume.md, scripts/state/check-lock.sh, scripts/lifecycle/write-lock.sh, scripts/lifecycle/write-continue.sh, scripts/verify/check-external-mods.sh]
Consumes: [scripts/state/derive-phase.sh (state derivation), scripts/dispatch/build-context.sh (payload), scripts/dispatch/detect-capabilities.sh (runtime detection), scripts/verify/check-must-haves.sh (verification), commands/dispatch.md (task dispatch), commands/verify.md (verification), commands/plan-phase.md (phase planning), templates/recovery-briefing.md, templates/continue-file.md, templates/context-draft.md]

Must-Haves:
Truths: [auto.md drives full state machine loop without human intervention; auto.md pauses within 1 dispatch cycle of budget threshold (SC-020); discuss.md routes to pre-planning mode in discussing state and decision injection mode in executing+ states; resume.md detects stale lock vs active session vs graceful pause; check-lock.sh distinguishes local PID from CI runtime liveness; stuck detection triggers within 2 dispatch cycles (SC-005)]
Artifacts: [commands/auto.md (min 150 lines), commands/discuss.md (min 80 lines), commands/resume.md (min 100 lines), scripts/state/check-lock.sh (min 25 lines), scripts/lifecycle/write-lock.sh (min 20 lines), scripts/lifecycle/write-continue.sh (min 25 lines), scripts/verify/check-external-mods.sh (min 25 lines)]
Key Links: [auto.md → derive-phase.sh (reads state each iteration); auto.md → dispatch.md (delegates task dispatch); auto.md → verify.md (delegates verification); auto.md → write-lock.sh (acquires/releases lock); auto.md → check-lock.sh (crash detection at startup); resume.md → check-lock.sh (stale lock detection); resume.md → templates/recovery-briefing.md (synthesis); discuss.md → templates/context-draft.md (pre-planning) + DECISIONS.md (injection)]

### Lifecycle & Detection Scripts

- [ ] T025 [P] [US5] Implement `scripts/state/check-lock.sh` — check lock file status per contracts/state-files.md Lock File Format. Accept no arguments (reads `.specify/orchestrator/orchestrator.lock`). Output: `none` (no lock), `active` (PID alive or CI run in_progress), `stale` (PID dead or CI run completed/failed). Runtime discriminator: read `runtime` field — `local` → `kill -0 $pid`, `ci-github` → `gh api` status check, unknown → treat as stale. Output lock metadata (unitId, unitType, startedAt) when lock exists.
- [ ] T026 [P] [US3] Implement `scripts/lifecycle/write-lock.sh` — create or update lock file per contracts/state-files.md Lock File Format. Accept unitType and unitId as arguments. Write JSON with: schema_version, pid ($$), runtime (detect from env: GITHUB_ACTIONS → ci-github, else → local), startedAt, unitType, unitId, unitStartedAt, completedUnits (read from existing lock or empty), featureBranch (from git), phase_start_tree (from `git write-tree` when unitType starts a new phase). Use temp-file-then-mv for atomic writes (R-016 concurrent access safety).
- [ ] T027 [P] [US5] Implement `scripts/lifecycle/write-continue.sh` — write structured continue file for graceful pause per data-model.md Continue File format. Accept milestone, phase, task, step, total_steps as arguments. Write YAML frontmatter + markdown body with: Completed Work (from execution-log.jsonl), Remaining Work (from phase plan), Decisions Made (from DECISIONS.md session entries), Context (current state summary), Next Action (exact first thing to do on resume). Write to `.specify/orchestrator/continue.md`.
- [ ] T029 [P] [US5] Implement `scripts/verify/check-external-mods.sh` — detect external modifications at phase boundary per FR-064. Accept milestone ID and phase ID. Read `phase_start_tree` from lock file. Compare current working tree against snapshot: `git diff --name-only $phase_start_tree HEAD`. Filter out files in the phase plan's declared scope. Remaining changes = external modifications. Output: list of externally modified files, or "none". Exit 0 if none, exit 2 if detected (pause signal).

### Commands

- [ ] T030 [US3] Implement `commands/auto.md` — replace placeholder. Frontmatter: description, scripts (derive-phase.sh, check-lock.sh, write-lock.sh, build-context.sh, detect-capabilities.sh, read-config.sh), handoffs (→ plan-phase, → dispatch, → verify, → status). Workflow: (1) check for existing lock via check-lock.sh — if active, abort with message; if stale, trigger resume flow, (2) acquire lock via write-lock.sh, (3) enter state machine loop: read state via derive-phase.sh, match dispatch table (R-002) — pre-planning→prompt evaluate, discussing→prompt discuss, planning→invoke plan-phase, executing→invoke dispatch+verify, summarizing→generate phase summary, validating→milestone gate, completing→milestone summary, complete→stop, (4) per-task cycle: dispatch → verify must-haves → run verification commands → persist task summary → next task, (5) per-phase cycle: all tasks verified → spec compliance review → code quality review → phase summary → roadmap reassessment (invoke roadmap.md in reassessment mode; when reassessment detects invalidation per FR-061/FR-073 criteria, mark downstream phases stale → state machine enters `replanning` state and re-plans affected phases before next dispatch), (6) budget check before each dispatch (FR-065): read dispatch_budget/duration_budget from config, compare against execution-log.jsonl totals — pause if threshold reached, (7) stuck detection (FR-022): if same unitId dispatched twice without new artifacts → stop and report, (8) DONE_WITH_CONCERNS handling (US3-scenario 6): when a task returns `done_with_concerns` status, evaluate concern type — if concerns affect correctness or scope, address before proceeding; if observational (e.g., "file growing large"), note in task summary and continue, (9) on clean completion or pause: release lock. CI mode (step): advance one unit per run, persist, exit. Gotchas: budget threshold crossed mid-phase, stuck detection false positive on slow tasks, lock file corruption.
- [ ] T031 [US3] Implement `commands/discuss.md` — replace placeholder. Frontmatter: description, scripts (derive-phase.sh, append-decision.sh), handoffs (→ roadmap from pre-planning, → auto from decision injection). Two modes selected by state (FR-052/FR-056): **Pre-planning mode** (state ∈ {pre-planning, discussing}): create/update `{M###}-CONTEXT.md` using {TEMPLATE:context-draft}. Present targeted questions about architectural preferences, scope boundaries, design constraints. Finalization sets `status: finalized` in frontmatter → triggers discussing→planning transition. Required gate for Tier C, optional for Tier B. **Decision injection mode** (state ∈ {executing, summarizing, validating, completing}): accept decision text via $ARGUMENTS, append entry to DECISIONS.md with sequential ID, current scope (M###/P##), scope tag, and rationale. Decision picked up at next phase boundary. Gotchas: running discuss in wrong mode, injecting decisions that contradict existing ones.
- [ ] T032 [US5] Implement `commands/resume.md` — replace placeholder. Frontmatter: description, scripts (check-lock.sh, derive-phase.sh, read-config.sh), handoffs (→ auto). Workflow: (1) check for continue file at `.specify/orchestrator/continue.md` — if exists: read resume point, delete file (consumed, FR-048), proceed from Next Action field, (2) check for stale lock via check-lock.sh — if stale: read lock metadata (what was attempted), examine disk (does task have summary? → completed before crash), synthesize recovery briefing using {TEMPLATE:recovery-briefing} from: lock file (attempted unit), git diff (changes made), execution-log.jsonl (last entries), (3) determine resume state via derive-phase.sh, (4) hand off to auto.md for continued execution. Distinguish graceful pause (continue file, no stale lock) from crash (stale lock, no continue file) per FR-049. Gotchas: continue file from wrong milestone, lock from active session misidentified as stale.

**Checkpoint**: Autonomous mode operational. Start auto → tasks dispatch and verify without intervention → milestone completes or blocker surfaces. Crash recovery detects stale locks and resumes cleanly. Graceful pause writes continue file and resumes exactly.

---

## Phase 6: Knowledge & Lifecycle — US4 Knowledge Generation + US6 Consolidation (Priority: P4, P6)

**Purpose**: Implement knowledge management scripts and the consolidation command. This phase can run in parallel with Phase 5 (plan dependency: Phase 5 ∥ Phase 6).

**Goal**: Every completed phase produces structured documentation. Completed milestones can be consolidated into optimized summaries with raw artifacts archived.

**Independent Test**: Complete a phase and verify task/phase summaries exist with correct frontmatter. Append a decision and verify DECISIONS.md has the new row. Run consolidation on a completed milestone and verify compressed summaries exist, raw artifacts archived, critical info preserved.

Boundary Map:
Produces: [scripts/knowledge/write-summary.sh, scripts/knowledge/append-decision.sh, scripts/knowledge/append-knowledge.sh, scripts/knowledge/consolidate-artifacts.sh, scripts/lifecycle/rollback-phase.sh, scripts/lifecycle/mark-complete.sh, commands/consolidate.md]
Consumes: [templates/task-summary.md, templates/phase-summary.md, templates/milestone-summary.md (summary formats), contracts/state-files.md (DECISIONS.md, KNOWLEDGE.md formats), scripts/state/read-roadmap.sh (phase status for rollback)]

Must-Haves:
Truths: [write-summary.sh produces summaries matching data-model.md schema (14-field frontmatter); append-decision.sh creates sequential D### IDs and never modifies existing rows; append-knowledge.sh includes scope tags per FR-062; consolidate-artifacts.sh reduces on-disk footprint by ≥60% (SC-011); rollback-phase.sh preserves prior summary in archive/ (FR-058) and flags downstream deps]
Artifacts: [scripts/knowledge/write-summary.sh (min 40 lines), scripts/knowledge/append-decision.sh (min 20 lines), scripts/knowledge/append-knowledge.sh (min 20 lines), scripts/knowledge/consolidate-artifacts.sh (min 50 lines), scripts/lifecycle/rollback-phase.sh (min 40 lines), scripts/lifecycle/mark-complete.sh (min 25 lines), commands/consolidate.md (min 80 lines)]
Key Links: [write-summary.sh → templates/task-summary.md + templates/phase-summary.md + templates/milestone-summary.md; append-decision.sh → DECISIONS.md (append-only); rollback-phase.sh → read-roadmap.sh (dependency graph for downstream flagging); consolidate.md → consolidate-artifacts.sh; mark-complete.sh → read-roadmap.sh (toggle checkbox)]

### Knowledge Scripts

- [ ] T033 [P] [US4] Implement `scripts/knowledge/write-summary.sh` — generate task, phase, or milestone summary. Accept unit type (task|phase|milestone), unit ID, milestone ID, and plan file path. Read completed work artifacts from disk. Populate 14-field YAML frontmatter per data-model.md summary schema: schema_version, id, parent, milestone, provides (~5 items), requires (upstream deps consumed), affects (downstream IDs), key_files, key_decisions, patterns_established, drill_down_paths, duration, verification_result, completed_at. Write markdown body: one-liner summary, What Happened, Deviations, Files Created/Modified. For phase summaries: compressed rollup of all task summaries with drill_down_paths. For milestone: rollup of phase summaries. Use temp-file-then-mv for atomic writes.
- [ ] T034 [P] [US4] Implement `scripts/knowledge/append-decision.sh` — append entry to DECISIONS.md per contracts/state-files.md format. Accept: scope (M###/P##/T##), decision_scope (arch|pattern|library|data|api|scope|convention), decision question, choice, rationale, revisable. Auto-generate sequential D### ID by reading last entry. Append new row to markdown table. For reversals: accept original ID and prefix Choice with "Reverses D###:". Append is atomic on POSIX for writes ≤ PIPE_BUF. Never edit existing rows.
- [ ] T035 [P] [US4] Implement `scripts/knowledge/append-knowledge.sh` — append entry to KNOWLEDGE.md per contracts/state-files.md format. Accept: scope_tag (project|milestone:M###|phase:M###/P##), description text. Format: `- **[scope_tag]** [YYYY-MM-DD] Description`. Append to end of file. Check for exact duplicate before appending (idempotency, FR-066).
- [ ] T036 [P] [US6] Implement `scripts/knowledge/consolidate-artifacts.sh` — compress and archive milestone artifacts per FR-027. Accept milestone ID. Workflow: (1) verify all phases complete, (2) for each phase: compress task summaries into phase summary (if not already compressed), (3) compress phase summaries into milestone summary, (4) verify no information loss: all decisions preserved, all boundary map contracts preserved, all patterns preserved — flag any loss, (5) move raw task/phase artifacts to `archive/` subdirectories, (6) keep compressed summaries in place for future context loading. Target: ≥60% on-disk footprint reduction (SC-011).
- [ ] T037 [P] [US5] Implement `scripts/lifecycle/rollback-phase.sh` — roll back a completed phase per FR-057/FR-058. Accept milestone ID and phase ID. Workflow: (1) move `P##-SUMMARY.md` to `archive/P##-SUMMARY-{timestamp}.md` (preserve, don't delete), (2) append reversal decision to DECISIONS.md via append-decision.sh referencing original completion decision, (3) scan roadmap dependency graph: find downstream phases that consumed this phase's boundary map outputs → mark them `stale` in roadmap frontmatter, (4) log rollback event to execution-log.jsonl, (5) require developer confirmation before flagged downstream phases re-execute. Prior summaries and task summaries preserved for historical reference.
- [ ] T038 [P] [US4] Implement `scripts/lifecycle/mark-complete.sh` — trigger state transitions by creating/updating completion artifacts. Accept unit type (task|phase|milestone) and unit ID. For tasks: verify task summary exists (no-op if so). For phases: toggle roadmap checkbox from `[ ]` to `[x]`, verify phase summary exists. For milestones: verify milestone summary exists; for Tier C, create `M###-VALIDATION.md` with success criteria checklist from the roadmap (YAML frontmatter: `schema_version`, `milestone`, `status`, `validated_at`, `validator`; body: one checkbox per success criterion with evidence reference) per contracts/state-files.md Milestone Validation Format. Idempotent (FR-066).

### Commands

- [ ] T039 [US6] Implement `commands/consolidate.md` — replace placeholder. Frontmatter: description (trigger-phrased), scripts (consolidate-artifacts.sh, read-roadmap.sh, derive-phase.sh), handoffs (none — terminal command). Workflow: (0) read tier from `{M###}-TIER.md`; if Tier B, exit with message "consolidation excluded per FR-054" — Tier B does not use knowledge consolidation, (1) verify milestone is complete via derive-phase.sh, (2) display pre-consolidation inventory (file count, total size), (3) invoke consolidate-artifacts.sh, (4) verify information preservation: all decisions from DECISIONS.md scoped to this milestone are in compressed summary, all boundary map contracts preserved, all patterns in KNOWLEDGE.md preserved, (5) report: files archived, space saved, any flagged information loss, (6) if git_isolation active: merge worktree branch back, remove worktree. Update SKILL.md at milestone boundaries per AD-6 release checklist. Gotchas: consolidating incomplete milestone, information loss on overly aggressive compression, worktree merge conflicts.

**Checkpoint**: Knowledge pipeline complete. Every completed task/phase/milestone produces structured summaries. Decisions and knowledge are append-only with scope tags. Consolidation reduces footprint while preserving critical information. Rollback preserves history and flags dependencies.

---

## Phase 7: Distribution & Testing — US7 GitHub AW + US8 APM Packaging (Priority: P7, P8)

> **Runtime strategy note**: `local-sequential` + `local-subprocess` are the two runtime strategies for SC-007 (v0.1.0). Cross-agent validation (Claude Code + one other spec-kit-supported agent) requires manual testing — automated tests validate adapter contracts and capability detection, not end-to-end multi-agent scenarios.

**Purpose**: Package the extension for distribution and create integration tests that validate the complete orchestration workflow.

**Goal**: The orchestrator is installable via `apm install speckit-orchestrator` or `specify extension add`, with comprehensive test coverage for all critical paths.

**Independent Test**: Run `apm install speckit-orchestrator` in a fresh project → verify all commands registered. Run the BATS test suite → all tests pass. Run quickstart.md scenarios end-to-end.

Boundary Map:
Produces: [apm.yml, SKILL.md, .extensionignore, docs/getting-started.md, docs/configuration.md, tests/test-*.sh (13 test files), tests/fixtures/ (sample state trees)]
Consumes: [all commands, scripts, templates, references from Phases 1-6; extension.yml (manifest); orchestrator-config.yml (config template); quickstart.md (validation scenarios)]

Must-Haves:
Truths: [apm.yml name/version/description match extension.yml; SKILL.md uses trigger-phrased descriptions per FR-029; .extensionignore excludes specs/, docs/, .planning/, tests/unit/; all 13 test files execute without error against fixture data; test-tier-surface.sh confirms Tier A=zero files, Tier B<half Tier C files (SC-008, SC-017)]
Artifacts: [apm.yml, SKILL.md, .extensionignore, docs/getting-started.md, docs/configuration.md, tests/test-scaffold.sh, tests/test-state-derivation.sh, tests/test-config-resolution.sh, tests/test-scope-filter.sh, tests/test-tier-surface.sh, tests/test-budget-enforcement.sh, tests/test-rollback.sh, tests/test-external-mods.sh, tests/test-two-stage-review.sh, tests/test-capability-detection.sh, tests/test-concurrent-access.sh, tests/test-dispatch-adapter.sh, tests/test-spec-propagation.sh, tests/fixtures/ (with state trees for all 9 states)]
Key Links: [apm.yml name/version ↔ extension.yml extension.name/version (must match, plan Manifest Authority Boundaries); SKILL.md command descriptions ↔ extension.yml provides.commands descriptions; .extensionignore patterns ↔ plan.md .extensionignore description; tests → scripts (test targets)]

### Distribution Artifacts

- [ ] T040 [P] [US8] Create `apm.yml` manifest per plan.md apm.yml section — name: speckit-orchestrator, version: 0.1.0, type: hybrid, target: all, description matching extension.yml, compilation.exclude for `.specify/orchestrator/**`, dependencies: [spec-kit], scripts: { status, verify, scaffold } with bash paths. Verify name/version/description consistency with extension.yml (plan Manifest Authority Boundaries).
- [ ] T041 [P] [US8] Create `SKILL.md` — root-level package summary per AD-6. Trigger-phrased description (FR-029). Sections: What It Does (orchestration overview), Commands (all 10 with trigger-phrased one-liners matching extension.yml), Quick Start (link to docs/getting-started.md), Configuration (link to docs/configuration.md), Tier Summary (A/B/C one-liner descriptions). Manually maintained, updated at milestone boundaries.
- [ ] T042 [P] [US8] Create `.extensionignore` — exclude from extension install: `specs/`, `docs/`, `.planning/`, `tests/`, `*.test.sh`, `conversus*/`, `.github/`. Keep: `commands/`, `scripts/`, `templates/`, `references/`, `extension.yml`, `apm.yml`, `SKILL.md`, `orchestrator-config.yml`.

### Documentation

- [ ] T043 [P] Create `docs/getting-started.md` — expand on quickstart.md with detailed walkthrough. Sections: Prerequisites, Installation (3 methods: spec-kit extension, APM, manual), First Run (evaluate → tier classification → config prompt), Tier B Workflow (step-by-step), Tier C Workflow (step-by-step with autonomous mode), Directory Structure (what gets created where), Troubleshooting (common issues).
- [ ] T044 [P] Create `docs/configuration.md` — full configuration reference. Sections: Config File Locations (4-layer precedence), All Config Keys (default_tier, verification_commands, context_verbosity, git_isolation, dispatch_budget, duration_budget, budget_enforcement — each with type, default, description, examples), Environment Variable Overrides (naming pattern, examples), CI Configuration (adapter selection, repo-memory, concurrency), Advanced (payload size guard threshold, context window estimate override).

### Integration Tests

- [ ] T045 [P] Create `tests/test-scaffold.sh` and `tests/fixtures/` — test FR-042 scaffolding and FR-066 idempotency. Fixtures: empty project, pre-scaffolded milestone, milestone with phases. Tests: scaffold creates correct directory tree, scaffold is idempotent (run twice → same output, SC-018), scaffold with git_isolation creates worktree, scaffold preserves existing global files (DECISIONS.md, KNOWLEDGE.md).
- [ ] T046 [P] Create `tests/test-state-derivation.sh` — test FR-020 state machine. Fixtures: state trees representing all 9 states. Tests: derive-phase.sh outputs correct state for each fixture, tier-conditional derivation (Tier B skips discussing/replanning/validating/completing), performance (<1s for 10-phase milestone), crash state detection (lock file + stale PID → identifies recovery state). Include idempotency assertion (SC-018): running derive-phase.sh twice in succession produces identical output.
- [ ] T047 [P] Create `tests/test-config-resolution.sh` — test FR-040/FR-041 config precedence. Tests: extension defaults used when no overrides, project config overrides defaults, local config overrides project, env vars override all, missing config files handled gracefully, per-invocation override does not modify stored config. Include idempotency assertion (SC-018): running read-config.sh twice in succession produces identical output and no side effects.
- [ ] T048 [P] Create `tests/test-scope-filter.sh` — test FR-062/FR-063 knowledge scoping. Fixtures: KNOWLEDGE.md with 50+ entries across project/milestone/phase scopes, DECISIONS.md with entries across scopes including arch-tagged ones. Tests: scope-filter.sh includes only matching scope entries (SC-019), project-scoped entries always included, arch-scoped decisions included milestone-wide, unrelated phase entries excluded. Include SC-002 validation: measure total entries vs filtered entries, assert filtered output is <20% of total. Include SC-006 note: compare raw vs filtered payload size to demonstrate knowledge artifacts reduce context payload.
- [ ] T049 [P] Create `tests/test-tier-surface.sh` — test FR-003/FR-054 tier behavior differentiation. Tests: Tier A produces zero orchestrator files (SC-008), Tier B completes with fewer than half Tier C state files (SC-017), Tier B skips discussing/replanning/validating/completing states, Tier C includes all states and requires finalized context draft.
- [ ] T050 [P] Create `tests/test-budget-enforcement.sh` — test FR-065 budget awareness. Fixtures: execution-log.jsonl with dispatch entries near budget threshold. Tests: budget check pauses within 1 dispatch cycle of threshold (SC-020), advisory mode warns but allows resume, duration_budget calculated correctly from log entries, no budget configured → no pause. Include idempotency assertion (SC-018): running budget check twice on the same log produces identical results.

> **SC-018 coverage**: Idempotency assertions are distributed across T045 (scaffold), T046 (state derivation), T047 (config resolution), and T050 (budget enforcement) — covering the primary write and read paths.
- [ ] T051 [P] Create `tests/test-rollback.sh` — test FR-057/FR-058 phase rollback. Fixtures: completed milestone with phase summaries. Tests: rollback preserves prior summary in archive/ (SC-016), reversal decision appended to DECISIONS.md with original ID reference, downstream dependent phases flagged stale, rollback is logged in execution-log.jsonl.
- [ ] T052 [P] Create `tests/test-external-mods.sh` — test FR-064 external modification detection. Tests: external mods detected at phase boundary when files outside declared scope change, phase_start_tree comparison works correctly, no false positives for in-scope file changes, pause signal (exit 2) emitted when external mods detected.
- [ ] T052a [P] Create `tests/test-two-stage-review.sh` — test FR-059/FR-060 two-stage review. Tests: spec compliance review catches missing demo sentence and boundary map violations, code quality review flags naming inconsistency and TODO/FIXME leftovers, spec compliance must pass before code quality begins, review results logged to execution-log.jsonl with verification tier breakdown.
- [ ] T053 [P] Create `tests/test-capability-detection.sh` — test FR-046 capability detection. Tests: detects local-sequential as default, detects local-subprocess when Agent tool available, detects gh-aw-ci when GITHUB_ACTIONS set, respects SPECKIT_ORCHESTRATOR_ADAPTER override, works correctly on at least two runtimes (SC-007).
- [ ] T053a [P] Create `tests/test-concurrent-access.sh` — test FR-053 concurrent access safety. Tests: status command reads state without corruption while lock file exists (SC-013), decision injection via discuss.md does not corrupt running execution state, concurrent reads of DECISIONS.md and KNOWLEDGE.md are safe.
- [ ] T053b [P] Create `tests/test-dispatch-adapter.sh` — test FR-067/FR-068 dispatch adapter contract. Tests: all 5 core operations (dispatch-task, await-completion, collect-result, signal-failure, inject-context) implemented for local-sequential adapter, no conditional branches on runtime identity in core dispatch/verification/state logic, adapter-internal optimizations are invisible to orchestrator core.
- [ ] T054 [P] Create `tests/test-spec-propagation.sh` and end-to-end validation — test FR-073 spec propagation (boundary map changes trigger downstream re-planning). Execute `quickstart.md` scenarios against the complete extension. Verify: Tier B workflow completes (evaluate → roadmap → plan-phase → dispatch → verify → status → complete), Tier C workflow completes (evaluate → discuss → roadmap → auto → consolidate), crash recovery works (kill mid-phase → resume → completes), status shows correct progress from second terminal. Fix any integration issues discovered.

**Checkpoint**: Extension packaged for distribution. All integration tests pass. Quickstart scenarios execute end-to-end. apm.yml and extension.yml are consistent.

---

## Deferred Work

Tasks explicitly deferred from v0.1.0. Tracked here for traceability.

- [ ] T055 [DEFERRED] [US7] **GitHub Agentic Workflows runtime** — Implement the `gh-aw-ci` runtime adapter per contracts/runtime-adapter.md. Create GitHub workflow files for scheduled/issue-triggered orchestration (US7 acceptance scenarios 1-2). Requires: all core commands from Phases 4-6. Deferred because: US7 acceptance scenario 3 (local works without GH AW) is satisfied by the local adapters; CI runtime is additive capability.

---

## Dependencies & Execution Order

### Phase Dependencies

```text
Phase 1 (Setup)
    ↓
Phase 2 (Foundation) — BLOCKS all command phases
    ↓
Phase 3 (Design Artifacts) — BLOCKS command implementation (templates needed)
    ↓
Phase 4 (Core Commands — US1+US2) — Tier B MVP
    ↓
    ├── Phase 5 (Autonomous Mode — US3+US5) ── ┐
    │                                           ├── Phase 7 (Distribution)
    └── Phase 6 (Knowledge — US4+US6) ─────────┘
```

- **Phase 1 → Phase 2**: Foundation scripts need directory structure and validated manifest
- **Phase 2 → Phase 3**: Templates reference file formats defined by foundation scripts
- **Phase 3 → Phase 4**: Commands reference templates via `{TEMPLATE:name}`
- **Phase 4 → Phase 5**: Autonomous mode composes core commands (dispatch, verify, plan-phase)
- **Phase 4 → Phase 6**: Knowledge scripts are called by core commands (write-summary, append-decision)
- **Phase 5 ∥ Phase 6**: Can run in parallel — no mutual dependency
- **Phase 5 + Phase 6 → Phase 7**: Distribution and testing require all commands and scripts complete

### User Story Dependencies

- **US1 (Scope Triage)**: Depends on Phase 2 foundation. Implemented in Phase 4.
- **US2 (Phase Execution)**: Depends on US1 (evaluate → roadmap). Implemented in Phase 4.
- **US3 (Autonomous Dispatch)**: Depends on US2 (composes core commands). Implemented in Phase 5.
- **US4 (Knowledge)**: Depends on Phase 2 foundation. Implemented in Phase 6 (parallel with Phase 5).
- **US5 (Crash Recovery)**: Depends on US3 (recovery from autonomous mode). Implemented across Phase 5 + Phase 6.
- **US6 (Consolidation)**: Depends on US4 (knowledge artifacts to consolidate). Implemented in Phase 6.
- **US7 (GitHub AW)**: Adapter only — depends on all core commands. Placeholder in Phase 7 (future).
- **US8 (APM Packaging)**: Depends on all artifacts existing. Implemented in Phase 7.

### Within Each Phase

- Scripts before commands (commands reference scripts via `{SCRIPT}` placeholders)
- Templates before commands (commands reference templates via `{TEMPLATE:name}`)
- All `[P]`-marked tasks can run in parallel within their phase
- Non-`[P]` tasks must wait for their dependencies

### Parallel Opportunities

- **Phase 3**: All 5 template/reference tasks are [P] — can run simultaneously
- **Phase 4 scripts**: All 6 verification/dispatch scripts are [P]
- **Phase 4 commands**: roadmap.md and plan-phase.md are [P] (different files, no mutual dependency)
- **Phase 5 scripts**: All 5 lifecycle/detection scripts are [P]
- **Phase 5 + Phase 6**: Entire phases can run in parallel
- **Phase 6 scripts**: All 6 knowledge/lifecycle scripts are [P]
- **Phase 7**: All distribution, documentation, and test tasks are [P]

---

## Skill Category Mapping

The orchestrator's command surface maps to 6 logical skill categories. These are NOT separate folder deliverables — they are cross-cutting concerns implemented across the flat command/script layout per AD-6 and the plan's project structure.

| Skill Category | Primary Command | Supporting Scripts | Templates | References |
|---------------|----------------|-------------------|-----------|------------|
| **orchestrator-auto** (Business Process) | auto.md | derive-phase.sh, write-lock.sh, detect-capabilities.sh, build-context.sh | dispatch-prompt.md | state-machine.md |
| **orchestrator-verify** (Verification) | verify.md | check-must-haves.sh, check-boundary-map.sh, check-scope.sh, run-commands.sh, check-external-mods.sh | verification-report.md, spec-compliance-review.md | verification-ladder.md |
| **orchestrator-scaffold** (Scaffolding) | evaluate.md | scaffold.sh, read-config.sh | roadmap.md, context-draft.md | tier-definitions.md |
| **orchestrator-review** (Code Quality) | verify.md (two-stage) | check-scope.sh | spec-compliance-review.md | verification-ladder.md |
| **orchestrator-recover** (Runbook) | resume.md | check-lock.sh, write-continue.sh | recovery-briefing.md, continue-file.md | state-machine.md |
| **orchestrator-status** (Data & Analysis) | status.md | derive-phase.sh, read-roadmap.sh, read-config.sh | — | tier-definitions.md |

---

## Parallel Example: Phase 4 Core Commands

```text
# Wave 1 — All verification & dispatch scripts (independent files):
scripts/dispatch/build-context.sh    [T013]
scripts/dispatch/scope-filter.sh     [T014]
scripts/dispatch/detect-capabilities.sh [T028]
scripts/verify/check-must-haves.sh   [T015]
scripts/verify/check-boundary-map.sh [T016]
scripts/verify/check-scope.sh        [T017]
scripts/verify/run-commands.sh       [T018]

# Wave 2 — Commands that depend on Wave 1 scripts:
commands/evaluate.md                 [T019] (depends: scaffold.sh from Phase 2)
commands/roadmap.md                  [T020] (parallel with T021)
commands/plan-phase.md               [T021] (parallel with T020)

# Wave 3 — Commands that reference Wave 1 scripts directly:
commands/dispatch.md                 [T022] (depends: T013 build-context)
commands/verify.md                   [T023] (depends: T015-T018 check scripts)
commands/status.md                   [T024] (depends: Phase 2 state scripts)
```

---

## Implementation Strategy

### MVP First (Phases 1–4 Only)

1. Complete Phase 1: Setup — directory structure, manifest validation
2. Complete Phase 2: Foundation — state machine, config, scaffolding
3. Complete Phase 3: Design Artifacts — all templates and reference docs
4. Complete Phase 4: Core Commands — evaluate, roadmap, plan-phase, dispatch, verify, status
5. **STOP AND VALIDATE**: Test Tier B workflow end-to-end (evaluate → roadmap → plan-phase → dispatch → verify → status)
6. Deploy as Tier B-only extension if ready

### Incremental Delivery

1. **Phases 1-4** → Tier B operational — manual phase transitions, structured handoff (**MVP**)
2. **+ Phase 5** → Tier C operational — autonomous dispatch, crash recovery, discussion
3. **+ Phase 6** → Knowledge pipeline — summaries, decisions, consolidation, rollback
4. **+ Phase 7** → Distributable — APM packaging, integration tests, documentation
5. Each increment adds value without breaking previous capability

### Parallel Team Strategy

With multiple developers after Phase 4 completes:
- **Developer A**: Phase 5 (Autonomous Mode — auto.md, discuss.md, resume.md, lifecycle scripts)
- **Developer B**: Phase 6 (Knowledge — write-summary.sh, append-*.sh, consolidate.md, rollback)
- Both complete → **Developer C**: Phase 7 (Distribution, tests, docs)

---

## Notes

- **[P]** tasks = different files, no dependencies on incomplete tasks in same phase
- **[US#]** label maps task to spec.md user story for traceability
- All commands must include: `$ARGUMENTS` handling, `scripts` frontmatter, `handoffs`, `## Gotchas` section (per plan Command Design Requirements)
- All scripts must start with `set -euo pipefail` (per research.md R-018)
- All state file writes must use temp-file-then-mv for atomic writes (per research.md R-016)
- All append operations use `>>` redirection (atomic on POSIX ≤ PIPE_BUF)
- All state files include `schema_version: 1` in frontmatter (per research.md R-019)
- Templates are structural shells — NO embedded orchestrator context (FR-074)
- Commands reference templates via `{TEMPLATE:name}` and scripts via `{SCRIPT}`
- Commit after each task or logical group
- Stop at any checkpoint to validate independently
