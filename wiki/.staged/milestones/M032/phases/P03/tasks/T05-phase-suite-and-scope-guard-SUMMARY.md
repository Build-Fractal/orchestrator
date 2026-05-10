---
schema_version: "1.0"
type: task-summary
id: "T05"
parent: "P03"
milestone: "M032"
provides:
  - "tools/verify/m032-p03-phase-suite.sh straight-line aggregator chaining all ten P03 sub-gates (FR-7 giscus-templating; FR-8 with-giscus-scope; FR-9 deploy-scope; FR-10 wiki-deploy-cwd-gate; FR-14 custom-nav-region; FR-13 with-feature-pattern-doc; AD-7 throwaway-protocol-shape; SC-4/SC-5/SC-6 acceptance-shape) per AD-19 single-script-file shape exits 0 iff every gate passes emits SUMMARY pass=N fail=M; tools/verify/m032-p03-scope-guard.sh SC-13 scope-guard with allowlist regex (P03-owned paths) plus denylist regex (P00/P01/P02-owned paths) plus first-run baseline-ref capture mirroring P01/P02 m032-p0?-baseline-ref.txt convention; tools/verify/fixtures/m032-p03-baseline-ref.txt baseline captured at HEAD a5f90e64 (T04 close commit) per the committed-history-only diff lesson from P01 patterns-established (verifier-contract-over-verifier-skeleton course-correction from payload-skeleton's git-status-porcelain working-tree approach which fails-noisy in dogfood loops with parallel M033 development)"
requires:
  - "from:T01,T02,T03,T04 what:ten P03 sub-gate verifiers all green; from:P02/T05 what:scope-guard-baseline-ref-and-phase-suite pattern reference plus tools/verify/fixtures/ directory"
affects:
  - "P04"
key_files:
  - "tools/verify/m032-p03-phase-suite.sh,tools/verify/m032-p03-scope-guard.sh,tools/verify/fixtures/m032-p03-baseline-ref.txt"
key_decisions:
  - "AD-19,SC-13,MEM001,MEM013,FR-7,FR-8,FR-9,FR-10,FR-13,FR-14,SC-4,SC-5,SC-6,AD-7"
patterns_established:
  - "verifier-contract-over-verifier-skeleton applied to scope-guard diff source -- payload-skeleton specified git-status-porcelain (working-tree state) which produces 146-out-of-scope FAIL noise in the dogfood orchestrator repo where parallel M033 development modifies many unrelated paths in the working tree -- repaired in-flight to committed-history-only diff (git diff --name-only baseline_ref HEAD) per the P01 patterns-established lesson and the P02 m032-p02-scope-guard.sh precedent; first-run-captures-HEAD-as-baseline pattern with SHA-comment-format baseline-ref file (mirrors P02 m032-p02-baseline-ref.txt one-SHA-line-with-leading-comment-headers shape); regex-allowlist plus regex-denylist twin-check pattern (single-pass git diff iteration; each diff path checked against ALLOWED_RE for in-scope-membership and against DENIED_RE for SC-13 violation surface); thin-aggregator phase-suite chains existing verifiers without adding new logic (matches M030/M031/M032 P00-P02 phase-suite-aggregator pattern); FR/SC/AD tag-prefix in gate names preserved for grep-able diagnostics in failure cases; bash 3.2 compatibility maintained throughout (no declare -A no process substitution no compound chains)"
drill_down_paths:
  - ".orchestrator/milestones/M032/phases/P03/tasks/T05-phase-suite-and-scope-guard-PAYLOAD.md,.orchestrator/milestones/M032/phases/P03/tasks/T05-phase-suite-and-scope-guard-PLAN.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-05-05T03:15:01Z"
---

## What Shipped

T05 closes M032/P03 with the verification-aggregation surface promised
by the P03 plan: a thin straight-line phase-suite aggregator chaining
all ten P03 sub-gates (FR-7 / FR-8 / FR-9 / FR-10 / FR-14 / FR-13 /
AD-7 / SC-4 / SC-5 / SC-6) and an SC-13 scope-guard pinning P03's
diff to the declared "Files Likely Touched" allowlist plus the
P00/P01/P02 denylist. Three artifacts ship together as a single
atomic unit:

1. **`tools/verify/m032-p03-phase-suite.sh`** -- straight-line
   aggregator invoking each P03 sub-gate in dependency order, exits
   0 iff every gate passes, emits
   `SUMMARY: m032-p03-phase-suite.sh pass=N fail=M`. Single-script-file
   shape per AD-19. The aggregator is intentionally thin: it captures
   each gate's stdout/stderr to a temp file, parses only the exit
   code, and surfaces the last three lines of output on failure for
   diagnostic context. FR-/SC-/AD- tag prefixes preserved in
   gate-name strings so failure diagnostics are grep-able.

2. **`tools/verify/m032-p03-scope-guard.sh`** -- SC-13 scope-guard
   with regex-allowlist (P03-owned paths) + regex-denylist
   (P00/P01/P02-owned paths) + first-run baseline-ref capture
   mirroring the P01/P02 `m032-p0?-baseline-ref.txt` convention.
   Single-script-file shape. Walks `git diff --name-only
   <baseline_ref> HEAD` and checks each diff path against both
   regexes; reports in-scope count and denylist hit count. First run
   captures HEAD SHA into the fixture file and PASSes
   unconditionally; subsequent runs compute the committed-history
   diff and verify scope discipline.

3. **`tools/verify/fixtures/m032-p03-baseline-ref.txt`** -- baseline
   captured at HEAD `a5f90e64` (T04 close commit). One-SHA-per-line
   with leading-comment headers (matches P02 baseline-ref shape).
   Subsequent re-baseline is an explicit operator act (delete the
   file and re-run).

## Verification Results

`bash tools/verify/m032-p03-phase-suite.sh` -> exit 0,
`SUMMARY: m032-p03-phase-suite.sh pass=10 fail=0`. All ten P03
sub-gates green. `bash tools/verify/m032-p03-scope-guard.sh` ->
exit 0, baseline captured at first run; second run reports
`SUMMARY: m032-p03-scope-guard.sh pass=4 fail=0` (4 = baseline-file
exists + baseline-ref resolves + allowlist-clean + denylist-clean).
T05 modified zero T01-T04 deliverables.

## Key Decisions / Course-Corrections

- **Verifier-contract-over-verifier-skeleton** (in-flight repair):
  the payload's required-content for the scope-guard specified
  `git status --porcelain | awk '{print $2}'` as the diff source --
  i.e. working-tree state, not committed history. Running the
  payload-shape verifier in the dogfood orchestrator repo produced
  146 out-of-scope FAIL paths because parallel [M033](../../../../../milestones/M033/index.md) development +
  knowledge-graph rebuilds + roadmap edits had modified many
  unrelated working-tree paths at scope-guard invocation time. The
  payload's stated expected output is `pass=N fail=0`. The two
  cannot reconcile under the working-tree-status approach.

  The P01 patterns-established lesson (referenced in P02's T05
  summary verbatim: "using committed-history-only diff per the P01
  patterns-established lesson") prescribes
  `git diff --name-only <baseline_ref> HEAD` -- committed deltas
  only -- precisely so parallel-development noise in the working
  tree never trips the scope-guard. P02's
  `m032-p02-scope-guard.sh` already implements this shape with a
  one-SHA-per-line baseline-ref fixture file.

  T05 follows the verifier-contract-over-verifier-skeleton pattern
  (established P02/T05): when a plan-time-sketched verifier line
  conflicts semantically with the reified contract, the ship shape
  implements the contract wording. The payload's allowlist + denylist
  are the load-bearing contract; the diff-source is implementation
  detail; and the P02 precedent is the canonical implementation.
  Adopted P02's structure verbatim (regex-based allowlist/denylist,
  HEAD-SHA capture at first-run, committed-history diff at
  subsequent runs) while preserving the payload's exact
  allowlist/denylist path set.

- **First-run baseline at T04 close commit** (`a5f90e64`):
  capturing HEAD at scope-guard first invocation means subsequent
  runs after T05 commits will diff `a5f90e64..HEAD` and surface
  exactly T05's own diff -- the in-scope set. This mirrors P02's
  pattern where the baseline was captured at T04's commit
  (`cf761131`) and the post-T05 verifier diffed only T05's work.

## Patterns Established

- **Verifier-contract-over-verifier-skeleton extension to scope-guards**:
  when a plan-time-sketched scope-guard specifies a working-tree-status
  diff source, override to committed-history diff per the P01/P02
  precedent. Working-tree state is too noisy in the dogfood loop
  where parallel milestones modify shared paths.
- **Twin-regex single-pass scope-guard**: walk the diff path list
  once; check each path against `ALLOWED_RE` for in-scope membership
  and against `DENIED_RE` for SC-13 violation. Report two counters
  (in_scope_count + deny_count) in the final summary line for
  operator visibility.
- **Thin-aggregator phase-suite**: chain existing verifiers via a
  `run_gate <name> <path>` helper that captures output to a temp
  file, parses only exit code, and surfaces last-three-lines of
  output on failure. Adds zero new verification logic; preserves
  FR-/SC-/AD- tag prefixes in gate names for grep-able diagnostics.
- **Sequential P0?-baseline-ref convention**: each phase's
  scope-guard captures HEAD at first run into
  `tools/verify/fixtures/m032-p0?-baseline-ref.txt` with leading
  comment headers (`# M032/P0? scope-guard baseline ref ...`)
  followed by the SHA on one line. Re-baselining is explicit
  operator act (delete + re-run).

## Affects Downstream

- **P04 (acceptance + closure)** -- inherits the
  m032-p03-phase-suite.sh + m032-p03-scope-guard.sh pattern; P04's
  T05 (or equivalent) will produce m032-p04-phase-suite.sh +
  m032-p04-scope-guard.sh + m032-p04-baseline-ref.txt with the same
  shape, captured at the P03-close commit.
- **M032 milestone-close** -- the P03 phase-suite aggregator feeds
  into the milestone-grain `validate-milestone.sh` battery; SC-13
  scope-guard runs as part of the post-close validation chain.
