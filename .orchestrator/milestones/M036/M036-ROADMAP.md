---
schema_version: "1.0"
type: roadmap
milestone: "M036"
feature_ref: "033-reference-corpus-ingest"
feature_spec: "specs/033-reference-corpus-ingest/spec.md"
vision: "Reference materials (regulatory rules, training content, glossaries) become first-class graph-queryable citizens of the orchestrator's knowledge layer, scope-injected into agent dispatch payloads under a token budget."
tier: "C"
created_at: "2026-04-30"
updated_at: "2026-04-30"
---

## Phases

- [ ] **P00**: Foundation — taxonomy SSOT + provenance frontmatter contract + adapter registry seam — "Operator runs `cat references/reference-taxonomy.md` and `cat scripts/dispatch/adapters/format/registry.tsv` and sees the four-category taxonomy and three-row adapter table; new chunks fail validation if they declare a category outside the taxonomy."
  - Risk: low
  - Depends: none
  - Blocked by: none
  - Boundary Map:
    - Produces: `references/reference-taxonomy.md` (SSOT for the four categories: cms-rule, training-material, glossary, regulatory-doc); `references/reference-frontmatter-contract.md` (required fields per FR-2); `scripts/dispatch/adapters/format/registry.tsv` (markdown=live, pdf=stub, xls=stub); declared edge-type list in the existing graph schema doc updated additively for `cites` / `derived_from` / `applies_to_field`; `[source:...]` tag namespace added to `references/spec-management.md` scope-tag grammar section.
    - Consumes: existing graph schema declaration site (for additive edge-type registration); existing scope-tag grammar reference (for namespace addition).

- [ ] **P01**: Ingest layer — reference-ingest command + classifier + chunk emission — "Operator runs `bash scripts/knowledge/ingest-reference.sh --reference-root <path>` against a fixture corpus of 10 markdown files spanning all four categories; afterwards `knowledge/reference/<cat>/REF-*.md` chunks exist for each, the index lists them, and the command exits 0 with `CREATED:` lines for each chunk."
  - Risk: medium
  - Depends: P00
  - Blocked by: none
  - Boundary Map:
    - Produces: `commands/ingest-reference.md`; `scripts/knowledge/ingest-reference.sh` (Bash 3.2); `scripts/knowledge/classify-reference.sh` (taxonomy validator); `knowledge/reference/<cat>/REF-<cat>-<id>.md` (per-chunk detail files); fixture corpus at `tests/fixtures/m036-reference-corpus/`; `tests/test-reference-ingest-fixture.sh` (SC-1, SC-2).
    - Consumes: P00 taxonomy + frontmatter-contract docs; P00 adapter registry (markdown row); existing `scripts/knowledge/rebuild-index.sh` (re-used unmodified per CON-5); existing `knowledge/` directory tree (M011/M020).

- [ ] **P02**: Graph schema extension — new edge types + tag namespace + traverser/scope-filter additive support — "Operator authors a fixture spec chunk `cites: [REF-cms-rule-§483-20]` plus a fixture reference chunk; runs `bash scripts/knowledge/traverse-graph.sh SPEC-requirement-FR-7 --depth 1`; output includes the reference chunk with edge label `cites`. Operator runs `bash scripts/dispatch/scope-filter.sh --tag '[source:cms-pbj-2024-q3]'` and gets matching chunks across spec/memory/reference categories."
  - Risk: high
  - Depends: P00
  - Blocked by: none
  - Boundary Map:
    - Produces: extended `scripts/knowledge/traverse-graph.sh` (recognizes new edge types); extended `scripts/dispatch/scope-filter.sh` (accepts `--tag '[source:...]'`); `tests/test-reference-graph-edges.sh` (SC-4); test that confirms existing `relates_to`/`supersedes` traversal is byte-identical to pre-P02 (regression guard for CON-5).
    - Consumes: P00 graph schema declaration update; existing `relates_to`/`supersedes` traversal code (extended additively).

- [ ] **P03**: Idempotent re-ingest + supersede chain — "Operator runs ingest twice on an unchanged fixture corpus and `git status knowledge/reference/` reports zero modified files (SC-5). Operator mutates one fixture body, re-runs ingest; a `REF-cat-id-v2.md` exists, the prior file's frontmatter has gained `superseded_by:`, and a `REVIEW:` line surfaces for any spec/memory chunk that cites the prior version (SC-6)."
  - Risk: medium
  - Depends: P01
  - Blocked by: none
  - Boundary Map:
    - Produces: content-hash + supersede-chain logic in `scripts/knowledge/ingest-reference.sh` (additive over P01 baseline); `REVIEW:` advisory emission for cross-category citation drift (FR-11); `tests/test-reference-reingest-idempotency.sh` (SC-5); `tests/test-reference-supersede-chain.sh` (SC-6).
    - Consumes: P01 ingest-reference.sh baseline + classifier; P02 graph traversal (to detect dangling cites for `REVIEW:` lines).

- [ ] **P04**: Dispatch context-builder injection + token-budget governor — "Operator dispatches a synthetic task whose plan declares `topic_tags: [pbj-staffing]` and `reference_token_budget: 4000`; the dispatched payload's `reference:` section is ≤4000 tokens, contains ≥1 chunk, and chunks are dropped at chunk-level granularity when over budget (SC-3). A task plan with no `topic_tags` and no `applies_to_field` produces a payload byte-identical to the pre-feature payload (SC-7 golden-baseline diff)."
  - Risk: high
  - Depends: P01, P02
  - Blocked by: none
  - Boundary Map:
    - Produces: extended `context-recipe.yaml` (new declarative `reference:` section per Principle X / Principle XIII); reference-injection logic in `scripts/dispatch/build-context.sh` (or its successor) hooked behind the recipe; token-budget governor (algorithm decided at plan-phase per Open Question #Q-2); `tests/test-reference-dispatch-injection.sh` (SC-3); `tests/test-reference-backwards-compat-golden.sh` (SC-7, M030 SC-11 shape).
    - Consumes: P01 reference chunks + index; P02 scope-filter `--tag '[source:...]'` + traverse-graph edges; existing tokenizer (M018); existing dispatch context-builder + recipe machinery (M005/M018).

- [ ] **P05**: Wiki projection — "Operator runs `mkdocs build` after ingest + index rebuild; the rendered site nav contains `Reference > CMS Rules`, `Reference > Training Materials`, `Reference > Glossary`, `Reference > Regulatory Docs` (SC-8); inline `cites` references in spec pages render as cross-doc links to the reference chunk's wiki page."
  - Risk: low
  - Depends: P01, P02
  - Blocked by: M032 wiki tooling (`--with-wiki` plumbing) closure
  - Boundary Map:
    - Produces: extended `wiki/` nav generator (or template fragment) that reads `knowledge/reference/**` and emits the `Reference` nav section; cross-doc link template for `cites:` frontmatter; `tests/test-reference-wiki-projection.sh` (SC-8).
    - Consumes: P01 reference chunks; P02 edge-graph for cross-doc rendering; existing wiki tooling from M012 (and M032 distribution plumbing once shipped).

- [ ] **P06**: PDF/XLS adapter stubs — "Operator invokes `bash scripts/dispatch/adapters/format/pdf.sh <fixture-pdf>` and the stub exits 2 with stderr containing the documented markdown-floor pointer (SC-9); the markdown adapter exits 0 on a fixture markdown file; the adapter registry from P00 lists pdf=stub, xls=stub, markdown=live."
  - Risk: low
  - Depends: P00
  - Blocked by: none
  - Boundary Map:
    - Produces: `scripts/dispatch/adapters/format/markdown.sh` (live); `scripts/dispatch/adapters/format/pdf.sh` (stub: exit 2 + pointer); `scripts/dispatch/adapters/format/xls.sh` (stub: exit 2 + pointer); `tests/test-reference-adapter-stubs.sh` (SC-9, SC-10 — no-binary-leak verification).
    - Consumes: P00 adapter registry; existing dispatch adapter convention (`scripts/dispatch/adapters/`).

## Cross-Cutting Concerns

- **Backwards-compat gate (CON-1 / FR-15 / SC-7)** — P02, P04. P04 establishes the golden-baseline diff harness (M030 SC-11 shape). Every phase touching the graph schema (P02) or dispatch payload (P04) MUST verify byte-equality of the pre-feature path before marking the phase complete. Verification commands belong in each phase plan's mandatory verification section.

- **Idempotency invariant (CON-4)** — P01, P03, P05. P01 establishes the ingest emission contract (`CREATED:` / `SKIPPED:` / `SUPERSEDED:` / `REMOVED:` / `REVIEW:` lines) matching `commands/ingest.md` precedent. P03 extends with the supersede chain. P05 wiki regeneration MUST produce byte-identical nav output on unchanged input. Re-running every command from this milestone twice on unchanged inputs MUST produce zero `git diff`.

- **Single Source of Truth (Principle XI)** — P00, P01, P02, P05. The taxonomy (P00), edge-type list (P00), and tag namespace (P00) each have exactly one authoritative declaration. P01 ingest classifier reads the taxonomy doc; P02 traverser reads the edge-type list; P05 wiki nav reads the taxonomy. No phase shall hardcode any of these lists.

- **Provenance fidelity (FR-4 / NG-5)** — P01, P03, P05. Reference chunk bodies are stored verbatim from source markdown — no LLM rewrite during ingest. P03 supersede chain preserves the prior version unmodified. P05 wiki projection renders source content verbatim (modulo MkDocs rendering of markdown). Test fixtures verify byte-equality of source body → chunk body across the pipeline.

- **No-binary-leak (NG-3 / FR-14 / SC-10)** — P01, P06. P01's ingest MUST reject or ignore binary files in the reference root without copying bytes. P06's stub adapters MUST NOT process binary content. Test SC-10 (`test-reference-adapter-stubs.sh` per phase plan) checksums the destination tree before/after to confirm no binary writes anywhere under `.orchestrator/` or `knowledge/`.

- **Plan-phase open questions (#Q-2..#Q-5, #Q-7)** — P01 (versioning model #Q-3, fidelity gate #Q-5), P03 (versioning), P04 (relevance signal #Q-2, table-shape #Q-4), all-phases (tag-namespace policy #Q-7). Each phase plan MUST resolve its applicable open questions before task generation; resolutions append to `.orchestrator/DECISIONS.md` with the milestone scope tag.

## Dependency Graph

```
                    ┌─→ P03 (idempotency / supersede)
P00 (foundation) ──→ P01 (ingest) ──┤
                    │               └─→ P04 (dispatch injection)
                    │                    ↑
                    └─→ P02 (graph) ─────┘
                    │   │
                    │   └─→ P05 (wiki projection)
                    │       ↑
                    │       └── P01 (chunks)
                    │
                    └─→ P06 (adapter stubs)
```

Edge legend: `→` = dependency. P05 has two parents (P01 + P02). P04 has two parents (P01 + P02).

## Execution Order

1. **P00** — foundation; establishes taxonomy + frontmatter contract + edge-type list + adapter registry. No dependencies. **Sequential, must complete first.**
2. **P01, P02, P06** — can execute concurrently once P00 completes. All depend only on P00.
   - P02 is highest risk (cross-cutting graph touch) — start P02 first if executing sequentially under autonomous mode (FR-043 risk-ordering rule).
   - P01 is medium risk; P06 is low risk.
3. **P03** — depends on P01; can start as soon as P01 completes (does not need P02 or P06).
4. **P04** — depends on P01 AND P02; must wait for both. Highest-risk phase in the milestone (backwards-compat gate). Plan-phase research required for governor algorithm (#Q-2).
5. **P05** — depends on P01 AND P02. Externally blocked by M032 wiki tooling closure (see Blocked by on P05). Can start once both internal deps complete IF M032 is shipped; otherwise queues until unblocked.

**Concurrent execution windows under `orchestrator:auto`**:

- Window A (post-P00): P01 + P02 + P06 in parallel.
- Window B (post-P01 only): P03 in parallel with continuing P02 + P06.
- Window C (post-P01 AND post-P02): P04 + P05 in parallel (P05 if M032 cleared).

**Validator-pilot defense path (2026-05-15 deadline)**: P00 → P01 → P02 → P04 is the critical path for the minimal slice (US-1 + US-2 + US-3). P03, P05, P06 do not gate the pilot window and may slip without harming launch. Critical path is 4 phases; sequencing target ≤3 weeks for the critical path under aggressive execution.

## Validation

- **No conflicting producers**: PASS — every produced artifact (file path, command, script) appears in exactly one phase's `Produces` list. Verified by manual inventory across the seven phases. Notable additive extensions (`traverse-graph.sh`, `scope-filter.sh`, `build-context.sh`, the wiki nav generator) are extended additively in their owning phase only; no phase modifies an artifact another phase also modifies.

- **All consumed items have producers**: PASS — every `Consumes` entry traces to either (a) a `Produces` entry in an upstream phase (P01 → P03/P04/P05; P02 → P04/P05; P00 → P01/P02/P06) or (b) an existing artifact from a prior milestone (rebuild-index.sh / knowledge/ tree from M011/M020; tokenizer from M018; dispatch context-builder from M005/M018; wiki tooling from M012/M032). External milestone dependencies are explicitly enumerated in the M036-CONTEXT.md context draft.

- **DAG is acyclic**: PASS — topological sort yields P00 → {P01, P02, P06} → {P03, P04, P05}. No phase depends (directly or transitively) on a phase later in the order. Verified by visual inspection of the dependency graph above.

- **Demo sentence coverage**: PASS — every phase has a concrete demo sentence naming the exact command(s) the operator runs and the observable outcome (file existence, exit code, stderr content, or git status output). No vague descriptions.

- **Cross-cutting concern coverage**: PASS — five cross-cutting concerns enumerated; each names the establishing phase and the consuming phases.

- **Open-question deferral**: PASS — five plan-phase open questions (#Q-2, #Q-3, #Q-4, #Q-5, #Q-7) are mapped to the phases that must resolve them. Two open questions (#Q-1 milestone slot, #Q-6 M013/M014 dependencies) are roadmap-resolved in M036-CONTEXT.md.
