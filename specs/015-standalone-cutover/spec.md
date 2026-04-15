# Feature Specification: Standalone Cutover

**Feature Branch**: `015-standalone-cutover`
**Created**: 2026-04-15
**Status**: Draft
**Input**: User description: "Remove the spec-kit extension host (extension.yml, hooks, command wrappers, dogfooded spec-kit slash commands, spec-kit templates and scripts), reframe documentation from 'spec-kit extension' to 'standalone orchestrator', migrate orchestrator state from .specify/orchestrator/ to .orchestrator/, and validate end-to-end via orchestrator-auto in Claude Code native with no spec-kit installed. Single hard-cutover milestone executed before M009 launch. Spec-kit migration adapters stay (they exist for users coming FROM spec-kit)."

## Problem Statement

Through M008, the orchestrator became a multi-runtime standalone tool with adaptive intensity, backend-agnostic dispatch, and a 5-rule state-root resolver that includes a `.specify/orchestrator/` bridge for spec-kit hosting. M003 then validated the migration tool end-to-end via `orchestrator-auto` in Claude Code native mode, confirming the standalone path works.

Two pieces of legacy remain:

1. **The spec-kit extension host is still wired up.** `extension.yml` registers the orchestrator as a spec-kit extension with 12 commands and 5 lifecycle hooks. The project's own `.claude/commands/` directory contains 9 dogfooded spec-kit slash commands. `.specify/scripts/bash/` and `.specify/templates/` hold spec-kit's helper scripts and templates. Documentation across `README.md`, `CLAUDE.md`, `references/`, and `docs/` frames the orchestrator as "a spec-kit extension."

2. **Orchestrator state still lives under `.specify/orchestrator/`.** While the resolver supports five roots, the live state in this repo uses the spec-kit bridge path, and `.specify/memory/constitution.md` mixes spec-kit's directory convention with orchestrator-owned content. The bridge code (resolver rule 4) exists only to support this in-place state.

Carrying this dual posture indefinitely violates the project's no-graceful-degradation rule (per M007) and obscures the standalone narrative needed for M009 launch. A single hard cutover removes the host, reframes the docs, migrates state, and drops the bridge — leaving the orchestrator unambiguously standalone before launch artifacts are produced.

The cutover must preserve one thing: the spec-kit-aware migration adapters (`scripts/migrate/adapters/speckit.sh`, `scripts/state/detect-speckit.sh`, `scripts/dispatch/adapters/format/speckit.sh`) and `commands/migrate.md`. These exist *because* of M003 — they help users coming *from* spec-kit adopt the orchestrator. They are migration sources, not runtime dependencies, and they stay.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Install Orchestrator With No Spec-Kit Present (Priority: P1)

A developer with a fresh Claude Code installation and no spec-kit installed adopts the orchestrator. They follow the documented install flow, run `orchestrator:init` in their project, and complete a full orchestrated workflow (evaluate → roadmap → plan-phase → auto). At no point does any command, script, or instruction reference spec-kit, `.specify/`, or extension manifests. The experience is unambiguously a standalone tool.

**Why this priority**: This is the post-M015 launch story. M009 will market the orchestrator as a standalone tool; the orchestrator must actually behave that way for a developer with no spec-kit context. If `extension.yml` still exists or docs still call it "a spec-kit extension," the launch narrative is broken on first contact.

**Independent Test**: Can be tested by cloning the repo into a fresh environment without spec-kit installed and running the full orchestrator workflow, verifying that no command output, error message, or required file references spec-kit.

**Acceptance Scenarios**:

1. **Given** a fresh repo clone with no spec-kit installed, **When** the developer reads `README.md`, **Then** the document describes the orchestrator as a standalone tool with no required runtime dependency on spec-kit.
2. **Given** a fresh repo clone, **When** the developer runs `orchestrator:init`, **Then** init completes successfully and produces standalone configuration without referencing spec-kit conventions.
3. **Given** init has completed, **When** the developer runs the full evaluate → roadmap → plan-phase → auto sequence, **Then** all commands execute successfully with no errors that reference missing spec-kit dependencies.
4. **Given** the developer inspects the project root, **When** they look for legacy entry points, **Then** there is no `extension.yml`, no `.specify/scripts/bash/`, no `.specify/templates/`, and no `speckit.*.md` slash commands installed by the project itself.

---

### User Story 2 - Orchestrator State Lives at `.orchestrator/` (Priority: P1)

A developer initializing an orchestrator project sees state created at `.orchestrator/` by default — the canonical standalone location. The 5-rule state-root resolver no longer falls through to `.specify/orchestrator/` as a bridge, because that bridge served only the spec-kit hosting model that has been removed. Existing project state in this repo is migrated from `.specify/orchestrator/` to `.orchestrator/` in the same change, with the orchestrator-owned constitution moved to `.orchestrator/memory/constitution.md`.

**Why this priority**: State location is part of the standalone identity. Continuing to write state under `.specify/` after removing the spec-kit host creates cognitive dissonance for new users and leaves dead code in the resolver. The migration must happen in lock-step with host removal so the project never sits in a half-cutover state.

**Independent Test**: Can be tested by running migration scripts on this repo, verifying state moves cleanly, the resolver no longer references the bridge rule, and `orchestrator-doctor` reports no missing artifacts.

**Acceptance Scenarios**:

1. **Given** the project state currently lives at `.specify/orchestrator/`, **When** the migration script runs, **Then** all state files (milestones, knowledge, decisions, telemetry, locks) move to `.orchestrator/` without loss and without touching unrelated `.specify/` content.
2. **Given** state has been migrated, **When** `scripts/state/resolve-root.sh` is invoked with no overrides, **Then** it resolves to `.orchestrator/` via rules 1–3 (env / config / `.orchestrator/`) and never reaches the former bridge rule.
3. **Given** the constitution previously lived at `.specify/memory/constitution.md`, **When** the cutover completes, **Then** it is at `.orchestrator/memory/constitution.md` and all references in commands, scripts, and docs point to the new location.
4. **Given** state has been migrated, **When** `orchestrator-doctor` runs, **Then** it reports a clean state with no orphaned artifacts, no stale references to `.specify/orchestrator/`, and no missing files.

---

### User Story 3 - Migration Adapters Still Help Users Coming From Spec-Kit (Priority: P2)

A developer with an existing spec-kit project runs the orchestrator's migrate command to bring their spec-kit artifacts into the orchestrator's format. The migration succeeds end-to-end. The cutover removed spec-kit as a *runtime host* but preserved spec-kit as a *migration source* — those are different concerns and the cutover does not conflate them.

**Why this priority**: M003 invested significant effort in migration adapters precisely so users on legacy tools (GSD2, GSD v1, spec-kit) can adopt the orchestrator without losing institutional knowledge. Breaking the spec-kit migration path during the host removal would undo M003's value. The two concerns must be cleanly separated.

**Independent Test**: Can be tested by running the migrate command against a spec-kit-shaped fixture project and verifying it produces a valid orchestrator state directory.

**Acceptance Scenarios**:

1. **Given** a spec-kit-shaped fixture project with `specs/`, `tasks.md`, and `.specify/memory/constitution.md`, **When** the developer runs the orchestrator's migrate command targeting that project, **Then** the migration completes successfully and produces a valid `.orchestrator/` state directory.
2. **Given** the cutover has completed, **When** the developer inspects `scripts/migrate/adapters/speckit.sh`, `scripts/state/detect-speckit.sh`, and `scripts/dispatch/adapters/format/speckit.sh`, **Then** all three files exist and function as before.
3. **Given** the migrate command runs in standalone mode, **When** it detects a spec-kit-shaped source, **Then** it can read spec-kit conventions even though the orchestrator itself no longer hosts on spec-kit.

---

### User Story 4 - Documentation Tells The Standalone Story (Priority: P2)

A developer reading any of the project's documentation — README, CLAUDE.md, getting-started guide, architecture reference, installation reference — sees a consistent standalone narrative. Spec-kit is mentioned only in two contexts: (a) historical changelog entries explaining how the project evolved, and (b) migration documentation explaining how to bring spec-kit projects into the orchestrator. No current-state documentation describes the orchestrator as "a spec-kit extension."

**Why this priority**: Mixed messaging in docs creates ambiguity for adopters and contributors. M009 (launch) ships docs as a primary artifact; if those docs still describe the orchestrator as an extension, the launch fails its own narrative test.

**Independent Test**: Can be tested by full-text searching the documentation for "spec-kit extension" and verifying every remaining occurrence is either in a changelog entry or in migration-flow documentation.

**Acceptance Scenarios**:

1. **Given** the cutover has completed, **When** the developer reads `README.md`, **Then** the project is described as a standalone orchestrator and no current-state copy frames it as a spec-kit extension.
2. **Given** the cutover has completed, **When** the developer reads `CLAUDE.md`, **Then** the project instruction file describes the standalone workflow without referencing `/speckit.*` slash commands as the SDD entry point.
3. **Given** the cutover has completed, **When** the developer reads `references/architecture.md`, `references/installation.md`, and `docs/getting-started.md`, **Then** all three describe standalone usage as the primary path.
4. **Given** the cutover has completed, **When** a full-text search of documentation runs for "spec-kit extension," **Then** the only remaining matches are in `CHANGELOG.md` (historical) or in migration-flow documentation (use case).

---

### User Story 5 - Test Suite Reflects Standalone Reality (Priority: P3)

A developer running the project's test suites sees all tests pass with no expectation that an extension manifest exists or that hooks are registered. Tests previously asserting extension-shape behavior are either deleted (if the behavior is gone) or repurposed (if their underlying validation still has value in the standalone world).

**Why this priority**: Tests that assert removed behaviors will fail and block merges. Tests that silently still pass against removed code are dead weight. Both must be cleaned up so the test suite is an accurate guard for the standalone codebase.

**Independent Test**: Can be tested by running all 7 test suites after cutover and verifying every suite passes with no skipped tests that hide removed behaviors.

**Acceptance Scenarios**:

1. **Given** the cutover has completed, **When** all 7 test suites run, **Then** every suite passes and no tests are skipped due to removed dependencies.
2. **Given** the previous extension-registration test exists, **When** the cutover decides its disposition, **Then** the test is either deleted (if no equivalent standalone behavior exists to validate) or rewritten to assert standalone command discovery instead.
3. **Given** the previous extension-shape fixtures exist at `tests/fixtures/verify-{pass,fail}/extension.yml`, **When** the cutover decides their disposition, **Then** the fixtures are either deleted or replaced with standalone-shape equivalents.

---

### Edge Cases

- **Existing in-flight state**: This repo's own `.specify/orchestrator/` contains live milestone state, knowledge, and telemetry. The migration must move all of it without loss and without leaving stale paths in any consumer.
- **References scattered across phase summaries**: M001-M008 phase summary files contain historical references to spec-kit conventions. These are immutable historical artifacts and should NOT be rewritten — only current-state docs are reframed.
- **Constitution file location**: `.specify/memory/constitution.md` is referenced by `.specify/scripts/bash/`, multiple commands, and the constitution-walkthrough reference. All references must be updated atomically with the file move.
- **`.claude/settings.json` permissions**: If the settings file references removed scripts or hook commands, those references must be removed without breaking active permissions for retained scripts.
- **Re-running the cutover**: The cutover is a one-way operation. There is no rollback feature flag. If the cutover is interrupted, the recovery path is git revert, not a partial re-run.

## Requirements *(mandatory)*

### Functional Requirements

#### Spec-Kit Host Removal

- **FR-001**: System MUST remove the `extension.yml` manifest from the project root.
- **FR-002**: System MUST remove the project's dogfooded spec-kit slash command files at `.claude/commands/speckit.*.md`.
- **FR-003**: System MUST remove `.specify/scripts/bash/` and its contents (spec-kit's helper scripts).
- **FR-004**: System MUST remove `.specify/templates/commands/` and the spec-kit-style template files at `.specify/templates/{plan,spec,tasks,checklist,constitution,agent-file}-template.md`.
- **FR-005**: System MUST NOT leave dangling references to removed files in any retained command, script, or documentation file.

#### State Tree Migration

- **FR-006**: System MUST move all orchestrator state from `.specify/orchestrator/` to `.orchestrator/` without data loss, using the existing `scripts/migrate/migrate-state.sh` tool.
- **FR-007**: System MUST move `.specify/memory/constitution.md` to `.orchestrator/memory/constitution.md` and update all references.
- **FR-008**: System MUST remove rule 4 (the `.specify/orchestrator/` bridge) from `scripts/state/resolve-root.sh` and renumber the rules accordingly without changing the resolution semantics for rules 1–3 and the former rule 5 (default).
- **FR-009**: System MUST verify that no script, command, template, or test contains a hardcoded reference to `.specify/orchestrator/` after cutover, except in migration adapters that explicitly target that path as a *source* during user migrations.

#### Documentation Reframe

- **FR-010**: System MUST update `README.md`, `CLAUDE.md`, `references/architecture.md`, `references/installation.md`, `docs/getting-started.md`, and `CHANGELOG.md` so the project's current-state framing is "standalone orchestrator," not "spec-kit extension."
- **FR-011**: System MUST preserve historical references to spec-kit hosting in `CHANGELOG.md` and milestone summary files — those are immutable historical artifacts.
- **FR-012**: System MUST retain or add documentation describing how users coming from spec-kit can migrate into the orchestrator (the migration adapter use case).

#### Migration Adapter Preservation

- **FR-013**: System MUST retain `scripts/migrate/adapters/speckit.sh`, `scripts/state/detect-speckit.sh`, `scripts/dispatch/adapters/format/speckit.sh`, and `commands/migrate.md` in working order.
- **FR-014**: System MUST verify that the spec-kit migration path remains functional end-to-end against a spec-kit-shaped fixture after cutover.

#### Test Suite Alignment

- **FR-015**: System MUST decide the disposition of `scripts/verify/m002-p07-extension-registration.sh` and `tests/fixtures/verify-{pass,fail}/extension.yml` — either delete (if no standalone equivalent applies) or rewrite for standalone shape.
- **FR-016**: System MUST verify that all 7 test suites pass after cutover with no tests skipped due to removed dependencies.
- **FR-017**: System MUST verify that `orchestrator-doctor` reports a clean state (no orphans, no stale references, no missing files) after cutover.

#### End-to-End Validation

- **FR-018**: System MUST validate that `orchestrator-auto` runs successfully end-to-end on a fresh clone of the repo in Claude Code native mode with no spec-kit installed.
- **FR-019**: System MUST validate that `orchestrator:init` produces standalone configuration in a fresh project with no spec-kit installed.

### Key Entities

- **Spec-Kit Host**: The collection of files that register the orchestrator as a spec-kit extension and provide spec-kit-style developer ergonomics (`extension.yml`, `.claude/commands/speckit.*.md`, `.specify/scripts/bash/`, `.specify/templates/`). Removed entirely by this milestone.
- **State Tree Bridge**: The legacy `.specify/orchestrator/` state location, supported by rule 4 of the state-root resolver. Removed entirely by this milestone in favor of the canonical `.orchestrator/` location.
- **Migration Adapter**: The retained code that lets users coming *from* spec-kit (or GSD v1, or GSD2) migrate into the orchestrator's format. Distinct from "host" — these are migration sources, not runtime dependencies.
- **Documentation Surface**: The current-state docs (README, CLAUDE.md, getting-started, architecture, installation) that frame the project for new readers. Reframed by this milestone. Distinct from historical artifacts (changelog entries, milestone summaries) which are immutable.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer with no spec-kit installed can complete the full evaluate → roadmap → plan-phase → auto sequence on a fresh repo clone with zero errors referencing spec-kit.
- **SC-002**: A full-text search of the repo for `extension.yml`, `.specify/scripts/bash/`, `.specify/templates/`, and `.claude/commands/speckit.` returns zero matches outside `CHANGELOG.md`, milestone summary files, and migration documentation.
- **SC-003**: A full-text search of current-state docs (`README.md`, `CLAUDE.md`, `references/architecture.md`, `references/installation.md`, `docs/getting-started.md`) for the phrase "spec-kit extension" returns zero matches except in changelog-style or migration-context callouts.
- **SC-004**: The orchestrator's own state has been moved from `.specify/orchestrator/` to `.orchestrator/` with no data loss, verified by file-count and checksum equivalence on the migrated tree.
- **SC-005**: `scripts/state/resolve-root.sh` no longer contains rule 4 (the spec-kit bridge), and the resolver still passes all standalone resolution tests.
- **SC-006**: All 7 test suites pass after cutover with no skipped tests hiding removed behaviors.
- **SC-007**: `orchestrator-doctor` reports a clean state after cutover.
- **SC-008**: The spec-kit migration path (`commands/migrate.md` + `scripts/migrate/adapters/speckit.sh`) successfully migrates a spec-kit-shaped fixture into a valid `.orchestrator/` state directory.

## Assumptions

- The 5-rule state-root resolver from M008 is sound and removing rule 4 will not break rules 1, 2, 3, or 5 (now renumbered to 4).
- M003's `scripts/migrate/migrate-state.sh` is sufficient to migrate this project's own state from `.specify/orchestrator/` to `.orchestrator/` without modification.
- M003 P07/P08 validation in `orchestrator-auto` Claude Code native mode is sufficient evidence that the standalone runtime can complete a full orchestrated workflow without spec-kit hosting.
- The dogfooded spec-kit slash commands at `.claude/commands/speckit.*.md` are not load-bearing for this project's own development going forward — the orchestrator's own commands replace them.
- Phase summary files and other historical artifacts under `.specify/orchestrator/milestones/M00*/` are immutable and do not need their spec-kit references rewritten.

## Constraints

- Hard migration only. No dual code paths, no feature flag, no compat shim. Per M007 no-graceful-degradation.
- Spec-kit migration adapters MUST remain functional. The cutover removes spec-kit as a *host*, not as a *migration source*.
- The cutover MUST happen as a single milestone before M009 launch. M009 cannot ship with the legacy entry point still present.
- No automated test or script may rely on the presence of `extension.yml` or `.specify/scripts/bash/` after cutover.
- Historical artifacts (CHANGELOG entries, milestone summaries, phase plans) MUST NOT be rewritten — only current-state documentation is reframed.

## Dependencies

- M008 (Standalone Orchestrator) complete — provides the 5-rule resolver, runtime adapters, and standalone packaging that make this cutover possible.
- M003 (Migration Tool) complete and validated — provides `scripts/migrate/migrate-state.sh` for the state move and confirms `orchestrator-auto` works in Claude Code native mode.
- M007 (Graph Knowledge) complete — its no-graceful-degradation rule governs the hard-migration discipline applied here.
