---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M015"
goal: "End-to-end validation of the standalone cutover: clean-clone walkthrough of orchestrator-auto in Claude Code native mode, all 7 test suites pass, orchestrator-doctor reports clean, and the spec-kit migration adapter produces a valid .orchestrator/ from a spec-kit-shaped fixture. Captures validation evidence under a dedicated phase evidence/ tree, then consolidates the cutover into M015-VERIFICATION.md (PASS/FAIL per FR-001..FR-019) and M015-SUMMARY.md (milestone closeout)."
demo_sentence: "Running bash scripts/verify/m015-p04-all-tests-pass.sh and bash scripts/verify/m015-p04-doctor-clean.sh and bash scripts/verify/m015-p04-speckit-migration-works.sh and bash scripts/verify/m015-p04-clean-clone-shape.sh all PASS; .orchestrator/milestones/M015/M015-VERIFICATION.md scores each of FR-001..FR-019 with PASS + an evidence pointer; .orchestrator/milestones/M015/M015-SUMMARY.md records the final cutover rollup; and bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M015/phases/P04 returns all PASS."
risk: "medium"
depends_on: [P03]
---

## Must-Haves

### Truths

- All 7 test suites (tests/test-s01 through test-s08, excluding the deleted one if any) run to completion and every assertion passes. The runner transcript is captured as validation evidence. No test is skipped because a removed dependency made it un-runnable.
  - Check: bash scripts/verify/m015-p04-all-tests-pass.sh

- scripts/diagnostics/run-doctor.sh exits 0 with no FAIL lines. The full doctor report is captured as validation evidence. No orphaned artifacts, no stale references, no missing files are flagged.
  - Check: bash scripts/verify/m015-p04-doctor-clean.sh

- The spec-kit migration adapter (scripts/migrate/adapters/speckit.sh via scripts/migrate/migrate.sh) produces a valid .orchestrator/ state directory from a spec-kit-shaped fixture project under tests/fixtures/m015-p04-speckit-migration/. The produced directory contains at minimum: memory/constitution.md (migrated from the fixture's .specify/memory/constitution.md) and a milestones/ subtree reflecting any source milestone data.
  - Check: bash scripts/verify/m015-p04-speckit-migration-works.sh

- A clean-clone shape test confirms the post-cutover working tree has zero extension-host artifacts: extension.yml absent, .specify/scripts/bash/ absent, .specify/templates/ absent, .claude/commands/speckit.*.md absent (project-owned), and .specify/orchestrator/ absent. The clean-clone simulation is performed against the current git HEAD via git archive into a temp directory rather than cloning over network.
  - Check: bash scripts/verify/m015-p04-clean-clone-shape.sh

- M015-VERIFICATION.md exists at .orchestrator/milestones/M015/M015-VERIFICATION.md and scores each of FR-001 through FR-019 as PASS or FAIL with a cited evidence pointer (a file path under .orchestrator/milestones/M015/phases/P##/evidence/, a verify script name, or a specific artifact path). The file is structured so that a mechanical grep can recover each FR's verdict.
  - Check: bash scripts/verify/m015-p04-verification-complete.sh

- M015-SUMMARY.md exists at .orchestrator/milestones/M015/M015-SUMMARY.md and follows the milestone-summary template schema: YAML frontmatter with schema_version, type milestone-summary, id M015, parent null, milestone M015, and the standard rollup sections (Milestone Rollup, Phase Summaries, Key Decisions, Patterns Established, Knowledge Captured). The body references every phase (P01..P04) and carries at least one sentence of closeout narrative for each.
  - Check: bash scripts/verify/m015-p04-milestone-summary-present.sh

- Validation evidence is captured under .orchestrator/milestones/M015/phases/P04/evidence/. At minimum: test-suite-transcript.txt (from T02), doctor-report.txt (from T02), migration-adapter-transcript.txt (from T02), and clean-clone-shape.txt (from T02). Each file is non-empty and dated (timestamps visible in content or transcript headers).
  - Check: bash scripts/verify/m015-p04-evidence-captured.sh

### Artifacts

- scripts/verify/m015-p04-all-tests-pass.sh (min 15 lines, contains "test-s0")
- scripts/verify/m015-p04-doctor-clean.sh (min 10 lines, contains "run-doctor")
- scripts/verify/m015-p04-speckit-migration-works.sh (min 20 lines, contains "migrate.sh")
- scripts/verify/m015-p04-clean-clone-shape.sh (min 20 lines, contains "extension.yml")
- scripts/verify/m015-p04-verification-complete.sh (min 15 lines, contains "FR-001")
- scripts/verify/m015-p04-milestone-summary-present.sh (min 10 lines, contains "M015-SUMMARY")
- scripts/verify/m015-p04-evidence-captured.sh (min 10 lines, contains "evidence")
- tests/fixtures/m015-p04-speckit-migration/build-fixture.sh (min 20 lines, contains "specify")
- tests/fixtures/m015-p04-speckit-migration/README.md (min 5 lines, contains "spec-kit")
- .orchestrator/milestones/M015/phases/P04/evidence/test-suite-transcript.txt (min 20 lines, contains "PASS")
- .orchestrator/milestones/M015/phases/P04/evidence/doctor-report.txt (min 5 lines, contains "doctor")
- .orchestrator/milestones/M015/phases/P04/evidence/migration-adapter-transcript.txt (min 5 lines, contains "migrate")
- .orchestrator/milestones/M015/phases/P04/evidence/clean-clone-shape.txt (min 5 lines, contains "clean")
- .orchestrator/milestones/M015/M015-VERIFICATION.md (min 60 lines, contains "FR-019")
- .orchestrator/milestones/M015/M015-SUMMARY.md (min 30 lines, contains "milestone-summary")

### Key Links

- .orchestrator/milestones/M015/M015-VERIFICATION.md → specs/015-standalone-cutover/spec.md
- .orchestrator/milestones/M015/M015-SUMMARY.md → .orchestrator/milestones/M015/M015-ROADMAP.md
- .orchestrator/milestones/M015/phases/P04/P04-PLAN.md → .orchestrator/milestones/M015/phases/P04/P04-PLANNING-PAYLOAD.md

## Tasks

### T01: Write P04 verify scripts and build spec-kit migration fixture

See .orchestrator/milestones/M015/phases/P04/tasks/T01-PLAN.md.

### T02: Execute the four validation streams and capture evidence

See .orchestrator/milestones/M015/phases/P04/tasks/T02-PLAN.md.

### T03: Author M015-VERIFICATION.md with PASS/FAIL per FR-001..FR-019

See .orchestrator/milestones/M015/phases/P04/tasks/T03-PLAN.md.

### T04: Author M015-SUMMARY.md milestone closeout

See .orchestrator/milestones/M015/phases/P04/tasks/T04-PLAN.md.

## Task Dependencies

```
T01 → T02 → T03 → T04
```

Strict linear chain. T01 lands all seven P04 verify scripts and the migration fixture so every downstream task has a pass/fail signal for its specific scope. T02 actually executes the four validation streams (7 test suites, doctor, migration adapter against the T01 fixture, clean-clone shape) and writes evidence transcripts to .orchestrator/milestones/M015/phases/P04/evidence/. T03 consumes the evidence from T02 to author M015-VERIFICATION.md — scoring each FR-001..FR-019 with PASS/FAIL + evidence pointer. T04 consumes P01..P04 phase summaries + T03's verification doc to author M015-SUMMARY.md, the milestone closeout.

## Scope Decision Notes

This phase is pure validation plus closeout authoring — no runtime code changes. Four scope decisions worth recording:

1. **Clean-clone test is hermetic, not network-based**. Cloning over network or against a remote introduces flakiness and secrets-handling concerns. Instead the test uses `git archive HEAD` piped into `tar -x` inside a `mktemp -d` directory — this is byte-equivalent to what a fresh clone would produce from this commit, minus the .git directory, and requires neither network nor credentials. The test then greps the extracted tree for the five host-artifact classes that P01 deleted and .specify/orchestrator (which P02 moved) and asserts all are absent. It does NOT attempt to run orchestrator-auto inside the extracted tree — M003 P07/P08 already validated auto in Claude Code native mode (spec assumption), and executing auto inside a nested tree would be a substantial orchestration puzzle without adding validation value beyond the shape assertion.

2. **M015-VERIFICATION.md scores each FR mechanically, not via narrative prose**. The doc uses a table-or-list format where every FR-### line is greppable: one line per FR with verdict token (PASS/FAIL) and an evidence pointer (verify script path, evidence transcript path, or specific artifact path). This shape lets `m015-p04-verification-complete.sh` mechanically confirm completeness — each of FR-001..FR-019 must appear at least once with a verdict. It also makes the doc useful to any future reader auditing the cutover without reading surrounding narrative.

3. **Migration adapter fixture is new, minimal, and self-contained**. tests/fixtures/m015-p04-speckit-migration/ follows the precedent set by tests/fixtures/m003-p08-gsd-minimal/: a README plus a build-fixture.sh that deterministically generates a spec-kit-shaped project tree (`.specify/memory/constitution.md`, a sample `specs/###-name/spec.md`, and optional `tasks.md`). T01 lands the fixture scaffolding; T02 runs `scripts/migrate/migrate.sh` against the built fixture in a temp directory and captures the transcript. The fixture itself is NOT committed as a populated tree — it's regenerated per run via build-fixture.sh — so the repo stays clean and the test is reproducible.

4. **Milestone summary is written last, from P01..P04 summary inputs**. M015-SUMMARY.md is NOT authored by scripts/lifecycle/phase-transition.sh (that script only writes phase summaries). T04 is a dedicated task that consumes all four phase summaries plus M015-VERIFICATION.md and writes the milestone-level closeout following templates/milestone-summary.md. This mirrors the M001 milestone-summary pattern and gives a future reader a single entry point to the milestone's full arc.

## Files Likely Touched

- scripts/verify/m015-p04-all-tests-pass.sh (create)
- scripts/verify/m015-p04-doctor-clean.sh (create)
- scripts/verify/m015-p04-speckit-migration-works.sh (create)
- scripts/verify/m015-p04-clean-clone-shape.sh (create)
- scripts/verify/m015-p04-verification-complete.sh (create)
- scripts/verify/m015-p04-milestone-summary-present.sh (create)
- scripts/verify/m015-p04-evidence-captured.sh (create)
- tests/fixtures/m015-p04-speckit-migration/build-fixture.sh (create)
- tests/fixtures/m015-p04-speckit-migration/README.md (create)
- .orchestrator/milestones/M015/phases/P04/evidence/test-suite-transcript.txt (create)
- .orchestrator/milestones/M015/phases/P04/evidence/doctor-report.txt (create)
- .orchestrator/milestones/M015/phases/P04/evidence/migration-adapter-transcript.txt (create)
- .orchestrator/milestones/M015/phases/P04/evidence/clean-clone-shape.txt (create)
- .orchestrator/milestones/M015/M015-VERIFICATION.md (create)
- .orchestrator/milestones/M015/M015-SUMMARY.md (create)
