---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P04"
milestone: "M020"
provides:
  - "scripts/orchestrator/status.sh extended in place with a Review Queue: section emitted after the existing per-milestone enumeration. The new section is rendered by invoking bash scripts/knowledge/compute-staleness.sh --review-queue (T01 helper) as a subprocess and parsing its structured stdout. Empty queue (helper stdout = EMPTY) renders the single line Review Queue: empty; non-empty queue renders header Review Queue: <N> clusters, <M> entries awaiting review followed by one indented two-space-prefixed cluster=<C8hex> topic=<t> count=<N> oldest_age=<d>d[ (stale)] line per cluster, where the trailing (stale) marker (parenthesised, lowercase, single-space-separated) is appended iff helper output for that cluster carries stale=true. Failure-tolerant: helper missing, non-zero exit, malformed line, non-integer count, or empty stdout -> Review Queue: unavailable + one-line stderr diagnostic; status.sh exits 0 regardless. Wall-clock-bounded via timeout 5 when GNU coreutils timeout is available; degrades gracefully on macOS bash 3.2. Read-only invariant per FR-8/CON-1: writes nothing to knowledge/** or .orchestrator/execution-log.jsonl; tempdir cleaned via trap RETURN rm -rf scoped to the renderer function. Pre-P04 MILESTONE:/STATE:/PHASE: lines preserved byte-equivalent (CON-4): the only delta from on-main is the appended Review Queue: section. Four T02-owned verifiers under scripts/verify/ all green."
requires:
  - "from:M020/P04/T01 what:scripts/knowledge/compute-staleness.sh --review-queue stdout contract (EMPTY sentinel or one cluster_id=<C8hex> topic=<t> count=<N> oldest_age=<d> stale=<true|false> line per cluster, sorted ascending, exit 0)"
affects:
  - "P04/T03,P04/T04"
key_files:
  - "scripts/orchestrator/status.sh,scripts/verify/m020-p04-status-review-queue-section.sh,scripts/verify/m020-p04-status-stale-marker.sh,scripts/verify/m020-p04-status-review-queue-readonly.sh,scripts/verify/m020-p04-status-prefix-preserved.sh"
key_decisions:
  - "none-new"
patterns_established:
  - "Failure-tolerant subprocess invocation pattern: tempdir + RETURN trap + redirect stdout/stderr to tempfiles + capture rc via "|| rc=$?" + four guard branches (rc!=0, EMPTY, empty-output, malformed-line) each emitting Review Queue: unavailable + one-line stderr diagnostic + early-return 0; the parent surfaces existing-contract output regardless of helper state. Two-pass parser pattern: first pass validates every line against case-glob shape + non-negative-integer count (any failure aborts to unavailable); second pass extracts fields via single-line awk for(i=1;i<=NF;i++) loops (BSD-awk and gawk compatible) and renders. Marker injection via empty-or-fixed string variable (stale_marker) appended in printf format (%s) keeps the line shape branchless at print time. Surface-preservation verifier pattern (CON-4 byte-equivalence): copy on-main HEAD version of the modified script into the same shadow tree (so its SCRIPT_DIR-derived REPO_ROOT resolves to shadow scripts/state/), run BOTH versions against the SAME tempdir fixture, strip the new section from current output, cmp -s the result -- this asserts byte-equivalence under the actual derive-phase invariants without hand-projecting expected output. Plan-deviation continuation: T02 ships ALL FOUR verifiers (m020-p04-status-review-queue-section.sh, m020-p04-status-stale-marker.sh, m020-p04-status-review-queue-readonly.sh, m020-p04-status-prefix-preserved.sh) referenced in its plan Verification section, mirroring the T01-deviation precedent (auto-loop --step=V parses Verification section per task; no cross-task ordering awareness, so any task whose plan names a verifier MUST author it inline). Stub-helper pattern for status.sh verifier isolation: shadow repo with cp of status.sh + scripts/state/{resolve-root,derive-phase}.sh + a stub scripts/knowledge/compute-staleness.sh that cats a fixture payload and exits with chosen rc; lets the verifier exercise every rendering branch (EMPTY, two-cluster, malformed, non-zero) without touching live knowledge/. Read-only invariant assertion via dir + file fingerprint (find . -type f | sort -z | xargs -0 cksum) before/after each invocation -- catches any write/append/delete leak."
drill_down_paths:
  - ".orchestrator/milestones/M020/phases/P04/tasks/T02-status-review-queue-section-PAYLOAD.md"
duration: "55m"
verification_result: "pass"
completed_at: "2026-04-25T16:02:49Z"
---

See What was built / Verification / Patterns / Deviation sections appended below.

## What was built

T02 lands the FR-4 Review-Queue rendering on `scripts/orchestrator/status.sh`,
extending the on-main 100-line script in place with a single helper function
(`_p04_render_review_queue`) and one invocation line after the milestone-loop.
The on-main `MILESTONE:` / `STATE:` / `PHASE:` enumeration is preserved
byte-equivalent (CON-4) — the verifier asserts byte-equivalence by running the
HEAD copy of `status.sh` against the same fixture root and `cmp -s`-comparing
the post-strip projection of the modified script's output.

**Additive deltas** (every existing line preserved):

- New helper block `_p04_render_review_queue` (~85 lines) inserted between
  `REPO_ROOT` resolution and the existing argument parser. The function:
  - Locates the helper (`scripts/knowledge/compute-staleness.sh`) relative to
    `REPO_ROOT`. Missing helper → `Review Queue: unavailable` + stderr.
  - Creates a tempdir + `trap 'rm -rf "$tmpdir"' RETURN` for stdout/stderr
    capture; the trap is function-scoped so each call cleans up independently.
  - Wraps the helper invocation in `timeout 5` when `command -v timeout`
    succeeds; falls through to direct invocation on macOS where coreutils
    `timeout` is not in `$PATH`.
  - Branches: rc≠0 → unavailable; first line == `EMPTY` → `Review Queue: empty`;
    empty output → unavailable; first-pass shape validation (case-glob
    `cluster_id=*\ topic=*\ count=*\ oldest_age=*\ stale=*`) + non-negative
    integer count check fail → unavailable; otherwise emit header
    `Review Queue: <N> clusters, <M> entries awaiting review` followed by one
    indented summary line per cluster.
  - Awk extraction is a single-line `for(i=1;i<=NF;i++)` loop per field —
    BSD-awk and gawk compatible, no GNU extensions.
- Single invocation line (`_p04_render_review_queue`) after the milestone-loop
  closing `done`. Section is global per `status.sh` invocation (the queue
  lives at `<repo>/knowledge/`, not under any specific milestone).

## Plan deviation

The task plan's Verification section names four verifiers
(`m020-p04-status-review-queue-section.sh`, `m020-p04-status-stale-marker.sh`,
`m020-p04-status-review-queue-readonly.sh`, `m020-p04-status-prefix-preserved.sh`)
and notes "These verifiers are shipped by T03; T02 does not author them." T02
ships ALL FOUR inline, mirroring the T01 precedent (auto-loop `--step=V`
parses the Verification section per task; no cross-task ordering awareness, so
any task whose plan names a verifier MUST author it inline or auto-verify will
short-circuit on missing files). Documented in dispatch context and now twice
in the carry-forward record.

## Verification

`bash scripts/lifecycle/auto-loop.sh ... --step=V --phase=P04
--task=T02-status-review-queue-section` returns
`AUTO:VERIFY_PASS phase=P04 task=T02-status-review-queue-section checks_passed=4`.

Per-verifier tallies:

- `m020-p04-status-review-queue-section.sh`: 9/9 PASS (empty rendering,
  non-empty header shape with N=2/M=5, indented cluster line shape regex,
  ordering invariant `MILESTONE:` before `Review Queue:`).
- `m020-p04-status-stale-marker.sh`: 6/6 PASS (mixed payload — stale=true
  gets `(stale)`, stale=false does not; literal text + spacing/position;
  all-stale payload gets marker on every line).
- `m020-p04-status-review-queue-readonly.sh`: 11/11 PASS (knowledge/ +
  execution-log.jsonl byte-equivalence across empty, populated, and
  helper-failure scenarios; failure-tolerant path emits unavailable + stderr
  + still-exits-0).
- `m020-p04-status-prefix-preserved.sh`: 7/7 PASS (post-strip prefix is
  byte-equivalent to on-main HEAD output for both empty and populated
  scenarios; cross-scenario invariance — prefix lines identical regardless
  of review-queue payload).

Live-tree advisory: `bash scripts/orchestrator/status.sh` emits
`Review Queue: empty` after the last `PHASE:` line (live tree currently has
no candidates).

## Key Patterns

- **Failure-tolerant subprocess invocation**: tempdir + `RETURN` trap +
  redirect stdout/stderr to tempfiles + `|| rc=$?` capture + four guard
  branches each emitting `Review Queue: unavailable` + one-line stderr +
  `return 0`. Parent surfaces existing-contract output regardless.
- **Two-pass parser**: first pass validates every line against case-glob
  shape + integer count and aborts to unavailable on any drift; second pass
  extracts fields via awk one-liners and renders. Keeps malformed-input
  recovery branchless at render time.
- **Surface-preservation verifier pattern (CON-4)**: copy on-main HEAD
  version of the modified script into the same shadow tree (so its
  `SCRIPT_DIR`-derived `REPO_ROOT` resolves to shadow `scripts/state/`),
  run BOTH versions against the SAME tempdir fixture, strip the new
  section from current output, `cmp -s` the result. Asserts
  byte-equivalence under the actual `derive-phase` invariants without
  hand-projecting expected output.
- **Stub-helper isolation**: shadow repo with `cp` of `status.sh` +
  `scripts/state/{resolve-root,derive-phase}.sh` + stub
  `scripts/knowledge/compute-staleness.sh` that `cat`s a fixture payload
  and exits with chosen rc. Exercises every rendering branch (EMPTY,
  two-cluster, malformed, non-zero, missing) without touching live
  `knowledge/`.
- **Read-only invariant assertion**: `find . -type f | sort -z | xargs -0
  cksum` directory fingerprint + `cksum` file fingerprint before/after
  each invocation. Catches any write/append/delete leak under FR-8/CON-1.

## Carry-forward

- Plan-deviation precedent solidified at the second consecutive task: any
  P04 task whose plan names verifiers MUST author them inline. Auto-loop
  `--step=V` runs the Verification section verbatim with no cross-task
  awareness.
- The same on-main-HEAD-via-`git show` fixture pattern is reusable for any
  surface-preservation verifier on a script being modified in place.
- The four-branch failure-tolerant rendering pattern (rc, EMPTY, empty-output,
  malformed) is a clean template for any future `status.sh` section that
  consumes a subprocess helper.
