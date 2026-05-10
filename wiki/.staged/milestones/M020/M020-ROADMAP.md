---
schema_version: "1.0"
type: roadmap
milestone: "M020"
feature_ref: "025-knowledge-layer-maturation"
feature_spec: "specs/025-knowledge-layer-maturation/spec.md"
vision: "Mature the knowledge layer from a flat registry into a queryable, reviewable, clusterable substrate so dispatches reason over knowledge, consolidation compresses duplicates without manual curation, and downstream milestones (M024, M019 Tier 2+3, M018) consume a stable schema contract."
tier: "C"
created_at: "2026-04-25T04:25:26Z"
updated_at: "2026-04-25T04:25:26Z"
---

## Phases

- [x] **P01**: Knowledge schema foundation + min-viable graduate.sh + Jaccard validation — "Running `bash scripts/knowledge/graduate.sh --rationale 'test' <entry-id>` flips an entry's `status:` from `candidate` to `graduated`, and `bash scripts/knowledge/lib/jaccard.sh validate knowledge/` writes a validation report at [`.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md`](../../milestones/M020/phases/P01/jaccard-validation-report.md) confirming the 0.7 threshold + CON-5 feature vector against the live knowledge tree."
  - Risk: high
  - Depends: none
  - Boundary Map:
    - Produces:
      - `scripts/knowledge/graduate.sh` (minimum-viable per A-1: `--rationale <text>` flag, single-entry candidate→graduated flip, atomic frontmatter write)
      - `scripts/knowledge/lib/jaccard.sh` (pairwise Jaccard similarity helper consumed by P05)
      - `scripts/knowledge/lib/frontmatter.sh` (atomic frontmatter read/write helper used by P03/P05; covers `status:`, `decision_history:`, `archived_into:`)
      - `knowledge/**/MEM*.md` `status:` field per FR-1 + FR-10 (incremental on-touch migration)
      - [`.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md`](../../milestones/M020/phases/P01/jaccard-validation-report.md) (threshold + feature-vector validation against live tree; may adjust 0.7 default)
      - schema-evolution note: `knowledge/conventions/MEMnnn.md` documenting the `status:` field vocabulary
    - Consumes:
      - existing `knowledge/**/MEM*.md` tree (read-only validation)
      - `.orchestrator/memory/constitution.md` (Principle VI + Principle XV gates for schema evolution)

- [x] **P02**: Query surface (US-1, FR-2 deterministic semantics) — "Running `bash scripts/knowledge/query.sh --topic <X>` against a fixture knowledge tree returns `entry_id=<ID>` lines for graduated entries matching `<X>` (case-insensitive whole-string `topic:` match OR case-folded `tags[]` membership), in rank order, with no writes to `knowledge/**`."
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces:
      - `scripts/knowledge/query.sh` (full FR-2 contract: `--topic <X>`, `--state <S>`, `--format ids|json`, deterministic semantics per spec FR-2 sub-clauses (a)–(f))
      - `scripts/dispatch/dispatch-interface.sh` query wrapper (one-line passthrough hook per OQ-4)
      - `tests/test-knowledge-query.sh` (SC-1, SC-7 fixtures + assertions)
    - Consumes:
      - P01: `status:` schema, `scripts/knowledge/lib/frontmatter.sh` for read access
      - existing dispatch dispatch-interface.sh shape (must preserve other adapter semantics byte-equivalently per CON-4)

- [x] **P03**: Candidate→graduate workflow extension + decision history + schema-authority lint — "Running `bash scripts/knowledge/graduate.sh --cluster C1 --rationale 'merge — same assertion'` against a three-entry candidate cluster flips one entry to `graduated`, two to `archived` with `archived_into:` back-references, and appends a `decision_history:` block containing rationale + ISO-8601 timestamp + operator email to all three entries; `bash scripts/verify/knowledge-schema-lint.sh` exits non-zero on a fixture introducing an unauthorized frontmatter field."
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces:
      - `scripts/knowledge/graduate.sh` extended (FR-3: `--cluster <id>`, `--rationale <text>`, `--reject` flags; atomic multi-entry write; `archived_into:` back-references)
      - `scripts/verify/knowledge-schema-lint.sh` (FR-9 + SC-8 enforcement: detects unauthorized field additions, vocabulary drift, missing required fields)
      - `scripts/knowledge/lib/decision-history.sh` (FR-7 append protocol: flow-style YAML map, operator from `git config user.email` per OQ-2 with `preferences.yml:operator_identifier` fallback)
      - `knowledge/**/MEM*.md` `decision_history:` + `archived_into:` schema additions
      - JSONL emit: `knowledge_graduate`, `knowledge_archive` records (consumed by [M019](../../milestones/M019/index.md) Tier 2+3 downstream)
      - `tests/test-graduate-workflow.sh` (SC-2 fixture + multi-entry assertions)
    - Consumes:
      - P01: `scripts/knowledge/graduate.sh` minimum-viable scaffold, `scripts/knowledge/lib/frontmatter.sh`, `status:` schema, schema-evolution note

- [x] **P04**: Review queue in `orchestrator:status` — "Running `bash scripts/orchestrator/status.sh` against a fixture knowledge tree with five candidate entries in two clusters emits a `Review Queue: 2 clusters, 5 entries` line plus a per-cluster summary (topic + count + oldest-entry-age); entries older than 14 days are flagged `(stale)`."
  - Risk: low
  - Depends: P03
  - Boundary Map:
    - Produces:
      - `scripts/orchestrator/status.sh` Review-Queue section (FR-4: cluster groups, age, default empty state, `(stale)` flag)
      - `scripts/knowledge/compute-staleness.sh` extension (default 14-day threshold per OQ-1; reads `staleness_threshold` preference if present)
      - `tests/test-status-review-queue.sh` (SC-3 fixture + empty-queue + stale-flag assertions)
    - Consumes:
      - P03: `status: candidate` vocabulary, cluster-id grouping convention, `decision_history:` for age computation

- [x] **P05**: Jaccard clustering in `orchestrator:consolidate` (US-4) — "Running `bash scripts/knowledge/consolidate-artifacts.sh --cluster` against a ten-entry candidate fixture (four near-duplicates by CON-5 feature vector at ≥0.7 similarity, six distinct) emits seven cluster IDs on stdout (one four-entry cluster + six singletons), each consumable by `graduate.sh --cluster <id>`; conflicting decision histories within a proposed cluster surface a `conflict:` diagnostic."
  - Risk: medium
  - Depends: P01, P03
  - Boundary Map:
    - Produces:
      - `scripts/knowledge/consolidate-artifacts.sh` `--cluster` flag (FR-5: pairwise Jaccard via `lib/jaccard.sh`, threshold-aware grouping, cluster-ID emission, conflict-diagnostic for divergent decision histories)
      - cluster-ID format: `C<8-hex-content-hash>` per AD-3 (deterministic across runs)
      - JSONL emit: `consolidate_cluster` record (consumed by M019 Tier 2+3)
      - `tests/test-jaccard-clustering.sh` (SC-4 fixture + conflict-diagnostic assertion)
    - Consumes:
      - P01: `scripts/knowledge/lib/jaccard.sh`, validated 0.7 threshold + CON-5 feature vector
      - P03: `graduate.sh --cluster` interface, `decision_history:` field for conflict detection

- [x] **P06**: Preferences layer (US-5, FR-6) — "Setting `similarity_threshold: 0.6` in `.orchestrator/preferences.yml` and `0.8` in `~/.orchestrator/preferences.yml`, then running `bash scripts/knowledge/consolidate-artifacts.sh --cluster`, emits `effective_threshold=0.6` on stdout (project wins); a malformed scalar falls back to default with a stderr diagnostic and does not rewrite the preferences file."
  - Risk: low
  - Depends: P02, P05
  - Boundary Map:
    - Produces:
      - `scripts/knowledge/lib/preferences.sh` (FR-6: scalar-only YAML parsing per AD-5, project>user>default precedence per-key, malformed-value fallback with stderr diagnostic)
      - preferences keys: `default_state_filter`, `similarity_threshold`, `staleness_threshold`, `preferred_cluster_size`, `operator_identifier`
      - `references/preferences.md` (FR-6 documentation: precedence rules, per-key partial-overlap behavior per DC-8 THREAT-007 disposition)
      - `tests/test-preferences-resolution.sh` (SC-5 fixture + precedence + malformed-fallback assertions)
    - Consumes:
      - P02: `scripts/knowledge/query.sh` resolves `default_state_filter` from preferences
      - P05: `scripts/knowledge/consolidate-artifacts.sh` resolves `similarity_threshold` + `preferred_cluster_size` from preferences

## Cross-Cutting Concerns

- **Schema authority enforcement (FR-9, SC-8)** — touches P01, P03, P04, P05, P06. P01 establishes the `status:` field vocabulary and schema-evolution note. P03 ships `scripts/verify/knowledge-schema-lint.sh` which all subsequent phases must pass under verify. Consuming phases that introduce frontmatter additions (P03's `decision_history:` + `archived_into:`, P05's optional cluster-membership annotations) MUST land via D-row in [`.orchestrator/DECISIONS.md`](../../decisions.md) + a corresponding schema-evolution note appended in P01's convention entry.

- **Read-only-during-dispatch invariant (FR-8, CON-1)** — touches P02, P05, P06. P02 establishes the contract: query surface is side-effect-free. P05's clustering wires into operator-invoked `consolidate-artifacts.sh --cluster` (NOT dispatch-invoked), preserving the boundary. P06's preferences layer is read by P02 + P05 with no write-back; preferences file is operator-owned. SC-7 (`git status knowledge/` clean post-dispatch) is the regression gate.

- **Atomic frontmatter writes** — touches P01, P03, P05. P01's `lib/frontmatter.sh` establishes the atomic-write pattern (temp-file + rename, or in-place with content-hash invariant per MEM005). P03's `decision_history:` append and `archived_into:` back-reference write must be atomic across all entries in a cluster (partial application is a corruption mode). P05's clustering is read-only — only emits cluster IDs, never writes frontmatter.

- **JSONL observability emissions** — touches P03, P05. Both phases emit M019 Tier 1 records via the existing emitter (`scripts/observability/emit.sh` or equivalent). Record shapes: `knowledge_graduate {entry_id, cluster_id, rationale_hash}`, `knowledge_archive {entry_id, archived_into, rationale_hash}`, `consolidate_cluster {cluster_id, member_ids[], threshold_used, conflict_flag}`. M019 Tier 2+3 (downstream) consumes these without coordination.

- **Cluster state consistency (DC-8 THREAT-006)** — touches P03, P05. P03's `graduate.sh --cluster <id>` MUST re-read each member entry's current `status:` at graduate-time (not at cluster-time) and abort with a clear `cluster-membership-drift` diagnostic if any member has changed state since clustering. P05's clustering output declares membership; P03's graduation enforces it. Avoids the temporal staleness hole the conversus gate identified.

- **Operator identity resolution (OQ-2)** — touches P03, P06. P03's `lib/decision-history.sh` resolves operator identity at write time: first try `git config user.email`, then fall back to `preferences.yml:operator_identifier` if explicitly set, then fall back to `unknown@local`. P06's preferences layer surfaces `operator_identifier` as an explicit override key.

## Dependency Graph

```
                   ┌──→ P02 ──────────────────┐
                   │                          │
P01 ───────────────┼──→ P03 ──┬──→ P04        ├──→ P06
  (foundation)     │          │               │
                   │          └──→ P05 ───────┘
                   │                ↑
                   └────────────────┘
                   (jaccard.sh + thresholds)
```

Edges:
- P01 → P02 (status: schema, frontmatter lib)
- P01 → P03 (graduate.sh scaffold, frontmatter lib, status: schema)
- P01 → P05 (jaccard.sh, validated thresholds)
- P03 → P04 (candidate vocabulary, cluster-id grouping)
- P03 → P05 (graduate.sh --cluster interface, decision_history: for conflicts)
- P02 → P06 (query surface honors default_state_filter)
- P05 → P06 (clustering honors similarity_threshold, preferred_cluster_size)

## Execution Order

1. **P01** — foundation, no dependencies. High risk, ships first regardless. Establishes schema vocabulary + minimum-viable graduate.sh per A-1 + validates Jaccard defaults against live knowledge tree.
2. **P02 + P03 — can execute concurrently** — both depend only on P01. Both high risk; P02 unblocks [M024](../../milestones/M024/index.md) query-surface dependency, P03 ships the schema-authority lint that all subsequent phases verify against. Parallel execution maximizes throughput on the critical path.
3. **P04 + P05 — can execute concurrently** — P04 depends only on P03 (low risk; status surface read-only). P05 depends on P01 + P03 (medium risk; clustering wired into consolidate). Both can land once P03 is verified.
4. **P06** — depends on P02 + P05. Low risk; preferences layer reads from query surface and clustering. Lands last.

Concurrency notes:
- The two-pair parallel structure (P02‖P03 then P04‖P05) lets autonomous dispatch keep two phases active most of the milestone.
- P06 is single-threaded at the tail because both upstream consumers must be stable before preference resolution can be exercised end-to-end.

## Validation

- **No conflicting producers**: PASS. Each artifact appears in exactly one phase's `Produces`. `scripts/knowledge/graduate.sh` is split cleanly: P01 ships the minimum-viable scaffold (`--rationale` only, single-entry); P03 extends in-place with `--cluster`, `--reject`, multi-entry atomicity. The extension is additive (no signature break), and the boundary is documented in P03's `Produces`. `scripts/knowledge/consolidate-artifacts.sh` exists pre-M020 and gains the `--cluster` flag in P05; this is an additive extension, not a re-creation.
- **All consumed items have producers**: PASS. P02 consumes P01 (status: schema, frontmatter lib) ✓. P03 consumes P01 (graduate.sh scaffold, frontmatter lib, status: schema) ✓. P04 consumes P03 (candidate vocabulary, cluster-id grouping) ✓. P05 consumes P01 (jaccard.sh, validated thresholds) ✓ + P03 (graduate.sh --cluster interface, decision_history:) ✓. P06 consumes P02 (query surface) ✓ + P05 (consolidate-artifacts.sh --cluster) ✓.
- **DAG is acyclic**: PASS. Topological order P01 → {P02, P03} → {P04, P05} → P06. No back-edges. Verified by inspection of the dependency graph.
- **Demo sentence coverage**: PASS. Each phase's demo sentence names a concrete shell command + observable assertion (file written, stdout pattern, exit code, frontmatter mutation). No vague "the system supports X" prose. Demo sentences map directly to the spec's SC-1..SC-8 (P01→part of SC-2/SC-6, P02→SC-1/SC-7, P03→SC-2/SC-6/SC-8, P04→SC-3, P05→SC-4, P06→SC-5).

## Notes

- **Conversus gate dispositions folded in**: M020-CONTEXT.md DC-8 records the disposition of THREAT-004 (queue growth, ACCEPTED with revisit trigger), THREAT-005 (query scalability, ACCEPTED with M019 Tier 2+3 trigger), THREAT-006 (cluster staleness, MITIGATED in P03/P05 cross-cutting concern), and THREAT-007 (preferences cascade, ACCEPTED with documentation in P06). No phase scope changes required beyond the cross-cutting concerns above.
- **Pre-M020 minimum-viable subset**: A-1 in spec assumed `graduate.sh` minimum-viable + `decision_history:` scaffolding were live before M020 planning. Verification at roadmap time shows neither is live (`scripts/knowledge/` does not contain `graduate.sh`). Per A-1's fallback clause, that scope is absorbed into P01.
- **Spec amendments landed during discuss**: FR-2 was rewritten with deterministic semantics (closes MIT-002), FR-5 was amended to defer to CON-5 (closes MIT-001), SC-1 was extended with `--format json` assertions. See `M020-CONTEXT.md` Operator Resolutions section for full audit trail.
