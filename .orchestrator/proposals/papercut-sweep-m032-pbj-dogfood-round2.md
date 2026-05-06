# Paper-cut Sweep round 2 — M032 wiki tooling, PBJ-central dogfood

**Status:** Active — patches landing this commit.
**Authored:** 2026-05-06.
**Surfaced by:** PBJ-central-mono-repo's second wiki-tooling pass after
the round-1 sweep (B1–B4) landed in commit `e4c3c8f7`. Three new
findings + one separate-domain ergonomic.

## Why a second sweep

Round 1 closed the immediate `mkdocs build --strict` blockers (extra:*
index emission, legacy nav: leak, top:/extra: collision detection,
sibling-map labels). Round 2 surfaces the issues that round-1 deferred
or didn't yet have reproducers for:

- **B5** was deferred in round 1 ("validate before patching"). PBJ
  reproduced it cleanly with a concrete reproducer — not just
  `--strict` warnings, **silent runtime breakage**: fragment-only
  `#anchor` links rewritten to `../../.orchestrator#anchor` (404).
- **B7** is new — the largest single visible gap. M036 reference-corpus
  chunks are metadata-only by design (frontmatter + `|` body) with real
  content in `<basename>.text.md` siblings. Current `extra:*` arm
  ignores siblings → ~150+ blank pages in PBJ-central.
- **B8** is new — empty-subdir knowledge indexes flagged as orphan by
  mkdocs.

All fixes localized to `scripts/wiki/` plus regression fixtures under
`tests/m032-acceptance/`. Same paper-cut-sweep cadence as round 1; same
shape (Tier A, regression fixtures, single-commit). Closure invariants
untouched (the M032 acceptance battery file is off-limits per the
"zero modifications to upstream deliverables" comment).

## Bugs in scope (B5, B7, B8)

### B5 — Fragment-only `#anchor` links rewritten to source-relative

**Location:** `scripts/wiki/wiki-generate-stubs.sh` `write_stub()` and
all routing arms emitting top:* singletons / proposals / knowledge-flat.

**Symptom:** `mkdocs-include-markdown-plugin`'s
`rewrite-relative-urls=true` rewrites fragment-only links by prepending
the relative path from includer to source. `[link](#process-and-cycle)`
in `.orchestrator/DECISIONS.md` projected into `wiki/docs/decisions.md`
becomes `[link](../../.orchestrator#process-and-cycle)` → silent 404.
PBJ reproducer:

```bash
curl -s http://127.0.0.1:8000/pbj-central-mono-repo/decisions/ \
  | grep -oE 'href="[^"]*process-and-cycle[^"]*"' | sort -u
# returns href="#process-and-cycle-commitments" AND
#         href="../../.orchestrator#process-and-cycle-commitments"
```

**Fix shape selected:** **per-routing-arm `rewrite-relative-urls`
toggle** (option 1 from the deferred brief, narrowed). `write_stub()`
gains an optional `<rewrite-relative-urls>` parameter (default `true`
to preserve current milestone/archive sibling-doc rewriting).
Singleton top-level docs that primarily use fragment-only intra-doc
anchors opt out:

- `top:constitution` / `top:decisions` / `top:knowledge` / `top:milestone-summary` / `top:glossary` → `false`
- `proposals:*` → `false`
- `knowledge-flat` → `false`
- `extra:*` (default include path) → `false` (per-chunk docs are
  typically self-contained; fragment-only passthrough is safer than
  rewriting all relative links to source-relative)
- `milestone:*` / `archive:*` → `true` (unchanged — they have many
  sibling-doc cross-refs that depend on rewriting)

This is the **minimum acceptance bar** from the round-1 brief: fragment-
only links pass through untouched. Broader rewrite-relative-urls
semantics for non-fragment cross-doc links inside top-level singletons
remains deferred — author convention + ad-hoc fixes cover that surface
today, and the singleton docs are mostly self-referential anyway.

**Trade-off accepted:** cross-doc links from `DECISIONS.md` /
`KNOWLEDGE.md` / similar to sibling docs (`knowledge/MEM004.md`) will
no longer be rewritten by include-markdown. In practice these top-level
docs have very few such links (most cross-refs are anchor-based).
Consumers can either inline the link target as text, switch to absolute
repo-root paths, or accept the 404. The cost of this trade-off is
strictly less than the silent runtime breakage of the status quo.

**Regression fixture:** `tests/m032-acceptance/p0X-pbj-b5-fragment-only-passthrough.sh`
— synthetic top:* docs with fragment-only anchors, run stubs, assert
each routing arm emits `rewrite-relative-urls=false`; control case for
milestone:* keeps `=true`.

### B7 — `extra:*` stubs miss `.text.md` siblings; scanner double-emits

**Locations:**
- `scripts/wiki/wiki-scan-sources.sh` `scan_extra_dir()` — sibling-suppression.
- `scripts/wiki/wiki-generate-stubs.sh` `extra:*` routing arm — body-empty + sibling detection.

**Symptom:** M036 reference-corpus chunks pair a metadata `.md` (frontmatter
+ literal `|` body placeholder) with a Tier-1-extracted `.text.md`
sibling carrying the real content. Current behavior:

1. Scanner walks `extra_dirs/*` and emits records for both `<basename>.md`
   and `<basename>.text.md` → duplicate nav entries (e.g., `REF-foo`
   and `REF-foo.text` side-by-side).
2. Stub generator's `extra:*` arm includes the metadata `.md` directly
   → wiki page renders only frontmatter + a literal `|` (~150+ blank
   pages in PBJ-central).

**Fix:**

1. **Scanner-side sibling suppression.** In `scan_extra_dir`, skip
   `*.text.md` files whose `<basename>.md` sibling exists in the same
   dir. Collapses duplicate nav entries.

2. **Body-empty heuristic + sibling detection in `extra:*` arm.**
   Three branches:

   - **Body-empty + sibling exists** (`REF-foo.md` body=`|`,
     `REF-foo.text.md` exists): emit one stub that renders frontmatter
     as a "Source metadata" admonition + includes the sibling's body
     via `include-markdown`. New helper `write_stub_extra_with_sibling`.
   - **Body-empty + no sibling** (Tier 0 chunk where real content lives
     behind `external_pointer:`): emit a metadata-only stub with a
     metadata table + an external_pointer callout. Graceful degradation
     for Tier 0; partial mitigation for B6 (the M036 SimplePBJ DOCX
     extraction gap) until DOCX extraction lands. New helper
     `write_stub_extra_metadata_only`.
   - **Body non-empty** (operator-authored alongside frontmatter):
     preserve current default-include behavior.

   Body-empty heuristic (awk-only, bash 3.2 safe): strip frontmatter,
   strip whitespace and any single-`|` placeholder line, return "empty"
   if remaining body has zero non-blank chars. New helper
   `body_is_empty()`.

   Frontmatter-as-table emission (awk-only): walk the YAML block,
   emit `| key | value |` rows. New helper
   `emit_frontmatter_metadata_table()`.

   external_pointer extraction: parse `external_pointer: <value>` from
   frontmatter. New helper `extract_external_pointer()`.

**Regression fixture:** `tests/m032-acceptance/p0X-pbj-b7-extra-text-md-sibling.sh`
— synthetic config with `extra_dirs: [refs/]` + three patterns:
paired (metadata + sibling), orphan (metadata only with
external_pointer), authored (body alongside frontmatter). Asserts
scanner suppresses `.text.md` duplicate, paired stub includes sibling
+ metadata table, orphan stub surfaces external_pointer, authored stub
preserves default include behavior.

### B8 — Empty-subdir knowledge indexes leak through

**Location:** `scripts/wiki/wiki-generate-stubs.sh` end-of-script
knowledge-index emission block.

**Symptom:** `wiki-generate-stubs.sh` unconditionally emits
`wiki/docs/knowledge/{patterns,conventions,lessons}/index.md` and
`wiki/docs/knowledge/index.md` regardless of whether any
`knowledge/<cat>/MEM*.md` source files exist. Result: title-only
"Knowledge — Patterns" pages flagged as orphan by mkdocs in projects
that don't yet have a populated knowledge graph.

**Fix:**

- `write_knowledge_sub_index_from_list` returns early when the source
  list file is empty (no MEM stubs were registered for this category).
- `write_knowledge_top_index` is gated on at least one of the three
  category lists having content.

**Note on PBJ's stronger preference:** PBJ flagged `knowledge/index.md`
itself as orphan even when populated, observing that the nav already
covers the surface via "Knowledge — Flat" + top-level "Knowledge:
knowledge.md". That's a nav-design decision (always-skip-when-redundant)
that affects every consumer; deferred to a separate decision after
this sweep. The B8 fix here is the empty-source gate only — already a
significant improvement for cold-start projects.

**Regression fixture:** `tests/m032-acceptance/p0X-pbj-b8-empty-knowledge-indexes.sh`
— minimal corpus with no `knowledge/<cat>/` trees, assert no
per-category indexes emit and no top-level knowledge index emits;
control case populates one MEM, asserts the populated index emits
while empty siblings stay gated off.

## Out of scope (deferred)

### B6 — Tier 1 extraction gap (M030/M036 lineage, not wiki domain)

Stays at `.orchestrator/proposals/m036-tier-1-docx-extraction-gap.md`
for M030/M036 follow-up. B7's metadata-only fallback partially
mitigates by surfacing `external_pointer:` in the stub.

### Install-template config.yml preservation (M025/M033 install territory)

Different domain (install-claude-code.sh, not wiki tooling). Filed as
separate brief: `.orchestrator/proposals/install-template-preserve-operator-keys.md`.

### Always-skip `knowledge/index.md`

PBJ's stronger preference (skip even when populated). Nav-design
decision affecting every consumer. Deferred to a future nav-shape pass.

### Two pre-existing M032-battery fails

SC-1 commands/ count drift (37 vs golden 34) and SC-11 wiki-serve
`--probe` flake reproduce on the pre-fix tree. Not introduced by this
sweep; will re-baseline at M035 packaging.

## Verification plan

1. New `tests/m032-acceptance/p0X-pbj-b{5,7,8}-*.sh` regression fixtures
   — each PASS standalone.
2. Round-1 fixtures (`p0X-pbj-b{1,2,3,4}-*.sh`) still PASS.
3. Re-run `bash tools/verify/validate-milestone.sh M032` — expect
   122/122 PASS unchanged (closure invariants untouched).
4. Smoke-test `bash scripts/wiki/wiki-generate-stubs.sh && bash
   scripts/wiki/wiki-generate-nav.sh` against the orchestrator's own
   config — confirm zero behavior change in the no-extras baseline.

## Return prompt to PBJ-central agent

After commit, hand the consumer-side agent:
1. Which fixes landed (B5/B7/B8 by ID, this commit-sha).
2. `orchestrator:update` to refresh tooling.
3. Re-run order: `bash scripts/wiki/wiki-generate-stubs.sh` →
   `bash scripts/wiki/wiki-generate-nav.sh` → restart `mkdocs serve`.
4. Verification reproducers (PBJ already has them):
   - B5: `curl /decisions/ | grep '../../.orchestrator#'` → empty.
   - B7: REF-* pages now show metadata admonition + Tier-1 body (or
     external_pointer callout).
   - B8: `find wiki/docs/knowledge -name 'index.md'` → only emits when
     MEM stubs exist for at least one category.
5. B6 + the install-template ergonomic remain deferred — tracked at
   their separate briefs.
