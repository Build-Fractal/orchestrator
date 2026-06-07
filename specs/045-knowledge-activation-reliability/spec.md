---
schema_version: "1.0"
type: feature-spec
feature_slug: "045-knowledge-activation-reliability"
created_at: "2026-06-07"
status: "Draft"
milestone: "M044"
---

# Feature Specification: 045-knowledge-activation-reliability

**Feature Branch**: `045-knowledge-activation-reliability`
**Created**: 2026-06-07
**Status**: Draft
**Milestone**: M044
**Input**: User description: "Harden the orchestrator knowledge-activation pipeline so it can never silently degrade, and close the capture-store-inject loop. Proven, file:line-verified upstream bugs: rebuild-index.sh:117 aborts the whole rebuild on one heading-less entry (unguarded grep under set -e/pipefail); build-context.sh:208 then silently injects first-5 off the empty index; append-decision.sh:93 writes a column order scope-filter.sh cannot parse; the bare archive skip-glob zeroes the index for any project rooted under a dir named archive; the compression filter drops flat hash-K knowledge; Quick intensity captures nothing and the Quick inject drops Decisions; decisions land in runtime memory the injector never reads (0-MEM injects, no warning). P0 fix: unify producer/consumer formats with a round-trip test; per-entry skip-and-warn rebuild; scope the archive glob; consumers fall back to deterministic grep over raw files with a provenance/freshness header; capture decisions regardless of intensity; declare .orchestrator the system of record; 0-MEM-inject warning plus a consolidated doctor check. Principles: silent degradation is the enemy (fail loud); index is a cache, raw corpus is truth, guarantee runs index-free; one system of record and the happy path must work."

> **Provenance.** This spec is authored from the conversus-validated upstream brief `.orchestrator/proposals/knowledge-activation-reliability.md` (consolidated 2026-06-06 from three independent downstream diagnoses, ground-truthed against live upstream source). The brief's eight design questions (DQ-1…DQ-8) were resolved in a 16-agent cooperative conversus deliberation (0 rejections; record at `.orchestrator/conversus/knowledge-activation/summary/final.md`). **Those resolutions are binding inputs to this spec — they are recorded in Constraints, not re-opened.** This spec scopes the **P0 hotfix slice** (proven, actively-burning bugs); the P1 / M040-track activation-build items are forward-pointed under Non-Goals and Downstream Consumers.

## Problem Statement

The orchestrator's central promise is that the agent always acts with the full stored context — decisions, SME feedback, and learnings are reliably activated when work happens. In practice that promise is **silently hollow** along the entire pipeline. On two independent production projects the knowledge base stopped activating for roughly a month / two full milestones, every dispatch resolved to **0 MEMs**, and **nobody was told**. An agent that *knows* it is under-informed behaves correctly; one that is *silently* under-informed produces confident, wrong work — so a silent activation failure is the most expensive failure mode the framework has.

Three concrete pain-points follow from the gap, each traced to a proven, file:line-verified defect. (1) **The rebuild fails closed-silent.** `scripts/knowledge/rebuild-index.sh` runs under `set -euo pipefail` (`:11`); its description-extraction grep at `:117` is unguarded (the sibling `fm_field()` at `:40` ends in `|| true`), so one heading-less entry aborts the entire rebuild mid-loop — zero output, exit 1, ~146 chunks left unindexed. (2) **The consumer then fails open-silent.** With an empty index, `scripts/dispatch/build-context.sh` (`:198–208`) silently falls back to "first-5 MEM IDs" with no warning and no provenance — the command operators use *specifically to guarantee context* injects near-nothing and says nothing. (3) **The official capture command produces rows the injector cannot read.** `append-decision.sh:93` writes a `| ID | When | Scope | … |` column order, but `scope-filter.sh`'s `filter_decisions` `awk -F'|'` reads `scope_col=$5` / `when_col=$6` (`:353-354`) — the leading pipe shifts every field by one, so the scope match silently never fires. Two further defects compound the class: a bare `*/archive/*` skip-glob (`resolve-entries.sh:45`, `rebuild-index.sh:74`) zeroes the index for any project rooted under a directory named `archive`; and the compression filter (`kf_filter_stream`) drops every flat `## K###` knowledge entry because it only passes frontmatter-bearing chunks. Underneath all five: there is **no fail-loud signal anywhere** — no inject-size surface, no 0-MEM warning, no provenance header — so degradation produces no observable trace.

The minimum surface that fixes all three pain-points is a **fail-loud, index-free-capable activation floor**: a producer/consumer format unified by a round-trip test that is the acceptance oracle; a per-entry skip-and-warn rebuild that survives malformed entries; consumers that fall back to deterministic grep over the raw corpus and stamp every payload with a knowledge-provenance header; capture that lands a readable, indexed decision regardless of intensity; and a 0-MEM-on-mature-project alarm plus a single consolidated doctor check. The guiding principles, drawn from the brief, are: **silent degradation is the enemy** (fail loud — never fail open or closed-silent); **the index is a cache, the raw corpus is the source of truth, and the guarantee runs index-free**; and **one system of record, and the happy path must work**.

This feature explicitly does **not** build the discoverable capture-command UX (that is M040's `/orchestrator-capture` + `/orchestrator-promote` surface), does not auto-graduate `execution-log.jsonl` notes at phase close (P1), does not read runtime agent memory live (cut — deferred to M009), does not add embeddings or any nondeterministic retrieval, and does not make corpus-exhaustion a hard dispatch-refusing gate anywhere except the already-shipped `comments` spec-amendment path. It hardens the floor; it does not build the activation product on top of it.

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 Load-Bearing Scope)

**US-1 (producer/consumer round-trip) + US-2 (resilient rebuild) + US-3 (fail-loud consumer + index-free fallback) + US-4 (capture-by-default at any intensity)** — together these close the capture→store→inject loop end-to-end against the proven bugs. The synthesis pulled BUG A (US-1) and explicit-capture-by-default (US-4) into P0 as **co-primary** because a hardened rebuild over a mis-columned (B-3) or never-written (G-1) store still injects nothing: a truth-layer failure outranks a cache-layer failure. The acceptance oracle for the slice is **AC-1**: a decision written by the legacy capture primitive on a default-intensity (Quick) fixture, rebuilt, then resolved by the consumer — byte-asserted. US-5 (0-MEM alarm + consolidated doctor check) is the safety net layered on top; it is a *build-prerequisite* (the round-trip needs an observable inject path) but a lower *priority* than the data-flow fixes it guards.

### User Story 1 — Producer/Consumer Contract Integrity with Round-Trip Oracle (Priority: P1)

As an operator who captures a decision via the official capture primitive, I want that decision to be provably resolved by the dispatch context-builder, so that the store I write to and the store dispatch reads from are one contract — not two silently-diverging shapes.

**Why this priority**: BUG A is co-primary. Every other fix in this slice is moot if the producer writes rows the consumer cannot parse — a resilient, index-free rebuild over a mis-columned store still injects nothing. This story locks the format; US-2/US-3 keep it readable under stress.

**Independent Test**: On a fresh Quick-intensity fixture project, run `append-decision.sh` with a known `M###/P##`-scoped decision, run `rebuild-index.sh`, then run the consumer's `filter_decisions` and byte-assert the resolved row against the captured input. Repeat for `append-knowledge.sh` ↔ `filter_knowledge` (`## K###` shape).

**Acceptance Scenarios**:

1. **Given** a decision appended by `append-decision.sh` with scope `M044/P01`, **When** `rebuild-index.sh` runs and `filter_decisions` queries scope `M044/P01`, **Then** the resolved row byte-equals the captured decision's scope/choice fields (the `awk` `$5` scope / `$6` when indices land on the intended fields, not on the producer's Choice/Rationale text).
2. **Given** the canonical format is fixed, **When** the three shapes are inspected — producer (`append-decision.sh`), consumer comment (`scope-filter.sh:351`), and consumer `awk` (`:353-354`) — **Then** all three agree, and the init-time empty `DECISIONS.md` header matches the producer output (one CI-checked change set, no shape left behind).
3. **Given** a knowledge entry appended by `append-knowledge.sh` in `## K###` shape, **When** `filter_knowledge` queries it, **Then** it resolves (the parallel producer/consumer mismatch is closed too).

---

### User Story 2 — Resilient Rebuild that Survives Malformed Entries (Priority: P1)

As an operator with a real-world corpus that contains an imperfect entry, I want the index rebuild to skip-and-warn on the bad entry and index everything else, so that one heading-less chunk can never silently zero my entire knowledge base.

**Why this priority**: B-1 is the proven root incident — one malformed entry aborted a full rebuild and left 146 chunks unindexed for a month. Resilience over atomicity is the fix.

**Independent Test**: Build a fixture corpus with ≥1 valid entry and ≥1 heading-less (description-less) entry; run `rebuild-index.sh`; assert exit 0, all valid entries indexed, and an `INDEXED: N / SKIPPED: M [ids/paths]` summary naming the skipped entry. Separately, build a fixture project rooted under a path segment named `archive/` and assert a non-empty index plus a non-zero `:do` quick-inject.

**Acceptance Scenarios**:

1. **Given** a corpus with one heading-less entry, **When** `rebuild-index.sh` runs, **Then** it indexes all valid entries, emits the skip to stderr and a final `INDEXED / SKIPPED` summary, and exits 0 (non-zero only on catastrophic failure — missing `knowledge/`, DB write failure).
2. **Given** a project whose root path contains a directory named `archive`, **When** the index builds, **Then** the index is non-empty and the `:do` quick-inject is non-zero — while a genuine `knowledge/archive/` cold-storage subtree (declared at `rebuild-index.sh:6`) remains excluded.
3. **Given** the bounded audit of `rebuild-index.sh` plus the libraries it sources directly, **When** the audit completes, **Then** every command that can fail silently under `set -e`/`pipefail` is either guarded or recorded with a justify-and-track note (no unbounded sweep of the whole codebase).

---

### User Story 3 — Fail-Loud Consumer with Index-Free Grep Fallback (Priority: P1)

As an agent receiving a dispatch payload, I want the context-builder to tell me — in the payload itself — when it ran degraded and to fall back to deterministic grep over the raw corpus, so that I never silently act on a "first-5" stub and can trust the provenance of what I was given.

**Why this priority**: B-2 is the consumer half of the silent-degradation incident, and the index-free fallback is the load-bearing realization of "the guarantee runs index-free." This is the alarm-and-floor the whole slice is built on.

**Independent Test**: With an empty / stale / missing index, run `build-context.sh` against a populated raw corpus; assert the payload contains a visible degradation WARNING *and* a knowledge-provenance header (`source: index|grep-fallback|degraded`, `index_age`, `entries_considered`), that relevant context is present via grep over raw `knowledge/**/*.md`, and that no silent first-N path executes without a provenance flag. Run twice with identical inputs and byte-compare the provenance/fallback artifact.

**Acceptance Scenarios**:

1. **Given** an empty or missing index but a populated raw corpus, **When** `build-context.sh` assembles a payload, **Then** the payload carries a degradation WARNING (also on stderr), the provenance header reports `source: grep-fallback`, and relevant entries are present via deterministic grep over raw files.
2. **Given** a stale index, **When** the consumer detects it (mtime / content-hash against the newest `knowledge/**/*.md`), **Then** it reports the degradation rather than serving stale results silently.
3. **Given** the index/db path was historically resolved in multiple places, **When** any reader resolves it, **Then** it uses one canonical resolver (`get_index_path` / `get_db_path`); vestigial copies are removed or aliased and the canonical location is documented.
4. **Given** the grep fallback runs, **When** it reads into the payload, **Then** the read is bounded by the M036a token-budget governor (SC-3/SC-7) and the index-free regression asserts hits *within budget* — the fix must not trade a silent under-inject for a silent over-inject.

---

### User Story 4 — Capture-by-Default Regardless of Intensity (Priority: P1)

As an operator on a default-intensity (Quick) project, I want an explicitly-captured decision to land in `DECISIONS.md`, be indexed, and appear in the next inject — and I want the Quick inject to stop dropping the Decisions section — so that the most dangerous place to forget a prior decision (a tiny change) is not the place that gets the least context.

**Why this priority**: Co-primary with US-1. G-1 (`intensity-knowledge.sh:92` — Quick captures nothing) and G-2 (Quick inject drops Decisions) mean a Quick project ships a Decisions slot that is empty-forever. The capture-format fix and the explicit-capture slice ride the **same change set** so neither ships green alone.

**Independent Test**: On a fresh Quick fixture, capture an explicit decision; assert it appears in `DECISIONS.md`, is indexed by `rebuild-index.sh`, and is present in the next `build-context.sh` inject (which now includes a bounded Decisions digest at Quick).

**Acceptance Scenarios**:

1. **Given** a Quick-intensity project, **When** an operator captures an explicit decision (a one-line `append-decision.sh` row-append at Quick), **Then** the decision is written to `DECISIONS.md` regardless of intensity.
2. **Given** the captured decision is indexed, **When** the next dispatch builds context at Quick profile, **Then** the inject includes a bounded Decisions digest (the section is no longer omitted) and the captured decision is present.
3. **Given** this is the P0 write-primitive slice, **When** the capture surface is inspected, **Then** no net-new capture verb is introduced — the primitive is the legacy `append-decision.sh` extended with round-trip confirmation; the discoverable command UX is forward-pointed to the M040 track.

---

### User Story 5 — Fail-Loud Observability: 0-MEM Alarm and Consolidated Doctor Check (Priority: P2)

As an operator, I want a visible warning whenever an inject resolves to 0 MEMs on a project that already has milestones/decisions on disk, and a single doctor check that surfaces the three knowledge-activation failure symptoms, so that a month-long silent degradation can never recur unseen.

**Why this priority**: Build-prerequisite but lower priority — the alarm is what would have caught the original incident, and the round-trip's "confirms the entry resolves in an inject" check needs an observable inject surface to assert against. It ranks P2 because it guards the data-flow fixes rather than carrying them.

**Independent Test**: On a mature fixture (milestones + decisions on disk) force a 0-MEM inject; assert a visible warning. Run `orchestrator:doctor` and assert a single consolidated check reports the three symptoms (0-MEM-on-mature-project / vestigial-index / runtime-memory decisions absent from `.orchestrator/`).

**Acceptance Scenarios**:

1. **Given** a project with prior milestones/decisions on disk, **When** an inject resolves to 0 MEMs, **Then** a visible warning is emitted (inject-size surface: `knowledge: N MEMs / X tokens`).
2. **Given** `orchestrator:doctor` runs, **When** it checks knowledge activation, **Then** a **single** consolidated check reports all three symptoms — 0-MEM-on-mature-project, vestigial/divergent index path, and runtime-memory decisions absent from `.orchestrator/` — reconciling (not duplicating) `papercut-doctor-knowledge-gap-surface.md`.

---

## Edge Cases

- **Heading-less / tag-less entry mid-loop** — must skip-and-warn, never abort the rebuild (US-2 AC-1). A second malformed entry later in the loop must also be skipped, not abort.
- **Project rooted under `archive/`** — the bare `*/archive/*` false-match must be dropped *without* dropping the genuine `knowledge/archive/` cold-storage exclusion the script intentionally declares (US-2 AC-2).
- **Stale-but-present index** — must be detected and reported as degraded; the consumer never serves stale results silently. P0 policy is rebuild-then-warn-if-still-bad on the burning path; never silent auto-rebuild mid-dispatch.
- **Grep fallback over an empty raw corpus** — degrades to a visible "no qualifying entries, ran degraded" provenance state, not a silent empty payload.
- **Capture-write under any failure** — capture-write (disk row-append) is free and unbudgeted; only read-into-payload paths are budget-governed. A budget exhaustion on the read path must not silently drop the capture.
- **Provenance header on a healthy index** — the minimal provenance header is always present in the payload even when `source: index` (fail-loud is not conditional on failure).
- **Three-shape drift reintroduced** — a future edit that changes one of the three shapes (producer / consumer-comment / consumer-awk) without the others must be caught by the round-trip oracle in CI.

---

## Functional Requirements

> FR identifiers are preserved from the upstream brief for traceability. The P0 membership set is **unordered** with an **intra-P0 build sequence** (sequence ≠ priority): alarm first (FR-15 + FR-5, no deps) → BUG-A + capture immediately after.

- **FR-1 (unify-producer-consumer-format)**: Unify `append-decision.sh` / `append-knowledge.sh` output with the `filter_decisions` / `filter_knowledge` shapes the consumer parses. One canonical format reconciling **three** shapes — producer, consumer comment (`scope-filter.sh:351`), consumer `awk` (`:353-354`). The round-trip test (SC-1) is the acceptance oracle, asserting against the **observed `awk` indices** (`$5` scope / `$6` when), not the documented column order. The init-time empty `DECISIONS.md` header must match the canonical format. (Satisfies US-1; fixes B-3 / BUG A.)
- **FR-2 (compression-filter-flat-knowledge)**: Fix `compression.knowledge_filter` (`kf_filter_stream`) to pass flat `## K###` knowledge entries (or unify the knowledge shape so frontmatter is not required), so the shape the consumer parses and the filter's requirement are consistent. (Satisfies US-1; fixes B-5.)
- **FR-3 (resilient-rebuild + bounded-audit)**: `rebuild-index.sh` performs per-entry try/skip/warn — never abort the whole rebuild on one bad entry. Guard `:117` and conduct a **bounded** audit of `rebuild-index.sh` plus the libraries it sources directly for every other command that can fail silently under `set -e`/`pipefail`; fix `:117` plus any *reproduced* failure, else justify-and-track. Emit per-skip to stderr plus a final `INDEXED: N / SKIPPED: M [ids/paths]` summary. Exit non-zero only on catastrophic failure. (Satisfies US-2; fixes B-1.)
- **FR-4 (scope-archive-glob)**: Scope the archive skip to the orchestrator's own subtree (`.orchestrator/**/archive/` / `knowledge/archive/`), not a bare `*/archive/*` against absolute paths, in both `resolve-entries.sh:45` and `rebuild-index.sh:74`. **Preserve** the genuine `knowledge/archive/` cold-storage exclusion declared at `rebuild-index.sh:6`. (Satisfies US-2; fixes B-4.)
- **FR-5 (fail-loud + index-free fallback)**: `build-context.sh` (and every index reader) detects empty/missing/stale index and (a) emits a visible WARNING into the **injected payload** *and* stderr; (b) prefers a **grep-over-raw-files fallback** over a silent first-N; (c) stamps the payload with a knowledge-provenance header (`source: index|grep-fallback|degraded`, `index_age`, `entries_considered`). The fallback read is **budget-bounded** via the M036a token governor. (Satisfies US-3; fixes B-2.)
- **FR-6 (decisions-in-quick-inject)**: Stop omitting the Decisions section from the Quick-profile inject; include at least a compact, budget-bounded decisions digest. Ships in the **same change set** as the FR-8 G-1 capture slice. (Satisfies US-4; fixes G-2.)
- **FR-8/G-1 (explicit-capture-at-quick)**: Never drop *explicit* decisions at Quick — always run the `append-decision.sh` row-append for explicit decisions even at Quick intensity, so a Quick project never ships an empty-forever Decisions slot. (P0 slice of FR-8 only; the auto-graduate-at-phase-close half is P1/M040-track.) (Satisfies US-4; fixes the G-1 capture gap.)
- **FR-9/enforcement (runtime-memory-divergence warning)**: Ship the **enforcement-warning half** of the system-of-record resolution — the 0-MEM-on-mature-project warning plus a doctor check that flags runtime-memory decisions absent from `.orchestrator/`. (The graduation *mechanism* and the full system-of-record documentation are P1/M040-track; live runtime-memory read is **cut** — deferred to M009.) (Satisfies US-5; fixes the observable half of G-3.)
- **FR-11 (canonical-index-path)**: Canonicalize the index/db path: a single `get_index_path` / `get_db_path` resolver used everywhere; remove or alias vestigial `.orchestrator/` copies; document the canonical location. (Satisfies US-3; fixes part of G-7.)
- **FR-15 (0-MEM-warning + consolidated-doctor)**: Surface inject size everywhere (`knowledge: N MEMs / X tokens`) and **WARN when an inject resolves to 0 MEMs on a project that already has milestones/decisions on disk**. Add a **single consolidated** `orchestrator:doctor` check covering the three symptoms (0-MEM-on-mature-project / vestigial-index / runtime-memory-divergence), reconciling `papercut-doctor-knowledge-gap-surface.md` rather than adding a second overlapping surface. (Satisfies US-5; fixes G-7.)

## Success Criteria

- **SC-1 (round-trip byte-equality)**: On a default-intensity (Quick) fixture, a decision written by `append-decision.sh`, rebuilt, and resolved by `filter_decisions` **byte-equals** the captured scope/choice fields (per the byte-equality fixture default). The **dynamic** round-trip lane (runtime-appended row) is split from the **static** byte-equality fixtures (a frozen file is not forced to contain a runtime-appended row). The parallel `append-knowledge.sh` ↔ `filter_knowledge` round-trip passes. Command + exit 0 + asserted resolved row.
- **SC-2 (resilient rebuild)**: A corpus with ≥1 heading-less entry rebuilds successfully — all valid entries indexed, per-skip warning emitted, `INDEXED: N / SKIPPED: M` summary present, exit 0.
- **SC-3 (bounded audit recorded)**: An audit artifact lists every command in `rebuild-index.sh` + directly-sourced libs that can fail silently under `set -e`/`pipefail`, each marked guarded or justify-and-track; `:117` is guarded.
- **SC-4 (archive glob scoped, exclusion preserved)**: An `archive/`-rooted fixture project builds a non-empty index and a non-zero `:do` quick-inject, while a `knowledge/archive/` entry remains excluded.
- **SC-5 (fail-loud consumer)**: With an empty/stale/missing index and a populated raw corpus, `build-context.sh` produces a payload containing a degradation WARNING (also on stderr), a provenance header (`source` / `index_age` / `entries_considered`), and relevant entries via grep fallback; no code path injects first-N without a provenance flag.
- **SC-6 (deterministic, budget-bounded fallback)**: The grep fallback / provenance artifact is reproducible (same inputs → byte-identical artifact; `LC_ALL=C` sort, stable file order, no wall-clock in artifact bodies), and the index-free regression asserts hits *within* the M036a budget.
- **SC-7 (flat-knowledge passes filter)**: A flat `## K###` `KNOWLEDGE.md` entry passes `kf_filter_stream` and appears in the inject (no "(no qualifying knowledge entries)" for valid flat entries).
- **SC-8 (capture-at-quick + decisions digest)**: On a Quick fixture, an explicitly-captured decision lands in `DECISIONS.md`, is indexed, and appears in the next inject; the Quick inject includes a bounded Decisions digest.
- **SC-9 (capture-by-default round-trip)**: On a fresh project at any intensity, a decision captured via the capture primitive is provably present in the next dispatch's inject (composes SC-1 + SC-8).
- **SC-10 (0-MEM warning)**: A 0-MEM inject on a project with prior milestones/decisions on disk emits a visible warning.
- **SC-11 (consolidated doctor check)**: `orchestrator:doctor` reports a **single** knowledge-activation check covering all three symptoms; no second overlapping doctor surface exists (papercut reconciled).
- **SC-12 (canonical path resolver)**: Exactly one `get_index_path` / `get_db_path` definition is sourced by all index readers; no vestigial divergent path remains; the canonical location is documented.

## Non-Goals

- **Discoverable capture-command UX** — the `/orchestrator-capture` + `/orchestrator-promote` command surface is M040-track. P0 ships the write primitive + round-trip confirmation only (DQ-7: no net-new capture verb). Rationale: command-NAME is decoupled from ship-TIMING; the primitive ships on a committed timeline regardless of M040's queue position.
- **Auto-graduate `execution-log.jsonl` notes at phase close** (the FR-8 auto-graduate half) — P1/M040-track. Rationale: P0 ships explicit-capture-at-Quick; the at-close graduation mechanism is a larger surface.
- **Live runtime-memory read** — **cut entirely** (DQ-8), deferred to M009 runtime-memory-adapter work. Rationale: a live read couples dispatch to CC's `MEMORY.md` shape (Principle VI / latent M009 debt) and puts a nondeterministic source on the guarantee path. P0 ships only the enforcement *warning*; the graduation *mechanism* + system-of-record docs are M040-track.
- **Embeddings / semantic retrieval** — out of scope (DQ-2). Rationale: the guarantee stays deterministic-grep; embeddings, if ever added, are additive-only, never gate, never enter the evidence artifact.
- **Corpus-exhaustion as a hard dispatch-refusing gate** beyond the already-shipped `comments` spec-amendment path — out of scope (DQ-5). Rationale: advisory-default everywhere; the default-on hardening of `comments`/`discuss`/`specify`/`plan-phase`/`materials-intake` (brief FR-12/13/14) is P1/M040-track.
- **Index freshness auto-rebuild policy (FR-10) and the freshness content-hash contract** — P1/M040-track. P0 detects + warns on stale on the burning path; it does not build the full freshness invariant or any mid-dispatch auto-rebuild.
- **REF-chunk ingest headings / `scope_tags` population (FR-14)** — P1/M040-track.

## Constraints

- **CON-1 (DQ-resolutions-binding)**: The eight design questions (DQ-1…DQ-8) are **resolved and binding**; they must not be re-opened without new evidence. Index = cache, raw corpus = truth, guarantee runs index-free (DQ-1); deterministic-grep floor, embeddings additive-only (DQ-2); rebuild-then-warn-if-still-bad on stale (DQ-3); provenance header always + full provenance to stderr/artifact (DQ-4); advisory-default, hard gate only on `comments` (DQ-5); reconcile three shapes asserting against observed `awk` indices (DQ-6); no net-new capture verb (DQ-7); `.orchestrator/` is system of record via graduation, live-read cut (DQ-8).
- **CON-2 (Principle-I budget guardrail, both directions)**: The fix must not trade a silent *under*-inject for a silent *over*-inject. Every **read-into-payload** path (FR-5, FR-6) routes through the existing M036a token-budget governor (SC-3/SC-7 of that milestone) and the index-free regression asserts hits *within budget*. **Capture-write (disk row-append) is free and unbudgeted.**
- **CON-3 (determinism on the guarantee path)**: The grep fallback and the corpus-gate evidence artifact must be reproducible — `LC_ALL=C` sort, stable file order, no wall-clock in artifact bodies, no nondeterminism vectors. Same inputs → byte-identical output.
- **CON-4 (preserve genuine archive exclusion)**: FR-4 drops only the bare `*/archive/*` false-match; the intentional `knowledge/archive/` cold-storage exclusion (`rebuild-index.sh:6`) is preserved.
- **CON-5 (one doctor surface)**: FR-15's doctor check reconciles-or-supersedes `papercut-doctor-knowledge-gap-surface.md` into a single consolidated 3-symptom check before intake — no second overlapping doctor surface.
- **CON-6 (round-trip oracle asserts observed indices)**: The AC-1 oracle asserts against the observed `awk` field indices (`$5` scope / `$6` when), not the documented column order; whichever shape loses the DQ-6 reconciliation is rewritten and CI-checked.

### Knowledge-Layer Boundary (M044 vs. M036a / M040)

M044 **claims** the write-sites for the producer/consumer format (`append-decision.sh`, `append-knowledge.sh`, `scope-filter.sh` `filter_decisions`/`filter_knowledge`), the rebuild loop (`rebuild-index.sh`, `resolve-entries.sh`), the consumer fallback + provenance header (`build-context.sh`), the canonical path resolver, the compression knowledge filter (`kf_filter_stream`), and the 0-MEM/doctor observability surfaces. M044 **delegates** the token-budget governor to M036a (consumed read-only via the existing SC-3/SC-7 governor — M044 routes its read-into-payload paths through it but does not modify it), the discoverable capture-command UX + graduation mechanism + system-of-record documentation to the M040 track, REF-chunk ingest metadata to M036b, and live runtime-memory adapter work to M009. M044 writes no new graph schema, no new edge types, no new tag namespace.

## Assumptions

- The M036a token-budget governor (SC-3/SC-7) is on disk and consumable read-only (closed 2026-05-02).
- The `orchestrator-corpus-gate` primitive is shipped and its index-independence is intact (the load-bearing asset; M044 verifies and preserves it but does not re-author it).
- The conversus adapter (M011/P07) is available if any downstream gate needs it; P0 itself requires no new conversus run (the brief's deliberation is the adversarial pass).
- The five proven defects reproduce against live source at the cited file:line anchors (re-confirmed 2026-06-06); the bounded audit may surface additional unguarded commands, which are justify-and-tracked, not necessarily fixed in P0.
- `.orchestrator/` is (and will be documented as) the system of record; runtime agent memory is a convenience cache, not read on the guarantee path.

## Constitution Check

Compliance with `.orchestrator/memory/constitution.md` for each principle materially touched:

- **Principle II (Evidence Before Claims)**: The entire spec is evidence-first — every defect is cited at file:line and re-verified against live source; the acceptance oracle is a byte-asserted round-trip, and the provenance header makes the *evidence of what was injected* a first-class payload artifact. Fail-loud is the operationalization of "never claim context you do not have."
- **Principle VI (State On Disk Is Truth)**: FR-9/enforcement + the system-of-record posture make `.orchestrator/` authoritative and forbid a live read of nondeterministic runtime memory on the guarantee path; the two-store divergence that produced silent 0-MEM injects is closed by enforcement-warning in P0 and graduation in P1.
- **Principle VII (Knowledge Compounds)**: This is the spec's reason for being — knowledge that is captured but never re-activated does not compound. Capture-by-default + a readable round-trip + fail-loud injection restore the compounding loop the framework promises.
- **Principle IX (Reproducibility Over Convenience)**: CON-3 forbids nondeterminism on the guarantee path (`LC_ALL=C`, stable order, no wall-clock); the grep fallback and evidence artifact are reproducible by contract.
- **Principle XI (Single Source of Truth)**: FR-1 collapses three drifting shapes into one canonical format; FR-11 collapses multiple index-path resolutions into one resolver; the system-of-record posture names one authoritative store.
- **Principle XIV (No Speculative Complexity)**: P0 is deliberately bounded — the audit is bounded to `rebuild-index.sh` + directly-sourced libs, embeddings are excluded, hard gates are excluded except the already-shipped `comments` path, and the discoverable UX / graduation mechanism are forward-pointed rather than speculatively built now.
- **Principle XV (Surgical Precision)**: FR-4 drops only the false-match while preserving the genuine exclusion; FR-8's P0 slice is a one-line row-append, not a capture subsystem; each seam ships incrementally with a one-line Principle-XIV justification + a deterministic evidence artifact.

## Open Questions (defer to planning)

- **#Q-1 (canonical-column-order)**: DQ-6 locks the *oracle* (assert against observed `awk` indices `$5`/`$6`), but the plan must pick which concrete column order becomes the written contract and rewrite the losing shape. Confirm whether the producer's order or the consumer's order is least-disruptive to existing on-disk `DECISIONS.md` files across dogfood projects, and whether a migration of existing rows is needed or the format is forward-only. *Answered at plan-phase time by the planner with a dogfood-corpus scan.*
- **#Q-2 (stale-detection mechanism)**: P0 detects stale via mtime *or* content-hash. The plan should pick the P0 mechanism (mtime is cheaper; content-hash is the eventual FR-10 contract) and confirm the burning-path "rebuild-then-warn-if-still-bad" behavior does not add unacceptable mid-dispatch latency. *Answered at plan-phase time.*
- **#Q-3 (doctor reconciliation shape)**: Confirm whether `papercut-doctor-knowledge-gap-surface.md` is *superseded* (deleted/folded) or *reconciled* (its check rewritten into the consolidated one), and that no existing doctor test asserts against the old surface. *Answered at plan-phase time against the live doctor implementation.*
- **#Q-4 (provenance-header byte-contract version)**: The provenance header is a payload byte-contract consumed downstream. Confirm whether P0 pins a version field now (cheap insurance for the P1 `resolved-id` surface) or defers versioning to the P1 freshness work. *Answered at plan-phase time.*

## Dependencies

- **M036a token-budget governor** (closed 2026-05-02) — consumed read-only for the Principle-I budget guardrail on every read-into-payload path.
- **`orchestrator-corpus-gate`** (shipped) — its index-independent grep primitive is the load-bearing asset preserved by this work.
- **conversus adapter (M011/P07)** — available for any downstream gate; P0 requires no new run.
- **The five proven defects** at their cited anchors (`rebuild-index.sh:11/:40/:74/:117`, `build-context.sh:198-208/~:223`, `append-decision.sh:93`, `scope-filter.sh:351/:353-354`, `resolve-entries.sh:45`, `intensity-knowledge.sh:92`).

## Downstream Consumers (informational, not binding)

- **M040 (ambient feedback loop)** — consumes the P0 write primitive + round-trip-confirm mechanism as the foundation for `/orchestrator-capture` + `/orchestrator-promote`, the FR-8 auto-graduate half, the graduation mechanism + system-of-record docs, FR-10 freshness, and FR-12/13/14 corpus-gate default-on. This spec supplies one of M040's ≥5 inbox-report demand triggers (trigger borderline-unfired; P0 ships milestone-independent regardless).
- **M034 (interactive review gates — current branch)** — FR-5's provenance/conflict surfacing composes with the decision-packet shape; M040's contradiction gate emits M034 packet shape.
- **M038 (living documents)** — the freshness contract (FR-10, P1) and the provenance header (FR-5) are living-doc primitives.
- **`papercut-doctor-knowledge-gap-surface.md`** — reconciled-or-superseded by FR-15 into the single consolidated 3-symptom doctor check (CON-5).
