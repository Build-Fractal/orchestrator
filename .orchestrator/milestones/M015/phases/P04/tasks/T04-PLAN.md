---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P04"
milestone: "M015"
name: "Author M015-SUMMARY.md milestone closeout"
depends_on: [T03]
---

## Prerequisites

- T01/T02/T03 complete.
- `.orchestrator/milestones/M015/M015-VERIFICATION.md` exists with PASS verdicts for FR-001..FR-019.
- All four phase summaries exist:
  - `.orchestrator/milestones/M015/phases/P01/P01-SUMMARY.md`
  - `.orchestrator/milestones/M015/phases/P02/P02-SUMMARY.md`
  - `.orchestrator/milestones/M015/phases/P03/P03-SUMMARY.md`
  - `.orchestrator/milestones/M015/phases/P04/P04-SUMMARY.md` — note: P04's own summary is written by `scripts/lifecycle/phase-transition.sh` at phase end AFTER this task completes. For T04 authoring purposes, draft the P04 phase-summary rollup content from direct inspection of T01..T04 work (roadmap + this task plan + evidence/) and cross-reference it into M015-SUMMARY.md. The final P04-SUMMARY.md file that `phase-transition.sh` writes will land in a later step; the milestone summary content authored here does not need to wait for it.

## Description

Author `.orchestrator/milestones/M015/M015-SUMMARY.md` as the milestone-level closeout document. This is the canonical single entry point that a future reader uses to understand the M015 Standalone Cutover arc — what changed, why, what evidence confirmed it, and what patterns were established.

The document follows `templates/milestone-summary.md` schema: YAML frontmatter with `schema_version`, `type: milestone-summary`, `id: "M015"`, `parent: null`, `milestone: "M015"`, `provides:`, `requires:`, `affects:`, `key_files:`, `key_decisions:`, `patterns_established:`, `drill_down_paths:`, `duration:`, `verification_result:`, `completed_at:`, `observability_surfaces:`. Body sections: Milestone Rollup, Phase Summaries (compressed), Key Decisions, Patterns Established, Knowledge Captured.

Content is aggregated from the four phase summaries plus M015-VERIFICATION.md. The rollup is narrative but concise — every phase gets one paragraph; key decisions and patterns are bulleted.

## Steps

1. Re-read `templates/milestone-summary.md` to confirm the current schema.

2. Re-read all four phase summaries. Extract from each:
   - `provides:` entries (what the phase produced)
   - `key_decisions:` entries (non-trivial choices made during the phase)
   - `patterns_established:` entries (repeatable patterns future milestones can use)
   - `duration:` value
   - Drill-down paths (task summaries under `phases/P##/tasks/`)

3. Re-read `.orchestrator/milestones/M015/M015-VERIFICATION.md` to confirm the overall verdict (PASS) and the evidence citations.

4. Re-read `.orchestrator/milestones/M015/M015-ROADMAP.md` to cross-reference phase goals and demo sentences.

5. Compute total milestone duration — sum of P01..P04 `duration:` values. For P04, estimate from the evidence capture window (`find .orchestrator/milestones/M015/phases/P04/evidence/ -type f -printf ...` — or visually inspect timestamps in evidence transcripts) or from execution-log.jsonl entries.

6. Author `.orchestrator/milestones/M015/M015-SUMMARY.md` using this skeleton:

   ```markdown
   ---
   schema_version: "1.0"
   type: milestone-summary
   id: "M015"
   parent: null
   milestone: "M015"
   provides:
     - "<1-3 sentences synthesizing what the milestone delivers — draw from P01..P04 provides entries>"
   requires:
     - from: "M008"
       what: "5-rule state-root resolver, standalone runtime adapters, multi-runtime packaging, orchestrator:init onboarding — the substrate the cutover operates on"
     - from: "M003"
       what: "migration tool + spec-kit adapter + orchestrator-auto-in-Claude-Code-native validation — source of the migration adapter kept after cutover and source of the auto-behavior evidence the cutover relies on (per spec assumption)"
     - from: "M007"
       what: "no-graceful-degradation discipline — governs the hard-cutover approach; no dual code paths, no feature flags, no compat shims"
   affects:
     - "M009 (launch readiness): M015 removes the last ambiguity in the standalone narrative; M009 can ship a launch story that survives first-contact inspection"
     - "All future orchestrator milestones: they run against .orchestrator/-rooted state and author docs in the standalone voice by default"
   key_files:
     - "<list the highest-signal files: deleted extension.yml, migrated state tree, resolver, five primary reframed docs, M015-VERIFICATION.md, seven P04 verify scripts, evidence transcripts — pull from P01..P04 key_files lists but dedupe aggressively; this should be the 20-30 most important files, not the full union>"
   key_decisions:
     - "<each top-level decision from the phase summaries; aim for 5-10 bullets>"
   patterns_established:
     - "<pre-reframe gate scaffolding — validation-as-task — write verify scripts before the change they gate, so each downstream task has an immediate pass/fail signal>"
     - "<snapshot-based immutability check — capture 'first ## [' pre-edit, verify 'second ## [' post-edit>"
     - "<seal-by-sentinel allow-list retirement — __NAME_NEVER_MATCH__>"
     - "<hard-delete cutover discipline — no legacy/, no archive, no compat shim>"
     - "<write migration-gate verify scripts BEFORE irreversible state moves (P02 pattern)>"
     - "<single-script-file shape for all Check: commands per AD-19, re-affirmed>"
     - "<four-stream evidence capture for validation phases (test-suite + doctor + migration-adapter + clean-clone-shape)>"
   drill_down_paths:
     - ".orchestrator/milestones/M015/phases/P01/P01-SUMMARY.md"
     - ".orchestrator/milestones/M015/phases/P02/P02-SUMMARY.md"
     - ".orchestrator/milestones/M015/phases/P03/P03-SUMMARY.md"
     - ".orchestrator/milestones/M015/phases/P04/P04-SUMMARY.md"
     - ".orchestrator/milestones/M015/M015-VERIFICATION.md"
     - ".orchestrator/milestones/M015/M015-ROADMAP.md"
   duration: "<sum of P01..P04 durations; format 'Xh Ym' or 'Ym'>"
   verification_result: "pass"
   completed_at: "<ISO-8601 UTC timestamp at task completion>"
   observability_surfaces:
     - "none"
   ---

   M015 Standalone Cutover is complete. The orchestrator is now an unambiguously standalone tool: the spec-kit extension host is gone (`extension.yml`, `.specify/scripts/bash/`, `.specify/templates/commands/`, `.specify/templates/*-template.md` at the root, and the nine `.claude/commands/speckit.*.md` project-owned slash commands all deleted), orchestrator state lives at `.orchestrator/` with the constitution at `.orchestrator/memory/constitution.md`, the state-root resolver has dropped its bridge rule and is now a 4-rule standalone resolver, current-state documentation frames the project as a standalone tool with no runtime dependency on spec-kit, and a migration guide at `docs/migrating-from-speckit.md` explains how users coming from spec-kit adopt the orchestrator. Spec-kit migration adapters (`scripts/migrate/adapters/speckit.sh`, `scripts/state/detect-speckit.sh`, `scripts/dispatch/adapters/format/speckit.sh`, `commands/migrate.md`) were preserved verbatim — spec-kit is removed as a runtime host but retained as a migration source. End-to-end validation confirms all 8 test suites pass, `orchestrator-doctor` reports clean, the spec-kit migration adapter produces a valid `.orchestrator/` from a spec-kit-shaped fixture, and a clean-clone shape check confirms no extension-host artifacts survive the cutover. M015-VERIFICATION.md scores each of FR-001..FR-019 as PASS with a cited evidence pointer.

   ## Milestone Rollup

   <2-4 paragraphs synthesizing what changed and why. Pull themes from the phase summaries but speak in milestone-level voice. Topics to cover:

   - Why the cutover happened now (M008 made standalone possible, M009 requires the narrative clean, M007 governs the hard-cutover posture)
   - The keep-vs-remove bucket decision: extensions and hosts out, migration adapters in
   - State tree migration + resolver simplification (4 rules, not 5)
   - Documentation reframe scope (5 primary docs + 13 wider docs + new migration guide)
   - Evidence shape (four validation streams + M015-VERIFICATION.md FR-scoring)

   Keep total prose under ~600 words across Milestone Rollup + Phase Summaries. Not a play-by-play — a readable rollup.>

   ## Phase Summaries

   ### P01 — Spec-Kit Host Removal (<duration from P01-SUMMARY frontmatter>)

   <1 paragraph. Drawn from `.orchestrator/milestones/M015/phases/P01/P01-SUMMARY.md` body's first-paragraph narrative — compressed. Cover: what got deleted, the preflight bug fix, the hard-delete discipline.>

   ### P02 — State Tree Migration (<duration>)

   <1 paragraph. Cover: state moved to `.orchestrator/`, constitution moved, resolver rule 4 removed, config.yml cleanup, migration adapter preservation confirmed.>

   ### P03 — Documentation Reframe (<duration>)

   <1 paragraph. Cover: 5 primary docs reframed, CHANGELOG M015 entry appended, migrating-from-speckit.md authored, 13 wider docs swept, ALLOW_P03_DOCS sealed with never-match sentinel.>

   ### P04 — End-to-End Validation (<duration>)

   <1 paragraph. Cover: 7 P04 verify scripts authored, 4 validation streams executed (test suites / doctor / migration adapter against spec-kit-shaped fixture / clean-clone shape), M015-VERIFICATION.md scored FR-001..FR-019 as PASS, this M015-SUMMARY.md authored.>

   ## Key Decisions

   <Bulleted list. Pull from each phase summary's key_decisions field, synthesize at milestone level, drop redundancy. Expect 5-10 bullets. Examples:

   - Hard-delete discipline (M007 governance): git rm, no rename, no compat shim, verify scripts assert absence.
   - Migration adapter preservation treated as orthogonal to host removal — FR-013 confirmed via empty `git diff --stat` at P01/P02 close.
   - Resolver reduction from 5 rules to 4 was a deletion, not a gating: bridge rule removed outright, not feature-flagged.
   - P03 ALLOW_P03_DOCS sealed with never-match sentinel after the docs graduated, converting the transitional tolerance to a permanent regression guard.
   - P04 clean-clone simulation uses `git archive HEAD | tar -x` rather than a network clone — hermetic, deterministic, no secrets concern.
   - P04 migration fixture is built deterministically by tests/fixtures/m015-p04-speckit-migration/build-fixture.sh per run, not committed as a populated tree.>

   ## Patterns Established

   <Bulleted list. Pull from each phase's patterns_established and dedupe. Expect 5-8 bullets. Examples:

   - Pre-change gate scaffolding (validation-as-task MEM011): write verify scripts before the changes they assert, so every downstream task has an immediate pass/fail signal.
   - Snapshot-based immutability check: capture at "first ## [" pre-edit, verify starting at "second ## [" post-edit; handles prepend-only append patterns without re-flagging.
   - Seal-by-sentinel allow-list retirement: replace regex body with __NAME_NEVER_MATCH__ when a transitional tolerance has served its purpose; keeps negated-grep syntax valid while tolerating nothing.
   - Four-stream evidence capture for validation phases: test-suite + doctor + migration-adapter-against-fixture + clean-clone-shape, each with a named marker line the gate verifier keys on.
   - Framing-verifier-friendly migration callouts: describe the relocation without literally naming the legacy path, so the no-legacy-install grep stays clean while the narrative stays informative.
   - Config is override, not canonical-location declaration: state_root: line in config.yml conflicts with Rule 3 directory existence; preferred pattern is an empty or commented-example config.>

   ## Knowledge Captured

   <Bulleted list. For each new MEM entry created during M015, cite the ID and a one-line summary. If no new MEM entries were created (the milestone operated entirely within established knowledge), say so explicitly — "No new MEM entries; M015 exercised the pre-change gate scaffolding (MEM011) and single-script-file Check shape (AD-19) patterns repeatedly and confirmed both remain sound."

   Also cite any DECISIONS.md entries added during the milestone (e.g., D003 from P02 re: state_root: removal).>

   ## Validation Summary

   All 19 Functional Requirements (FR-001..FR-019) verified PASS with cited evidence. See `.orchestrator/milestones/M015/M015-VERIFICATION.md` for the per-FR breakdown.

   Validation streams:
   - **Test suite sweep**: all 8 `tests/test-s*.sh` pass. Evidence: `.orchestrator/milestones/M015/phases/P04/evidence/test-suite-transcript.txt`.
   - **Doctor report**: `scripts/diagnostics/run-doctor.sh` clean. Evidence: `.orchestrator/milestones/M015/phases/P04/evidence/doctor-report.txt`.
   - **Migration adapter**: `scripts/migrate/migrate.sh` produces valid `.orchestrator/` from spec-kit-shaped fixture. Evidence: `.orchestrator/milestones/M015/phases/P04/evidence/migration-adapter-transcript.txt`.
   - **Clean-clone shape**: `git archive HEAD | tar -x` extraction has no extension-host artifacts. Evidence: `.orchestrator/milestones/M015/phases/P04/evidence/clean-clone-shape.txt`.

   The spec's assumption that M003 P07/P08 evidence is sufficient for the behavioral half of FR-018 (orchestrator-auto e2e) is honored — P04 does not attempt to re-run auto inside the clean-clone extraction; the shape check covers the tree-structure half and M003 covers the behavioral half.

   ## Sign-off

   M015 Standalone Cutover is complete. The orchestrator is ready for M009 launch with an unambiguous standalone identity.
   ```

7. Run the T01 milestone summary presence check:

   ```bash
   bash scripts/verify/m015-p04-milestone-summary-present.sh
   ```

   Expected: `PASS: milestone summary schema-shaped and references P01..P04`.

8. Run the full phase must-haves sweep — all truths, artifacts, key links must PASS:

   ```bash
   bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M015/phases/P04
   ```

   Expected: all PASS, no FAIL lines.

9. Run all seven P04 verify scripts to confirm the phase is fully green:

   ```bash
   bash scripts/verify/m015-p04-all-tests-pass.sh
   bash scripts/verify/m015-p04-doctor-clean.sh
   bash scripts/verify/m015-p04-speckit-migration-works.sh
   bash scripts/verify/m015-p04-clean-clone-shape.sh
   bash scripts/verify/m015-p04-verification-complete.sh
   bash scripts/verify/m015-p04-milestone-summary-present.sh
   bash scripts/verify/m015-p04-evidence-captured.sh
   ```

   All seven must exit 0 with PASS lines.

## Must-Haves

This task addresses these phase must-haves:

- Truth: M015-SUMMARY.md exists, schema-shaped, references P01..P04
- Artifact: .orchestrator/milestones/M015/M015-SUMMARY.md (min 30 lines, contains "milestone-summary")
- Key Link: .orchestrator/milestones/M015/M015-SUMMARY.md → .orchestrator/milestones/M015/M015-ROADMAP.md

After T04, all phase must-haves are PASS; all FR-001..FR-019 verdicts in M015-VERIFICATION.md are PASS; all seven P04 verify scripts PASS.

## Verification

- T01 gate PASSes:

  ```
  bash scripts/verify/m015-p04-milestone-summary-present.sh
  ```

- Schema shape visually confirmed: frontmatter has `type: milestone-summary`, `schema_version: "1.0"`, `id: "M015"`, `parent: null`, `milestone: "M015"`, and the standard mandatory fields.

- Every phase id (P01, P02, P03, P04) appears in the document (T01 verifier asserts this).

- Full phase gate sweep PASSes:

  ```
  bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M015/phases/P04
  ```

## Inputs

### From Previous Tasks

- `.orchestrator/milestones/M015/M015-VERIFICATION.md` (from T03)
  - Key content: overall verdict (PASS), per-FR verdicts, deviations section. T04 cites this as the "Validation Summary" section's primary source.
- Four T02 evidence transcripts under `.orchestrator/milestones/M015/phases/P04/evidence/` — cited in the Validation Summary with exact paths.
- Seven `scripts/verify/m015-p04-*.sh` (from T01) — cited under key_files if the summary lists them; otherwise referenced in P04 phase summary paragraph.

### From Disk (Pre-existing)

- `templates/milestone-summary.md` — schema source of truth; T04 follows this skeleton.
- `.orchestrator/milestones/M015/phases/P01/P01-SUMMARY.md` — P01 phase summary (provides, key_decisions, patterns_established, duration).
- `.orchestrator/milestones/M015/phases/P02/P02-SUMMARY.md` — P02 phase summary.
- `.orchestrator/milestones/M015/phases/P03/P03-SUMMARY.md` — P03 phase summary.
- `.orchestrator/milestones/M015/M015-ROADMAP.md` — roadmap for cross-referencing phase goals and dependency graph.
- `.orchestrator/milestones/M001/milestone-summary.md` (if it exists) or `.orchestrator/milestones/M003/M003-SUMMARY.md` — structural precedent. Use whichever is closest to a validation-phase milestone summary; follow its tone and length.

### Structural Precedent

The M003 milestone summary (`.orchestrator/milestones/M003/M003-SUMMARY.md`) is the closest structural precedent — a cutover-validation milestone similar in shape to M015. Target a comparable length (roughly 400-700 prose words plus frontmatter + bulleted sections).

## Constraints

- **Follow templates/milestone-summary.md schema exactly** in the frontmatter. Any extra fields are permissible; missing mandatory fields are not.
- **No new runtime code or script changes** — T04 is authoring only.
- **Prose budget**: total document ≤ ~1200 lines (aim for ~150-300 lines including frontmatter and bullets). A verbose milestone summary is a maintenance liability.
- **Do not copy phase-summary bodies verbatim** — synthesize. Each phase gets ~100-150 words in the Phase Summaries section.
- **Cite evidence paths literally** (no backticks around artifact paths per MEM023) in the Validation Summary section, consistent with the P04-PLAN.md style.
- **Verification result is "pass"** — the milestone closed with all FRs PASS.
- **completed_at uses ISO 8601 UTC**: `date -u +%Y-%m-%dT%H:%M:%SZ`.

## Expected Output

At task end:

- `.orchestrator/milestones/M015/M015-SUMMARY.md` exists, ≥ 30 lines, frontmatter follows milestone-summary schema, body covers P01..P04 + Validation Summary + Sign-off.
- `bash scripts/verify/m015-p04-milestone-summary-present.sh` → PASS.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M015/phases/P04` → every Truth PASS, every Artifact PASS, every Key Link PASS, zero FAIL lines.
- All seven `scripts/verify/m015-p04-*.sh` PASS.
- The milestone is ready for M009 launch work.
