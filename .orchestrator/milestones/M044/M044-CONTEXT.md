---
schema_version: "1.0"
type: context-draft
milestone: "M044"
status: finalized
created_at: "2026-06-07"
finalized_at: "2026-06-07"
---

> **Provenance.** This context draft is **not** the product of a fresh interactive `orchestrator:discuss` session. The architectural discussion for M044 already happened: the upstream brief (`.orchestrator/proposals/knowledge-activation-reliability.md`) was run through a 16-agent cooperative conversus deliberation (2026-06-06, 5 phases, **0 rejections, all 8 design questions resolved**; record at `.orchestrator/conversus/knowledge-activation/summary/final.md`). Those resolutions are **binding** (spec CON-1) and must not be re-opened without new evidence. This draft consolidates them into the roadmap-consumable shape. Re-running an interactive discussion would risk re-litigating settled questions, which CON-1 forbids.

## Architectural Decisions

Three load-bearing principles govern every decision (from the brief §1):

- **P-A — Silent degradation is the enemy.** Every knowledge-activation path must fail **loud** (visible warning + provenance), never fail **open** (silently under-load) and never fail **closed-silent** (silently abort). An agent that *knows* it is under-informed behaves correctly; one silently under-informed produces confident, wrong work.
- **P-B — Index is a cache; the raw corpus is the source of truth; the guarantee runs index-free.** Grep over raw `knowledge/**/*.md` is *the* guarantee. The index makes activation fast; it must never be what makes activation possible.
- **P-C — One system of record, and the happy path must work.** The store the agent writes to and the store dispatch reads from must not silently diverge. Producer and consumer are one contract, covered by a round-trip test.

Binding design-question resolutions (DQ-1…DQ-8 — CLOSED; do not re-open):

- **AD-1 (DQ-1) — Index demoted to a cache.** Every consumer must have an index-free path; full retrofit is P1, the burning consumer (`build-context.sh`) gets it in P0.
- **AD-2 (DQ-2) — Deterministic-grep floor; embeddings additive-only.** Grep over raw files is the sole input to the corpus-gate evidence artifact. Embeddings, if ever added, never gate and never enter the receipt. Forbid nondeterminism (`LC_ALL=C` sort, no wall-clock in artifact bodies, stable file order).
- **AD-3 (DQ-3) — Rebuild-then-warn-if-still-bad** on stale; never a silent auto-rebuild mid-dispatch.
- **AD-4 (DQ-4) — Minimal provenance header always in the payload + full provenance to stderr/evidence-artifact.** Fail-loud is not conditional on failure: the header is present even when `source: index`.
- **AD-5 (DQ-5) — Advisory-default everywhere; dispatch-refusing hard gate only on `comments` spec-amendment** (already shipped). Each seam ships with a one-line Principle-XIV justification + a deterministic-grep evidence artifact. (P0 builds no new hard gate.)
- **AD-6 (DQ-6) — Reconcile THREE shapes, not two** — producer (`append-decision.sh`) / consumer-comment (`scope-filter.sh:351`) / consumer-awk (`:353-354`). The round-trip oracle (AC-1) asserts against the **observed awk field indices** (`$5` scope / `$6` when), not the documented column order. The canonical winner is locked by AC-1; init-header + append script + consumer comment + consumer awk re-align in one CI-checked change set.
- **AD-7 (DQ-7) — No net-new capture verb.** P0 ships the legacy `append-decision.sh` write primitive extended with round-trip confirmation; the discoverable `/orchestrator-capture` + `/orchestrator-promote` command UX is M040-track.
- **AD-8 (DQ-8) — `.orchestrator/` is the system of record via graduation; live-runtime-memory read is CUT** (deferred to M009 runtime-memory-adapter work). P0 ships only the enforcement *warning* (0-MEM + doctor check); the graduation mechanism + SoR docs are M040-track.

Three resolved contradictions (the load-bearing fusions):

- **AD-9 — BUG-A + explicit-capture-by-default are co-primary P0 members.** A resilient, index-free rebuild over a mis-columned (B-3) or never-written (G-1) store still injects nothing — a truth-layer failure outranks a cache-layer failure. One fixture corpus locks both capture-format and grep-fallback; neither ships green alone.
- **AD-10 — Command-NAME decoupled from ship-TIMING.** The capture primitive + round-trip mechanism ride P0; the discoverable UX lands M040-track. M040's formal demand trigger is borderline-unfired (needs ≥5 inbox reports; this supplies one), so the P0 primitive ships milestone-independent.
- **AD-11 — Live runtime-memory read withdrawn** in favor of graduation into `.orchestrator/` (a live read couples dispatch to CC's `MEMORY.md` shape — Principle VI / latent M009 debt — and puts a nondeterministic source on the guarantee path).

## Scope Boundaries

**In scope — the P0 hotfix membership set (unordered set; intra-P0 build SEQUENCE ≠ priority):**

- **FR-1** unify producer/consumer decision+knowledge format (**BUG A**, co-primary) — three-shape reconciliation, round-trip oracle is the acceptance test.
- **FR-2** compression filter (`kf_filter_stream`) passes flat `## K###` entries.
- **FR-3** resilient per-entry skip-and-warn rebuild + **bounded** unguarded-command audit (`rebuild-index.sh` + directly-sourced libs only; fix `:117` + any *reproduced* failure, else justify-and-track).
- **FR-4** scope the archive glob (`resolve-entries.sh:45` + `rebuild-index.sh:74`) — drop only the bare `*/archive/*` false-match; **preserve** the genuine `knowledge/archive/` cold-storage exclusion (`rebuild-index.sh:6`).
- **FR-5** fail-loud + index-free grep fallback for the burning consumer (`build-context.sh`), **budget-bounded** via the M036a governor; provenance header always present.
- **FR-6** bounded Decisions digest in the Quick-profile inject (ships in the same change set as the FR-8 G-1 slice).
- **FR-8 (G-1 slice only)** explicit-decision capture at Quick — always run the `append-decision.sh` row-append for explicit decisions even at Quick intensity.
- **FR-9 (enforcement-warning half only)** 0-MEM-on-mature-project warning + doctor check for runtime-memory decisions absent from `.orchestrator/`.
- **FR-11** canonical index/db path (single `get_index_path`/`get_db_path` resolver; remove/alias vestigial copies; document the canonical location).
- **FR-15** surface inject size everywhere + WARN on 0-MEM inject on a mature project + a **single consolidated** `orchestrator:doctor` 3-symptom check.

**Intra-P0 build sequence (sequence ≠ priority):** alarm first (**FR-15 + FR-5**, no deps, ship day one — the AC-1 capture-confirm round-trip literally needs an observable inject path) → **BUG-A (FR-1) + capture (FR-8/G-1 + FR-6)** immediately after. Capture is co-primary, not a fast-follow.

**Out of scope (forward-pointed Non-Goals):**

- Discoverable `/orchestrator-capture` + `/orchestrator-promote` command UX → M040-track (P0 ships the write primitive + round-trip confirm only).
- Auto-graduate `execution-log.jsonl` `note` fields at phase close (FR-8 auto-graduate half) → P1/M040-track.
- Live runtime-memory read → **cut entirely** (DQ-8), deferred to M009.
- Embeddings / semantic retrieval → out of scope (DQ-2; additive-only if ever added).
- Corpus-exhaustion as a hard dispatch-refusing gate beyond the shipped `comments` path → out of scope (DQ-5; advisory-default).
- Index-freshness auto-rebuild policy (FR-10) + the freshness content-hash contract → P1/M040-track (P0 detects + warns on stale only).
- REF-chunk ingest headings / `scope_tags` population (FR-14) → P1/M040-track.

**Knowledge-layer boundary (M044 vs M036a / M040 / M036b / M009):** M044 **claims** the producer/consumer write-sites (`append-decision.sh`, `append-knowledge.sh`, `scope-filter.sh` `filter_decisions`/`filter_knowledge`), the rebuild loop (`rebuild-index.sh`, `resolve-entries.sh`), the consumer fallback + provenance header (`build-context.sh`), the canonical path resolver, the compression knowledge filter (`kf_filter_stream`), and the 0-MEM/doctor observability surfaces. M044 **delegates** the token-budget governor to M036a (consumed read-only via the existing SC-3/SC-7 governor — routed through, never modified), the discoverable capture UX + graduation mechanism + SoR documentation to M040, REF-chunk ingest metadata to M036b, and live runtime-memory adapter work to M009. **M044 writes no new graph schema, no new edge types, no new tag namespace.**

## Design Constraints

- **CON-1 (DQ-resolutions binding)** — DQ-1…DQ-8 are resolved; do not re-open without new evidence (captured as AD-1…AD-8 above).
- **CON-2 (Principle-I budget guardrail, both directions)** — the fix must not trade a silent *under*-inject for a silent *over*-inject. Every **read-into-payload** path (FR-5, FR-6) routes through the existing M036a token-budget governor (SC-3/SC-7) and the index-free regression asserts hits *within budget*. **Capture-write (disk row-append) is free and unbudgeted.**
- **CON-3 (determinism on the guarantee path)** — grep fallback + corpus-gate evidence artifact reproducible: `LC_ALL=C` sort, stable file order, no wall-clock in artifact bodies. Same inputs → byte-identical output.
- **CON-4 (preserve genuine archive exclusion)** — FR-4 drops only the bare `*/archive/*` false-match; the intentional `knowledge/archive/` cold-storage exclusion (`rebuild-index.sh:6`) is preserved.
- **CON-5 (one doctor surface)** — FR-15's doctor check reconciles-or-supersedes `papercut-doctor-knowledge-gap-surface.md` into a single consolidated 3-symptom check (0-MEM-on-mature-project / vestigial-index / runtime-memory-divergence). No second overlapping surface.
- **CON-6 (round-trip oracle asserts observed indices)** — AC-1 asserts against the observed awk field indices (`$5` scope / `$6` when), not the documented column order; whichever shape loses DQ-6 is rewritten and CI-checked.
- **AC-1 (acceptance oracle)** — capture→rebuild→grep→assert round-trip over the legacy documented `append-decision.sh`/`append-knowledge.sh` primitives on a **default-intensity (Quick)** fixture, **byte-asserting** the resolved row (byte-equality, not substring — per the fixtures-byte-equality default). Split the **dynamic** round-trip lane from the **static** byte-equality fixtures (do not force a frozen file to contain a runtime-appended row).
- **Dependencies** — M036a token-budget governor (closed 2026-05-02, consumed read-only); `orchestrator-corpus-gate` (shipped, its index-independent grep primitive is the load-bearing asset preserved here, not re-authored); conversus adapter (M011/P07, available — P0 requires no new run, the brief's deliberation is the adversarial pass).
- **Env (bash shape-guard / commit form)** — bash 3.2 compatible; no `cd` in compound commands; no `>2`-link compound chains (`a && b && c`) — separate calls or `scripts/util/run-probe.sh`; commit via `git commit -F <file>` (inline-HEREDOC `-m "$(cat <<'EOF'…)"` is REJECTED by the M021 shape-guard, AP-008).

## Open Questions

These are **plan-time** design questions (resolved by the planner at the named phase against the live dogfood corpus), not operator/SME questions. They do not block roadmap generation.

- **#Q-1 (canonical-column-order)** — DQ-6/AD-6 lock the *oracle* (assert observed awk `$5`/`$6`); the plan must pick which concrete column order becomes the written contract and rewrite the losing shape. Confirm producer-order vs consumer-order is least-disruptive to existing on-disk `DECISIONS.md` files across dogfood projects, and whether a migration of existing rows is needed or the format is forward-only. **Pre-resolved evidence:** the consumer's documented data-row order (`scope-filter.sh:343`: `ID | Decision | Choice | Scope | When | Rationale`) is the order under which `awk -F'|'` `$5`=Scope / `$6`=When already holds; the producer (`append-decision.sh:93`: `ID | When | Scope | Decision | Choice | …`) is therefore the loser to rewrite. *Answered at the FR-1 phase plan-phase.*
- **#Q-2 (stale-detection mechanism)** — P0 detects stale via mtime *or* content-hash. Pick the P0 mechanism (mtime is cheaper; content-hash is the eventual FR-10 contract) and confirm "rebuild-then-warn-if-still-bad" does not add unacceptable mid-dispatch latency. *Answered at the FR-5 phase plan-phase.*
- **#Q-3 (doctor reconciliation shape)** — confirm whether `papercut-doctor-knowledge-gap-surface.md` is *superseded* (deleted/folded) or *reconciled* (its check rewritten into the consolidated one), and that no existing doctor test asserts against the old surface. *Answered at the FR-15 phase plan-phase against the live doctor implementation.*
- **#Q-4 (provenance-header byte-contract version)** — the provenance header is a payload byte-contract consumed downstream. Confirm whether P0 pins a version field now (cheap insurance for the P1 `resolved-id` surface) or defers versioning to the P1 freshness work. *Answered at the FR-5 phase plan-phase.*
