---
schema_version: "1.0"
type: phase-summary
id: "P00"
parent: "M030"
milestone: "M030"
provides:
  - "40-plan classifier ground-truth fixture skeleton at tests/fixtures/m030-classifier-corpus/labels.yml (TBD labels — T02 fills); p00-corpus-shape.sh + p00-plans-exist.sh AD-19 verifiers under tools/verify/ (project-owned path),40-entry hand-labeled classifier ground-truth corpus (20 mechanical / 15 standard / 5 novel) plus tools/verify/p00-class-coverage.sh strict-vocabulary + per-class-floor + total-floor + no-TBD-rationale gate; tools/verify/p00-corpus-shape.sh tightened to reject TBD,corpus-README + D-A4-independence-verifier + README-shape-verifier + phase-suite-gate"
requires:
  - "none"
affects:
  - "P01"
key_files:
  - "tests/fixtures/m030-classifier-corpus/labels.yml,tools/verify/p00-corpus-shape.sh,tools/verify/p00-plans-exist.sh,tools/verify/p00-class-coverage.sh,tests/fixtures/m030-classifier-corpus/README.md,tools/verify/p00-d-a4-independence.sh,tools/verify/p00-readme-shape.sh,tools/verify/p00-phase-suite.sh"
key_decisions:
  - "D-A4 (independence-by-construction: classifier labels predate classifier code on disk); closed-milestone-only sourcing (in-flight bias guard); 40-plan floor with provisional class-diversity intent,D-A4 (mechanical independence preserved — classify-task.sh STILL absent during T02 labeling); rubric application per-plan with judgment,no automated pre-pass,D-A4-independence-by-absence-during-P00; phase-suite-straight-line-no-loops"
patterns_established:
  - "project-owned verifier path under tools/verify/ (AD-19 install-clobber containment); single-script-file Truth Check shape with awk-based shape walker + grep-based key probe; TBD-tolerant vocabulary check at skeleton phase that T02/T03 tighten,strict closed-enum vocabulary at T02-close (mechanical|standard|novel for character; high|medium|low for confidence); per-class floor 5; rationale field as audit trail capturing the specific signal that drove each call,phase-suite-aggregator-pattern; absence-check-as-load-bearing-D-A4-proxy; SELECTION-NOTES-graduates-into-README-on-phase-close"
drill_down_paths:
  - ".orchestrator/milestones/M030/phases/P00/tasks/T01-SUMMARY.md, .orchestrator/milestones/M030/phases/P00/tasks/T02-SUMMARY.md, .orchestrator/milestones/M030/phases/P00/tasks/T03-SUMMARY.md"
duration: "180m"
verification_result: "pass"
completed_at: "2026-04-30T11:14:39Z"
observability_surfaces:
  - "none"
---

P00 builds the version-controlled classifier ground-truth fixture corpus that anchors SC-10's ≥85% agreement check. Three linear tasks (T01 → T02 → T03) shipped 40 hand-labeled task plans drawn from this repo's milestone history, plus the methodology + compliance documentation, plus five Bash 3.2-compatible verifiers under `tools/verify/` aggregated by `p00-phase-suite.sh`.

## What was built

- `tests/fixtures/m030-classifier-corpus/labels.yml` — 40 entries with `plan_path` + `character` (mechanical|standard|novel) + `confidence` (high|medium|low) + non-empty `rationale`. Final class distribution: 20 mechanical / 15 standard / 5 novel. Confidence distribution: 26 high / 14 medium / 0 low (T02 reports `low` is in-vocabulary but unused — borderline cases honestly resolve to a clear two-class window). All 40 `plan_path` values resolve on disk.
- `tests/fixtures/m030-classifier-corpus/README.md` (190 lines) — Source Pool + Sampling Methodology + Labeling Rubric (FR-1 verbatim) + D-A4 Independence Compliance + Cross-References. Graduates T01's SELECTION-NOTES.md working artifact, including T02's load-bearing observation that the file-count threshold is the mechanical/standard distinguisher.
- `tools/verify/p00-corpus-shape.sh` (197 lines) — frontmatter shape + ≥30 entry floor + four-required-keys-per-entry + strict closed-enum vocabulary check (rejects TBD as of T02-tighten).
- `tools/verify/p00-plans-exist.sh` (49 lines) — every `plan_path` resolves on disk via `[ -f "$p" ]`.
- `tools/verify/p00-class-coverage.sh` (161 lines) — per-class floor of 5 + strict three-class character vocabulary + strict three-value confidence vocabulary + non-empty rationale.
- `tools/verify/p00-readme-shape.sh` (109 lines) — required-section presence (Source Pool, Sampling Methodology, Labeling Rubric, D-A4 Independence Compliance) + character keyword reproduction.
- `tools/verify/p00-d-a4-independence.sh` (56 lines) — absence-check for `scripts/dispatch/classify-task.sh`. Header comments document the post-P01 git-log ordering graduation path.
- `tools/verify/p00-phase-suite.sh` (84 lines) — straight-line aggregator over the five P00 gates; emits final SUMMARY line; no loops or eval per AD-19.

## Key decisions

- **D-A4 independence-by-construction** holds at P00-close. `scripts/dispatch/classify-task.sh` did not exist on disk during T01, T02, or T03. The mechanical proxy passes by absence today; post-P01 it graduates to a git-log ordering check (labels.yml first-commit timestamp precedes classify-task.sh first-commit timestamp).
- **Closed-milestone-only sourcing**. Candidate plans came from `.orchestrator/milestones/M*/{archive,phases}/P*/T*-PLAN.md` filtered to milestones with `M*-SUMMARY.md` at root. M028 (in-flight) and M030 (self) were excluded so the labeler isn't biased by current development context.
- **Project-owned verifier path** under `tools/verify/`. Slug-bearing filenames (`p00-*`) contain install-clobber risk per AD-19's path discipline.
- **Rubric application per-plan with judgment**. No automated keyword-pre-pass produced labels — T02 read each plan and applied the rubric. The `rationale` field captures the specific signal that drove each call (the D-A4 audit trail).

## Verification results

- `bash tools/verify/p00-phase-suite.sh` → `SUMMARY: p00-phase-suite.sh pass=5 fail=0`, exit 0.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P00` → all truths + artifacts + key-links pass, exit 0.

## Patterns established (carry forward)

- **Phase-suite aggregator pattern** — straight-line invocation of N sub-gates, no loops, single SUMMARY line.
- **Skeleton-tighten-graduate task chain** — T01 ships TBD-tolerant skeleton; T02 fills labels and tightens the shape verifier; T03 documents methodology and ships the gate suite.
- **SELECTION-NOTES → README graduation** — T01's working notes file is removed at T03 close after its content is folded into the README's `## Sampling Methodology` section.

## Notes for downstream

- P01 (`scripts/dispatch/classify-task.sh` author) MUST graduate `p00-d-a4-independence.sh` to its post-P01 git-log ordering check. Header comments in the script identify the graduation point.
- The unused `low` confidence bucket (0 entries in this corpus) is in-vocabulary but absent. If the FR-1 classifier emits `low`, vocabulary parity is preserved but no agreement assertion can be made on that bucket from this corpus.
- The shipped check-must-haves.sh `grep -F` paper-cut fix (changed from regex to fixed-string substring match) is a downstream beneficiary — every prior milestone's `contains "..."` artifact spec that included regex meta-characters was a latent failure waiting on input shape.
