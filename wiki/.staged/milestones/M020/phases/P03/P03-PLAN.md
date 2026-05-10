---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M020"
goal: "Extend `scripts/knowledge/graduate.sh` from the P01 single-entry minimum-viable scaffold into the full FR-3 cluster-aware workflow (multi-entry atomic state flips, `archived_into:` back-references, FR-7 `decision_history:` append, JSONL observability emit, `--reject` path), and ship the FR-9 schema-authority lint that enforces M020's frontmatter boundary against future drift."
demo_sentence: "Running `bash scripts/knowledge/graduate.sh --cluster C1 --rationale 'merge — same assertion' MEM900 MEM901 MEM902` against a three-entry candidate cluster fixture flips one canonical entry to `status: graduated`, the two siblings to `status: archived` with `archived_into: <canonical-id>` back-references, and appends a `decision_history:` block containing the rationale + ISO-8601 timestamp + operator email to all three entries; `bash scripts/verify/knowledge-schema-lint.sh` exits non-zero on a fixture introducing an unauthorized frontmatter field; `tests/test-graduate-workflow.sh` exits 0 across all SC-2 cases."
risk: "high"
depends_on: ["P01"]
---

## Must-Haves

### Truths

<!-- Each truth is a behavioral statement + a single-script-file Check.
     Per AD-19 / MEM031 / continue.md lessons (P01 + P02), Truth Check
     commands MUST use single-invocation script-file shape — no inline
     compound bash, no plain subshells, no $() containing pipes, no
     process substitution. Verifier scripts referenced here are produced
     by the listed task; the phase-level Verification Commands block at
     the bottom is the rollup. -->

- `scripts/knowledge/lib/decision-history.sh` exists, is sourceable, exposes `dh_resolve_operator` and `dh_emit_jsonl`, and `dh_resolve_operator` falls through `git config user.email` → `preferences.yml:operator_identifier` → `unknown@local` per OQ-2.
  - Check: `bash scripts/verify/m020-p03-decision-history-helper-contract.sh`
- `scripts/knowledge/graduate.sh --cluster <id> --rationale <text> <id1> <id2> <id3>` against a three-entry candidate cluster flips the first listed entry to `graduated`, remaining entries to `archived`, writes `archived_into: <canonical-id>` on each archive, and appends a `decision_history:` record on all three.
  - Check: `bash scripts/verify/m020-p03-graduate-cluster-multi-entry.sh`
- `scripts/knowledge/graduate.sh --reject --cluster <id> --rationale <text> <id1> <id2>` flips ALL listed entries to `archived` without writing any `archived_into:` field (rejection has no canonical), and appends a `decision_history:` record on every entry.
  - Check: `bash scripts/verify/m020-p03-graduate-reject-path.sh`
- `scripts/knowledge/graduate.sh --cluster` is atomic across the cluster — if any single entry's pre-flight `fm_read_status` reports a non-`candidate` value (cluster-membership-drift per DC-8 THREAT-006), the entire invocation aborts before mutating any file and exits non-zero with a `cluster-membership-drift` diagnostic.
  - Check: `bash scripts/verify/m020-p03-graduate-cluster-drift-abort.sh`
- `scripts/knowledge/graduate.sh` emits a `knowledge_graduate` JSONL record per graduate operation and a `knowledge_archive` JSONL record per archive operation, appended to `.orchestrator/execution-log.jsonl` ([M019](../../../../milestones/M019/index.md) Tier 1 contract).
  - Check: `bash scripts/verify/m020-p03-graduate-jsonl-emit.sh`
- `scripts/knowledge/graduate.sh` preserves single-entry P01 invocation shape — `graduate.sh --rationale <text> <entry-id>` (no `--cluster`) still flips a single candidate to graduated, idempotent re-run on graduated still NO-OPs, and rejected re-graduate on archived still FAILs (CON-4 byte-equivalent surface preservation).
  - Check: `bash scripts/verify/m020-p03-graduate-p01-shape-preserved.sh`
- `scripts/verify/knowledge-schema-lint.sh` exits 0 against the live `knowledge/**/MEM*.md` tree and exits non-zero against a fixture introducing an unauthorized frontmatter field (FR-9 + SC-8).
  - Check: `bash scripts/verify/m020-p03-schema-lint-contract.sh`
- `scripts/verify/knowledge-schema-lint.sh` rejects vocabulary drift — a fixture entry with `status: deprecated` (outside MEM031's closed enum) exits the lint non-zero with a `vocabulary-drift` diagnostic.
  - Check: `bash scripts/verify/m020-p03-schema-lint-vocabulary-drift.sh`
- `tests/test-graduate-workflow.sh` exists, is executable, and exits 0 covering SC-2 (three-entry cluster graduation), single-entry cluster graduation, rejection-path archive, and cluster-membership-drift abort.
  - Check: `bash tests/test-graduate-workflow.sh`

### Artifacts

- `scripts/knowledge/lib/decision-history.sh` (min 80 lines, contains "dh_resolve_operator")
- `scripts/knowledge/graduate.sh` (min 200 lines, contains "cluster")
- `scripts/verify/knowledge-schema-lint.sh` (min 120 lines, contains "MEM031")
- `tests/test-graduate-workflow.sh` (min 150 lines, contains "cluster")
- `scripts/verify/m020-p03-decision-history-helper-contract.sh` (min 40 lines, contains "dh_resolve_operator")
- `scripts/verify/m020-p03-graduate-cluster-multi-entry.sh` (min 60 lines, contains "archived_into")
- `scripts/verify/m020-p03-graduate-reject-path.sh` (min 50 lines, contains "reject")
- `scripts/verify/m020-p03-graduate-cluster-drift-abort.sh` (min 50 lines, contains "drift")
- `scripts/verify/m020-p03-graduate-jsonl-emit.sh` (min 50 lines, contains "knowledge_graduate")
- `scripts/verify/m020-p03-graduate-p01-shape-preserved.sh` (min 40 lines, contains "graduated")
- `scripts/verify/m020-p03-schema-lint-contract.sh` (min 50 lines, contains "schema")
- `scripts/verify/m020-p03-schema-lint-vocabulary-drift.sh` (min 40 lines, contains "vocabulary-drift")

### Key Links

- `scripts/knowledge/graduate.sh` → `scripts/knowledge/lib/decision-history.sh` (graduate.sh sources the dh helper for operator resolution + JSONL emit; comment in graduate.sh header names the file)
- `scripts/knowledge/graduate.sh` → `scripts/knowledge/lib/frontmatter.sh` (graduate.sh sources the fm helpers for `fm_read_status`, `fm_write_status`, `fm_write_archived_into`, `fm_append_decision_history`; comment in graduate.sh names the file)
- `scripts/verify/knowledge-schema-lint.sh` → [`knowledge/conventions/MEM031.md`](../../../../knowledge/conventions/MEM031.md) (lint script comments name MEM031 as the authoritative schema source for the closed-enum vocabulary)
- `tests/test-graduate-workflow.sh` → `scripts/knowledge/graduate.sh` (test invokes the script under test verbatim)

## Tasks

### T01: decision-history helper (`scripts/knowledge/lib/decision-history.sh`)

See `tasks/T01-decision-history-helper-PLAN.md`.

Lands the FR-7 + OQ-2 + JSONL-emit helper sourced by T02. Pure functions only — no file mutation; mutation flows through the existing P01 `frontmatter.sh::fm_append_decision_history` helper which graduate.sh calls directly. T01 owns operator-identity resolution (`git config user.email` → `preferences.yml:operator_identifier` → `unknown@local`) and the `knowledge_graduate` / `knowledge_archive` JSONL record shapes.

### T02: graduate.sh extension — cluster, multi-entry atomicity, archived_into, decision_history, JSONL

See `tasks/T02-graduate-cluster-extension-PLAN.md`.

Extends `scripts/knowledge/graduate.sh` in place (CON-4 byte-equivalent surface preservation for the P01 single-entry path). New flags: `--cluster <id>`, `--reject`. New positional shape: accepts N entry-ids when `--cluster` is set (first id is canonical for graduation; all are archived for `--reject`). Atomicity via two-phase commit: (phase 1) read all entry statuses and abort on cluster-membership-drift; (phase 2) commit all writes via existing P01 helpers — no partial application possible because each fm_* helper is itself atomic and the abort-on-drift gate runs before any mutation.

### T03: schema-authority lint (`scripts/verify/knowledge-schema-lint.sh`)

See `tasks/T03-schema-authority-lint-PLAN.md`.

Ships the FR-9 + SC-8 enforcement — scans `knowledge/**/MEM*.md` for unauthorized frontmatter field additions and vocabulary drift. The authorized-field set is the union of (pre-M020 baseline fields) + (M020-authorized fields per D024). Vocabulary check enforces the MEM031 closed enum on `status:`. Two failure shapes: `unauthorized-field` and `vocabulary-drift` — both exit non-zero with a structured `FAIL:` line naming the file + field/value.

### T04: integration test (`tests/test-graduate-workflow.sh` covering SC-2)

See `tasks/T04-integration-test-PLAN.md`.

Cross-cutting end-to-end test exercising the four operational modes through `graduate.sh` directly: (1) three-entry cluster graduation with archive-back-references + decision-history on every entry; (2) single-entry cluster graduation with no archive-side-effects; (3) `--reject` rejection-path with all entries archived and no canonical; (4) cluster-membership-drift abort with zero file mutations. Also asserts JSONL records land in `.orchestrator/execution-log.jsonl` for SC-2.

## Task Dependencies

```
T01 ──→ T02 ──→ T04
              │
              ▼
T03 ──────── (T03 independent of T01/T02; can land in parallel)
```

- **T01** ships the decision-history helper (operator resolution + JSONL record shapes). No upstream dependencies beyond P01.
- **T02** extends `graduate.sh` and consumes T01's helper. Must wait for T01.
- **T03** is independent of T01/T02 — the schema-authority lint only depends on P01's MEM031 vocabulary + the existing knowledge tree shape. Can run in parallel with T01/T02.
- **T04** depends on T02 — exercises the cluster path end-to-end and asserts JSONL records emitted via T01's helper.

Auto-loop dispatch order: T01, then T02 + T03 in either order (T03 first reduces blast-radius if schema lint catches an unrelated drift early), then T04. Parallel-execution opportunity is small (T03 vs T01) and not load-bearing for the phase deadline; sequential execution is acceptable.

## Verification Commands

<!-- Cross-task invariants and phase-level rollups. Per-task verifiers
     live under each task's own ## Verification block; the commands here
     are the phase-completion gate that runs after T04 ships. Per the
     P01/P02 retrospective lesson: NEVER reference verifier scripts
     created by future tasks from inside a task's own verification
     block. Cross-task assertions belong here. -->

```
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M020/phases/P03
bash scripts/verify/m020-p03-decision-history-helper-contract.sh
bash scripts/verify/m020-p03-graduate-cluster-multi-entry.sh
bash scripts/verify/m020-p03-graduate-reject-path.sh
bash scripts/verify/m020-p03-graduate-cluster-drift-abort.sh
bash scripts/verify/m020-p03-graduate-jsonl-emit.sh
bash scripts/verify/m020-p03-graduate-p01-shape-preserved.sh
bash scripts/verify/m020-p03-schema-lint-contract.sh
bash scripts/verify/m020-p03-schema-lint-vocabulary-drift.sh
bash scripts/verify/knowledge-schema-lint.sh
bash tests/test-graduate-workflow.sh
```

All eleven commands must exit 0. The first is the must-haves rollup; the next eight are per-truth Tier-1 verifiers; the next is the schema lint run against the live tree (an asymmetric truth — the lint must pass on real knowledge); the last is the integration test.

## Files Likely Touched

- `scripts/knowledge/lib/decision-history.sh` (create)
- `scripts/knowledge/graduate.sh` (modify — extend with cluster + reject + JSONL emit; preserve P01 single-entry surface byte-equivalent per CON-4)
- `scripts/verify/knowledge-schema-lint.sh` (create)
- `tests/test-graduate-workflow.sh` (create)
- `scripts/verify/m020-p03-decision-history-helper-contract.sh` (create)
- `scripts/verify/m020-p03-graduate-cluster-multi-entry.sh` (create)
- `scripts/verify/m020-p03-graduate-reject-path.sh` (create)
- `scripts/verify/m020-p03-graduate-cluster-drift-abort.sh` (create)
- `scripts/verify/m020-p03-graduate-jsonl-emit.sh` (create)
- `scripts/verify/m020-p03-graduate-p01-shape-preserved.sh` (create)
- `scripts/verify/m020-p03-schema-lint-contract.sh` (create)
- `scripts/verify/m020-p03-schema-lint-vocabulary-drift.sh` (create)

No files under `knowledge/**` are touched by P03 task code (only by transient verifier tempdirs). No files under `.orchestrator/memory/` or [`.orchestrator/DECISIONS.md`](../../../../decisions.md) are touched (no schema evolution in P03 — schema authority work landed in P01 per D024; P03 enforces the boundary the schema authorized).

JSONL emission writes to `.orchestrator/execution-log.jsonl` at runtime, but verifier tests use isolated `ORCH_ROOT` env-var overrides so the live execution log is never touched during verification.
