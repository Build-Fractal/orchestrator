---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P04"
milestone: "M020"
provides:
  - "scripts/knowledge/compute-staleness.sh extended in place with --review-queue + --knowledge-root <path> flags. New mode short-circuits at the top of the argument parser; legacy --archive-below / --min-hits / --dry-run / no-flag invocations preserved byte-equivalent per CON-4. Walks <knowledge-root>/**/MEM*.md, filters via fm_read_status to status: candidate, groups via P05 lib/cluster.sh::cluster_compute, and emits one structured cluster_id=<C8hex> topic=<topic-or-empty> count=<N> oldest_age=<days> stale=<true|false> line per cluster on stdout sorted by cluster-id ascending. Empty candidate set emits exactly the literal EMPTY on stdout. Staleness threshold resolves: default 14 (per OQ-1) -> .orchestrator/preferences.yml::staleness_threshold integer-positive override -> malformed warns WARN: malformed staleness_threshold=<raw> -- using default=14 to stderr and falls back to 14. Similarity threshold resolves: default 0.7 (AD-5) -> preferences::similarity_threshold N.N override -> malformed silent fallback to 0.7. Topic field whitespace-collapsed via tr -s [:space:] _ so output line is awk-on-whitespace parseable. Age computation uses fm_field created_at then last_verified fallback; default 0 if neither field present."
requires:
  - "from:M020/P01 what:scripts/knowledge/lib/frontmatter.sh::fm_read_status (candidate filter); from:M020/P05 what:scripts/knowledge/lib/cluster.sh::cluster_compute (cluster grouping); from:M001 what:scripts/knowledge/lib/staleness.sh::days_since (age primitive); from:M001 what:scripts/knowledge/lib/detail-utils.sh::fm_field (frontmatter scalar reader)"
affects:
  - "P04/T02,P04/T03,P04/T04,P06"
key_files:
  - "scripts/knowledge/compute-staleness.sh"
key_decisions:
  - "none-new"
patterns_established:
  - "Additive flag-gated extension preserves CON-4 byte-equivalence: gating new mode on a new flag (--review-queue) means legacy invocations pay zero cost and exhibit no behavior delta -- the only adds are two variable defaults, two case branches, one short-circuit if, and one helper block. Process-substitution-inside-script-body is AD-19 safe (P03/T04 carry-forward): the harness shape-guard inspects directly-invoked Bash tool-call shapes, not script internals -- the inner find-pipe-while-read pattern is permitted. Pure-helper composition: _p04_review_queue_emit consumes cluster_compute (subprocess via the source-then-call shape; cluster.sh execs jaccard.sh as subprocess so jaccard helpers do not pollute caller scope), reads frontmatter via fm_field/fm_read_status, computes age via days_since -- zero copy-paste of clustering, frontmatter, or date logic. Tempfile + RETURN-trap rm -rf for transient cluster-line + id-path-map storage scoped to function via mktemp -d. Bash 3.2 conventions throughout: no associative arrays, no mapfile, no <<<-into-command-substitution; awk handles all multi-key extraction. Stream-iterate pre-sorted cluster_compute output and flush on cluster-id transition (not per-line buffering of the entire group) -- cluster_compute output is already sorted by cluster-id asc then member-id asc per its contract. Plan deviation -- verifier shipped under T01 instead of T03 because auto-loop --step=V parses the plan's Verification section and runs whatever it finds at task close, with no awareness of cross-task ordering: any task whose plan names a verifier MUST ship that verifier alongside the implementation regardless of which downstream task originally owned it. Reusable invariant for all auto-loop-driven phase plans."
drill_down_paths:
  - ".orchestrator/milestones/M020/phases/P04/tasks/T01-compute-staleness-review-queue-PAYLOAD.md"
duration: "40m"
verification_result: "pass"
completed_at: "2026-04-25T15:48:54Z"
---

## What was built

T01 lands the FR-4 review-queue mode on `scripts/knowledge/compute-staleness.sh`, extending the existing 143-line script in place with a new `--review-queue` mode that emits one structured line per candidate cluster on stdout. The legacy invocation surface (no flag, `--archive-below`, `--min-hits`, `--dry-run`) is preserved byte-equivalent per CON-4.

**Additive deltas** (every existing line preserved):

- Sources three new helpers above the argument loop: `lib/detail-utils.sh` (for `fm_field`), `lib/frontmatter.sh` (for `fm_read_status`), `lib/cluster.sh` (for `cluster_compute`). All three carry double-source guards so re-sourcing is a no-op.
- New helper block `_p04_review_queue_emit` plus four pure helpers: `_p04_default_knowledge_root`, `_p04_read_pref_scalar`, `_p04_resolve_staleness_threshold`, `_p04_resolve_similarity_threshold`, `_p04_first_field`, `_p04_flush_one`.
- Two new variable defaults alongside existing ones: `review_queue_mode=false`, `knowledge_root=""`.
- Two new `case` branches in the existing argument-parser before the `*)` catch-all: `--review-queue` and `--knowledge-root <path>`.
- One short-circuit `if` after the argument loop and before the legacy `index_path="$(get_index_path)"` block: when `review_queue_mode=true`, call `_p04_review_queue_emit` and `exit 0`.

New mode contract (verified via three smoke fixtures):

```
cluster_id=<C8hex> topic=<topic-or-empty> count=<N> oldest_age=<days> stale=<true|false>
```

EMPTY-queue contract: when `cluster_compute` emits zero lines (live tree as of P03 close), emit exactly the literal `EMPTY` and exit 0.

## Key decisions

- **Source `detail-utils.sh` directly for `fm_field`** rather than waiting for a future `lib/frontmatter.sh::fm_field` helper. The payload referenced `fm_field` but `frontmatter.sh` does not currently expose it -- `detail-utils.sh::fm_field` is the canonical reader (reused by `rebuild-index.sh`, `promote-entry.sh`, `supersede-entry.sh`, `lib/jaccard.sh`). Sourcing both `frontmatter.sh` (for `fm_read_status`) and `detail-utils.sh` (for `fm_field`) is the minimal-deviation path.
- **`_p04_flush_one` takes positional args, not closure-captured locals.** Hoisting the flush helper to script scope and passing the loop-variant scalars (`cid`, `can_file`, `cnt`, `stale_threshold`, `today`) keeps the helper testable in isolation and avoids bash 3.2 nested-function scoping fragility.
- **`mktemp -d` + `trap RETURN rm -rf "$tmpdir"`** for transient cluster-line + id-path-map storage. CON-1 read-only-during-dispatch invariant preserved at the helper boundary; the trap fires on function return so successive `--review-queue` invocations do not leak temp dirs.
- **Stream-iterate cluster_compute output**, flush on cluster-id transition. cluster_compute already emits its output sorted by cluster-id ascending then member-id ascending, so the canonical (lexicographically-first) member is the first row encountered for each cluster.
- **Topic whitespace-collapse via `tr -s [:space:] _`** rather than awk. Single short pipe, no awk dependency for the trivial substitution.

## Patterns established

- **Additive-flag-gated extension preserves CON-4 byte-equivalence** -- gating new behavior on a new flag means legacy invocations pay zero cost and exhibit no behavior delta. Reusable for any in-place script extension under M020 dispatch-isolation invariants.
- **Process-substitution-inside-script-body is AD-19 safe** (P03/T04 carry-forward) -- the inner `done < <(find ... | sort)` is permitted because the harness shape-guard inspects directly-invoked Bash tool-call shapes, not script internals.
- **Pure-helper composition without copy-paste of clustering/frontmatter/date logic** -- T01 reads the P05 + P01 + M001 helpers verbatim per Principle VII (Knowledge Compounds).
- **Bash 3.2 stream-and-flush over buffer-and-iterate** -- cluster_compute output is pre-sorted by cluster-id; track `current_cid` + `canonical_file` + `count` and flush on transition.
- **`mktemp -d` + `trap RETURN rm -rf`** for function-scoped tempdirs (vs `trap EXIT` which would leak across function boundaries when the script continues after the helper returns).

## Verification results

T01 truth verifier `scripts/verify/m020-p04-compute-staleness-review-queue.sh` (shipped under T01 per the deviation noted below) -> 9/9 PASS lines, exit 0. Auto-loop `--step=V` returned `AUTO:VERIFY_PASS phase=P04 task=T01-compute-staleness-review-queue checks_passed=2`. Smoke-checks below remain as the original local advisory trio:

- `bash scripts/knowledge/compute-staleness.sh | head -1` -> `STALENESS REPORT (as of 2026-04-25)` (legacy header preserved byte-equivalent).
- `bash scripts/knowledge/compute-staleness.sh --dry-run --archive-below 0.50 --min-hits 5` -> exit 0; reports `Total entries: 31` + `Would archive: 0 (threshold=0.50, min-hits=5, dry-run)` (legacy auto-archive path preserved).
- `bash scripts/knowledge/compute-staleness.sh --review-queue` against the live tree -> stdout `EMPTY`, exit 0 (live tree has no candidates as of P03 close).
- Single-candidate fixture (status=candidate, topic=shell utilities, created_at=2026-01-01) -> `cluster_id=C6c38f433 topic=shell_utilities count=1 oldest_age=113 stale=true` (whitespace-collapsed topic, age >= 14 -> stale=true).
- Two-candidate fixture (unrelated topics) plus one graduated entry -> two singleton cluster lines with the graduated entry excluded; `oldest_age=5 stale=false` and `oldest_age=10 stale=false` (under threshold).
- Malformed `staleness_threshold: notanint` in `.orchestrator/preferences.yml` -> stderr `WARN: malformed staleness_threshold=...notanint... -- using default=14`; stdout uses default 14; similarity malformed `bogus` -> silent fallback to 0.7.

`git status --short scripts/knowledge/compute-staleness.sh` -> single ` M` line. No files under `knowledge/**` touched by T01 itself (pre-existing index-rebuild churn from prior P03 runs is the new normal per P03 carry-forward lesson #9; T01's tempdirs are scoped under `mktemp -d`).

## Demo sentence

> `bash scripts/knowledge/compute-staleness.sh --review-queue --knowledge-root /tmp/fixture` walks the fixture's `MEM*.md` files, filters via `fm_read_status` to `status: candidate`, groups via `cluster_compute` at the resolved similarity threshold, and emits one `cluster_id=<C8hex> topic=<topic> count=<N> oldest_age=<days> stale=<true|false>` line per cluster on stdout (or the literal `EMPTY` when the candidate set is empty), exit 0 in both cases. The legacy `bash scripts/knowledge/compute-staleness.sh` (no flag) continues to print the staleness-decay report byte-equivalent.

## Plan deviations

- **Sourced `lib/detail-utils.sh` in addition to `lib/frontmatter.sh`.** The payload's helper body called `fm_field`, which is defined in `detail-utils.sh` (not `frontmatter.sh`). The payload's source list mentioned `frontmatter.sh` + `cluster.sh` only; sourcing `detail-utils.sh` is the minimal-deviation path to expose `fm_field` to the new helpers (vs. inlining a duplicate reader, which would violate Principle VII). All three helpers carry double-source guards so re-sourcing is a no-op.
- **Hoisted `_flush_one` to script scope as `_p04_flush_one` with positional args** rather than nesting it inside `_p04_review_queue_emit` and relying on closure-captured locals. The payload's helper body defined `_flush_one` inline; the hoisted form is functionally identical and avoids bash 3.2 scoping fragility.
- **Plan deviation -- verifier shipped under T01 instead of T03.** The plan body asserts that `scripts/verify/m020-p04-compute-staleness-review-queue.sh` is owned by T03, but the orchestrator's mechanical verifier (`scripts/lifecycle/auto-loop.sh --step=V`) parses the plan's Verification section and runs whatever it finds at task close -- it has no cross-task ordering awareness. The first auto-loop verify pass for T01 returned exit 127 (`No such file or directory`) because the verifier did not yet exist. Resolution: ship the verifier now under T01 with full FR-4 coverage (legacy-shape preservation, EMPTY-queue contract, single-cluster shape regex, AD-3 cluster-id format, multi-cluster + graduated-exclusion + sort-order). The verifier emits `PASS:`/`FAIL:` lines per MEM002, exits 0 only when all 9 checks pass, uses `mktemp -d` + `trap EXIT rm -rf` for fixture isolation, and is read-only against `knowledge/**`. T03 retains ownership of the *other* three P04 truth verifiers (per-truth verifier suite); T01 only ships the truth-1 verifier that gates this task itself. Reusable invariant: any task whose plan names a verifier MUST ship that verifier alongside the implementation, regardless of which downstream task originally owned it on paper.
- No other deviations. Argument parser branches, short-circuit `if`, helper-body algorithms, threshold-resolution semantics, EMPTY-queue contract, and CON-4-preserving placement all match the payload.

## Downstream impact

- **T02 (`scripts/orchestrator/status.sh` Review-Queue section)** consumes the cluster_id-line output (or `EMPTY`) by invoking `bash scripts/knowledge/compute-staleness.sh --review-queue` and rendering the first-line summary `Review Queue: <N> clusters, <M> entries awaiting review` plus indented per-cluster lines (with `(stale)` marker on lines whose underlying output carries `stale=true`).
- **T03 (per-truth verifiers)** owns the *remaining* three `scripts/verify/m020-p04-*.sh` scripts that gate truths #2-#4. T01 ships truth-1's verifier (`scripts/verify/m020-p04-compute-staleness-review-queue.sh`) under itself per the auto-loop --step=V parser's task-local ordering invariant (deviation noted above). T03's scope reduces from four verifiers to three: status-integration, malformed-prefs WARN diagnostic, and SC-3-style integration coverage.
- **T04 (SC-3 integration test)** exercises end-to-end fixtures: empty fixture -> `EMPTY`; single-candidate fixture -> one cluster line; multi-candidate fixture -> N cluster lines sorted by cluster-id; malformed-prefs WARN to stderr.
- **P06 (preferences cascade)** rewires the two `_p04_resolve_*_threshold` helpers to consume `lib/preferences.sh` once that helper ships; the project-only read here is the deliberate FR-6 deferral scoped to T01.
