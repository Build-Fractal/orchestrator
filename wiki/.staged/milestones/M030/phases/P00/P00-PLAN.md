---
schema_version: "1.0"
type: phase-plan
phase: "P00"
milestone: "M030"
goal: "Build the version-controlled classifier-ground-truth fixture corpus at tests/fixtures/m030-classifier-corpus/ — ≥30 hand-labeled pre-M030 task plans (T*-PLAN.md) drawn from this repo's milestone history, with labels recorded in labels.yml and methodology recorded in README.md, committed BEFORE scripts/dispatch/classify-task.sh is authored in P01 so the D-A4/SC-10 independence-by-construction property holds."
demo_sentence: "An operator reads tests/fixtures/m030-classifier-corpus/labels.yml and counts ≥30 entries each carrying plan_path + character + confidence + rationale, reads tests/fixtures/m030-classifier-corpus/README.md and confirms the methodology + D-A4 compliance section, runs bash tools/verify/p00-phase-suite.sh and observes SUMMARY: pass=N fail=0 with exit 0, and confirms via git log that the corpus commit landed before any commit creating scripts/dispatch/classify-task.sh."
risk: "medium"
depends_on: []
---

## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19.
     Verifier scripts live under tools/verify/ — project-owned path,
     slug-bearing filenames so install-clobber risk is contained.
     Each verifier is co-authored alongside its corresponding artifact
     within the SAME task (plan-time discipline rule 2). -->

### Truths

- `tests/fixtures/m030-classifier-corpus/labels.yml` exists with YAML frontmatter (`schema_version: "1.0"`, `type: classifier-fixture-corpus`, `milestone: "M030"`, `phase: "P00"`, `created_at`, `labeler_constraint`) and an `entries:` list with ≥30 items, each entry carrying the four required keys `plan_path`, `character`, `confidence`, `rationale`.
  - Check: `bash tools/verify/p00-corpus-shape.sh`

- Every `plan_path` value in `labels.yml` resolves to an existing file on disk (not a deleted reference, not a typo). Resolution tested via `[ -f "$plan_path" ]` per entry.
  - Check: `bash tools/verify/p00-plans-exist.sh`

- Class-coverage floor holds: ≥5 entries with `character: mechanical`, ≥5 with `character: standard`, ≥5 with `character: novel` (so no class can be empty when SC-10's ≥85% agreement is later measured against the ≥30-entry corpus). Each entry's `character` value is exactly one of the three-class taxonomy from FR-1.
  - Check: `bash tools/verify/p00-class-coverage.sh`

- Every entry's `confidence` value is exactly one of `high|medium|low` (matching the FR-1 classifier output vocabulary so labels.yml can be diffed against `classify-task.sh` stdout in P01 without a vocabulary-translation layer).
  - Check: `bash tools/verify/p00-corpus-shape.sh`

- Every entry's `rationale` field is non-empty and ≥1 sentence — the labeling party's reason for picking this character/confidence pair, captured at labeling time. This is the D-A4 audit trail: future readers can replay the labeler's reasoning without access to the (now-shipped) classifier implementation.
  - Check: `bash tools/verify/p00-corpus-shape.sh`

- `tests/fixtures/m030-classifier-corpus/README.md` exists with at minimum these sections: `## Source Pool` (names the milestone-history sweep that produced the candidate set), `## Sampling Methodology` (how 30+ plans were selected from 455 task plans available), `## Labeling Rubric` (the FR-1 character definitions reproduced verbatim so labelers and future auditors apply identical criteria), `## D-A4 Independence Compliance` (states explicitly that `scripts/dispatch/classify-task.sh` did not exist on disk at labeling time, and that no labeler had access to a draft implementation).
  - Check: `bash tools/verify/p00-readme-shape.sh`

- D-A4 independence-by-construction holds at corpus-commit time: at the moment `tools/verify/p00-d-a4-independence.sh` runs during P00 execution, `scripts/dispatch/classify-task.sh` does not yet exist anywhere in the working tree. (This is the mechanical proxy for the timeline constraint — the verifier passes by absence of the future file. Post-P01, the verifier graduates to a `git log` ordering check: the labels.yml first-commit timestamp precedes the classify-task.sh first-commit timestamp.)
  - Check: `bash tools/verify/p00-d-a4-independence.sh`

- `bash tools/verify/p00-phase-suite.sh` invokes all five P00 gates (corpus-shape, plans-exist, class-coverage, readme-shape, d-a4-independence) in order, exits 0 iff every sub-gate passes, and emits a single line `SUMMARY: p00-phase-suite.sh pass=N fail=M` before exit.
  - Check: `bash tools/verify/p00-phase-suite.sh`

### Artifacts

- `tests/fixtures/m030-classifier-corpus/labels.yml` (min 100 lines, contains "schema_version", contains "type: classifier-fixture-corpus", contains "entries:", contains "character:", contains "rationale:") — create
- `tests/fixtures/m030-classifier-corpus/README.md` (min 60 lines, contains "## Source Pool", contains "## Sampling Methodology", contains "## Labeling Rubric", contains "## D-A4 Independence Compliance", contains "mechanical", contains "novel") — create
- `tools/verify/p00-corpus-shape.sh` (min 40 lines, contains "schema_version", contains "entries:", contains "character", contains "confidence", contains "rationale") — create
- `tools/verify/p00-plans-exist.sh` (min 25 lines, contains "plan_path", contains "[ -f") — create
- `tools/verify/p00-class-coverage.sh` (min 30 lines, contains "mechanical", contains "standard", contains "novel") — create
- `tools/verify/p00-readme-shape.sh` (min 25 lines, contains "Source Pool", contains "Sampling Methodology", contains "Labeling Rubric", contains "D-A4 Independence Compliance") — create
- `tools/verify/p00-d-a4-independence.sh` (min 30 lines, contains "classify-task.sh") — create
- `tools/verify/p00-phase-suite.sh` (min 30 lines, contains "SUMMARY:", contains "p00-corpus-shape", contains "p00-plans-exist", contains "p00-class-coverage", contains "p00-readme-shape", contains "p00-d-a4-independence") — create

### Key Links

- `specs/032-adaptive-model-selection/spec.md` → `tests/fixtures/m030-classifier-corpus/labels.yml` (SC-10 names the corpus path; FR-1 / FR-2 define the labeling vocabulary)
- [`.orchestrator/milestones/M030/M030-CONTEXT.md`](../../../../milestones/M030/M030-CONTEXT.md) → `tests/fixtures/m030-classifier-corpus/README.md` (D-A4 independence constraint originates the README's compliance section)
- `tests/fixtures/m030-classifier-corpus/labels.yml` → `tests/fixtures/m030-classifier-corpus/README.md` (labels.yml frontmatter `labeler_constraint:` value points at README's compliance section)
- `tools/verify/p00-phase-suite.sh` → `tools/verify/p00-corpus-shape.sh` (suite invokes shape gate)
- `tools/verify/p00-phase-suite.sh` → `tools/verify/p00-d-a4-independence.sh` (suite invokes independence gate)

## Tasks

### T01: Source-pool sweep + corpus skeleton + shape verifier

See `tasks/T01-source-pool-and-skeleton-PLAN.md`.

### T02: Hand-labeling + class-coverage verifier

See `tasks/T02-hand-labeling-PLAN.md`.

### T03: README methodology + D-A4 independence verifier + phase-suite gate

See `tasks/T03-readme-and-gate-PLAN.md`.

## Task Dependencies

```
T01 ──▶ T02 ──▶ T03
```

Linear chain. T01 enumerates the candidate pool (455 task plans across `.orchestrator/milestones/M*/`), selects ≥30 with class-diversity intent (the labeler picks plans that read mechanical / standard / novel based on a quick scan), writes the `labels.yml` skeleton with `plan_path` + placeholder `character: <to-fill>` + `confidence: <to-fill>` + `rationale: <to-fill>` for each, and ships `tools/verify/p00-corpus-shape.sh` + `tools/verify/p00-plans-exist.sh` to gate the skeleton's structural integrity. T02 reads each selected plan's body, applies a `character` + `confidence` + `rationale` per the FR-1 rubric, and ships `tools/verify/p00-class-coverage.sh` to gate the per-class floor. T03 writes the README documenting methodology + D-A4 compliance, ships `tools/verify/p00-d-a4-independence.sh` (the timeline gate) + `tools/verify/p00-readme-shape.sh` + `tools/verify/p00-phase-suite.sh`, and runs the full suite to confirm phase close.

The chain is strict — T02 cannot label entries that don't exist in the skeleton; T03's phase-suite cannot pass without T01's + T02's verifier scripts present.

## Files Likely Touched

- `tests/fixtures/m030-classifier-corpus/labels.yml` (create)
- `tests/fixtures/m030-classifier-corpus/README.md` (create)
- `tools/verify/p00-corpus-shape.sh` (create)
- `tools/verify/p00-plans-exist.sh` (create)
- `tools/verify/p00-class-coverage.sh` (create)
- `tools/verify/p00-readme-shape.sh` (create)
- `tools/verify/p00-d-a4-independence.sh` (create)
- `tools/verify/p00-phase-suite.sh` (create)

<!-- The phase plan and task plan files themselves (this file +
     tasks/T0[1-3]-*-PLAN.md) are written by the planner, not by the
     executor — they are not listed here. -->
