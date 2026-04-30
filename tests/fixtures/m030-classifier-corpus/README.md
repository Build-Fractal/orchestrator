# M030 Classifier Ground-Truth Corpus

This directory holds the version-controlled fixture corpus that gates
`scripts/dispatch/classify-task.sh` against ground truth (SC-10:
>=85% agreement on >=30 hand-labeled task plans).

The corpus's value depends on a single load-bearing property:
**the labels were applied before the classifier was authored**.
See `## D-A4 Independence Compliance` below.

## Source Pool

The candidate pool was assembled by a milestone-history sweep:

```
find .orchestrator/milestones -name "T*-PLAN.md" -type f
```

filtered to **closed milestones** — directories carrying an
`M*-SUMMARY.md` at the milestone root, where the milestone is not
in-flight per `CLAUDE.md` and not the milestone-under-development
itself.

- Snapshot at T01 author time (2026-04-30): **458** total
  candidates returned by the unfiltered `find`.
- After the closed-milestone filter and the in-flight exclusions
  (M028 next-up, M030 self), the closed-milestone candidate pool is
  **433** task plans across the milestones M002, M003, M004, M005,
  M006, M007, M008, M011, M012, M013, M014, M015, M016, M018, M019,
  M020, M021, M024, M026, M027.
- Single-phase milestones whose state directory contains
  `P*-PLAN.md` only (no `T*-PLAN.md` files) — M001, M025, M999 — were
  skipped; nothing to sample from them.
- M028 (in-flight, next-up per the forward roadmap) and M030 (self,
  the milestone whose classifier this corpus tests) are excluded so
  the labeler is not biased by current development context.

## Sampling Methodology

40 plans were drawn from the 433-plan candidate pool. The phase plan
floor is 30 entries; T01 selected 40 to leave slack against T02
label-revision and against the `p00-class-coverage.sh` per-class
floor of 5.

Selection strategy (per T01 working notes, now graduated into this
section):

1. **Milestone-spread** — at least one plan from every closed
   milestone in the pool (20 milestones * >=1 plan = 20 floor).
2. **Phase-spread within milestones** — where a milestone has
   multiple phases, pick from at least two so the corpus samples
   setup/scaffold tasks alongside extension/integration tasks.
3. **Task-position spread** — mix T01 (often fresh-author / setup),
   mid-T (extension / integration), and final-T-in-phase
   (verification / E2E) so the corpus has shape diversity.
4. **Slug visibility** — prefer plans with descriptive filename slugs
   (`T01-grammar-contract-PLAN.md`, `T02-cache-prune-PLAN.md`,
   `T03-predictive-surface-PLAN.md`) when available; slugs hint at
   class signal without being load-bearing for the rubric.

T02 hand-labeled all 40 entries against the rubric below. Final
distribution: **20 mechanical / 15 standard / 5 novel**, with
**26 high / 14 medium / 0 low** confidence.

T02's labeling pass surfaced one load-bearing distinguisher between
mechanical and standard that was not part of the prior rubric prose:
**file-count threshold**. A plan whose `## Steps` block touches
<=3 files reads as mechanical; the same shape spanning 4+ files
reads as standard even when each individual edit is concrete. This
threshold matches FR-1's wording ("across <=3 files") but is
recorded here explicitly because it is the most common single call
the labeler made.

The `low` confidence bucket is **unused** in the final corpus — every
T02 call was either `high` or `medium`. The bucket remains valid in
the FR-1 vocabulary (`high|medium|low`); future corpus extensions or
SC-10 retests may introduce `low`-confidence entries when the rubric
genuinely fits two classes. The current 0/14/26 distribution is a
property of this particular 40-plan sample, not a constraint on
future labels.

## Labeling Rubric

Reproduced verbatim from `specs/032-adaptive-model-selection/spec.md`
US-1 acceptance scenarios (FR-1 character definitions, lines 36-47):

> As an orchestrator operator running a dispatch, I want each task
> classified into one of three character classes (mechanical /
> standard / novel) before the model is selected, so the routing
> table has a deterministic input and the classification is
> reproducible across runs without an LLM call.

Acceptance Scenarios:

1. **Given** a PLAN.md with explicit `## Steps` listing file paths
   and exact edits across <=3 files plus unambiguous bash verifiers,
   **When** the classifier runs, **Then** stdout contains
   `character=mechanical` and `confidence=high`.
2. **Given** a PLAN.md whose Goal section uses words like "explore",
   "design", or "evaluate alternatives" with no concrete file
   targets, **When** the classifier runs, **Then** stdout contains
   `character=novel` and `confidence=high`.
3. **Given** a PLAN.md that is partially specified (file paths
   declared but verifiers ambiguous), **When** the classifier runs,
   **Then** stdout contains `character=standard` and
   `confidence=medium`.
4. **Given** the same PLAN.md run through the classifier twice,
   **When** both runs complete, **Then** both runs emit
   byte-identical stdout (deterministic).

Distilled labeling shorthand applied during T02:

- **mechanical** — explicit `## Steps` block listing file paths and
  exact edits across <=3 files; bash verifiers named explicitly. Plan
  reads as "do these N things in this order" with no judgment calls.
- **standard** — partially specified: file paths declared but
  verifier shape ambiguous, OR step list present but spans 4+ files /
  multiple subsystems. Some judgment required by the executor.
- **novel** — Goal/Description uses words like "explore", "design",
  "evaluate alternatives", "spike", "research"; no concrete file
  targets; reads as open-ended.

Confidence levels:

- **high** — the rubric matches the plan unambiguously.
- **medium** — the rubric matches with one or two minor caveats.
- **low** — the plan plausibly fits two of the three classes; the
  label captures the closest fit but the call is not robust.

The labeler captured each call's reasoning in the `rationale` field
of `labels.yml`. This is the audit trail for D-A4: future readers
(including SC-10's >=85% agreement check post-P01) can replay the
labeling reasoning without access to the (now-shipped) classifier.

## D-A4 Independence Compliance

Per `.orchestrator/milestones/M030/M030-CONTEXT.md` D-A4 (and per the
SC-10 amendment promoting Q-1 to spec constraint), the ground-truth
corpus has three load-bearing properties:

1. **Drawn from pre-M030 milestone history.** Every `plan_path` in
   `labels.yml` resolves to a `T*-PLAN.md` file authored before M030
   began. The closed-milestone filter on the source pool guarantees
   this by construction; `tools/verify/p00-plans-exist.sh` is the
   mechanical proxy that asserts each path resolves on disk.

2. **Labeled before the classifier was authored.** At the moment
   this README and `labels.yml` were committed, the file
   `scripts/dispatch/classify-task.sh` did not exist anywhere in the
   working tree. The mechanical proxy is
   `bash tools/verify/p00-d-a4-independence.sh` which during P00
   asserts the absence of `classify-task.sh` on disk. Post-P01 (when
   the classifier ships) the same verifier graduates to a `git log`
   ordering check: `labels.yml`'s first-commit timestamp must precede
   `classify-task.sh`'s first-commit timestamp.

3. **No labeler had access to a draft classifier.** The labeling was
   a manual rubric application, not an automated classifier-assist
   task. No LLM was invoked with a "classify these for me" prompt; no
   draft of `classify-task.sh` existed to consult; the rubric was
   read from `spec.md` and applied entry-by-entry by a human labeler.

These three properties together satisfy D-A4 / SC-10's
independence-by-construction requirement. P01's `classify-task.sh`
plan-phase verifier MUST confirm property (2) via `git log` ordering
before ratifying SC-10. The full P00 gate suite is invoked via
`bash tools/verify/p00-phase-suite.sh`.

## Cross-References

- `specs/032-adaptive-model-selection/spec.md` — FR-1 (classifier
  character definitions, lines 36-47), FR-2 (deterministic output
  contract), SC-10 (>=85% agreement constraint with the
  independence-by-construction amendment).
- `.orchestrator/milestones/M030/M030-CONTEXT.md` — D-A4 (arbiter
  ruling promoting Q-1 to spec constraint).
- `tools/verify/p00-corpus-shape.sh` — fixture file shape gate
  (frontmatter, key set, count floor).
- `tools/verify/p00-plans-exist.sh` — `plan_path` on-disk resolution
  gate.
- `tools/verify/p00-class-coverage.sh` — vocabulary + per-class
  floor + total-count gate.
- `tools/verify/p00-readme-shape.sh` — this README's structural
  gate (verifies the four required `## ` sections + rubric
  vocabulary + classifier-name reference).
- `tools/verify/p00-d-a4-independence.sh` — independence-by-
  construction verifier (absence-check during P00; graduates to
  `git log` ordering check post-P01).
- `tools/verify/p00-phase-suite.sh` — full P00 gate suite, invokes
  all five verifiers in dependency order and aggregates pass/fail.
