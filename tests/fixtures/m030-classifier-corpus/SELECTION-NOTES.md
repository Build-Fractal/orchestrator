# M030 Classifier Corpus — T01 Selection Notes

Working notes for the T01 source-pool sweep + skeleton authorship.
T03 graduates the methodology summary into `README.md` (`## Sampling
Methodology`); this file is the working artifact behind that section.

## Source pool

- Probe: `find .orchestrator/milestones -name "T*-PLAN.md" -type f`
- Total candidates: **458** (snapshot at T01 author time, 2026-04-30).
- Filter applied — closed milestones only: every milestone whose
  directory carries an `M*-SUMMARY.md` at the milestone root, AND that
  is not in-flight per CLAUDE.md / D-A4.
  - **Excluded**: M028 (in-flight; next-up per roadmap) and M030
    (self — labeling our own plans would bias the labeler with current
    development context).
  - **Included** closed milestones with task plans: M002, M003, M004,
    M005, M006, M007, M008, M011, M012, M013, M014, M015, M016, M018,
    M019, M020, M021, M024, M026, M027.
  - **No task plans on disk** (single-phase milestones with `P*-PLAN.md`
    only): M001, M025, M999. Skipped — nothing to sample.
- Closed-milestone candidate pool: **433** plans
  (`.orchestrator/milestones/M*/{archive,phases}/...T*-PLAN.md`).

## Selection — 40 plans

Floor is 30 per phase plan; we selected 40 to leave slack against
T02 label-revision and against the per-class ≥5 floor that
`p00-class-coverage.sh` will gate (T03).

Strategy:

1. **Milestone-spread**: include at least one plan from every closed
   milestone listed above (20 milestones × ≥1 plan = 20 floor).
2. **Phase-spread within milestones**: where a milestone has multiple
   phases, pick from at least two phases so we sample setup/scaffold
   tasks alongside extension/integration tasks.
3. **Task-position spread**: mix T01s (often fresh-author / setup),
   mid-Ts (extension / integration), and the final-T-in-phase
   (verification / E2E) so the corpus has shape diversity.
4. **Slug visibility**: prefer plans with descriptive filename slugs
   (`T01-grammar-contract-PLAN.md`, `T02-cache-prune-PLAN.md`,
   `T03-predictive-surface-PLAN.md`) when available — slugs hint at
   class signal (`-fixture-`, `-classifier-`, `-helper-` are all
   useful priors for T02's labeling pass without being load-bearing).

## Provisional class targets

Floor per class is 5 entries. Provisional eyeball reads (from
reading first ~40-60 lines of each plan; T01 does NOT label, T02
does — these are pre-labels for T01 working notes only):

- **mechanical** (~13 candidate plans): explicit step-by-step file
  edits; bounded scope (≤3 files); concrete diffs / literals; reads
  as "do these N things in this order." Examples: `M002/P01/T01`
  (mkdir + .gitkeep), `M015/P01/T01` (delete-list of named files),
  `M016/P01/T02` (single-line edit), `M021/P01/T01` (single util
  script with verbatim body), `M026/P03/T02` (six in-place rewrites
  with line-numbered insertion targets).
- **standard** (~16 candidate plans): well-specified but spans
  multiple files / subsystems; verifier shape declared; some
  judgment required on integration seams. Examples: `M003/P01/T02`
  (sqlite reader lib + multiple table queries), `M004/P02/T05`
  (hooks lifecycle dispatch — multi-step library implementation),
  `M013/P02/T01` (shared helpers + fixture scaffolding), `M018/P03/T02`
  (cache-prune utility), `M019/P01/T01` (pricing.sh + schema validator),
  `M020/P01/T01` (D-row + MEM031 + index registration),
  `M026/P01/T01` (parity-matrix authoring with fs-inspection rows).
- **novel** (~11 candidate plans): exploratory / open-ended /
  contract authoring / corpus design; no concrete file targets OR
  Goal/Description uses words like "design", "evaluate", "research",
  "spike". Examples: `M002/P07/T04` (E2E pipeline test design +
  anomaly fixture authorship), `M003/P08/T03` (E2E integration test
  with two-pass discipline), `M006/P01/T01` (architecture doc —
  contributor-oriented design), `M011/P05/T01` (chunks-first metric
  path design with fallback wiring), `M018/P01/T01` (compression
  grammar contract — designs the artifact reviewers dispute on
  paper), `M018/P07/T01` (parity-runner corpus design),
  `M024/P01/T01` (template authorship — schema-binding design).

Ratio (~33% / 40% / 27%) is in line with M030 spec FR-1 expectations
that mechanical/standard span the bulk of dispatched work and novel
is a meaningful but smaller minority. T02 may revise these.

## Plans considered and rejected

None at T01 time. The 40 selected plans came from a single targeted
sweep across milestones; T01 did not encounter ambiguity-too-high
candidates that warranted exclusion. If T02's reading pass surfaces
a plan that resists single-class assignment with `confidence: low`
even after rationale, T02 may flag it for SELECTION-NOTES augment +
SC-10 retest with the per-class floor (5) preserved.

## Independence trace (D-A4)

Verified at T01 start: `ls scripts/dispatch/classify-task.sh` returns
exit 1 (file does not exist on disk). Labels in this corpus will be
applied by T02 BEFORE any line of `classify-task.sh` is authored.
The first commit of `labels.yml` (T01 commit) MUST predate the first
commit of `scripts/dispatch/classify-task.sh` (P01) per the SC-10
audit trail.

## Verifier shape contract (anchors T02/T03 expectations)

T01 ships two verifiers:

- `tools/verify/p00-corpus-shape.sh` — file/frontmatter/keys/count
  shape. Accepts `TBD` placeholders at T01-close.
- `tools/verify/p00-plans-exist.sh` — every `plan_path` resolves on
  disk via `[ -f "$path" ]`.

T02 will tighten the vocabulary check (no more `TBD`) via a separate
`p00-class-coverage.sh` (per phase truths). T03 graduates this notes
file's methodology summary into `README.md ## Sampling Methodology`.
