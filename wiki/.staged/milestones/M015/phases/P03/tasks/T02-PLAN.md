---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M015"
name: "Reframe the five primary standalone docs + append CHANGELOG M015 entry"
depends_on: [T01]
---

## Prerequisites

- T01 is complete. All six `scripts/verify/m015-p03-*.sh` verify scripts exist, parse, are executable, and currently FAIL (expected pre-reframe state). The CHANGELOG historical snapshot exists at `scripts/verify/m015-p03-helpers/changelog-historical-snapshot.txt`.
- P02 is complete. State lives at `.orchestrator/`, constitution lives at `.orchestrator/memory/constitution.md`.
- Working in repo root: `/Users/brettkellgren/Sites/lakeledger/orchestrator`.

## Description

Rewrite the five primary current-state documents so they describe the orchestrator as a standalone tool — not as a spec-kit extension. After this task, a reader with no prior spec-kit familiarity can read any of these five documents end-to-end and walk away with a correct mental model of the orchestrator's install flow, workflow, and runtime footprint without ever needing to know what spec-kit is.

The five primary docs:

1. `README.md` — project overview, quick start, install, architecture summary, commands table.
2. `CLAUDE.md` — project instructions for Claude Code working IN this repo (orientation + workflow).
3. `references/architecture.md` — contributor-oriented deep reference on the engine pipeline, dispatch, state machine.
4. `references/installation.md` — installation reference (single source of truth for install steps).
5. `docs/getting-started.md` — user-oriented quickstart (first-run experience).

Additionally, append a new M015 entry at the top of `CHANGELOG.md` describing the standalone cutover. Historical entries below must remain byte-identical to the snapshot captured in T01.

spec-kit references that are permitted to remain in these five docs:
- Migration callouts that explicitly link to `docs/migrating-from-speckit.md` and frame spec-kit as a migration source (NOT a runtime dependency).
- Short historical sentence in `README.md` and `CHANGELOG.md` noting the project's evolution (e.g., "Originally built as a spec-kit extension; became standalone in v0.9.0.").

spec-kit references that MUST be removed:
- Any mention of "spec-kit extension" as current-state framing (the phrase triggers the framing verifier).
- `extension.yml` install/config instructions.
- `.specify/orchestrator/` or `.specify/memory/constitution.md` paths as canonical state locations.
- `/speckit.specify`, `/speckit.plan`, `/speckit.tasks`, `/speckit.clarify`, `/speckit.implement`, `/speckit.analyze`, `/speckit.checklist` slash-command invocations presented as THIS project's SDD entry points.
- Spec-kit hooks/lifecycle-point language describing how the orchestrator plugs in.

Replacement narrative: the orchestrator is a standalone tool distributed via `packaging/install/install-{claude-code,codex,cursor}.sh` installers. Users run `orchestrator:init` to configure a project. Canonical state lives at `.orchestrator/`. Constitution lives at `.orchestrator/memory/constitution.md`. The SDD entry point is whatever the host runtime (Claude Code / Codex CLI / Cursor) exposes — typically a skill or slash command named `orchestrator:evaluate`, `orchestrator:roadmap`, `orchestrator:plan-phase`, `orchestrator:auto`, etc. (These names come from `scripts/state/namespace-aliases.sh` which maps `speckit.orchestrator.* → orchestrator:*`.)

## Steps

1. Read T01's `scripts/verify/m015-p03-standalone-framing.sh` and `scripts/verify/m015-p03-no-legacy-install.sh` so you know the exact banned strings. Run both scripts once to capture their failure output — that output names every file and token you must address.

2. **Rewrite `README.md`** (currently 258 lines). Preserve overall structure (The Problem, The Solution, Quick Start, Workflow, All Commands, Core Capabilities, Architecture, Installation, Agent Compatibility, Testing, Governing Principles, Extending, License) but rewrite each section for standalone framing:

   - Opening line: replace "A spec-kit extension that adds autonomous multi-phase orchestration to spec-kit's spec-driven development (SDD) workflow." with a standalone description: "A standalone autonomous multi-phase orchestrator for long-horizon software development. Runs on Claude Code, Codex CLI, or Cursor."
   - Version badge: update to `v0.9.0 — standalone-cutover complete. 13 commands, 80+ scripts, 24+ templates, 15 reference docs, 5 user guides.` (exact count numbers are best-effort — match what's actually on disk.)
   - Quick Start: replace "Copy extension files into your spec-kit project" + `cp -r ... extension.yml ./` with the standalone install flow: `bash packaging/install/install-claude-code.sh` (or the equivalent for codex / cursor) run from a fresh clone of the orchestrator repo or from a prebuilt skill bundle.
   - Steps 2–5 of Quick Start: replace `/speckit.specify`, `/speckit.clarify`, `/speckit.orchestrator.evaluate`, `/speckit.orchestrator.discuss`, `/speckit.orchestrator.roadmap`, `/speckit.orchestrator.plan-phase`, `/speckit.orchestrator.auto`, `/speckit.orchestrator.status`, `/speckit.orchestrator.consolidate` with the `orchestrator:*` skill names. The workflow becomes: `orchestrator:init` → `orchestrator:evaluate` → `orchestrator:discuss` (Tier C) → `orchestrator:roadmap` → `orchestrator:plan-phase` → `orchestrator:auto` → `orchestrator:status` / `orchestrator:consolidate`.
   - Commands table: rename every row from `speckit.orchestrator.*` to `orchestrator:*`.
   - Architecture section: replace the `extension.yml ← manifest: 10 commands, 5 hooks, 27 scripts` diagram header with a standalone layout diagram (root-level `packaging/install/` + `.orchestrator/` state tree + `commands/` + `scripts/` + `templates/` + `references/`). Replace "All orchestrator state lives at `.specify/orchestrator/`" with "All orchestrator state lives at `.orchestrator/`". Update the "Config Resolution" note — four layers become `Environment vars > orchestrator-config.local > project config > defaults` (no extension layer).
   - Installation section: replace "Option 1: Copy from repo" cp-r flow and "Option 2: spec-kit CLI" with the canonical standalone install via `bash packaging/install/install-<runtime>.sh`. Remove the `extension.yml` copy line. Remove the `spec-kit >= 0.1.0` requirement. Keep Bash 3.2+, git, jq (optional).
   - "Hooks" section: delete or replace — the "5 spec-kit lifecycle points" table is no longer accurate. If any equivalent mechanism exists in standalone mode (e.g., runtime-adapter-level hooks), describe that; otherwise drop the section entirely and renumber subsequent H2 headings.
   - "What NOT to copy": delete (there is no copy-based install anymore).
   - Agent Compatibility: update to reflect that the orchestrator now formally supports Claude Code, Codex CLI, and Cursor via `packaging/install/install-*.sh`.
   - Testing: keep the 7 test suite list; the tests themselves haven't changed in this milestone.
   - Governing Principles: keep as-is — principles are unchanged.
   - Extending: rewrite the "Adding a new command" list — replace "Register in `extension.yml` under `provides.commands`" with whatever standalone registration is ("Ensure the command file is discovered by `packaging/install/install-<runtime>.sh` during next install, or add it to the runtime adapter's command registry.").
   - Add a short new section titled "Migrating from spec-kit" near the bottom (or at the end of Installation) with a one-paragraph summary and a link to `docs/migrating-from-speckit.md`.
   - Add a short historical note somewhere near the top (e.g., at the end of the opening paragraph or in a "History" sub-line): "Originally built as a spec-kit extension; standalone as of v0.9.0 (M015)." — this is the only permitted historical use of the phrase "spec-kit extension" in README.md per the framing verifier rules. **Important**: the framing verifier (`m015-p03-standalone-framing.sh`) as written in T01 disallows the literal phrase "spec-kit extension" in primary docs entirely. So rephrase the historical note to "Originally built as an extension to spec-kit; standalone as of v0.9.0 (M015)." — use "extension to spec-kit" (not "spec-kit extension") to avoid triggering the verifier while preserving the historical meaning.

3. **Rewrite `CLAUDE.md`** (currently 78 lines). This file is the project instruction document for Claude Code operating IN this repo.

   - Rewrite the opening "What This Is" section: "A standalone autonomous multi-phase orchestrator. This repo holds the orchestrator itself — its commands, scripts, templates, reference docs, and packaging installers. It uses its own orchestration workflow (`orchestrator:*` commands) to develop itself."
   - Update "Project Status": bump to v0.9.0, drop the M008-era description, add a one-line M015 summary: "M015 standalone-cutover milestone complete — spec-kit extension host removed, state tree migrated to `.orchestrator/`, documentation reframed for standalone."
   - Rewrite "Standalone Mode" section: remove the "still hosted under .specify/orchestrator in this repo" caveat (no longer true). The `scripts/state/resolve-root.sh` bullet should describe it as a 4-rule resolver (not 5-rule with bridge): "ORCHESTRATOR_ROOT env → config → `.orchestrator/` → default". Remove the "migration tool is available" note — migration is complete.
   - Rewrite "Key Files": remove `extension.yml`; update `.specify/memory/constitution.md` to `.orchestrator/memory/constitution.md`; update `.specify/orchestrator/KNOWLEDGE.md` to [`.orchestrator/KNOWLEDGE.md`](../../../../../knowledge.md); update `.specify/orchestrator/milestone-summary.md` to `.orchestrator/milestone-summary.md`.
   - Rewrite "Architecture" — delete the "This is a **spec-kit extension** (markdown commands + shell scripts), NOT a standalone CLI." sentence and the three bullet points that follow (registers via extension.yml, uses hooks at 5 lifecycle points, uses command composition to wrap spec-kit). Replace with: "This is a standalone orchestrator delivered as a runtime-specific skill bundle (Claude Code / Codex CLI / Cursor). It registers commands via `packaging/install/install-<runtime>.sh`, stores state at `.orchestrator/`, and operates with no runtime dependency on spec-kit."
   - Rewrite "Constitution Principles": update the read-path reference from `.specify/memory/constitution.md` to `.orchestrator/memory/constitution.md`.
   - Rewrite "SDD Workflow" section: the current list (`/speckit.specify`, `/speckit.clarify`, `/speckit.plan`, `/speckit.tasks`, `/speckit.analyze`, `/speckit.implement`) must be REMOVED. This project no longer uses spec-kit slash commands for its own development. Replace with: "This project uses its own orchestrator workflow for development: `orchestrator:evaluate` → `orchestrator:discuss` (Tier C) → `orchestrator:roadmap` → `orchestrator:plan-phase` → `orchestrator:auto` / `orchestrator:dispatch` → `orchestrator:verify` → `orchestrator:consolidate`. See `commands/` for each command's definition."
   - Active Technologies: drop the `spec-kit >=0.1.0 (extension host)` clause. Keep Bash 3.2+ / POSIX sh, git, jq (optional).
   - Recent Changes: add an M015 line at the top. Keep the [M008](../../../../../milestones/M008/index.md) and M001/[M006](../../../../../milestones/M006/index.md) lines.

4. **Rewrite `references/architecture.md`** (currently 378 lines). This is a contributor-oriented deep reference.

   - Opening Overview: rewrite the first paragraph to describe the orchestrator as standalone. Replace "orchestrator is a spec-kit extension that adds autonomous multi-phase orchestration to spec-kit's spec-driven development workflow." with a standalone opening. Replace "All state is derived from file presence on disk under `.specify/orchestrator/`." with `.orchestrator/`.
   - Paragraph 2 of Overview: remove "It registers with spec-kit via `extension.yml`, which declares 12 commands, 5 lifecycle hooks, and over 40 helper scripts. The extension requires spec-kit >= 0.1.0". Replace with a standalone description of how the orchestrator plugs into a runtime (Claude Code agent tool / Codex CLI SDK / Cursor) via `packaging/install/install-<runtime>.sh`.
   - Paragraph 3 of Overview: update the `.specify/memory/constitution.md` reference to `.orchestrator/memory/constitution.md`.
   - Engine Pipeline section: sweep the 9 occurrences of `.specify/orchestrator/` to `.orchestrator/`. The structural content (7-stage pipeline, Init/Hook/Build/Compress/Dispatch/Verify/Record) remains unchanged.
   - Any remaining `extension.yml` references: remove or replace with the appropriate standalone registration mechanism.
   - Any `spec-kit` runtime-dependency language: remove.

5. **Rewrite `references/installation.md`** (currently 258 lines). This is the single source of truth for install steps.

   - Overview: rewrite opening. Replace "orchestrator is an extension that adds multi-phase orchestration to spec-kit's SDD workflow. It is distributed as a set of files that you copy into your project." with "orchestrator is a standalone autonomous orchestrator. It is distributed as a runtime-specific skill bundle installed via `packaging/install/install-<runtime>.sh`."
   - What to Copy / What NOT to Copy: the cp-r install is obsolete. Delete the entire "What to Copy" table and "What NOT to Copy" table, and replace with a single "Install" section pointing at the installers:
     - `bash packaging/install/install-claude-code.sh` (Claude Code)
     - `bash packaging/install/install-codex.sh` (Codex CLI)
     - `bash packaging/install/install-cursor.sh` (Cursor)
   - Installation Steps: rewrite to use the installers. Remove step "Copy extension files". Remove `extension.yml` copy. Add `orchestrator:init` as the first post-install command.
   - Step 3 "Set up CLAUDE.md for your project": remove the `/speckit.orchestrator.*` list entirely and replace with `orchestrator:*` names. Simpler still — point readers at `docs/getting-started.md` for the full walkthrough.
   - Step 4 "Create your feature spec": remove the "using standard spec-kit" clause — replace with a bare instruction to create `specs/{NNN}-{name}/spec.md` (the orchestrator reads spec-kit-shaped specs via `scripts/dispatch/adapters/format/speckit.sh`, but the user doesn't need spec-kit installed; clarify this).
   - Step 5 "Start orchestration": rename `/speckit.orchestrator.evaluate` to `orchestrator:evaluate`.
   - Directory Structure After Installation diagram: replace `.specify/` + `extension.yml` + `specs/` layout with the standalone layout: `.orchestrator/` state, `commands/`, `scripts/`, `templates/`, `references/`, `docs/`, `packaging/`, optional `orchestrator-config.yml`. Delete the `extension.yml` line. Update `.specify/orchestrator/` to `.orchestrator/`.
   - Autonomy Configuration section: sweep `.specify/orchestrator` → `.orchestrator` wherever it appears.

6. **Rewrite `docs/getting-started.md`** (currently 391 lines). This is the user-oriented quickstart.

   - Overview: rewrite opening paragraph to describe standalone usage. Drop "is a spec-kit extension that adds autonomous multi-phase orchestration to spec-kit's spec-driven development (SDD) workflow". Replace with a standalone opening. The "If your feature fits in one context, the orchestrator classifies it as Tier A and steps aside -- you use standard spec-kit commands with zero overhead." sentence must change — Tier A now routes to the host runtime's native single-context workflow (e.g., plain Claude Code conversation), not to spec-kit.
   - Prerequisites: delete the `spec-kit >= 0.1.0` row. Keep Bash 3.2+, git, jq (optional).
   - Installation: replace cp-r flow with the `packaging/install/install-<runtime>.sh` invocation matching the primary runtime (default to Claude Code with notes for the others).
   - "Create project configuration" step: fine as-is but drop the `extension.yml config_schema` reference — replace with the project-config schema documented at `references/file-formats.md` or in `templates/orchestrator-config-default.yml`.
   - Usage section: sweep every `/speckit.orchestrator.*` invocation to `orchestrator:*`. Sweep every `.specify/orchestrator/` path to `.orchestrator/`.
   - Any remaining `extension.yml` references: remove.

7. **Append new M015 entry to CHANGELOG.md**. Insert between the top-level `# Changelog` title block (lines 1–5) and the current top entry `## [0.8.0] — 2026-04-14`. The new entry uses heading `## [0.9.0] — 2026-04-15` (match today's date). Structure it to match the existing entries' shape (see the `[0.8.0]` entry for the template):

   ```markdown
   ## [0.9.0] — 2026-04-15

   M015 (015-standalone-cutover). Standalone cutover — removes the spec-kit extension host, migrates orchestrator state from `.specify/orchestrator/` to `.orchestrator/`, moves the constitution to `.orchestrator/memory/constitution.md`, reduces the state-root resolver from 5 rules to 4 (bridge removed), and reframes all current-state documentation for the standalone narrative. The orchestrator now runs with zero runtime dependency on spec-kit. Spec-kit migration adapters are preserved — they help users coming FROM spec-kit, not TO it.

   ### Removed

   - `extension.yml` manifest (project root)
   - Dogfooded spec-kit slash commands at `.claude/commands/speckit.*.md`
   - `.specify/scripts/bash/` spec-kit helper scripts
   - `.specify/templates/{plan,spec,tasks,checklist,constitution,agent-file}-template.md` spec-kit-style templates
   - `.specify/orchestrator/` bridge rule from `scripts/state/resolve-root.sh`
   - `.specify/memory/` directory (after constitution move)

   ### Changed

   - Orchestrator state canonical location: `.specify/orchestrator/` → `.orchestrator/`
   - Constitution canonical location: `.specify/memory/constitution.md` → `.orchestrator/memory/constitution.md`
   - `scripts/state/resolve-root.sh` reduced from 5-rule to 4-rule resolver
   - Documentation reframed across README.md, CLAUDE.md, references/architecture.md, references/installation.md, docs/getting-started.md, and wider reference + user-guide set
   - CHANGELOG.md historical entries preserved byte-identical; immutability verified via snapshot diff

   ### Added

   - `docs/migrating-from-speckit.md` — migration guide for users coming from spec-kit (FR-012)
   - Six P03 verify scripts under `scripts/verify/m015-p03-*.sh`

   ### Preserved (migration-source contract)

   - `scripts/migrate/adapters/speckit.sh`, `scripts/state/detect-speckit.sh`, `scripts/dispatch/adapters/format/speckit.sh`, `commands/migrate.md` — spec-kit migration path remains functional end-to-end

   Originally built as an extension to spec-kit; standalone as of this release.
   ```

   Insert this block so the file becomes: line 1–5 (title block) → blank line → new `## [0.9.0]` block → blank line → existing `## [0.8.0]` block → rest of file.

8. Run the framing verifier:

   ```
   bash scripts/verify/m015-p03-standalone-framing.sh
   ```

   Must exit 0 with `PASS:`. If it FAILs, its output names the exact file and line number where "spec-kit extension" still appears. Fix those specific occurrences and re-run.

9. Run the no-legacy-install verifier:

   ```
   bash scripts/verify/m015-p03-no-legacy-install.sh
   ```

   Must exit 0 with `PASS:`. If it FAILs, its output names the exact file and banned token (`extension.yml`, `.specify/orchestrator`, `.specify/memory/constitution`, or `/speckit.<cmd>`). Fix and re-run.

10. Run the changelog verifier:

    ```
    bash scripts/verify/m015-p03-changelog-has-m015.sh
    ```

    Must exit 0 with `PASS:`. If it FAILs on the historical-diff check, the historical portion of CHANGELOG.md has been unintentionally modified — inspect `/tmp/m015-p03-changelog-current-historical.txt` against `scripts/verify/m015-p03-helpers/changelog-historical-snapshot.txt` and restore the historical text byte-for-byte.

11. Re-run the no-legacy-install verifier one last time for safety. It must still PASS.

## Must-Haves

This task addresses the following truth-level must-haves from the phase plan:

- Truth 1 (standalone-framing): primary docs no longer describe the orchestrator as "a spec-kit extension" — PASSed by `m015-p03-standalone-framing.sh`.
- Truth 2 (no-legacy-install): primary docs no longer instruct readers to install `extension.yml` or use `/speckit.*` as SDD entry points — PASSed by `m015-p03-no-legacy-install.sh`.
- Truth 3 (changelog-has-m015): CHANGELOG.md has a new M015 entry at the top with historical entries immutable — PASSed by `m015-p03-changelog-has-m015.sh`.

## Verification

```
bash scripts/verify/m015-p03-standalone-framing.sh
bash scripts/verify/m015-p03-no-legacy-install.sh
bash scripts/verify/m015-p03-changelog-has-m015.sh
```

All three must PASS after this task. The other three P03 verify scripts (`m015-p03-migration-doc.sh`, `m015-p03-wider-docs-sweep.sh`, `m015-p03-allow-list-tightened.sh`) remain FAILing — T03 and T04 address them.

## Inputs

- Existing `README.md`, `CLAUDE.md`, `references/architecture.md`, `references/installation.md`, `docs/getting-started.md` — read first, understand the current structure, preserve section headings where possible.
- `specs/015-standalone-cutover/spec.md` — FR-010, FR-011 (the immutability constraint), and the Constraints section.
- `scripts/state/namespace-aliases.sh` — authoritative for the `speckit.orchestrator.* → orchestrator:*` name mapping. If uncertain what to rename `/speckit.orchestrator.foo` to, check this script's output.
- Existing `CHANGELOG.md` entries (any of them) — model the new M015 entry's shape on these.
- `packaging/install/` contents — confirm the exact installer filenames referenced in updated install instructions.
- [`.orchestrator/milestones/M008/M008-SUMMARY.md`](../../../../../milestones/M008/M008-SUMMARY.md) (if it exists) — source of truth for the runtime list (Claude Code / Codex CLI / Cursor) and standalone capability description.

## Constraints

- Do NOT edit any file under `.orchestrator/` except via the dispatch/verify loop writing this task's summary. All historical artifacts (phase summaries, task summaries, DECISIONS.md) are immutable per MEM and per spec.
- Do NOT modify `CHANGELOG.md` below the new M015 entry. The historical portion must remain byte-identical to T01's snapshot.
- Do NOT remove the migration adapters under `scripts/migrate/*`, `scripts/state/detect-speckit.sh`, `scripts/dispatch/adapters/format/speckit.sh`, or `commands/migrate.md`. These are preserved per FR-013.
- Do NOT broaden the P02 sweep's `ALLOW_P03_DOCS` regex — that belongs to T04.
- Use "extension to spec-kit" (NOT "spec-kit extension") if you must write a historical one-liner in README.md. The framing verifier's literal blocklist is the phrase "spec-kit extension".
- Path literalism (MEM023): if you list artifact paths in any task summary or in the P03 summary later, do NOT wrap them in markdown backticks — they are parsed literally.
- Single-script-file shape applies to any new Check commands you write, but this task writes no new verify scripts.

## Expected Output

After T02 completes:

1. The five primary docs are rewritten with standalone framing. Line counts are approximately:
   - README.md: 180–230 lines (down from 258)
   - CLAUDE.md: 70–90 lines (similar to 78)
   - references/architecture.md: 340–380 lines (similar to 378)
   - references/installation.md: 200–260 lines (similar to 258)
   - docs/getting-started.md: 340–400 lines (similar to 391)
2. `CHANGELOG.md` has a new `## [0.9.0] — 2026-04-15` block at the top describing M015. Total file length grows to ~320 lines.
3. Three of six P03 verify scripts now PASS:
   - `m015-p03-standalone-framing.sh` → PASS
   - `m015-p03-no-legacy-install.sh` → PASS
   - `m015-p03-changelog-has-m015.sh` → PASS
4. The other three verify scripts remain FAILing (T03 and T04 work).
5. No edits to `.orchestrator/` tree, no edits to migration adapters, no edits to `ALLOW_P03_DOCS`.
