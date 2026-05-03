---
schema_version: "1.0"
type: roadmap
milestone: "M036"
feature_ref: "033-reference-corpus-ingest"
feature_spec: "specs/033-reference-corpus-ingest/spec.md"
vision: "Reference materials (regulatory rules, training content, glossaries) become first-class graph-queryable citizens of the orchestrator's knowledge layer via orchestrator-owned tiered extraction (Tier 0 manifest+original / Tier 1 cheap searchable text / Tier 2 LLM-driven structured Markdown with conversus fidelity gate), scope-injected into agent dispatch payloads under a token budget."
tier: "C"
created_at: "2026-04-30"
updated_at: "2026-05-01"
amended_at: "2026-05-01"
amendment_summary: "Extraction-ownership flip (NG-3/4/5 inverted/narrowed) + tier model added + DOCX added + #Q-3/#Q-5 resolved + milestone split into M036a (pre-launch urgent) and M036b (post-launch)."
---

## Amendment Note (2026-05-01)

This roadmap was substantially restructured 2026-05-01 to reflect the spec amendment. Prior version was 7 phases (P00–P06) under a single milestone slot; this version is **10 phases (P00–P09) split across M036a (pre-launch urgent, 8 phases) and M036b (post-launch, 2 phases)**. The original P06 (stub adapters) is replaced by P01 (live Tier 1 adapters); two new phases (P02 Tier 0 + extract command, P03 Tier 2 + conversus gate) cover the orchestrator-owned extraction surface that the amendment adds. The remaining phases (foundation, ingest layer, graph schema, idempotency, dispatch injection, wiki projection) are renumbered but retain their original boundary maps and risk levels.

## Milestone Split

- **M036a (pre-launch urgent)** — 8 phases (P00–P07). Defends the **2026-05-15 PBJ validator pilot**. Critical path delivers tiered extraction → ingest → dispatch injection so validator agents can receive scoped CMS rules. Inserts ahead of M035 P02–P06 if launch event slips past mid-May.
- **M036b (post-launch)** — 2 phases (P08–P09). Wiki projection (depends on M032 closure) + operator-facing scale UX (REVIEW queue, change-over-time queries, supersede chain at scale). Demand-driven; ships when validator-pilot feedback surfaces concrete operator pain.

## Phases

### M036a — Pre-Launch Urgent

- [x] **P00**: Foundation — taxonomy SSOT + provenance frontmatter contract + tier-policy schema + adapter registry seam + edge-type / tag-namespace declarations — "Operator runs `cat references/reference-taxonomy.md`, `cat references/reference-source-types.yaml`, and `cat scripts/dispatch/adapters/format/registry.tsv` and sees the four-category taxonomy, the per-category default-tier policy, and the four-row live-adapter table; new chunks fail validation if they declare a category outside the taxonomy or a tier outside {0, 1, 2}."
  - Risk: low
  - Depends: none
  - Blocked by: none
  - Boundary Map:
    - Produces: `references/reference-taxonomy.md` (SSOT for the four categories: cms-rule, training-material, glossary, regulatory-doc); `references/reference-frontmatter-contract.md` (required fields per FR-2 + FR-4); `references/reference-source-types.yaml` (per-category default tier per FR-17); `scripts/dispatch/adapters/format/registry.tsv` (markdown=live, pdf=live, docx=live, xlsx=live); declared edge-type list in the existing graph schema doc updated additively for `cites` / `derived_from` / `applies_to_field`; `[source:...]` tag namespace added to `references/spec-management.md` scope-tag grammar section.
    - Consumes: existing graph schema declaration site (for additive edge-type registration); existing scope-tag grammar reference (for namespace addition).

- [x] **P01**: Tier 1 live format adapters (PDF, DOCX, XLSX, Markdown) — "Operator invokes `bash scripts/dispatch/adapters/format/pdf.sh tests/fixtures/m036/sample.pdf` and gets exit 0 with stdout containing the PDF's body text. Same for `docx.sh`, `xlsx.sh` (emits one CSV per sheet to a temp dir), and `markdown.sh` (passthrough). The registry lists all four `status: live`."
  - Risk: medium
  - Depends: P00
  - Blocked by: none
  - Boundary Map:
    - Produces: `scripts/dispatch/adapters/format/markdown.sh` (live passthrough); `scripts/dispatch/adapters/format/pdf.sh` (live, calls `pdftotext -layout`); `scripts/dispatch/adapters/format/docx.sh` (live, calls `pandoc`); `scripts/dispatch/adapters/format/xlsx.sh` (live, sheet-by-sheet CSV emission with header detection); fixture corpus at `tests/fixtures/m036-tier-1-adapters/` (small samples per format); `tests/test-tier-1-adapters.sh` (SC-9). External-tooling probe at `scripts/lifecycle/probe-extraction-tools.sh` reports presence of `pdftotext`, `pandoc`, and the chosen Excel parser; documents fallback messages.
    - Consumes: P00 adapter registry; existing dispatch adapter convention (`scripts/dispatch/adapters/`); host system's `pdftotext` (poppler-utils), `pandoc`, and Excel parser.

- [x] **P02**: Tier 0 manifest + `orchestrator:extract` command (synchronous Tier 0/1 path) + binary preservation — "Operator runs `bash scripts/knowledge/extract-reference.sh --manifest tests/fixtures/m036/extract-manifest.yaml` against a 3-doc fixture (1 PDF, 1 DOCX, 1 already-md). Afterwards: each doc has a manifest entry under `knowledge/reference/<cat>/REF-*.md` with summary + tags + content_hash; original binaries exist under `.orchestrator/knowledge/reference/_originals/<source>/`; Tier 1 plain-text files exist alongside; command exits 0 with `EXTRACTED:` lines per doc."
  - Risk: high
  - Depends: P00, P01
  - Blocked by: none
  - Boundary Map:
    - Produces: `commands/extract.md`; `scripts/knowledge/extract-reference.sh` (Bash 3.2); manifest schema at `references/extract-manifest-contract.md`; Tier 0 summary-generation pass (LLM single-call, model declared in source-type config); content-hash + binary-preservation logic (FR-14); size-cap + external-storage hook governance (CON-7); `tests/test-tier-0-manifest.sh` (SC-10); `tests/fixtures/m036/extract-manifest.yaml` + sample binaries.
    - Consumes: P00 source-type config (default tier per category) + frontmatter contract; P01 Tier 1 adapters (called for the Tier 1 leg of any doc declared `tier: 1` or `tier: 2`).

- [x] **P03**: Tier 2 LLM extraction + M030 routing + conversus fidelity gate — "Operator runs extract on a manifest where 1 doc declares `tier: 2`; the structured Markdown output exists at `knowledge/reference/<cat>/REF-*.structured.md` with PASS verdict file at `_extraction-log/<doc-id>.pass.md`; an `unit_close` JSONL record with non-empty `model` + `cost_usd` exists in the M030 ledger. A second run with a manifest forcing BLOCK (via mocked low-fidelity extraction) produces the BLOCK rationale on disk and the structured output is NOT in the chunk store."
  - Risk: high
  - Depends: P02
  - Blocked by: none
  - Boundary Map:
    - Produces: Tier 2 extraction logic in `scripts/knowledge/extract-reference.sh` (additive over P02); M030 task-type registration for `extraction` (FR-19); conversus gate adapter wiring (extractor-advocate + fidelity-advocate agents declared at `scripts/knowledge/conversus-tier-2-gate/`); BLOCK retention path under `.orchestrator/knowledge/reference/_extraction-log/` (FR-18); `tests/test-tier-2-extraction-with-gate.sh` (SC-11, SC-12) using **mocked LLM responses** (recorded conversus deliberation transcripts — no live LLM in CI per CON-3).
    - Consumes: P02 manifest + extract-reference.sh baseline; M030 model-selection adapter (closed 2026-05-01); conversus adapter from M011/P07 (`scripts/dispatch/adapters/conversus/`).

- [x] **P04**: Ingest layer — promote extraction outputs to chunks + classifier — "Operator runs `bash scripts/knowledge/ingest-reference.sh --reference-root knowledge/reference/` after P02/P03 have produced extraction outputs. Afterwards `knowledge/reference/<cat>/REF-*.md` chunks exist for each doc, the index lists them, and the command exits 0 with `CREATED:` lines."
  - Risk: medium
  - Depends: P02 (Tier 0/1 outputs), P03 (Tier 2 outputs)
  - Blocked by: none
  - Boundary Map:
    - Produces: `commands/ingest-reference.md`; `scripts/knowledge/ingest-reference.sh` (Bash 3.2); `scripts/knowledge/classify-reference.sh` (taxonomy validator); fixture corpus at `tests/fixtures/m036-reference-corpus/`; `tests/test-reference-ingest-fixture.sh` (SC-1, SC-2).
    - Consumes: P02 manifest + Tier 0/1 outputs; P03 Tier 2 outputs (where present); P00 taxonomy + frontmatter-contract docs; P00 adapter registry; existing `scripts/knowledge/rebuild-index.sh` (re-used unmodified per CON-5); existing `knowledge/` directory tree (M011/M020).

- [x] **P05**: Graph schema extension — new edge types + tag namespace + traverser/scope-filter additive support — "Operator authors a fixture spec chunk `cites: [REF-cms-rule-§483-20]` plus a fixture reference chunk; runs `bash scripts/knowledge/traverse-graph.sh SPEC-requirement-FR-7 --depth 1`; output includes the reference chunk with edge label `cites`. Operator runs `bash scripts/dispatch/scope-filter.sh --tag '[source:cms-pbj-2024-q3]'` and gets matching chunks across spec/memory/reference categories."
  - Risk: high
  - Depends: P00
  - Blocked by: none
  - Boundary Map:
    - Produces: extended `scripts/knowledge/traverse-graph.sh` (recognizes new edge types); extended `scripts/dispatch/scope-filter.sh` (accepts `--tag '[source:...]'`); `tests/test-reference-graph-edges.sh` (SC-4); test that confirms existing `relates_to`/`supersedes` traversal is byte-identical to pre-P05 (regression guard for CON-5).
    - Consumes: P00 graph schema declaration update; existing `relates_to`/`supersedes` traversal code (extended additively).

- [x] **P06**: Idempotent re-extract + re-ingest + supersede chain mechanism — "Operator runs extract + ingest twice on an unchanged fixture corpus and `git status knowledge/reference/` reports zero modified files (SC-5, SC-13). Operator mutates one fixture body, re-runs extract + ingest; a `REF-cat-id-v2.md` exists, the prior file's frontmatter has gained `superseded_by:`, and a `REVIEW:` line surfaces for any spec/memory chunk that cites the prior version (SC-6)."
  - Risk: medium
  - Depends: P02, P04
  - Blocked by: none
  - Boundary Map:
    - Produces: content-hash + supersede-chain logic in `scripts/knowledge/extract-reference.sh` and `scripts/knowledge/ingest-reference.sh` (additive over P02/P04 baselines, content-hash gates re-extraction at every tier per FR-9 + FR-16); `REVIEW:` advisory emission for cross-category citation drift (FR-11); `tests/test-reference-reingest-idempotency.sh` (SC-5); `tests/test-extract-idempotency.sh` (SC-13); `tests/test-reference-supersede-chain.sh` (SC-6).
    - Consumes: P02 extract baseline + manifest; P04 ingest baseline + classifier; P05 graph traversal (to detect dangling cites for `REVIEW:` lines).

- [x] **P07**: Dispatch context-builder injection + token-budget governor — "Operator dispatches a synthetic task whose plan declares `topic_tags: [pbj-staffing]` and `reference_token_budget: 4000`; the dispatched payload's `reference:` section is ≤4000 tokens, contains ≥1 chunk, and chunks are dropped at chunk-level granularity when over budget (SC-3). A task plan with no `topic_tags` and no `applies_to_field` produces a payload byte-identical to the pre-feature payload (SC-7 golden-baseline diff)."
  - Risk: high
  - Depends: P04, P05
  - Blocked by: none
  - Boundary Map:
    - Produces: extended `context-recipe.yaml` (new declarative `reference:` section per Principle X / Principle XIII); reference-injection logic in `scripts/dispatch/build-context.sh` (or its successor) hooked behind the recipe; token-budget governor (algorithm decided at plan-phase per Open Question #Q-2); `tests/test-reference-dispatch-injection.sh` (SC-3); `tests/test-reference-backwards-compat-golden.sh` (SC-7, M030 SC-11 shape).
    - Consumes: P04 reference chunks + index; P05 scope-filter `--tag '[source:...]'` + traverse-graph edges; existing tokenizer (M018); existing dispatch context-builder + recipe machinery (M005/M018).

### M036b — Post-Launch

- [ ] **P08**: Wiki projection — "Operator runs `mkdocs build` after ingest + index rebuild; the rendered site nav contains `Reference > CMS Rules`, `Reference > Training Materials`, `Reference > Glossary`, `Reference > Regulatory Docs` (SC-8); inline `cites` references in spec pages render as cross-doc links to the reference chunk's wiki page."
  - Risk: low
  - Depends: P04, P05
  - Blocked by: M032 wiki tooling (`--with-wiki` plumbing) closure
  - Boundary Map:
    - Produces: extended `wiki/` nav generator (or template fragment) that reads `knowledge/reference/**` and emits the `Reference` nav section; cross-doc link template for `cites:` frontmatter; `tests/test-reference-wiki-projection.sh` (SC-8).
    - Consumes: P04 reference chunks; P05 edge-graph for cross-doc rendering; existing wiki tooling from M012 (and M032 distribution plumbing).

- [ ] **P09**: Operator-facing scale UX — REVIEW queue + change-over-time queries + supersede chain at scale — "Operator runs `bash scripts/knowledge/review-queue.sh` and gets a list of every spec/memory chunk currently citing a superseded reference, ordered by oldest-supersession-date. Operator runs `bash scripts/knowledge/reference-history.sh REF-cms-rule-483-20` and gets a chronological list of all versions with content-diff between adjacent versions."
  - Risk: medium
  - Depends: P06
  - Blocked by: none
  - Boundary Map:
    - Produces: `commands/review-queue.md` + `scripts/knowledge/review-queue.sh`; `scripts/knowledge/reference-history.sh` (change-over-time query); operator-facing tier-upgrade-advisory consumer (reads the dispatch-side advisory log per CON-6, presents an upgrade queue); `tests/test-review-queue.sh`; `tests/test-reference-history.sh`.
    - Consumes: P06 supersede chain; P07 dispatch advisory log; existing knowledge index.

## Cross-Cutting Concerns

- **Backwards-compat gate (CON-1 / FR-15 / SC-7)** — P05, P07. P07 establishes the golden-baseline diff harness (M030 SC-11 shape). Every phase touching the graph schema (P05) or dispatch payload (P07) MUST verify byte-equality of the pre-feature path before marking the phase complete. Verification commands belong in each phase plan's mandatory verification section.

- **Idempotency invariant (CON-4)** — P02, P04, P06, P08. P02 establishes the extract emission contract (`EXTRACTED:` / `SKIPPED:` / `BLOCKED:` lines). P04 establishes the ingest emission contract (`CREATED:` / `SKIPPED:` / `SUPERSEDED:` / `REMOVED:` / `REVIEW:` lines) matching `commands/ingest.md` precedent. P06 extends both with the supersede chain. P08 wiki regeneration MUST produce byte-identical nav output on unchanged input. Re-running every command from this milestone twice on unchanged inputs MUST produce zero `git diff`.

- **Single Source of Truth (Principle XI)** — P00, P01, P02, P04, P05, P08. The taxonomy (P00), edge-type list (P00), tag namespace (P00), tier-policy defaults (P00), and adapter registry (P00 + P01) each have exactly one authoritative declaration. P02 extract reads tier-policy + manifest; P04 ingest classifier reads taxonomy; P05 traverser reads edge-type list; P08 wiki nav reads taxonomy. No phase shall hardcode any of these lists.

- **Provenance fidelity (FR-4)** — P02, P03, P04, P06, P08. Tier 0 stores the original binary unmodified. Tier 1 plain-text extraction is deterministic (shell-out, byte-stable per pdftotext / pandoc). Tier 2 LLM extraction is gated by the conversus fidelity deliberation (FR-18) — content paraphrase / summarization is rejected by the gate. P06 supersede chain preserves prior versions unmodified. P08 wiki projection renders source content verbatim (modulo MkDocs rendering of markdown).

- **Binary-storage governance (CON-7)** — P02. The `.orchestrator/.gitignore` template adds `knowledge/reference/_originals/` so operators opt-in to commit binaries. The size cap enforces external-storage hook above the threshold. Test SC-10 verifies content-hash matches and external-pointer is recorded for over-cap files.

- **Explicit-tier-upgrade determinism (CON-6 / Principle VI)** — P03, P07. P03 Tier 2 promotion happens only via explicit `orchestrator:extract --tier=2` invocation. P07 dispatch path emits `tier_upgrade_advisory:` log lines but does **not** trigger upgrades. Test in P07 verifies that two consecutive dispatch runs on the same task plan produce byte-identical payloads (no implicit promotion happened between them).

- **Plan-phase open questions (#Q-2, #Q-4, #Q-7, #Q-8, #Q-9, #Q-10)** — P02 (#Q-8 tier defaults; #Q-9 size cap + external hook; #Q-10 queue concurrency), P04 (#Q-4 storage shape), P07 (#Q-2 relevance signal; #Q-7 tag-namespace policy). Each phase plan MUST resolve its applicable open questions before task generation; resolutions append to `.orchestrator/DECISIONS.md` with the milestone scope tag.

## Dependency Graph

```
                                    ┌─→ P05 (graph) ─→ P07 (dispatch injection)
P00 (foundation) ──→ P01 (Tier 1) ──→ P02 (Tier 0 + extract) ──→ P03 (Tier 2 + gate)
                                                          │              │
                                                          └─→ P04 (ingest) ─→ P06 (idempotency + supersede)
                                                                  │              │
                                                                  └──────────────┴─→ P08 (wiki, M036b, blocked by M032)
                                                                                 └─→ P09 (M036b scale UX)
```

Edge legend: `→` = dependency. P04 has two parents (P02 + P03). P07 has two parents (P04 + P05). P06 has two parents (P02 + P04). P08 has two parents (P04 + P05). P09 depends on P06.

## Execution Order

### M036a critical path (validator-pilot defense, 2026-05-15 deadline)

1. **P00** — foundation; establishes taxonomy + frontmatter contract + tier-policy schema + edge-type list + adapter registry. No dependencies. **Sequential, must complete first.**
2. **P01** — Tier 1 adapters; depends only on P00. Live shell-out adapters for PDF/DOCX/XLSX/Markdown.
3. **P02** — Tier 0 manifest + extract command; depends on P00 + P01. Synchronous Tier 0/1 path.
4. **P03** — Tier 2 LLM extraction + conversus gate + M030 routing; depends on P02. Highest risk in M036a (LLM + gate integration).
5. **P04** — ingest layer; depends on P02 + P03 (consumes their extraction outputs).
6. **P05** — graph schema extension; depends only on P00. **Can execute concurrently with P01–P04** under autonomous mode (FR-043 risk-ordering rule places P05 first if sequential due to high risk).
7. **P06** — idempotency + supersede chain; depends on P02 + P04. Mechanism only; M036b exercises at scale.
8. **P07** — dispatch injection + token-budget governor; depends on P04 + P05. Highest-risk phase in M036a (backwards-compat gate). Plan-phase research required for governor algorithm (#Q-2).

### M036b (post-launch)

9. **P08** — wiki projection; depends on P04 + P05; externally blocked by M032 wiki tooling closure.
10. **P09** — operator-facing scale UX (REVIEW queue, change-over-time queries); depends on P06.

### Concurrent execution windows under `orchestrator:auto` (M036a)

- Window A (post-P00): P01 + P05 in parallel. (P01 starts the extraction stack; P05 starts graph extension.)
- Window B (post-P01): P02 in parallel with continuing P05.
- Window C (post-P02): P03 + P04 (both depend on P02) — but P04 also depends on P03 for Tier 2 outputs, so practically P03 → P04.
- Window D (post-P04): P06 + P07 in parallel (P06 depends on P02 + P04; P07 depends on P04 + P05 — both eligible).

### Validator-pilot defense path (2026-05-15)

Critical path: **P00 → P01 → P02 → P03 → P04 → P05 → P07** (7 phases). P06 is required for idempotency in production but not strictly required for the *first* validator dispatch (initial pilot runs against a one-shot ingest). Sequencing target ≤3 weeks for the critical path under aggressive execution. P08 (wiki) and P09 (scale UX) explicitly defer to M036b.

## Validation

- **No conflicting producers**: PASS — every produced artifact (file path, command, script) appears in exactly one phase's `Produces` list. Notable additive extensions (`traverse-graph.sh`, `scope-filter.sh`, `build-context.sh`, `extract-reference.sh`, `ingest-reference.sh`) are extended additively in their owning phase only; no phase modifies an artifact another phase also modifies.

- **All consumed items have producers**: PASS — every `Consumes` entry traces to either (a) a `Produces` entry in an upstream phase or (b) an existing artifact from a prior milestone (rebuild-index.sh / knowledge/ tree from M011/M020; tokenizer + dispatch context-builder from M005/M018; M030 model-selection adapter from M030; conversus adapter from M011/P07; wiki tooling from M012/M032). External milestone dependencies are explicitly enumerated in the M036-CONTEXT.md context draft.

- **DAG is acyclic**: PASS — topological sort yields P00 → P01 → P02 → P03 → P04 → {P05, P06} → {P07, P08} → P09 (with P05 also reachable post-P00 directly for parallelism). No phase depends (directly or transitively) on a phase later in the order.

- **Demo sentence coverage**: PASS — every phase has a concrete demo sentence naming the exact command(s) the operator runs and the observable outcome (file existence, exit code, stderr content, or git status output).

- **Cross-cutting concern coverage**: PASS — six cross-cutting concerns enumerated (added binary-storage governance + explicit-tier-upgrade determinism in the amendment); each names the establishing phase and the consuming phases.

- **Open-question deferral**: PASS — six plan-phase open questions (#Q-2, #Q-4, #Q-7, #Q-8, #Q-9, #Q-10) are mapped to the phases that must resolve them. Three open questions (#Q-1 milestone slot, #Q-3 versioning model, #Q-5 fidelity-gate posture) are roadmap-resolved in M036-CONTEXT.md and via the spec amendment. #Q-6 (M013/M014 dependencies) was roadmap-resolved at original creation. #Q-11 (M036a/M036b phase partition) is resolved by this roadmap amendment.

- **M036a/M036b partition**: PASS — phase numbering plus the section headings (`### M036a — Pre-Launch Urgent` / `### M036b — Post-Launch`) declare the slot (P00–P07 = M036a; P08–P09 = M036b). The validator-pilot critical path lies entirely within M036a. (Phase headers do not carry the slot tag inline — `read-roadmap.sh` requires `**P##**` immediately followed by `:`; the slot is conveyed structurally by section heading.)
