---
schema_version: "1.0"
type: context-draft
milestone: "M036"
feature_ref: "033-reference-corpus-ingest"
status: "finalized"
finalized_at: "2026-04-30"
---

# M036 Context Draft

## Architectural Framing (resolved at roadmap-time)

### Milestone slot

This work lands as **M036** — its own milestone, sequential after the queued M031–M035. Three positions were considered (spec Open Question #Q-1):

- **(a) Own milestone M036 (chosen)** — the seven open questions, the cross-cutting graph + dispatch + wiki concerns, and the 2026-05-15 PBJ validator pilot deadline justify a dedicated roadmap deliberation.
- (b) Re-open M020 as M020.1 — rejected; closed milestones are not idiomatic to re-open in this project.
- (c) Defer post-launch — rejected; the validator pilot window is the load-bearing demand signal that justifies the work now.

**Launch-posture decision**: M036 is positioned as a **post-launch fast-follow** — sequenced after the M031 → M032 → M033 → M029 → M035 launch queue. The minimal-slice (US-1+US-2+US-3) MUST be shippable in time to defend the 2026-05-15 PBJ validator pilot, which means M036 may need to insert ahead of M035 P02–P06 (the publishing pipeline phases) if the launch event slips. Roadmap calls this out as a sequencing risk.

### Phase decomposition strategy

Three SDD flows mapped to phases (per evaluation):

1. **Ingest layer** — own phases for taxonomy + frontmatter contract, ingest command, idempotent re-ingest. Foundation.
2. **Graph + dispatch integration** — own phases for graph schema extension + tag namespace, scope-filter wiring, dispatch payload + token-budget governor. Backwards-compat-gated.
3. **Wiki projection + adapter seam** — own phases for wiki nav generator and the format-adapter dispatch table with PDF/XLS stubs. Distinct surfaces.

Risk-ordered: graph-schema extension is the highest-risk phase (touches multiple downstream consumers); ingest layer is medium (new directory tree, but isolated); wiki + adapter seam are lower (additive, well-bounded).

### Dependencies on prior milestones

Inventoried at roadmap-time, deferred to plan-phase for the precise integration points:

- **M011 (spec-management) / M020 (knowledge-layer maturation)** — knowledge tree, `rebuild-index.sh`, `traverse-graph.sh`. Re-used; additively extended. **Hard dependency** on the existing spec-chunk machinery being functional (it is — both closed).
- **M005 / M018 (dispatch + compression-tier)** — context recipe, scope-filter, dispatch context-builder, tokenizer. Re-used for the `reference:` payload section and budget governor. **Hard dependency** on the recipe schema being declarative (Principle X) — already true.
- **M012 / M032 (wiki tooling)** — MkDocs integration. M032 is **in queue** (pre-launch). **Soft dependency**: M036 wiki-projection phase consumes M032's `--with-wiki` plumbing; if M036 lands before M032 wraps, this phase blocks. Roadmap calls this out as a sequencing dependency.
- **M013 / M014 (GitHub native + spec management gate work)** — initial reading: **NO hard dependency** (per spec Open Question #Q-6). M013/M014's gates fire on spec-shape conformity and Section Contract fidelity, neither of which apply to reference content (which has its own taxonomy + provenance contract). Soft integration points (dual-write helper, M027 metrics surface) are useful but not load-bearing.
- **M027 (cost+quality observability)** — used additively: ingest emits `unit_close` records; dispatch payload emits `reference_chunks_injected`, `reference_tokens_used` fields. Soft dependency.
- **M030 (adaptive model selection)** — soft. Reference-injection touches dispatch payload; the byte-equality invariant SC-11 from M030 is the harness shape this feature's SC-7 inherits.

### Runtime + portability constraints

- CON-2: Bash 3.2 / POSIX-sh + optional jq. No new runtime deps.
- CON-3: text-only test fixtures. No binaries in the repo.
- CON-1 + FR-15 + SC-7: backwards-compat is a hard gate. Golden-baseline diff harness required.

## Decisions Deferred to Plan-Phase

These remain Open Questions in the spec; roadmap explicitly does NOT resolve them:

- #Q-2 Relevance-ordering signal for token-budget governance — research at the dispatch-integration phase.
- #Q-3 Versioning model (supersede chain vs parallel-version retention) — research at the ingest layer phase.
- #Q-4 Storage shape (file-based vs SQLite table) — initial inclination is file-based (minimum delta); plan-phase confirms.
- #Q-5 Fidelity-gate posture (yes/no/per-source-type) — research at the ingest layer phase.
- #Q-7 Tag-namespace collision policy — captured as a DECISION at plan-phase regardless of resolution.

Open Question #Q-1 (milestone slot) and #Q-6 (M013/M014 dependencies) ARE resolved here and reflected in the roadmap.

## Constitution Check (roadmap-level)

- **Principle III (Design Before Code)**: roadmap surfaces the seven load-bearing ambiguities; plan-phase MUST resolve them per principle.
- **Principle XIV (No Speculative Complexity)**: PDF/XLS stubs (FR-13) are minimum-seam; vector retrieval / NotebookLM / binary storage are explicit Non-Goals.
- **Principle XV (Surgical Precision)**: phase boundary maps will declare exact write-sites; existing chunks/edges are extended additively, not modified.
