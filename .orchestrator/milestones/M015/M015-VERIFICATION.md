# M015 Verification Report

**Milestone**: M015 Standalone Cutover
**Completed**: 2026-04-15T00:00:00Z
**Verification author**: T03 of M015/P04
**Spec**: specs/015-standalone-cutover/spec.md
**Overall verdict**: PASS

## How to read this report

Each row below corresponds to one Functional Requirement from
`specs/015-standalone-cutover/spec.md`. The verdict is a single token
(`PASS` or `FAIL`). The evidence pointer is a file path to either a
verify script (which, when re-run, re-confirms the verdict) or an
evidence transcript captured during P04/T02. Readers can answer
"did FR-NNN pass?" in one `grep FR-NNN M015-VERIFICATION.md`.

Greppable shape: every verdict line begins with `- **FR-NNN**` followed
by a human-readable summary, the verdict token, and a file-path
evidence pointer.

## FR Verdict Table

### Spec-Kit Host Removal

- **FR-001** PASS — Remove `extension.yml` from project root — Evidence: `scripts/verify/m015-p01-no-extension-yml.sh`
- **FR-002** PASS — Remove `.claude/commands/speckit.*.md` dogfooded slash commands — Evidence: `scripts/verify/m015-p01-no-speckit-commands.sh`
- **FR-003** PASS — Remove `.specify/scripts/bash/` — Evidence: `scripts/verify/m015-p01-no-specify-bash.sh`
- **FR-004** PASS — Remove `.specify/templates/` (commands/ + spec-kit-style template files) — Evidence: `scripts/verify/m015-p01-no-specify-templates.sh`
- **FR-005** PASS — No dangling references to removed files in retained code/docs — Evidence: `scripts/verify/m015-p01-no-stale-refs.sh`

### State Tree Migration

- **FR-006** PASS — All orchestrator state migrated from `.specify/orchestrator/` to `.orchestrator/` without data loss — Evidence: `scripts/verify/m015-p02-state-tree-migrated.sh`
- **FR-007** PASS — Constitution moved to `.orchestrator/memory/constitution.md` and references updated — Evidence: `scripts/verify/m015-p02-constitution-moved.sh`
- **FR-008** PASS — Resolver rule 4 (`.specify/orchestrator/` bridge) removed from `scripts/state/resolve-root.sh` — Evidence: `scripts/verify/m015-p02-resolver-no-bridge.sh`
- **FR-009** PASS — No hardcoded `.specify/orchestrator/` references in scripts/commands/templates/tests (except migration adapters targeting it as source) — Evidence: `scripts/verify/m015-p02-no-stale-state-refs.sh`

### Documentation Reframe

- **FR-010** PASS — `README.md`, `CLAUDE.md`, `references/architecture.md`, `references/installation.md`, `docs/getting-started.md`, `CHANGELOG.md` reframed as standalone orchestrator — Evidence: `scripts/verify/m015-p03-standalone-framing.sh` + `scripts/verify/m015-p03-no-legacy-install.sh`
- **FR-011** PASS — Historical spec-kit references preserved in `CHANGELOG.md` and milestone summary files (immutable artifacts) — Evidence: `scripts/verify/m015-p03-changelog-has-m015.sh` (snapshot-based historical-immutability check)
- **FR-012** PASS — Migration documentation for users coming from spec-kit retained/added — Evidence: `scripts/verify/m015-p03-migration-doc.sh` + `docs/migrating-from-speckit.md`

### Migration Adapter Preservation

- **FR-013** PASS — Migration adapters retained and in working order — Evidence: `scripts/migrate/adapters/speckit.sh` + `scripts/state/detect-speckit.sh` + `scripts/dispatch/adapters/format/speckit.sh` + `commands/migrate.md` (all present on disk; preserved verbatim through P01/P02 per empty diffs at phase close)
- **FR-014** PASS — Spec-kit migration path functional end-to-end against spec-kit-shaped fixture — Evidence: `scripts/verify/m015-p04-speckit-migration-works.sh` + `.orchestrator/milestones/M015/phases/P04/evidence/migration-adapter-transcript.txt`

### Test Suite Alignment

- **FR-015** PASS — Disposition of `m002-p07-extension-registration.sh` and `tests/fixtures/verify-{pass,fail}/extension.yml` decided (deleted) — Evidence: `scripts/verify/m015-p01-no-extension-test-artifacts.sh` (confirms absence) + `.orchestrator/milestones/M015/phases/P01/P01-SUMMARY.md` (records the deletion decision)
- **FR-016** PASS — All test suites pass with no tests skipped due to removed dependencies — Evidence: `scripts/verify/m015-p04-all-tests-pass.sh` + `.orchestrator/milestones/M015/phases/P04/evidence/test-suite-transcript.txt` (see Deviations: 8 suites present, spec says 7)
- **FR-017** PASS — `orchestrator-doctor` reports clean state (no orphans, no stale references, no missing files) — Evidence: `scripts/verify/m015-p04-doctor-clean.sh` + `.orchestrator/milestones/M015/phases/P04/evidence/doctor-report.txt`

### End-to-End Validation

- **FR-018** PASS — `orchestrator-auto` validated end-to-end on fresh clone in Claude Code native mode with no spec-kit installed — Evidence: `scripts/verify/m015-p04-clean-clone-shape.sh` + `.orchestrator/milestones/M015/phases/P04/evidence/clean-clone-shape.txt` (post-cutover tree shape); behavioral half covered by M003 P07/P08 transcript per spec's Assumptions section (`.orchestrator/milestones/M003/phases/P07/`, `.orchestrator/milestones/M003/phases/P08/`)
- **FR-019** PASS — `orchestrator:init` produces standalone configuration in fresh project with no spec-kit installed — Evidence: `scripts/verify/m015-p04-clean-clone-shape.sh` (confirms no spec-kit artifacts in archive for init to encounter); behavioral half covered by M008 P07 onboarding-init validation per `.specify/orchestrator/milestones/M008/phases/P07/P07-SUMMARY.md`

## Upstream Validation Evidence

The spec's Assumptions section (`specs/015-standalone-cutover/spec.md`)
explicitly accepts M003 P07/P08 transcripts as sufficient evidence that
`orchestrator-auto` runs standalone in Claude Code native mode, and
M008 P07 is accepted as sufficient evidence that `orchestrator:init`
produces standalone configuration. This report does not re-run auto
inside a fresh clone or re-run init against a pristine fixture — the
`m015-p04-clean-clone-shape.sh` check validates the post-cutover tree
structure (no `extension.yml`, no `.specify/scripts/bash/`, no
`.specify/templates/`, no `.claude/commands/speckit.*.md`), and the
cited upstream transcripts cover the behavioral half.

## Deviations From Spec

- **"7 test suites" → 8**: the spec's FR-016 says "all 7 test suites."
  Inspection during T01/T02 confirms 8 suites exist (see
  `.orchestrator/milestones/M015/phases/P04/evidence/test-suite-transcript.txt`);
  all 8 run and pass. The "7" is a stale count in the FR copy; the
  intent is "all suites pass with no skips," which is satisfied. No
  test is skipped on account of removed dependencies.
- No other deviations.

## Summary

- **PASS**: 19 / 19
- **FAIL**: 0 / 19
- **Deviations**: 1 non-material (stale suite count in FR-016 spec text)

## Sign-off

All 19 Functional Requirements verified **PASS** with cited evidence.
M015 Standalone Cutover is complete pending milestone summary (T04).

Spec source of truth: `specs/015-standalone-cutover/spec.md`
