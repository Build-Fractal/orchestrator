---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M015"
name: "Author M015-VERIFICATION.md with PASS/FAIL per FR-001..FR-019"
depends_on: [T02]
---

## Prerequisites

- T01 complete: seven P04 verify scripts exist; fixture scaffold exists.
- T02 complete: four evidence transcripts exist under `.orchestrator/milestones/M015/phases/P04/evidence/`, and five of the seven T01 gate verifiers now PASS.
- `specs/015-standalone-cutover/spec.md` contains the canonical FR-001..FR-019 list — that is the source of truth for the 19 requirement verdicts.

## Description

Author `.orchestrator/milestones/M015/M015-VERIFICATION.md`: a mechanically-greppable document that scores each of FR-001 through FR-019 with a PASS or FAIL verdict and cites an evidence pointer for each.

The doc is structured so a grep for `FR-NNN` returns a single line containing that FR's ID, verdict token, and evidence pointer. A reader auditing the cutover should be able to answer "did FR-007 pass?" in one grep without reading surrounding narrative.

Each FR maps to one or more of:
- A T01 gate verify script (e.g. `scripts/verify/m015-p04-doctor-clean.sh`).
- A phase-specific verify script from P01/P02/P03 (e.g. `scripts/verify/m015-p01-no-extension-yml.sh`).
- An evidence transcript (e.g. `.orchestrator/milestones/M015/phases/P04/evidence/migration-adapter-transcript.txt`).
- A specific artifact path (e.g. `docs/migrating-from-speckit.md`).

The mapping is table-driven — one row per FR — and is audited at task end by running `bash scripts/verify/m015-p04-verification-complete.sh`.

## Steps

1. Re-read `specs/015-standalone-cutover/spec.md` FR list (section "Functional Requirements"). Confirm all 19 FRs are present and note their grouping headings (Spec-Kit Host Removal, State Tree Migration, Documentation Reframe, Migration Adapter Preservation, Test Suite Alignment, End-to-End Validation).

2. Re-read each phase's summary to know which verify scripts exist and what they assert:
   - [`.orchestrator/milestones/M015/phases/P01/P01-SUMMARY.md`](../../../../../milestones/M015/phases/P01/P01-SUMMARY.md) — enumerates P01 verify scripts.
   - [`.orchestrator/milestones/M015/phases/P02/P02-SUMMARY.md`](../../../../../milestones/M015/phases/P02/P02-SUMMARY.md) — enumerates P02 verify scripts.
   - [`.orchestrator/milestones/M015/phases/P03/P03-SUMMARY.md`](../../../../../milestones/M015/phases/P03/P03-SUMMARY.md) — enumerates P03 verify scripts.

3. Build the FR → evidence map. Each FR below includes its spec text summary, the likely evidence pointer, and the verdict you expect:

   | FR | Summary | Evidence pointer class |
   |----|---------|------------------------|
   | FR-001 | Remove extension.yml | `scripts/verify/m015-p01-no-extension-yml.sh` |
   | FR-002 | Remove .claude/commands/speckit.*.md | `scripts/verify/m015-p01-no-speckit-commands.sh` |
   | FR-003 | Remove .specify/scripts/bash/ | `scripts/verify/m015-p01-no-specify-bash.sh` |
   | FR-004 | Remove .specify/templates/ | `scripts/verify/m015-p01-no-specify-templates.sh` |
   | FR-005 | No dangling references to removed files | `scripts/verify/m015-p01-no-stale-refs.sh` |
   | FR-006 | Move state to .orchestrator/ | `scripts/verify/m015-p02-state-tree-migrated.sh` |
   | FR-007 | Move constitution to .orchestrator/memory/ | `scripts/verify/m015-p02-constitution-moved.sh` |
   | FR-008 | Remove resolver rule 4 | `scripts/verify/m015-p02-resolver-no-bridge.sh` |
   | FR-009 | No hardcoded .specify/orchestrator/ refs | `scripts/verify/m015-p02-no-stale-state-refs.sh` |
   | FR-010 | Reframe primary docs as standalone | `scripts/verify/m015-p03-standalone-framing.sh` + `m015-p03-no-legacy-install.sh` |
   | FR-011 | Preserve historical spec-kit refs in CHANGELOG / summaries | `scripts/verify/m015-p03-changelog-has-m015.sh` (the historical-immutability portion) |
   | FR-012 | Migration doc for users coming from spec-kit | `scripts/verify/m015-p03-migration-doc.sh` + `docs/migrating-from-speckit.md` |
   | FR-013 | Retain migration adapters | `scripts/migrate/adapters/speckit.sh`, `scripts/state/detect-speckit.sh`, `scripts/dispatch/adapters/format/speckit.sh`, `commands/migrate.md` (existence check) |
   | FR-014 | Spec-kit migration path functional end-to-end | `scripts/verify/m015-p04-speckit-migration-works.sh` + `.orchestrator/milestones/M015/phases/P04/evidence/migration-adapter-transcript.txt` |
   | FR-015 | Disposition of extension-registration test | P01 summary records the decision (deleted); `scripts/verify/m015-p01-no-extension-test-artifacts.sh` confirms absence |
   | FR-016 | All 7 (actually 8) test suites pass | `scripts/verify/m015-p04-all-tests-pass.sh` + `.orchestrator/milestones/M015/phases/P04/evidence/test-suite-transcript.txt` |
   | FR-017 | orchestrator-doctor clean | `scripts/verify/m015-p04-doctor-clean.sh` + `.orchestrator/milestones/M015/phases/P04/evidence/doctor-report.txt` |
   | FR-018 | orchestrator-auto e2e on fresh clone | `scripts/verify/m015-p04-clean-clone-shape.sh` (shape); [M003](../../../../../milestones/M003/index.md) P07/P08 validation (behavioral, cited as upstream evidence per spec assumption) |
   | FR-019 | orchestrator:init produces standalone config on no-spec-kit | `scripts/verify/m015-p04-clean-clone-shape.sh` (confirms no spec-kit artifacts that init would reach); [M008](../../../../../milestones/M008/index.md) P07 onboarding init already validated |

4. Author `.orchestrator/milestones/M015/M015-VERIFICATION.md` using this skeleton (fill in content from your map above):

   ```markdown
   # M015 Verification Report

   **Milestone**: M015 Standalone Cutover
   **Completed**: <ISO-8601 UTC timestamp>
   **Verification author**: T03 of M015/P04
   **Spec**: specs/015-standalone-cutover/spec.md
   **Overall verdict**: PASS

   ## How to read this report

   Each row below corresponds to one Functional Requirement from
   specs/015-standalone-cutover/spec.md. The verdict is a single token
   (PASS or FAIL). The evidence pointer is a file path to either a
   verify script (which, when run, re-confirms the verdict) or an
   evidence transcript captured during P04/T02.

   ## FR Verdict Table

   ### Spec-Kit Host Removal

   - **FR-001** — Remove extension.yml — **PASS** — Evidence: scripts/verify/m015-p01-no-extension-yml.sh
   - **FR-002** — Remove .claude/commands/speckit.*.md — **PASS** — Evidence: scripts/verify/m015-p01-no-speckit-commands.sh
   - **FR-003** — Remove .specify/scripts/bash/ — **PASS** — Evidence: scripts/verify/m015-p01-no-specify-bash.sh
   - **FR-004** — Remove .specify/templates/ — **PASS** — Evidence: scripts/verify/m015-p01-no-specify-templates.sh
   - **FR-005** — No dangling references — **PASS** — Evidence: scripts/verify/m015-p01-no-stale-refs.sh

   ### State Tree Migration

   - **FR-006** — State at .orchestrator/ — **PASS** — Evidence: scripts/verify/m015-p02-state-tree-migrated.sh
   - **FR-007** — Constitution at .orchestrator/memory/constitution.md — **PASS** — Evidence: scripts/verify/m015-p02-constitution-moved.sh
   - **FR-008** — Resolver rule 4 removed — **PASS** — Evidence: scripts/verify/m015-p02-resolver-no-bridge.sh
   - **FR-009** — No hardcoded .specify/orchestrator refs — **PASS** — Evidence: scripts/verify/m015-p02-no-stale-state-refs.sh

   ### Documentation Reframe

   - **FR-010** — Primary docs reframed — **PASS** — Evidence: scripts/verify/m015-p03-standalone-framing.sh + scripts/verify/m015-p03-no-legacy-install.sh
   - **FR-011** — Historical artifacts preserved — **PASS** — Evidence: scripts/verify/m015-p03-changelog-has-m015.sh (snapshot-based immutability check)
   - **FR-012** — Migration guide for spec-kit users — **PASS** — Evidence: scripts/verify/m015-p03-migration-doc.sh + docs/migrating-from-speckit.md

   ### Migration Adapter Preservation

   - **FR-013** — Migration adapters retained — **PASS** — Evidence: scripts/migrate/adapters/speckit.sh, scripts/state/detect-speckit.sh, scripts/dispatch/adapters/format/speckit.sh, commands/migrate.md (all present; preserved verbatim per empty git diff --stat at P01/P02 close)
   - **FR-014** — Spec-kit migration path functional e2e — **PASS** — Evidence: scripts/verify/m015-p04-speckit-migration-works.sh + .orchestrator/milestones/M015/phases/P04/evidence/migration-adapter-transcript.txt

   ### Test Suite Alignment

   - **FR-015** — Disposition of extension-registration test — **PASS** — Evidence: P01 decision to delete; scripts/verify/m015-p01-no-extension-test-artifacts.sh confirms fixtures removed
   - **FR-016** — All test suites pass — **PASS** — Evidence: scripts/verify/m015-p04-all-tests-pass.sh + .orchestrator/milestones/M015/phases/P04/evidence/test-suite-transcript.txt (note: 8 suites actually present; "7" in spec is a stale count)
   - **FR-017** — Doctor clean — **PASS** — Evidence: scripts/verify/m015-p04-doctor-clean.sh + .orchestrator/milestones/M015/phases/P04/evidence/doctor-report.txt

   ### End-to-End Validation

   - **FR-018** — orchestrator-auto e2e on fresh clone — **PASS** — Evidence: scripts/verify/m015-p04-clean-clone-shape.sh confirms no extension-host artifacts in `git archive HEAD`; M003 P07/P08 transcript (`.orchestrator/milestones/M003/phases/P07/...`, `.../P08/...`) previously validated orchestrator-auto behavior in Claude Code native mode (per spec assumption: M003 evidence is sufficient)
   - **FR-019** — orchestrator:init produces standalone config — **PASS** — Evidence: scripts/verify/m015-p04-clean-clone-shape.sh confirms no spec-kit artifacts present for init to encounter; M008 P07 onboarding init was already validated end-to-end per M008 summary

   ## Upstream Validation Evidence

   The spec's Assumptions section (specs/015-standalone-cutover/spec.md)
   explicitly accepts M003 P07/P08 transcripts as sufficient evidence
   that orchestrator-auto runs standalone in Claude Code native mode.
   This report does not re-run auto-inside-clean-clone — the clean-clone
   shape check validates the post-cutover tree structure, and M003's
   prior behavioral validation covers the behavioral half.

   ## Deviations From Spec

   - **"7 test suites" → 8**: the spec's FR-016 says "all 7 test suites."
     Inspection during T01/T02 confirms 8 suites exist (test-s01 through
     test-s08); all 8 run and pass. The "7" is a stale count in the FR
     copy; the intent is "all suites pass with no skips," which is
     satisfied.
   - None beyond the count discrepancy.

   ## Sign-off

   All 19 Functional Requirements verified PASS with cited evidence.
   M015 Standalone Cutover is complete.
   ```

5. Ensure every `FR-NNN` token appears at least once in the doc. A simple grep-loop (done mentally or with the T01 verify script in step 6 below) catches any you missed.

6. Run the T01 verification completeness gate:

   ```bash
   bash scripts/verify/m015-p04-verification-complete.sh
   ```

   Expected output: `PASS: verification doc references FR-001 through FR-019 and contains PASS verdicts`.

7. Run the full phase must-haves sweep to confirm T03 closes 10 of the 11 phase artifacts (M015-SUMMARY.md remains for T04):

   ```bash
   bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M015/phases/P04
   ```

## Must-Haves

This task addresses these phase must-haves:

- Truth: M015-VERIFICATION.md exists and scores FR-001..FR-019 with PASS/FAIL + evidence pointer
- Artifact: .orchestrator/milestones/M015/M015-VERIFICATION.md (min 60 lines, contains "FR-019")
- Key Link: .orchestrator/milestones/M015/M015-VERIFICATION.md → specs/015-standalone-cutover/spec.md

This task does NOT address M015-SUMMARY.md (T04).

## Verification

- T01's completeness gate PASSes:

  ```
  bash scripts/verify/m015-p04-verification-complete.sh
  ```

- Every FR ID is present in the doc. The T01 script loops 1..19 and greps `FR-00N` (or `FR-0NN` for N >= 10) — if any is missing, it fails with `FAIL: FR-NNN missing from verification doc`.

- At least one `PASS` token is present (T01 checks this too; expected count is 19).

- Key-link check: the verification doc contains a reference to `spec.md` (basename), confirmed via `grep -q "spec.md" .orchestrator/milestones/M015/M015-VERIFICATION.md` (this is implicit in `check-must-haves.sh` for the key-link row).

## Inputs

### From Previous Tasks

- All seven `scripts/verify/m015-p04-*.sh` (from T01): each verifier named in the FR table above; T03 cites these as evidence pointers.
- Four evidence transcripts (from T02) under `.orchestrator/milestones/M015/phases/P04/evidence/`: cited as evidence pointers for FR-014, FR-016, FR-017, FR-018, FR-019.

### From Disk (Pre-existing)

- `specs/015-standalone-cutover/spec.md` — canonical FR-001..FR-019 source of truth. Re-read section "Functional Requirements" to confirm wording and grouping before authoring verdicts.
- [`.orchestrator/milestones/M015/phases/P01/P01-SUMMARY.md`](../../../../../milestones/M015/phases/P01/P01-SUMMARY.md) — enumerates scripts/verify/m015-p01-*.sh names (FR-001..FR-005, FR-015 evidence pointers).
- [`.orchestrator/milestones/M015/phases/P02/P02-SUMMARY.md`](../../../../../milestones/M015/phases/P02/P02-SUMMARY.md) — enumerates scripts/verify/m015-p02-*.sh names (FR-006..FR-009 evidence pointers).
- [`.orchestrator/milestones/M015/phases/P03/P03-SUMMARY.md`](../../../../../milestones/M015/phases/P03/P03-SUMMARY.md) — enumerates scripts/verify/m015-p03-*.sh names (FR-010..FR-012 evidence pointers).
- Migration adapter files (for FR-013 presence citation):
  - `scripts/migrate/adapters/speckit.sh`
  - `scripts/state/detect-speckit.sh`
  - `scripts/dispatch/adapters/format/speckit.sh`
  - `commands/migrate.md`

## Constraints

- **One row per FR**, with the FR ID in bold, verdict token plain (PASS/FAIL), evidence as a file path. The exact format shown in step 4's skeleton is the target shape — do not restructure to a table or code block that hides `FR-NNN` from line-wise grep.
- **Every FR must have an evidence pointer**. Do not write `PASS — Evidence: TBD` or `PASS — Evidence: manual inspection`. If an FR genuinely has no mechanical evidence, the evidence pointer must cite a specific phase summary + a specific FR-keyed sentence in it.
- **Deviations section**: record any discrepancy between spec wording and on-disk reality (minimum: the "7 vs 8 suites" count). Do not paper over inconsistencies.
- **Do not modify** any verify script or evidence transcript in this task.
- **FR IDs formatted with zero-padding** (FR-001, FR-002, ..., FR-019). The T01 verifier constructs these exact strings.

## Expected Output

At task end:

- `.orchestrator/milestones/M015/M015-VERIFICATION.md` exists, ≥ 60 lines, contains every `FR-NNN` for NNN in 001..019, contains at least one PASS verdict, contains "spec.md" reference.
- `bash scripts/verify/m015-p04-verification-complete.sh` → PASS.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M015/phases/P04` → all Truths PASS, 14 of 15 artifacts PASS (M015-SUMMARY.md remains for T04), both key links PASS.
- No other files modified.
