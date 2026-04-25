---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P05"
milestone: "M020"
provides:
  - "scripts/knowledge/consolidate-artifacts.sh extended in place with --cluster short-circuit (FR-5),sources lib/cluster.sh + lib/decision-history.sh + lib/frontmatter.sh,emits cluster_id=C<8-hex> + indent member= block per cluster,advisory conflict: divergent-decision-history line on mixed-history or distinct-rationale-hash clusters,one consolidate_cluster JSONL record per cluster (cluster_id+member_count+member_ids+threshold_used+conflict_flag+milestone_id) via dh_emit_jsonl; four verifier scripts under scripts/verify/ (m020-p05-consolidate-cluster-emit/conflict-diagnostic/jsonl-emit/legacy-shape-preserved) all green; legacy two-positional invocation shape preserved byte-equivalent in observable behavior (CON-4)"
requires:
  - "from:P05/T01 what:scripts/knowledge/lib/cluster.sh exposes cluster_compute + cluster_id_for; from:P05/T02 what:scripts/knowledge/lib/jaccard.sh v2 feature vector; from:P03/T01 what:scripts/knowledge/lib/decision-history.sh exposes dh_emit_jsonl; from:P01/T02 what:scripts/knowledge/lib/frontmatter.sh present and sourceable"
affects:
  - "P05/T04,P06,M020-rollup"
key_files:
  - "scripts/knowledge/consolidate-artifacts.sh,scripts/verify/m020-p05-consolidate-cluster-emit.sh,scripts/verify/m020-p05-consolidate-conflict-diagnostic.sh,scripts/verify/m020-p05-consolidate-jsonl-emit.sh,scripts/verify/m020-p05-consolidate-legacy-shape-preserved.sh"
key_decisions:
  - "none-new,FR-5,FR-7,FR-8,CON-1,CON-4,AD-3,THREAT-006"
patterns_established:
  - "short-circuit-before-legacy-validation in-place extension (guard new flag at entry-point top + source helpers locally + exit 0 before legacy parser); subshell scope for pipefail-hostile pipelines (grep -v on empty input + find | head SIGPIPE wrapped in set +o pipefail; set +e capture); conflict-as-advisory (stdout conflict: line + JSONL conflict_flag=1 but no non-zero exit -- mutation gates live in graduate.sh per THREAT-006); awk associative grouping for bash-3.2 streams (flat <key>\t<value> -> one-summary-line-per-key); decision-history awk reader inlined for list-typed YAML (fm_field is scalar-only so per-record rationale_hash extraction uses inline awk state machine); read-only enforcement (FR-8/CON-1) via tempdir+PROJECT_ROOT+ORCH_ROOT verifier isolation -- live knowledge/ + execution-log.jsonl never touched"
drill_down_paths:
  - ".orchestrator/milestones/M020/phases/P05/tasks/T03-consolidate-cluster-extension-PAYLOAD.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-04-25T15:20:31Z"
---

## What was built

T03 extended `scripts/knowledge/consolidate-artifacts.sh` IN PLACE with a
`--cluster` short-circuit per FR-5, and shipped four single-script
verifiers under `scripts/verify/`. The new entry point produces
operator-readable cluster proposals + a JSONL audit record per cluster,
without mutating any knowledge entry (CON-1 / FR-8).

Concretely:

- `consolidate-artifacts.sh --cluster <orch-root> <milestone-id> [<knowledge-root>] [<threshold>]`
  is recognized BEFORE the legacy two-positional argument validation,
  via a guarded `if [ "${1:-}" = "--cluster" ]` block. When matched, the
  block sources `lib/cluster.sh` (T01), `lib/decision-history.sh` (P03),
  and `lib/frontmatter.sh` (P01); calls `cluster_compute` to derive
  `<cluster-id>\t<member-id>` lines; groups them by cluster_id via awk;
  and emits the `cluster_id=C<8-hex>` + indent `  member=<id>` block per
  cluster.
- Conflict diagnostic: for each cluster, the block reads
  `decision_history:` presence per member and captures `rationale_hash:`
  values from the YAML list. If at least one member has history AND at
  least one does not, OR if more than one distinct `rationale_hash`
  appears across members, a `conflict: cluster=<id>
  reason=divergent-decision-history` line is printed (advisory, not
  fatal — operator decides at graduate-time).
- JSONL emission: one `consolidate_cluster` record per cluster is
  appended to `${ORCH_ROOT}/execution-log.jsonl` via P03's
  `dh_emit_jsonl`, carrying `cluster_id`, `member_count`, `member_ids`
  (semicolon-joined), `threshold_used`, `conflict_flag`, `milestone_id`.
- The legacy two-positional shape (no `--cluster`) flows through the
  unchanged downstream code path verbatim per CON-4.

## Verifiers shipped

All four PASS:

- `scripts/verify/m020-p05-consolidate-cluster-emit.sh` — three-entry
  fixture (2 near-duplicates + 1 distinct, threshold 0.1); asserts at
  least one `cluster_id=C[0-9a-f]{8}` line, exactly three two-space
  indented `member=` lines, no duplicates.
- `scripts/verify/m020-p05-consolidate-conflict-diagnostic.sh` —
  two-entry fixture (one carries `decision_history:`, one pristine);
  asserts the `conflict: cluster=<id> reason=divergent-decision-history`
  line is emitted.
- `scripts/verify/m020-p05-consolidate-jsonl-emit.sh` — three-entry
  fixture, asserts at least one `consolidate_cluster` JSONL record with
  all required fields and `threshold_used=0.1`.
- `scripts/verify/m020-p05-consolidate-legacy-shape-preserved.sh` —
  complete-milestone scratch fixture, asserts legacy invocation rc=0
  with no `--cluster`-related error in stderr (CON-4 gate).

## Key decisions

- **Short-circuit placement** — the `--cluster` block is inserted AFTER
  the `set -euo pipefail` + `SCRIPT_DIR` + `PROJECT_ROOT` +
  `READ_ROADMAP` lines but BEFORE the `usage()` definition. This
  preserves the legacy script's path resolution while ensuring the new
  flag is never misread by the legacy `if [ $# -lt 2 ]` validator. The
  block ends with `exit 0` so legacy code is unreachable when
  `--cluster` is present.
- **`set -e` / `pipefail` taming inside the loop** — `cluster_compute`
  is wrapped in `set +e` / `set -e` so a non-zero rc surfaces as a
  diagnostic instead of aborting silently. The conflict-detection
  pipeline (`grep -v '^$' | sort -u | wc -l | awk`) is run in a
  subshell that disables pipefail+errexit, because `grep -v` returns rc
  1 on empty input — without taming, the legacy `set -euo pipefail`
  preamble would abort the script the moment a cluster has no
  decision_history members. Same treatment for `find ... | head -1`
  (head closes early → SIGPIPE on find under pipefail).
- **JSONL emission via P03's `dh_emit_jsonl`** — no jq, conservative
  backslash + double-quote escaping, ISO-8601 UTC timestamp, milestone
  resolved from `${ORCH_ROOT}/active-milestone` if present. Reusing the
  P03 helper keeps the JSONL shape consistent across `knowledge_*` and
  `consolidate_cluster` records (FR-7).
- **Read-only enforcement** — the `--cluster` block reads
  `knowledge/**/MEM*.md` files but writes nothing under `knowledge/`.
  Runtime writes are stdout, the JSONL log under `${ORCH_ROOT}`, and
  the ephemeral `${ORCH_ROOT}/.cluster-output.tmp.$$` scratch file
  removed at exit. Enforced by FR-8 / CON-1 and verified by the live
  tree being untouched after verifier runs.
- **awk associative arrays for grouping** — bash-3.2 constraint applies
  to bash code; awk's own arrays are fair game per MEM001. The grouping
  pass converts streaming `<cid>\t<mid>` lines into one summary line
  per cluster `<cid>\t<mid1>;<mid2>;...` for downstream iteration.

## Patterns established

- **Short-circuit-before-legacy-validation in-place extension**
  (generalises P03's CON-4 preserver) — guard the new flag at the very
  top of the entry point, source helpers locally, exit 0 before the
  legacy parser is reached. Legacy invocation pays no cost and exhibits
  no behavioral diff. Strictly additive.
- **Subshell scope for pipefail-hostile pipelines** — when `set -euo
  pipefail` is non-negotiable (legacy preamble), wrap individual
  pipefail-hostile pipelines (`grep -v` on empty input, `find | head`)
  in `"$(set +o pipefail; set +e; ... )"` capture form. Subshell
  isolates the option flips.
- **Conflict-as-advisory (not-abort)** — the `--cluster` block surfaces
  divergent-history clusters via a stdout `conflict:` line + a JSONL
  `conflict_flag=1` field but does NOT exit non-zero. Mutation gates
  (cluster-membership-drift abort) live in graduate.sh per
  THREAT-006 / DC-8. Consolidate's role is proposal + observation.
- **Awk associative grouping for bash-3.2 streams** — convert flat
  `<key>\t<value>` lines into one-summary-line-per-key via awk's
  built-in arrays, then iterate the grouped output in bash with
  `IFS=';'` member splitting.
- **Decision-history awk reader inlined for list-typed YAML** —
  `fm_field` (P01) is scalar-only; the per-record `rationale_hash:`
  extraction inside a `decision_history:` list block uses an inline
  awk state machine (`/^decision_history:/{in_dh=1}` ... terminate at
  next top-level key). Scoped to one site; not promoted to lib helper
  per Principle XIV.

## Verification results

- `bash scripts/verify/m020-p05-consolidate-cluster-emit.sh` — PASS:
  cluster_id + member lines + AD-3 shape.
- `bash scripts/verify/m020-p05-consolidate-conflict-diagnostic.sh` —
  PASS: divergent-history conflict line emitted.
- `bash scripts/verify/m020-p05-consolidate-jsonl-emit.sh` — PASS:
  1 `consolidate_cluster` record with all required fields,
  `threshold_used=0.1`.
- `bash scripts/verify/m020-p05-consolidate-legacy-shape-preserved.sh`
  — PASS: legacy two-positional shape rc=0 against complete-milestone
  fixture.
- `git status knowledge/` is dirty only for pre-existing hit_count
  churn (per P03 carry-forward lesson #9) — T03 verifiers wrote nothing
  under `knowledge/`; all writes routed to tempdirs.
- `git status .orchestrator/execution-log.jsonl` unchanged by T03
  verifier runs (verifiers used `ORCH_ROOT="$tmpdir/orch-state"`).

## Demo sentence

> Running `bash scripts/knowledge/consolidate-artifacts.sh --cluster
> <orch-root> <milestone-id> <knowledge-root> 0.1` against three
> candidate entries (two near-duplicates, one distinct) emits a
> `cluster_id=C<8-hex>` block with two indented `member=` lines plus a
> singleton, optionally surfaces a `conflict:` line when proposed
> members carry divergent `decision_history:` records, and appends one
> `consolidate_cluster` JSONL record per cluster to
> `${ORCH_ROOT}/execution-log.jsonl` — all without mutating any
> knowledge entry.

## Plan deviations

- **`set -e` / `pipefail` hardening beyond the payload snippet** — the
  payload's verbatim block worked under `set -u` only; the existing
  script preamble carries `set -euo pipefail`, so `grep -v '^$'` on
  empty input and `find | head -1` SIGPIPE caused the script to exit 1
  after correctly emitting the cluster block. Wrapped the affected
  command-substitution captures in `set +o pipefail; set +e` subshell
  scope. This is purely a robustness fix; observable contract
  unchanged.
- **No other deviations** — verifier scripts shipped verbatim per
  payload Steps 2–5. Insertion point matched exactly. CON-4 gate
  passed first try.

## Downstream impact

- **P05 / T04 (integration test):** can now exercise the full
  `consolidate-artifacts.sh --cluster → operator → graduate.sh
  --cluster` round-trip. The `consolidate_cluster` JSONL record IDs
  feed graduate.sh's `--cluster <id>` mutation path.
- **P06 (preferences layer):** `threshold_used` is currently a
  CLI-positional or 0.7 default; P06 will source it from
  `.orchestrator/preferences.yml:cluster_threshold` and fall through
  to 0.7. The CLI positional is preserved for tests/operator override.
- **M020 phase rollup:** T03 closes the FR-5 must-have. P05's `--`
  cluster proposal surface is now end-to-end functional; the only
  remaining P05 task is T04 (integration test).
