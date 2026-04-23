---
schema_version: "1.0"
type: feature-spec
feature_slug: "025-knowledge-layer-maturation"
created_at: "2026-04-23"
status: "Ready-for-discuss-gate-deferred"
milestone: "M020"
last_revised: "2026-04-23"
---

# Feature Specification: 025-knowledge-layer-maturation

**Feature Branch**: `025-knowledge-layer-maturation`
**Created**: 2026-04-23
**Status**: Ready-for-discuss-gate-deferred
**Milestone**: M020
**Last Revised**: 2026-04-23
**Input**: User description: "Mature the knowledge layer from a flat registry into a reviewable, queryable, clusterable substrate so dispatches can reason over knowledge and consolidation can compress duplicates without manual curation. M012 shipped cross-refs from specs to knowledge entries but left three affordances on the table (review/unreviewed state model, query/search surface callable from dispatches, A6 Jaccard clustering in consolidate) per the D011 evaluation — M020 closes all three. Scope: full A1 preferences layer (explicit user/project preference surface with precedence rules), full A2 candidate→graduate workflow extending the minimal graduate.sh guard already shipped (clustering into staging layer, review queue UI, decision history), A3 review queue surfaced in orchestrator:status, A6 Jaccard clustering in consolidate so near-duplicate knowledge entries cluster before graduation, and a dispatch-callable query/search surface (shape pinned at plan-phase: exact-match, semantic, or hybrid) that other commands invoke to resolve knowledge before payload assembly. M020 holds schema authority over knowledge/spec/** per the M013 Knowledge-Layer Boundary — any schema evolution (chunk-ID format changes, new frontmatter fields, review-state vocabulary) lands here, not in consuming milestones. Positioned before M024 so the universal intake router reasons over mature knowledge rather than raw registry dumps. Non-goals: no replacement of the file-on-disk-is-truth invariant; no knowledge mutation during dispatch (dispatches read-only); no retroactive migration of pre-M020 chunks beyond what the schema evolution strictly requires; A4 session-start file-loading manifest is out of scope (shipped independently pre-M020 per D013)."

## Problem Statement

The orchestrator's knowledge layer today is a flat registry — markdown files under `knowledge/spec/**` and `knowledge/**/MEM*.md` with stable IDs, discoverable via grep or direct filename. M012 shipped the wiki surface that cross-references specs to knowledge entries via include-markdown, but the registry itself is inert: every entry looks equivalent, every lookup is a full scan, every consolidation decision is a manual curation call, and dispatches that want to reason over knowledge have no callable surface — they either inline the whole registry (wasteful) or resolve by bespoke grep (brittle).

Three concrete pain-points follow from the flat-registry shape. **First**, consolidation at milestone boundaries is a pure human-judgment exercise: the operator reads every entry that accumulated during the milestone, decides which are duplicates, and manually merges. With 25+ entries per milestone this scales poorly and the rubber-stamping failure mode (D011) is live. **Second**, there is no protocol for an entry to be *tentative*: something a dispatch learned that should be available to future dispatches but has not yet earned permanent status. Every accepted entry is indistinguishable from every other, so the accumulated graduation costs are paid eagerly on every entry or (more commonly) not at all. **Third**, dispatches that want to resolve "did we learn anything about X?" before composing their payload have no query surface — they either read every entry (bloats context in violation of Principle I) or don't ask (which wastes the accumulated knowledge in violation of Principle VII).

The minimum surface that fixes all three is: a **review-state vocabulary** (candidate / graduated / archived) carried in every entry's frontmatter; a **candidate→graduate workflow** with clustering so near-duplicates are proposed together, explicit rationale, and decision history; a **query surface** callable from dispatches that resolves knowledge by topic + state filter without streaming every file; and a **preferences layer** that lets the operator tune resolution behavior per-user and per-project. M020 delivers all four as a single milestone, holding schema authority so downstream milestones (M024 universal intake router, M019 Tier 2+3 metrics) consume a stable contract.

This feature explicitly does not attempt: replacing the file-on-disk-is-truth invariant (Principle VI), enabling knowledge mutation during dispatch (dispatches remain read-only), retroactive migration of pre-M020 entries beyond what schema evolution strictly requires, or shipping the A4 session-start file-loading manifest (independent concern, already shipped per D013).

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 Load-Bearing Scope)

The smallest coherent subset whose shipment closes the dogfood loop: **US-1 (query surface) + US-2 (candidate→graduate workflow) + US-3 (review queue in status)**. Together they deliver an end-to-end path where a dispatch writes candidate knowledge, the operator sees the candidate in `orchestrator:status`, reviews it, runs the graduate workflow (clustering + rationale), and future dispatches resolve the graduated entry via the query surface. Every subsequent phase's scope is defended on top of this slice. US-4 (Jaccard clustering in consolidate) and US-5 (preferences layer) depend on the slice and layer on afterward.

### User Story 1 — Dispatch-callable knowledge query surface (Priority: P1)

A dispatch composing its payload asks the orchestrator "what do we know about authentication flow?" and receives a structured result containing the relevant graduated knowledge entries (IDs, titles, review state, relevance rank) without streaming the full registry into the dispatch's context.

**Why this priority**: every other story in this spec is consumed through this surface. The query API is the contract that makes the other affordances legible to the rest of the orchestrator. Without it, clustering and review-state are invisible to dispatches — they exist but don't compound (violating Principle VII). M024 universal intake routing depends on this surface specifically; deferring it blocks M024.

**Independent Test**: run a dispatch that invokes the query surface with a known-topic query against a fixture knowledge tree; assert the returned result set contains the fixture's graduated entries matching the topic, excludes candidate + archived entries by default, and honors an explicit `--state` filter.

**Acceptance Scenarios**:

1. **Given** a knowledge tree with three graduated entries on topic X and two candidate entries on topic X, **When** a dispatch invokes the query surface with `topic=X` and default state filter, **Then** only the three graduated entries are returned with IDs + titles + relevance ranks.
2. **Given** the same knowledge tree, **When** the query surface is invoked with `topic=X state=candidate`, **Then** only the two candidate entries are returned.
3. **Given** a query with no matching entries, **When** the surface is invoked, **Then** an empty structured result is returned (not an error) with a `no-matches` diagnostic field.

### User Story 2 — Candidate→graduate review workflow (Priority: P1)

An operator running `orchestrator:consolidate` at milestone close sees a staging layer of candidate knowledge entries clustered by topic similarity. For each cluster the operator invokes `scripts/knowledge/graduate.sh --rationale "..." --cluster <id>` and the cluster is either graduated (one canonical entry kept, sibling entries marked archived with back-references) or rejected (all entries marked archived with a rejection rationale). A decision-history record is appended to each affected entry's frontmatter.

**Why this priority**: this is the anti-rubber-stamping guard identified in D011. Without it, consolidation remains a human-judgment bottleneck that scales poorly and fails silently when the operator skips review. The minimal `graduate.sh` guard shipped pre-M020 (per D011's minimum-viable subset) proves the pattern; this story extends it from one-entry-at-a-time to cluster-at-a-time with staging + history.

**Independent Test**: run `scripts/knowledge/graduate.sh --rationale <text> --cluster <id>` against a fixture with a three-entry cluster; assert the canonical entry's `status` flips to `graduated`, sibling entries flip to `archived` with back-references, and each entry's frontmatter gains a `decision_history:` block containing the rationale + timestamp + operator identifier.

**Acceptance Scenarios**:

1. **Given** a cluster of three candidate entries on the same topic, **When** the operator invokes `graduate.sh --rationale "merge — same assertion" --cluster C1`, **Then** one entry becomes `status: graduated`, the other two become `status: archived` with `archived_into: <canonical-id>` frontmatter fields, and all three gain a `decision_history:` entry with rationale + timestamp.
2. **Given** a single-entry cluster (no siblings), **When** the operator invokes `graduate.sh --rationale <text> --cluster C2`, **Then** the entry flips to `graduated` and gains the decision-history entry with no archive-side-effects.
3. **Given** a cluster the operator rejects outright, **When** the operator invokes `graduate.sh --reject --rationale "superseded by M021" --cluster C3`, **Then** all entries in the cluster flip to `archived` with the rejection rationale in their decision history.

### User Story 3 — Review queue in orchestrator:status (Priority: P1)

An operator running `orchestrator:status` sees a review-queue section listing candidate knowledge entries awaiting review, grouped by cluster when applicable, with enough context (topic, originating milestone, age) to decide whether to review now or defer.

**Why this priority**: the review workflow is only load-bearing if the operator is nudged to use it. Hiding the queue behind a separate command means the rubber-stamping failure mode reappears — an out-of-sight queue grows until consolidation becomes a cliff. Surfacing it in the default-run status output makes the queue part of the operator's regular decision loop.

**Independent Test**: run `orchestrator:status` against a fixture with five candidate entries in two clusters; assert the output contains a `Review Queue:` section with the two clusters' topic summaries + entry counts + age, and excludes graduated / archived entries.

**Acceptance Scenarios**:

1. **Given** a knowledge tree with five candidates in two clusters and ten graduated entries, **When** the operator runs `orchestrator:status`, **Then** the output includes `Review Queue: 2 clusters, 5 entries awaiting review` with a two-line-per-cluster summary (topic + count + oldest-entry-age).
2. **Given** an empty review queue (no candidate entries), **When** the operator runs `orchestrator:status`, **Then** the output includes `Review Queue: empty` and no further review-section prose.
3. **Given** a review queue with entries older than a configured threshold (default 14 days), **When** the operator runs `orchestrator:status`, **Then** the stale entries are flagged with a `(stale)` marker.

### User Story 4 — Jaccard clustering during consolidate (Priority: P2)

An operator running `orchestrator:consolidate` at milestone close sees that the consolidate command has already pre-clustered similar candidate entries using Jaccard similarity, so the review step lands on coherent clusters rather than a flat entry list.

**Why this priority**: clustering makes the review workflow (US-2) scalable, but the review workflow itself is load-bearing without automated clustering — the operator can cluster by hand for the first milestone or two. Deferring clustering to P2 means US-1/US-2/US-3 can ship and be validated before tuning Jaccard threshold + feature vector shape.

**Independent Test**: run `orchestrator:consolidate --cluster` against a fixture of ten candidate entries where four are near-duplicates of each other and six are distinct; assert the consolidate output proposes one four-entry cluster and six single-entry clusters.

**Acceptance Scenarios**:

1. **Given** ten candidate entries where four share ≥70% Jaccard similarity on a configured feature vector, **When** the operator runs `orchestrator:consolidate --cluster`, **Then** the command outputs one four-entry cluster + six single-entry clusters, each with cluster IDs consumable by `graduate.sh`.
2. **Given** entries that cluster above threshold but have conflicting `decision_history` (one previously graduated, one previously rejected), **When** the operator runs `--cluster`, **Then** the cluster is surfaced with a `conflict:` diagnostic so the operator reviews manually.

### User Story 5 — Preferences layer with precedence rules (Priority: P2)

An operator declares explicit preferences (user-level at `~/.orchestrator/preferences.yml`, project-level at `.orchestrator/preferences.yml`) that tune knowledge resolution behavior — default state filter, similarity threshold, staleness threshold, preferred cluster size — and the query surface + consolidate command honor them with project-level winning over user-level where both are declared.

**Why this priority**: preferences are an ergonomics layer on top of the minimum-viable contract. Without them the query surface still works (it uses defaults); with them, teams with different tastes can tune behavior without editing orchestrator internals.

**Independent Test**: set a project-level preference overriding a user-level preference (e.g., `similarity_threshold: 0.6` at project, `0.8` at user); invoke the query surface; assert the effective threshold resolved to 0.6.

**Acceptance Scenarios**:

1. **Given** a user-level preferences file with `similarity_threshold: 0.8` and no project-level file, **When** the query surface resolves the threshold, **Then** 0.8 is used.
2. **Given** both a user-level and a project-level preferences file with different thresholds, **When** the query surface resolves the threshold, **Then** the project-level value wins.
3. **Given** a preferences file with a malformed scalar (non-numeric threshold), **When** the query surface resolves the threshold, **Then** the built-in default is used and a one-line diagnostic is emitted to stderr.

---

## Edge Cases

- **Candidate entry with no cluster assignment**: a candidate written by a dispatch before the clustering run sits in a one-entry "cluster of itself" in the review queue; `graduate.sh` treats it as a single-entry cluster per US-2 scenario 2.
- **Query surface called before any graduated entries exist**: returns an empty structured result with `no-matches` diagnostic (US-1 scenario 3); does not error.
- **Two concurrent dispatches write candidates about the same topic**: both land as distinct candidates; clustering happens at next consolidate run; no locking at write time (read-only-during-dispatch invariant preserved).
- **Operator archives an entry already referenced by a live spec's cross-ref**: the archive operation updates `archived_into:` if a canonical replacement exists; if archived outright (rejection), the cross-ref still resolves (files-on-disk) but emits a `referenced-archived` diagnostic during next `orchestrator:status`.
- **Preferences file declares a threshold outside the valid range** (e.g., `similarity_threshold: 1.5`): built-in default is used, diagnostic emitted; config is not rewritten (operator's file is theirs to edit).
- **Clustering run against a knowledge tree with a pre-M020 entry** (no `status:` frontmatter): entry is treated as `graduated` by default (most conservative — don't re-review what was already implicitly trusted); schema-evolution migration writes `status: graduated` into the frontmatter on first touch.

---

## Functional Requirements

- **FR-1 (review-state-vocabulary)**: Every knowledge entry carries a `status:` frontmatter field with one of `{candidate, graduated, archived}`. Pre-M020 entries are treated as `graduated` on first read; migration writes the field at next touch. Satisfies US-1 + US-2 + US-3.
- **FR-2 (query-surface)**: A dispatch-callable query surface resolves `topic=<X> [state=<S>]` via exact-match + topic-keyword-index into a structured result containing matching entries' IDs, titles, review states, and relevance ranks — without streaming the full registry into the caller's context. Semantic/hybrid resolution is deferred unless M024 routing demonstrates real need (CON-3). Satisfies US-1.
- **FR-3 (graduate-workflow)**: `scripts/knowledge/graduate.sh` extends the pre-M020 minimal guard to accept `--cluster <id>` + `--rationale <text>` [+ `--reject`], flipping entry states + writing back-references + appending decision-history entries atomically. Satisfies US-2.
- **FR-4 (review-queue-surface)**: `orchestrator:status` emits a `Review Queue:` section listing candidate clusters with topic summaries, entry counts, and oldest-entry age; flags entries older than a configured staleness threshold. Satisfies US-3.
- **FR-5 (jaccard-clustering)**: `orchestrator:consolidate --cluster` computes pairwise Jaccard similarity on a configured feature vector (topic keywords + frontmatter fields) and proposes clusters at or above a configurable threshold; emits cluster IDs consumable by `graduate.sh`. Satisfies US-4.
- **FR-6 (preferences-layer)**: User-level (`~/.orchestrator/preferences.yml`) and project-level (`.orchestrator/preferences.yml`) preferences tune query + consolidate behavior (default state filter, similarity threshold, staleness threshold, preferred cluster size); project-level wins over user-level; malformed values fall back to built-in defaults with a stderr diagnostic. Satisfies US-5.
- **FR-7 (decision-history)**: Every graduate or archive operation appends a `decision_history:` entry to each affected entry's frontmatter containing `{rationale, timestamp, operator, cluster_id}`. History is append-only; no compaction in M020 (see Open Question Q-5). Satisfies US-2 + US-4.
- **FR-8 (read-only-during-dispatch)**: The query surface is side-effect-free: no writes to knowledge/**, no `decision_history:` updates, no frontmatter mutations. All mutations happen through `graduate.sh` or `orchestrator:consolidate`, both of which are operator-invoked (not dispatch-invoked). Preserves Principle VI and the dispatch-read-only invariant.
- **FR-9 (schema-authority)**: M020 holds exclusive schema authority over `knowledge/spec/**` and `knowledge/**/MEM*.md` frontmatter. Any new field, renamed field, or vocabulary change (e.g., adding a fourth state) lands via a D-row + a schema-evolution note in M020 consolidation. Consuming milestones (M024, M019 Tier 2+3) may READ any field M020 exposes but MUST NOT introduce fields without a D-row authorizing the extension. Satisfies the M013 Knowledge-Layer Boundary clause.
- **FR-10 (graceful-migration)**: Pre-M020 entries without `status:` frontmatter are treated as `graduated` on first read and the field is written on next touch. No bulk migration pass; schema evolution is incremental.

## Success Criteria

- **SC-1**: `bash scripts/knowledge/query.sh --topic <X>` against a fixture with three graduated + two candidate entries on topic X returns exactly the three graduated entries; exit 0; stdout matches `^entry_id=<ID>$` lines only for graduated entries. (US-1, FR-2, FR-8)
- **SC-2**: `bash scripts/knowledge/graduate.sh --rationale "test" --cluster C1` against a three-entry candidate cluster fixture flips one entry to `status: graduated` and two to `status: archived` with `archived_into:` pointers; all three gain a `decision_history:` block; exit 0. (US-2, FR-3, FR-7)
- **SC-3**: `bash scripts/status/status.sh` against a fixture with five candidates in two clusters emits a line matching `^Review Queue: 2 clusters, 5 entries` on stdout; exit 0. (US-3, FR-4)
- **SC-4**: `bash scripts/consolidate/consolidate.sh --cluster` against a ten-entry fixture (four near-duplicates, six distinct) outputs seven cluster IDs on stdout (one four-entry cluster + six singletons); exit 0. (US-4, FR-5)
- **SC-5**: Setting `similarity_threshold: 0.6` in a fixture project preferences file and `0.8` in the user preferences file, then invoking `orchestrator:consolidate --cluster`, produces clusters computed at threshold 0.6 (project wins). Assertion: stdout contains `effective_threshold=0.6`. (US-5, FR-6)
- **SC-6**: Every entry modified during M020 execution gains or preserves a `status:` frontmatter field; `grep -L 'status:' knowledge/**/MEM*.md` returns an empty list after the M020 dogfood consolidation run. (FR-1, FR-10)
- **SC-7**: A dispatch-payload-assembly run invoking `query.sh` emits zero writes to `knowledge/**`; `git status knowledge/` reports a clean tree post-dispatch. (FR-8)
- **SC-8**: Attempting to introduce a new frontmatter field from a consuming milestone (simulated with a test fixture) triggers a schema-authority violation diagnostic from `scripts/verify/knowledge-schema-lint.sh`. (FR-9)

## Non-Goals

- **NG-1**: M020 does NOT replace file-on-disk-is-truth (Principle VI). All query surface reads hit the filesystem; no in-memory caches across sessions.
- **NG-2**: M020 does NOT enable knowledge mutation during dispatch. Dispatches remain read-only consumers of the query surface.
- **NG-3**: M020 does NOT perform retroactive bulk migration of pre-M020 entries. Migration is incremental (FR-10); entries gain `status:` on next touch, not via a one-shot pass.
- **NG-4**: M020 does NOT ship the A4 session-start file-loading manifest. Out-of-scope per D013; shipped independently.
- **NG-5**: M020 does NOT ship a graphical review queue UI. The `orchestrator:status` text surface is the UX (FR-4); a richer interface is deferred until usage warrants it.
- **NG-6**: M020 does NOT implement decision-history compaction. History is append-only in M020; compaction is an independent concern (Open Question Q-5).

## Constraints

- **CON-1 (read-only-during-dispatch)**: The query surface MUST be side-effect-free (FR-8). Any mutation path — graduate, archive, cluster — is operator-invoked, not dispatch-invoked. This preserves the M015 dispatch isolation invariant and Principle VI.
- **CON-2 (principle-i-context-budget)**: The query surface result shape MUST return entry metadata (IDs, titles, state, rank) rather than full entry bodies. Callers that need the body fetch it separately via a standard file read. This preserves Principle I's context budget for dispatches.
- **CON-3 (principle-xiv-no-speculative-complexity)**: The query-surface shape pinned at plan-phase (Q-1) MUST NOT commit to semantic or hybrid resolution without dogfood evidence that exact-match is insufficient. Start with exact-match + topic-keyword index; escalate only if M024 routing demonstrates real need.
- **CON-4 (principle-xv-surgical-precision)**: Frontmatter-schema changes landed in M020 MUST preserve byte-equivalence for fields not explicitly listed in the schema-evolution note. Unrelated adjacent edits are out of scope.
- **CON-5 (jaccard-feature-vector-bounded)**: The Jaccard clustering feature vector IS: frontmatter `title` + `topic` + `tags[]` keys plus first-paragraph content-words capped at 50 tokens. Full-body tokenization remains out of scope in M020 (revisit in M018 once context-compression lands).

### Knowledge-Layer Boundary (M020 vs. M013/M024)

M020 holds exclusive schema authority over `knowledge/spec/**` and `knowledge/**/MEM*.md` frontmatter. Consuming milestones interact with the knowledge layer as READERS only:

- **M013 (GitHub native integration)** already writes spec cross-refs via include-markdown; M020 preserves that surface byte-equivalently. M013 MUST NOT add new frontmatter fields without an M020 D-row.
- **M024 (universal intake & routing)** consumes the query surface (FR-2) to resolve "has this been specified before?" lookups; MUST NOT introduce new entry types or review-state vocabulary.
- **M019 Tier 2+3 (observability)** reads entry metadata (state, age, decision-history length) for metrics rollups; MUST NOT write to entries.

Any knowledge-schema change from a consuming milestone is a scope violation (FR-9 + SC-8). If a consuming milestone discovers it needs a new field, the handshake is: open an M020 D-row → M020 lands the schema change in a follow-up phase → consuming milestone uses the field.

## Assumptions

- **A-1**: The pre-M020 minimum-viable subset (`graduate.sh` minimal guard + `decision_history:` scaffolding) is live on main before M020 planning begins. If it is not, scope absorbs the scaffolding into M020/P01. Per D013.
- **A-2**: M019 Tier 1 emitter is live, so M020 consolidation runs produce measurable before/after metrics on review-queue size + decision-history growth. Per D016 sequence.
- **A-3**: No external dependency on semantic embeddings in M020. Exact-match + topic-keyword-index is sufficient for Minimal Slice; semantic/hybrid escalation is deferred to a follow-up milestone if dogfooding demonstrates need (CON-3).
- **A-4**: The operator running `orchestrator:consolidate` has write access to the knowledge tree. Read-only operators cannot graduate; the query surface and review-queue surface remain available to them.
- **A-5 (jaccard-threshold-default)**: Default Jaccard similarity threshold is 0.7. Validation against the live `knowledge/**/MEM*.md` tree occurs at M020/P01 kickoff; threshold is operator-tunable via FR-6 preferences.

## Constitution Check

- **Principle I (Context Minimization)**: The query surface returns metadata-only results (CON-2), not full entry bodies, so dispatches consuming knowledge do not bloat their context budget. Pre-M020 behavior (full-registry inline or bespoke grep) both violated this; M020 is the fix.
- **Principle II (Evidence Before Claims)**: Every SC- above pins a mechanical command + exit code + stdout assertion. No "should work" language. Schema-evolution verifier (`scripts/verify/knowledge-schema-lint.sh`, SC-8) is the evidence gate for FR-9's schema authority.
- **Principle III (Design Before Code)**: Query-surface shape pinning is explicitly deferred to plan-phase (Q-1) — surfaced as an Open Question rather than guessed. Jaccard threshold + feature vector shape similarly deferred (Q-2, Q-3). Load-bearing ambiguity is enumerated, not hidden.
- **Principle VI (State On Disk Is Truth)**: FR-8 preserves this invariant — no cross-session in-memory state, all mutations persist to frontmatter, query surface reads from disk on every call.
- **Principle VII (Knowledge Compounds)**: The whole milestone exists to enforce this. Pre-M020 knowledge accumulated but did not compound (flat registry = no leverage). M020 adds the review/query/cluster loop so accumulation and compounding are the same motion.
- **Principle XIV (No Speculative Complexity)**: CON-3 bounds the query surface to exact-match + topic-keyword-index unless dogfood evidence demands more. NG-5 bounds the review UI to text. NG-6 defers decision-history compaction. No speculative scope creep.
- **Principle XV (Surgical Precision)**: CON-4 bounds frontmatter-schema changes to only fields named in the schema-evolution note. FR-9 bounds schema authority to M020 exclusively, preventing scope bleed from consuming milestones.

## Open Questions (defer to planning)

> **Pre-discuss pressure-test gate status**: the M014/P01 `orchestrator:specify`
> adversarial gate (`templates/conversus-presets/spec-pressure-test.yml`) is
> deferred for this spec pending resolution of two upstream conversus bugs
> captured in `conversus/PRESSURE-TEST-FINDINGS.md` (remediation brief in
> `conversus/CONVERSUS-PR-HANDOFF.md`). The orchestrator-side shim is verified
> green (`tests/test-conversus-adapter-shim.sh`). Per D019, a Full-intensity
> `orchestrator:specify` run normally treats BLOCK as halting; this spec
> proceeds to `orchestrator:discuss` under the infrastructure-blocked exception
> and re-runs the gate against the final body once the conversus PRs land.

## Dependencies

- **M012 (closed)** — spec wiki with cross-refs to `knowledge/**/MEM*.md` via include-markdown. Contract M020 preserves byte-equivalently (Knowledge-Layer Boundary).
- **M019 Tier 1 (closed)** — observability emitter. M020 consolidation runs produce `consolidate_cluster`, `knowledge_graduate`, `knowledge_archive` JSONL records consumable by M019's rollup (Tier 2+3, downstream).
- **M021 (closed)** — autonomous hardening v2 (shape-guard hook). M020's `graduate.sh` + `consolidate` invocations must pass shape-guard without workarounds; relevant AP-* entries honored.
- **Pre-M020 minimum-viable subset (independent)** — `graduate.sh` minimal guard + `decision_history:` scaffolding + A4 session-start manifest. Per D011/D013, ships before M020 kickoff; M020 extends the guard, does not reinvent it (A-1).

## Downstream Consumers (informational, not binding)

- **M024 (universal intake & routing)** — consumes FR-2 query surface for "has this been specified before?" lookups in the routing proposal. Schema-authority boundary holds: M024 reads, does not extend.
- **M019 Tier 2+3 (observability rollup)** — reads entry metadata (state, age, decision-history length) for milestone-level metrics (review-queue throughput, graduate-reject ratio, cluster-size distribution).
- **M018 (context compression)** — may consume query surface to identify which knowledge entries are hot (frequently queried) vs. cold (archived), informing compression-tier decisions per M018/P01 tier grammar. Not binding; M018 can ship without M020 hot/cold signals.
- **M009 (launch)** — runtime-parity audit consumes M020 artifacts to confirm CC / Codex / Cursor all read the same schema. No M009 dependency on M020 features beyond schema stability.
