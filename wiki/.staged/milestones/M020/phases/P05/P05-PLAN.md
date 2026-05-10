---
schema_version: "1.0"
type: phase-plan
phase: "P05"
milestone: "M020"
goal: "Extend `scripts/knowledge/consolidate-artifacts.sh` with the FR-5 `--cluster` flag (pairwise-Jaccard clustering, deterministic AD-3 cluster IDs, `consolidate_cluster` JSONL emit, conflict diagnostic on divergent decision histories), extend the CON-5 feature vector per the P01 validation-report recommendation (`relates_to[]` + `source_unit` + capped full-body tokens), and ship the SC-4 integration test that exercises clustering end-to-end against a 10-entry candidate fixture consumable by `graduate.sh --cluster`."
demo_sentence: "Running `bash scripts/knowledge/consolidate-artifacts.sh --cluster .orchestrator MTEST` against a ten-entry candidate fixture (four near-duplicates by the extended CON-5 feature vector at >= the configured threshold, six distinct) emits seven cluster IDs on stdout (one four-entry cluster + six singletons), each formatted `C[0-9a-f]{8}` per AD-3 and consumable verbatim by `graduate.sh --cluster <id>`; a separate fixture with conflicting `decision_history` records inside a proposed cluster surfaces a `conflict:` diagnostic on stdout for that cluster; one `consolidate_cluster` JSONL record is appended to `${ORCH_ROOT}/execution-log.jsonl` per emitted cluster."
risk: "medium"
depends_on: ["P01", "P03"]
---

## Must-Haves

### Truths

<!-- Each truth is a behavioral statement + a single-script-file Check.
     Per AD-19 / MEM031 / P01+P03 retrospective lessons, Truth Check
     commands MUST use single-invocation script-file shape — no inline
     compound bash, no plain subshells, no $() containing pipes, no
     process substitution. Verifier scripts referenced here are produced
     by the listed task; the phase-level Verification Commands block at
     the bottom is the rollup. -->

- `scripts/knowledge/lib/cluster.sh` exists, is sourceable, and exposes `cluster_compute <root> <threshold>` (emits `<cluster-id>\t<member-id>` lines, one per (cluster, member) pair) and `cluster_id_for <sorted-member-id-csv>` (deterministic `C<8-hex>` content-hash per AD-3).
  - Check: `bash scripts/verify/m020-p05-cluster-helper-contract.sh`
- `scripts/knowledge/lib/cluster.sh::cluster_compute` produces deterministic output: invoking it twice against the same fixture produces byte-identical stdout (sorted by cluster-id then member-id).
  - Check: `bash scripts/verify/m020-p05-cluster-determinism.sh`
- `scripts/knowledge/lib/cluster.sh::cluster_compute` against a ten-entry fixture (four near-duplicates above threshold, six distinct) emits seven distinct cluster IDs covering all ten members exactly once (no orphans, no duplicates).
  - Check: `bash scripts/verify/m020-p05-cluster-singleton-coverage.sh`
- `scripts/knowledge/lib/jaccard.sh` exposes the extended CON-5 feature vector (`title` + `topic` + `tags[]` + `relates_to[]` + `source_unit` + body words capped at 200 tokens), and the validation report at [`.orchestrator/milestones/M020/phases/P05/jaccard-validation-report.md`](../../../../milestones/M020/phases/P05/jaccard-validation-report.md) is regenerated against the live tree using the extended vector with the new threshold recommendation recorded.
  - Check: `bash scripts/verify/m020-p05-feature-vector-extension.sh`
- `scripts/knowledge/consolidate-artifacts.sh --cluster <orch-root> <milestone-id>` emits exactly N cluster-ID lines on stdout (matching `^cluster_id=C[0-9a-f]{8}$` followed by `  member=<entry-id>` indent lines per member) when the underlying tree has N candidate clusters; cluster IDs are valid for direct passthrough to `graduate.sh --cluster <id>`.
  - Check: `bash scripts/verify/m020-p05-consolidate-cluster-emit.sh`
- `scripts/knowledge/consolidate-artifacts.sh --cluster` surfaces a `conflict: cluster=<id> reason=divergent-decision-history` line on stdout when a proposed cluster contains entries whose `decision_history:` records were rejected by an earlier graduate operation (e.g. one previously rejected, one pristine).
  - Check: `bash scripts/verify/m020-p05-consolidate-conflict-diagnostic.sh`
- `scripts/knowledge/consolidate-artifacts.sh --cluster` emits one `consolidate_cluster` JSONL record per emitted cluster (including singletons) to `${ORCH_ROOT}/execution-log.jsonl`, carrying `cluster_id`, `member_count`, `member_ids` (semicolon-joined), `threshold_used`, and `conflict_flag` fields per the M020 ROADMAP cross-cutting concern.
  - Check: `bash scripts/verify/m020-p05-consolidate-jsonl-emit.sh`
- `scripts/knowledge/consolidate-artifacts.sh` preserves byte-equivalent observable behavior of its pre-M020 invocation shape — `consolidate-artifacts.sh <orch-root> <milestone-id>` (no `--cluster`) still archives task plans and reports a reduction percentage exactly as it did before P05 (CON-4).
  - Check: `bash scripts/verify/m020-p05-consolidate-legacy-shape-preserved.sh`
- `tests/test-jaccard-clustering.sh` exists, is executable, and exits 0 covering SC-4 (ten-entry fixture: four-entry cluster + six singletons), conflict-diagnostic surface, and the round-trip handoff to `graduate.sh --cluster <id>`.
  - Check: `bash tests/test-jaccard-clustering.sh`

### Artifacts

- `scripts/knowledge/lib/cluster.sh` (min 120 lines, contains "cluster_compute")
- `scripts/knowledge/lib/jaccard.sh` (min 350 lines, contains "relates_to")
- `scripts/knowledge/consolidate-artifacts.sh` (min 280 lines, contains "--cluster")
- `tests/test-jaccard-clustering.sh` (min 180 lines, contains "conflict")
- [`.orchestrator/milestones/M020/phases/P05/jaccard-validation-report.md`](../../../../milestones/M020/phases/P05/jaccard-validation-report.md) (min 40 lines, contains "relates_to")
- `scripts/verify/m020-p05-cluster-helper-contract.sh` (min 50 lines, contains "cluster_compute")
- `scripts/verify/m020-p05-cluster-determinism.sh` (min 40 lines, contains "deterministic")
- `scripts/verify/m020-p05-cluster-singleton-coverage.sh` (min 50 lines, contains "singleton")
- `scripts/verify/m020-p05-feature-vector-extension.sh` (min 50 lines, contains "relates_to")
- `scripts/verify/m020-p05-consolidate-cluster-emit.sh` (min 60 lines, contains "cluster_id=")
- `scripts/verify/m020-p05-consolidate-conflict-diagnostic.sh` (min 50 lines, contains "conflict:")
- `scripts/verify/m020-p05-consolidate-jsonl-emit.sh` (min 50 lines, contains "consolidate_cluster")
- `scripts/verify/m020-p05-consolidate-legacy-shape-preserved.sh` (min 50 lines, contains "legacy")

### Key Links

- `scripts/knowledge/lib/cluster.sh` -> `scripts/knowledge/lib/jaccard.sh` (cluster.sh sources jaccard.sh for `pairwise_jaccard` and the extended CON-5 feature vector; comment in cluster.sh header names the file)
- `scripts/knowledge/consolidate-artifacts.sh` -> `scripts/knowledge/lib/cluster.sh` (consolidate-artifacts.sh sources cluster.sh for `cluster_compute` and `cluster_id_for`; comment in consolidate header names the file)
- `scripts/knowledge/consolidate-artifacts.sh` -> `scripts/knowledge/lib/decision-history.sh` (consolidate sources dh helper for `dh_emit_jsonl` to write `consolidate_cluster` records; comment in consolidate header names the file)
- `tests/test-jaccard-clustering.sh` -> `scripts/knowledge/consolidate-artifacts.sh` (test invokes the script under test verbatim; assertion comments name graduate.sh as the round-trip consumer)

## Tasks

### T01: Cluster computation helper (`scripts/knowledge/lib/cluster.sh`)

See `tasks/T01-cluster-helper-PLAN.md`.

Lands the FR-5 + AD-3 pure-function helper sourced by T02. Two callable surfaces: `cluster_compute <knowledge-root> <threshold>` walks all candidate entries, computes pairwise Jaccard via the (already-extended-by-T02-of-this-phase OR current) `lib/jaccard.sh::pairwise_jaccard`, builds an undirected similarity graph, and emits connected components above the threshold as clusters; `cluster_id_for <sorted-csv>` computes the deterministic AD-3 cluster ID (`C<first-8-hex-of-sha1-of-sorted-member-csv>`). Pure read — no file mutations, no JSONL emission. T01 lands BEFORE T02 (feature-vector extension) so cluster.sh has a stable jaccard.sh contract; the singleton-coverage truth is what proves correctness regardless of whether the threshold yields any non-singleton clusters against the live tree.

### T02: Feature-vector extension + validation re-run (`scripts/knowledge/lib/jaccard.sh` + P05 jaccard-validation-report)

See `tasks/T02-feature-vector-extension-PLAN.md`.

Per the P01 jaccard-validation-report.md recommendation: extend the CON-5 feature vector beyond `title + topic + tags[] + first-paragraph-50-tokens` to also include (a) `relates_to[]` frontmatter edges, (b) `source_unit` provenance string, and (c) full-body word-set capped at 200 tokens (rather than just the first paragraph at 50 tokens). The schema-authority gate for `relates_to[]` and `source_unit` is already covered — both fields are pre-existing on entries written before M020 (see e.g. MEM029, MEM030 in the live tree); P05 only TOKENIZES them, does not introduce them, so no D-row is required. After extension, re-run `bash scripts/knowledge/lib/jaccard.sh validate knowledge/` against the live tree and persist the regenerated report at [`.orchestrator/milestones/M020/phases/P05/jaccard-validation-report.md`](../../../../milestones/M020/phases/P05/jaccard-validation-report.md) with the updated threshold recommendation.

### T03: `consolidate-artifacts.sh --cluster` extension

See `tasks/T03-consolidate-cluster-extension-PLAN.md`.

Extends `scripts/knowledge/consolidate-artifacts.sh` IN PLACE (CON-4 byte-equivalent surface preservation for the existing legacy two-positional-arguments invocation shape). New flag: `--cluster`. When set, the command computes the cluster set via T01's `cluster_compute` against `knowledge/` filtered to `status: candidate` entries only, computes deterministic cluster IDs via `cluster_id_for`, surfaces conflicts (entries within a proposed cluster whose `decision_history:` records are present and divergent — i.e. one rejected, one pristine — flag with `conflict:` line on stdout), and emits one `consolidate_cluster` JSONL record per cluster via T01-of-P03's `dh_emit_jsonl` helper.

### T04: Integration test (`tests/test-jaccard-clustering.sh` covering SC-4)

See `tasks/T04-integration-test-PLAN.md`.

Cross-cutting end-to-end test exercising the full clustering loop through `consolidate-artifacts.sh --cluster` directly: (1) ten-entry candidate fixture (four near-duplicates that DO cluster above threshold by the extended CON-5 vector + six distinct entries) emits seven cluster IDs (one 4-member + six singletons) per SC-4; (2) conflict-diagnostic fixture (cluster with mixed decision-history states) surfaces `conflict:` line; (3) cluster-IDs from (1) are valid passthrough to `graduate.sh --cluster <id>` against the same fixture (asserts the ID format contract end-to-end); (4) JSONL records land in `.orchestrator/execution-log.jsonl` for SC-4. Bash 3.2 + tempdir + PROJECT_ROOT/ORCH_ROOT fixture isolation per the P03/T04 pattern.

## Task Dependencies

```
T01 ───────────────┐
                   ▼
T02 ──────────────► T03 ──────► T04
   (independent
    of T01,
    can run before
    or after T01)
```

- **T01 (cluster helper)** consumes only the existing `lib/jaccard.sh::pairwise_jaccard` (P01 contract); no dependency on T02. Ships the pure-function clustering primitive.
- **T02 (feature-vector extension)** modifies `lib/jaccard.sh` in place to broaden the feature vector. Independent of T01 — T01's `cluster_compute` calls `pairwise_jaccard` regardless of vector internals. T02 lands the vector extension AND regenerates the P05 validation report.
- **T03 (consolidate extension)** depends on BOTH T01 (cluster helpers) AND T02 (extended vector — clustering against the broader vector is what produces the four-entry cluster the SC-4 fixture demands). Sources `lib/decision-history.sh::dh_emit_jsonl` from P03/T01.
- **T04 (integration test)** depends on T03 (exercises the extended consolidate-artifacts.sh end-to-end + asserts the round-trip to graduate.sh --cluster).

Auto-loop dispatch order: T01 then T02 in either order (or in parallel if dispatch supports it), then T03, then T04. The two-pair cadence mirrors the P03 plan.

## Verification Commands

<!-- Cross-task invariants and phase-level rollups. Per-task verifiers
     live under each task's own ## Verification block; the commands here
     are the phase-completion gate that runs after T04 ships. Per the
     P01/P02/P03 retrospective lesson: NEVER reference verifier scripts
     created by future tasks from inside a task's own verification
     block. Cross-task assertions belong here. -->

```
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M020/phases/P05
bash scripts/verify/m020-p05-cluster-helper-contract.sh
bash scripts/verify/m020-p05-cluster-determinism.sh
bash scripts/verify/m020-p05-cluster-singleton-coverage.sh
bash scripts/verify/m020-p05-feature-vector-extension.sh
bash scripts/verify/m020-p05-consolidate-cluster-emit.sh
bash scripts/verify/m020-p05-consolidate-conflict-diagnostic.sh
bash scripts/verify/m020-p05-consolidate-jsonl-emit.sh
bash scripts/verify/m020-p05-consolidate-legacy-shape-preserved.sh
bash tests/test-jaccard-clustering.sh
```

All ten commands must exit 0. The first is the must-haves rollup; the next eight are per-truth Tier-1 verifiers; the last is the integration test.

## Files Likely Touched

- `scripts/knowledge/lib/cluster.sh` (create)
- `scripts/knowledge/lib/jaccard.sh` (modify — extend feature vector with `relates_to[]` + `source_unit` + capped full-body tokens; preserve `pairwise_jaccard` contract: same signature, broader content)
- `scripts/knowledge/consolidate-artifacts.sh` (modify — add `--cluster` flag; preserve legacy two-positional-arguments shape byte-equivalent per CON-4)
- `tests/test-jaccard-clustering.sh` (create)
- [`.orchestrator/milestones/M020/phases/P05/jaccard-validation-report.md`](../../../../milestones/M020/phases/P05/jaccard-validation-report.md) (create — regenerated against the live tree using the extended vector)
- `scripts/verify/m020-p05-cluster-helper-contract.sh` (create)
- `scripts/verify/m020-p05-cluster-determinism.sh` (create)
- `scripts/verify/m020-p05-cluster-singleton-coverage.sh` (create)
- `scripts/verify/m020-p05-feature-vector-extension.sh` (create)
- `scripts/verify/m020-p05-consolidate-cluster-emit.sh` (create)
- `scripts/verify/m020-p05-consolidate-conflict-diagnostic.sh` (create)
- `scripts/verify/m020-p05-consolidate-jsonl-emit.sh` (create)
- `scripts/verify/m020-p05-consolidate-legacy-shape-preserved.sh` (create)

No files under `knowledge/**` are touched by P05 task code (clustering is read-only per FR-8 / CON-1 — only `graduate.sh` mutates entries, and graduate.sh itself is not invoked by consolidate-artifacts.sh; the round-trip is operator-mediated). The verifier scripts use tempdirs with `PROJECT_ROOT` overrides so the live tree is never touched. JSONL emission writes to `${ORCH_ROOT}/execution-log.jsonl` at runtime, but verifier tests use isolated `ORCH_ROOT` env-var overrides so the live execution log is never touched during verification.

No files under `.orchestrator/memory/` or [`.orchestrator/DECISIONS.md`](../../../../decisions.md) are touched (no schema evolution in P05 — `relates_to[]` and `source_unit` are pre-existing fields not authored by P05; only their tokenization changes inside lib/jaccard.sh).

T02 writes a new [`.orchestrator/milestones/M020/phases/P05/jaccard-validation-report.md`](../../../../milestones/M020/phases/P05/jaccard-validation-report.md) derived from `lib/jaccard.sh validate knowledge/`; this is the canonical P05 calibration artifact and is reproducible from source data on every run (per the P01/T05 pattern). It is the only file P05 writes outside `scripts/`, `tests/`, and the P05 phase verifier set.
