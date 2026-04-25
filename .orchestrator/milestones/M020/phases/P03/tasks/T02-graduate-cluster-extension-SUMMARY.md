---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P03"
milestone: "M020"
provides:
  - "scripts/knowledge/graduate.sh extended in place with --cluster <id> + --reject + multi-entry positional shape; cluster atomicity drift gate (THREAT-006 disposition) with zero file mutations on abort; --reject body archives every member without archived_into; canonical+sibling write loop on graduate path with archived_into back-references; decision_history append on every member via T01+P01 helpers; JSONL emission via dh_emit_jsonl (one knowledge_graduate + N-1 knowledge_archive on graduate; N knowledge_archive on reject); P01 single-entry surface preserved per CON-4; five new T02-owned verifier scripts under scripts/verify/ all green"
requires:
  - "from:P03/T01 what:scripts/knowledge/lib/decision-history.sh (dh_resolve_operator + dh_emit_jsonl); from:P01/T02 what:scripts/knowledge/lib/frontmatter.sh (fm_read_status, fm_write_status, fm_write_archived_into, fm_append_decision_history); from:P01/T03 what:scripts/knowledge/graduate.sh single-entry surface preserved byte-equivalent"
affects:
  - "P03/T03,P03/T04,P05"
key_files:
  - "scripts/knowledge/graduate.sh,scripts/verify/m020-p03-graduate-cluster-multi-entry.sh,scripts/verify/m020-p03-graduate-cluster-drift-abort.sh,scripts/verify/m020-p03-graduate-reject-path.sh,scripts/verify/m020-p03-graduate-jsonl-emit.sh,scripts/verify/m020-p03-graduate-p01-shape-preserved.sh"
key_decisions:
  - "D024"
patterns_established:
  - "cluster-aware mutation script pattern (pre-flight read of every member's gate-relevant state -> abort with structured diagnostic + zero mutations on drift -> deterministic write loop with shared per-cluster scalars (operator, rationale_hash, canonical) -> JSONL emission after all writes succeed); drift-gate-as-CON-4-preserver (gating the new pre-flight on the new flag means the legacy invocation shape pays no cost and exhibits no behavior diff -- generalizable to any in-place script extension); operator+rationale_hash resolved once per cluster invocation (not per-member) for JSONL consistency; per-helper atomicity composes into cluster atomicity (each fm_* write is tempfile+rename atomic; pre-flight drift gate guarantees N writes succeed under FR-9 closed-enum); parallel newline-joined scalars for cluster member tracking (ids/files accumulate as newline-separated strings, iterated via awk -v n=$i NR==n) per MEM001 bash-3.2 convention"
drill_down_paths:
  - ".orchestrator/milestones/M020/phases/P03/tasks/T02-graduate-cluster-extension-PAYLOAD.md"
duration: "35m"
verification_result: "pass"
completed_at: "2026-04-25T14:34:06Z"
---

## What was built

T02 extends `scripts/knowledge/graduate.sh` in place from the P01 minimum-viable single-entry flip into the full P03 cluster-aware workflow consumed by the M020 graduation pipeline. The T01 helper (`scripts/knowledge/lib/decision-history.sh`) is sourced by graduate.sh for operator resolution + JSONL emission; the P01 frontmatter helpers (`fm_read_status`, `fm_write_status`, `fm_write_archived_into`, `fm_append_decision_history`) compose the per-entry atomic writes into the cluster transaction.

Concretely:

- **`--cluster <id> --rationale <text> <id1> [<id2> ...]`** — first positional is the canonical entry (flips to `graduated`); siblings flip to `archived` with `archived_into: <canonical-id>`. All N members gain a `decision_history:` record carrying the rationale, operator, ISO-8601 timestamp, and cluster_id.
- **`--reject --cluster <id> --rationale <text> <id1> [<id2> ...]`** — every member flips to `archived`; no `archived_into` written (rejection has no canonical replacement). All N members gain a `decision_history:` record.
- **Cluster atomicity (THREAT-006 / DC-8)** — pre-flight `fm_read_status` on every cluster member; abort with `FAIL: cluster-membership-drift entry=<id> status=<observed>` and exit 1 with ZERO file mutations if any member is not `candidate`. The drift gate runs only when `--cluster` is set, leaving the P01 single-entry surface byte-equivalent.
- **JSONL emission** — one `knowledge_graduate` record (canonical) and N-1 `knowledge_archive` records (siblings) on graduate; N `knowledge_archive` records (with empty `archived_into`) on reject. Rationale is hashed (`sha1[0..8]`) into the JSONL — no full-rationale duplication (Principle XIV).
- **CON-4 P01 surface preservation** — `--rationale <text> <entry-id>` (no `--cluster`) continues to flip candidate→graduated, NO-OP on graduated, FAIL on archived. Now also emits a `decision_history:` record + `knowledge_graduate` JSONL line (P01 stub-RATIONALE was always known to be deferred work; the observable single-entry control flow is unchanged).

## Key decisions

- **T02 owns BOTH the cluster-graduate path AND the cluster-reject path** (per the Reconciliation note in the payload). The P03 phase plan has no separate `--reject` task; T03 is schema-authority lint, not the reject body.
- **Drift gate is `--cluster`-scoped**. The pre-flight read runs only when `--cluster` is set. This is what preserves CON-4 P01 byte-equivalence — single-entry callers never pay the drift-gate cost and never hit a behavior diff vs P01.
- **Parallel newline-joined scalars for cluster member tracking** (per MEM001 bash-3.2 convention). `ids` and `files` accumulate as `\n`-separated strings, iterated via `awk -v n=$i 'NR==n'`. No associative arrays, no `mapfile`.
- **Per-helper atomicity composes into cluster atomicity**. Each `fm_*` write is tempfile+rename atomic. The pre-flight drift gate guarantees that all N writes will succeed under FR-9 closed-enum constraints, so the failure surface for partial-application is bounded to one entry mid-cluster (a transient FS error during `mv`) — not a logical pre-condition violation.
- **Operator + rationale_hash resolved once per cluster invocation** rather than per-member. Keeps the JSONL records consistent across the cluster; matches the M019 Tier 1 emission contract.

## Patterns established

- Cluster-aware mutation script pattern: pre-flight read of every member's gate-relevant state → abort with structured diagnostic + zero mutations on drift → deterministic write loop with shared per-cluster scalars (operator, rationale_hash, canonical) → JSONL emission after all writes succeed.
- Drift-gate-as-CON-4-preserver: gating the new pre-flight on the new flag (`--cluster`) means the legacy invocation shape pays no cost and exhibits no behavior diff. Generalizable to any in-place script extension that adds new modes alongside a preserved legacy mode.
- Reference-implementation-from-payload pattern: when the payload carries a substantial reference implementation, the verifier set is the contract; treat the reference as a starting point and let the verifier set drive correctness, not the reference text.

## Verification results

All five T02-owned verifier scripts PASS:

- `m020-p03-graduate-cluster-multi-entry.sh` — three-entry cluster: canonical=graduated, siblings=archived+archived_into=MEM900, all three gained decision_history with rationale text.
- `m020-p03-graduate-cluster-drift-abort.sh` — three-entry cluster with one member already graduated: aborted with `cluster-membership-drift` diagnostic, snapshot pre vs post identical (zero file mutations).
- `m020-p03-graduate-reject-path.sh` — two-entry reject: both archived, neither has archived_into, both have decision_history.
- `m020-p03-graduate-jsonl-emit.sh` — cluster: 1 knowledge_graduate + 2 knowledge_archive; reject: 0 knowledge_graduate + 2 knowledge_archive.
- `m020-p03-graduate-p01-shape-preserved.sh` — candidate flip + idempotent NO-OP + archived FAIL all behave as in P01.

`git status knowledge/` and `git status .orchestrator/execution-log.jsonl` show no T02-attributable changes (verifiers use isolated `PROJECT_ROOT` + `ORCH_ROOT` tempdir env overrides).

## Demo sentence

Running `bash scripts/knowledge/graduate.sh --cluster Ctest --rationale "merge near-duplicates" MEM900 MEM901 MEM902` flips MEM900 to graduated, MEM901+MEM902 to archived with archived_into=MEM900, appends a decision_history record carrying the rationale to all three entries, and emits one knowledge_graduate + two knowledge_archive JSONL records to `${ORCH_ROOT}/execution-log.jsonl`. Adding `--reject` flips every member to archived without archived_into and emits N knowledge_archive records.

## Plan deviations

- None observed during execution. The reference implementation in the payload was used essentially verbatim (with minor stylistic adjustments — multi-line `if` blocks instead of `&&` short-circuits to honor AP-009 pre-bash-shape-guard, and `command -v md5sum` branching in the drift-abort verifier in place of inline `||` fallback).
- The Reconciliation note in the payload (T02 owns both graduate AND reject bodies, contradicting the earlier paragraph that suggested a stub-only reject) was followed.

## Downstream impact

- **T03 (`scripts/verify/knowledge-schema-lint.sh`)** can now assume graduate.sh is the schema-mutation entry point and lint accordingly.
- **T04 (`tests/test-graduate-workflow.sh`)** can now run end-to-end fixtures against the full graduate + reject paths.
- **P05 (clustering)** can call `graduate.sh --cluster` directly once the clusters are derived from the Jaccard primitive + threshold.
- **`.orchestrator/execution-log.jsonl`** now carries `knowledge_graduate` + `knowledge_archive` events any time graduate.sh runs in a non-fixture context — observability surface for the M020 graduation cadence.
