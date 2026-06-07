---
schema_version: "1.0"
type: roadmap
milestone: "M044"
feature_ref: "045-knowledge-activation-reliability"
feature_spec: "specs/045-knowledge-activation-reliability/spec.md"
vision: "Harden the knowledge-activation pipeline so it can never silently degrade, and close the capture→store→inject loop — fail loud, run index-free, one system of record."
tier: "C"
created_at: "2026-06-07T01:08:32Z"
updated_at: "2026-06-07T01:08:32Z"
---

## Phases

- [x] **P01**: Fail-loud floor — canonical path resolver + index-free consumer fallback + observability — "With an empty/missing/stale index over a populated raw corpus, `build-context.sh` injects relevant entries via deterministic grep, stamps a provenance header, and emits a degradation WARNING; a 0-MEM inject on a mature project warns; `orchestrator:doctor` reports one consolidated 3-symptom knowledge-activation check."
  - Risk: high
  - Depends: none
  - Boundary Map:
    - Produces: `scripts/knowledge/lib/index-paths.sh` (new — canonical `get_index_path`/`get_db_path` resolver, FR-11); `scripts/dispatch/build-context.sh` (degradation WARNING into payload + stderr, knowledge-provenance header `source: index|grep-fallback|degraded` / `index_age` / `entries_considered`, grep-over-raw fallback budget-bounded via the M036a governor, inject-size surface `knowledge: N MEMs / X tokens`, 0-MEM-on-mature-project warning — FR-5 + FR-15); consolidated `orchestrator:doctor` knowledge-activation check (3 symptoms: 0-MEM-on-mature / vestigial-index / runtime-memory-divergence — FR-15 + FR-9-enforcement, reconciling `papercut-doctor-knowledge-gap-surface.md` per CON-5); provenance-header byte-contract (#Q-4 version-field decision); index-free within-budget regression fixture (SC-5/SC-6)
    - Consumes: M036a token-budget governor (read-only, SC-3/SC-7); `orchestrator-corpus-gate` index-independent grep primitive (preserved, not re-authored)

- [ ] **P02**: Producer/consumer format unification + round-trip oracle (BUG-A) — "A decision appended by `append-decision.sh` on a Quick fixture, rebuilt, then resolved by `filter_decisions`, byte-equals the captured scope/choice fields (observed awk `$5`/`$6` land on Scope/When); a flat `## K###` entry passes `kf_filter_stream` and appears in the inject."
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces: `scripts/knowledge/append-decision.sh` (canonical column order — the DQ-6 loser rewritten so `awk -F'|'` `$5`=Scope/`$6`=When holds, FR-1); `scripts/knowledge/append-knowledge.sh` (canonical `## K###` shape aligned to `filter_knowledge`, FR-1); `scripts/dispatch/scope-filter.sh` (`filter_decisions` comment `:351` + awk `:353-354` reconciled to observed indices, `filter_knowledge` aligned — FR-1, CON-6); `scripts/lib/knowledge-filter.sh` (`kf_filter_stream` passes flat `## K###` entries, FR-2); init-time empty `DECISIONS.md` header matching the canonical format; AC-1 round-trip oracle — **dynamic** capture→rebuild→grep→byte-assert lane (Quick fixture) split from **static** byte-equality fixtures (SC-1, SC-7)
    - Consumes: P01 observable inject surface (round-trip "resolves in inject" assertion); P01 canonical path resolver (rebuild/resolve reads)

- [ ] **P03**: Resilient rebuild + scoped archive glob — "A corpus with a heading-less entry rebuilds successfully — all valid entries indexed, a per-skip warning + an `INDEXED: N / SKIPPED: M` summary emitted, exit 0; an `archive/`-rooted fixture project builds a non-empty index and a non-zero `:do` quick-inject while a genuine `knowledge/archive/` entry stays excluded."
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces: `scripts/knowledge/rebuild-index.sh` (per-entry try/skip/warn guarding `:117`, bounded unguarded-command audit of the script + directly-sourced libs, per-skip stderr + final `INDEXED/SKIPPED` summary, exit non-zero only on catastrophic failure — FR-3; scoped archive glob `:74` dropping the bare `*/archive/*` false-match while preserving `knowledge/archive/` per `:6` — FR-4, CON-4); `scripts/knowledge/resolve-entries.sh` (scoped archive glob `:45`, same preservation — FR-4); bounded-audit artifact under `M044/gates/` listing each at-risk command guarded/justify-and-track (SC-3); resilient-rebuild fixture (heading-less entry, SC-2) + archive-rooted fixture (SC-4)
    - Consumes: P01 canonical path resolver

- [ ] **P04**: Capture-by-default at Quick + Decisions digest — "On a fresh Quick-intensity fixture, an explicitly-captured decision lands in `DECISIONS.md`, is indexed by `rebuild-index.sh`, and is present in the next `build-context.sh` inject — which now carries a bounded, budget-bounded Decisions digest at the Quick profile."
  - Risk: high
  - Depends: P01, P02
  - Boundary Map:
    - Produces: `scripts/knowledge/intensity-knowledge.sh` (explicit-decision capture runs `append-decision.sh` even at Quick intensity — FR-8/G-1 slice); `scripts/dispatch/build-context.sh` (bounded, budget-bounded Decisions digest in the Quick-profile inject — the section is no longer omitted, FR-6); capture-by-default round-trip fixture (Quick: capture→index→appears-in-inject — SC-8, SC-9)
    - Consumes: P02 canonical decision format (capture writes it; round-trip resolves it); P01 Quick-profile consumer + provenance/observability surface + M036a budget governor

## Cross-Cutting Concerns

- **Determinism on the guarantee path (CON-3)** — P01, P03. P01 establishes the pattern: the grep fallback and any evidence artifact use `LC_ALL=C` sort, stable file order, and carry no wall-clock in artifact bodies (same inputs → byte-identical output). P03's rebuild output ordering (`sort` of index entries) must conform. The byte-equality fixtures (P02, SC-1/SC-7) inherit this contract.
- **Principle-I budget guardrail, both directions (CON-2)** — P01, P04. Every **read-into-payload** path routes through the M036a token-budget governor: P01's FR-5 grep fallback and P04's FR-6 Decisions digest both assert hits *within budget* (no silent over-inject). **Capture-write (disk row-append) is free and unbudgeted** — P02/P04 capture paths are not budget-gated.
- **Three-shape reconciliation + observed-index oracle (CON-6, AD-6)** — P02 owns it: producer (`append-decision.sh`) / consumer-comment (`scope-filter.sh:351`) / consumer-awk (`:353-354`) re-align in one CI-checked change set; the round-trip oracle asserts the observed awk `$5`/`$6` indices, not the documented column order. #Q-1 (which order becomes the written contract) is resolved at P02 plan-phase against a dogfood `DECISIONS.md` scan.
- **One doctor surface (CON-5)** — P01 owns it: FR-15's check reconciles-or-supersedes `papercut-doctor-knowledge-gap-surface.md` into a single consolidated 3-symptom check; no second overlapping surface. #Q-3 (reconcile vs supersede) is resolved at P01 plan-phase against the live doctor implementation.
- **Preserve the genuine archive exclusion (CON-4)** — P03 owns it: FR-4 drops only the bare `*/archive/*` false-match; the intentional `knowledge/archive/` cold-storage exclusion (`rebuild-index.sh:6`) is preserved in both `resolve-entries.sh:45` and `rebuild-index.sh:74`.
- **Canonical path resolver is a shared seam** — P01 produces `lib/index-paths.sh`; P02 (rebuild reads), P03 (`rebuild-index.sh`/`resolve-entries.sh`), and P04 (consumer) all consume it. P01 must land the resolver and migrate the in-scope readers before its dependents run.

## Dependency Graph

```
        ┌──────────► P02 ──────────┐
        │                          ▼
P01 ────┤                         P04
        │                          ▲
        └──────────► P03           │
        └──────────────────────────┘   (P04 also depends on P01)
```

- P01 → P02 (format work needs the observable inject surface + path resolver)
- P01 → P03 (rebuild consumes the canonical path resolver)
- P01 → P04 and P02 → P04 (capture writes the P02 format into the P01 consumer/observability surface)
- P02 ∥ P03 (siblings — touch disjoint files: P02 = `append-*` / `scope-filter.sh` / `knowledge-filter.sh`; P03 = `rebuild-index.sh` / `resolve-entries.sh`)

## Execution Order

1. **P01** — foundation/alarm, no dependencies. Ships the fail-loud floor first (per the intra-P0 build sequence: alarm before BUG-A + capture, because the AC-1 round-trip needs an observable inject path). Establishes the canonical path resolver and determinism pattern every dependent consumes.
2. **P02, P03** — can execute concurrently (both depend only on P01, and modify disjoint file sets). P02 is BUG-A (co-primary); P03 fixes the proven root incident B-1.
3. **P04** — depends on P02 (canonical format) and P01 (Quick consumer + budget governor). The capture co-primary; ships FR-6 + FR-8/G-1 in one change set so a Quick project never carries an empty-forever Decisions slot.

## Validation

- **No conflicting producers**: PASS. No two **concurrent** phases produce the same artifact — the only concurrent pair (P02 ∥ P03) touches disjoint files. `build-context.sh` is modified by P01 (FR-5/FR-15 consumer-fallback + provenance + observability) and P04 (FR-6 Quick Decisions digest), but P04 depends on P01 (strictly sequential) and the edits are at distinct seams. `rebuild-index.sh` and `resolve-entries.sh` are touched by P01 (FR-11 path resolver) and P03 (FR-3/FR-4), with P03 depending on P01 (sequential). Boundary maps are declared at seam granularity to make the non-overlap auditable.
- **All consumed items have producers**: PASS. P02/P03/P04 consume P01's `lib/index-paths.sh` + observable inject surface + budget-governor routing; P04 additionally consumes P02's canonical decision format. M036a governor + `orchestrator-corpus-gate` grep primitive are external (closed/shipped) dependencies, not phase-produced.
- **DAG is acyclic**: PASS. Edges: P01→P02, P01→P03, P01→P04, P02→P04. No cycle.
- **Demo sentence coverage**: PASS. Each phase has a concrete, observable, testable demo sentence tied to its acceptance scenarios (P01→SC-5/SC-6/SC-10/SC-11/SC-12; P02→SC-1/SC-7; P03→SC-2/SC-3/SC-4; P04→SC-8/SC-9).
