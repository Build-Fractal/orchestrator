---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M012"
name: "MEM stub generation + nav integration + anchor resolution verification"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete:
  - `wiki/mkdocs.yml` has `rewrite_relative_urls: true` on the include-markdown plugin and `toc: { permalink: true }` under `markdown_extensions:`.
  - `scripts/wiki/wiki-scan-sources.sh` emits `knowledge:<category>|<rel-path>|<title>` records in addition to its existing `.orchestrator/**.md` records.
  - `bash scripts/verify/m012-p01-phase-suite.sh` still exits 0.
- P01 patterns:
  - Stub template is a ≤ 25-line markdown file with YAML frontmatter (`title:` only), a short auto-generated comment citing AD-3, and one `include-markdown` block pointing at the canonical file via a `../…`-relative path. See `wiki/docs/milestones/M001/M001-CONTEXT.md` (or any P01-generated stub) for the exact shape.
  - Section-index files are identified by the comment `Auto-generated section index` (classification probe used by P01's SSOT gate).
  - Nav generator splices its output between `# >>> M012-P01 nav` and `# <<< M012-P01 nav end` markers in `wiki/mkdocs.yml`. T02 preserves the marker pair; its additions go inside the existing region alongside existing subtrees.
- `wiki/docs/` currently has NO `knowledge/` subdirectory. T02 creates it.

## Description

T02 teaches the two generators (stub + nav) to consume the new `knowledge:<category>` scanner records. Three deliverables:

**Deliverable 1 — Stub generator extension.** `scripts/wiki/wiki-generate-stubs.sh` learns to route `knowledge:<category>` records to `wiki/docs/knowledge/<category>/<MEM###>.md`, using the same thin-stub template as P01 (≤ 25 lines, one include directive, no body copy). Also emit section indexes:

- `wiki/docs/knowledge/index.md` — top-level index listing the three categories.
- `wiki/docs/knowledge/patterns/index.md`, `wiki/docs/knowledge/conventions/index.md`, `wiki/docs/knowledge/lessons/index.md` — per-category indexes listing the MEM entries in that category.

Each section index carries the `Auto-generated section index` comment probe so P01's existing SSOT gate (`m012-p01-ssot.sh`) continues to classify them correctly (P01 already permits section indexes to exceed the 25-line cap because they are bullet lists, not content).

**Deliverable 2 — Nav generator extension.** `scripts/wiki/wiki-generate-nav.sh` emits a new `Knowledge Entries` subtree inside the existing marker-bounded nav region. Position: between the existing `Knowledge` top-level entry (which points at the single consolidated `.orchestrator/KNOWLEDGE.md` stub) and the `Milestone Summary` entry. The subtree groups by category:

```yaml
      - Knowledge Entries:
          - Patterns:
              - wiki/docs/knowledge/patterns/index.md
              - MEM001: wiki/docs/knowledge/patterns/MEM001.md
              - MEM002: wiki/docs/knowledge/patterns/MEM002.md
              # … one line per entry, lexical order
          - Conventions:
              - wiki/docs/knowledge/conventions/index.md
              - MEM012: wiki/docs/knowledge/conventions/MEM012.md
              # …
          - Lessons:
              - wiki/docs/knowledge/lessons/index.md
              - MEM021: wiki/docs/knowledge/lessons/MEM021.md
              # …
```

The existing top-level `Knowledge` entry (pointing at `KNOWLEDGE.md`) is preserved unchanged; `Knowledge Entries` is an additional subtree. Rationale: `.orchestrator/KNOWLEDGE.md` is the consolidated view and is its own navigation target; the per-entry files are the granular view. Both are legitimate and both belong in nav per AD-6 (every scanner record maps to exactly one nav leaf).

**Deliverable 3 — MEM anchor resolution probe.** KNOWLEDGE.md already renders with MkDocs heading anchors (because of T01's `toc: permalink: true` setting). The per-MEM headings in `.orchestrator/KNOWLEDGE.md` look like `### Shell Script Conventions` (section-style, not `### MEM001: …`-style — the consolidated file groups by topic). By contrast, the per-entry files (`knowledge/patterns/MEM001.md`) DO carry `# MEM001: Shell Script Conventions` H1s. The D011 criterion (a) from AD-1 specifies BOTH: "cross-refs to `knowledge/**/MEM*.md`". The primary cross-ref target is the per-entry files (T02's new stubs). Anchor-style references `KNOWLEDGE.md#mem-NNNN` are a secondary convenience — at the rendered KNOWLEDGE page, those anchors may not exist because the consolidated file uses topical headings. The resolution policy (documented in T04) clarifies: prefer `knowledge/<cat>/MEM###.md`-style file-path links; `KNOWLEDGE.md#mem-NNNN` anchor links resolve only when the consolidated file happens to carry a matching heading.

T02 ships the anchor-resolution probe as a diagnostic helper used by T05's gate, NOT as a build-breaking assertion. The probe scans the rendered KNOWLEDGE HTML (if mkdocs is installed) and reports which MEM IDs DO have a matching anchor; the list is saved for T04 documentation.

## Steps

1. **Open `scripts/wiki/wiki-generate-stubs.sh`**. Locate the main loop that reads scanner records and routes by category (`top:*`, `milestone:M###`, `archive:M###`). Add a new branch for `knowledge:<category>`:

   ```bash
   # ---- knowledge:* routing (added in M012/P02/T02) ----------------------------
   case "$category" in
     knowledge:patterns|knowledge:conventions|knowledge:lessons)
       sub="${category#knowledge:}"                     # patterns | conventions | lessons
       # mem_id derived from basename: "MEM001.md" -> "MEM001"
       mem_id=$(basename "$rel_path" .md)
       stub_path="$ROOT/wiki/docs/knowledge/$sub/$mem_id.md"
       mkdir -p "$ROOT/wiki/docs/knowledge/$sub"
       # Depth from wiki/docs to the canonical knowledge/<sub>/<MEM>.md target.
       # wiki/docs/knowledge/<sub>/<MEM>.md needs to climb 3 dirs to repo root.
       canonical_rel="../../../$rel_path"
       write_stub "$stub_path" "$title" "$canonical_rel"
       continue
       ;;
   esac
   ```

   `write_stub` is the existing P01 helper. If it does not exist under that exact name, inline the equivalent (P01 T03 pattern):

   ```bash
   # Thin stub template — 12–13 lines, SSOT-safe.
   cat > "$stub_path" <<EOF
   ---
   title: "$title"
   ---

   <!-- Auto-generated by scripts/wiki/wiki-generate-stubs.sh.
        Do not hand-edit. The canonical content lives at:
        $rel_path
        See M012 AD-3 (SSOT via include-markdown). -->

   {%
     include-markdown "$canonical_rel"
     heading-offset=0
     rewrite-relative-urls=true
   %}
   EOF
   ```

2. **Add section-index emission for the `knowledge/` tree** in the same generator. After the main record loop, but before the generator exits, emit four section indexes:

   ```bash
   # ---- knowledge/ section indexes (M012/P02/T02) ------------------------------
   write_knowledge_top_index "$ROOT/wiki/docs/knowledge/index.md"
   for sub in patterns conventions lessons; do
     write_knowledge_sub_index "$ROOT/wiki/docs/knowledge/$sub/index.md" "$sub"
   done
   ```

   Top-level index template:

   ```markdown
   ---
   title: "Knowledge Entries"
   ---

   <!-- Auto-generated section index for knowledge/ stubs.
        Lists the three category indexes. -->

   # Knowledge Entries

   - [Patterns](patterns/index.md)
   - [Conventions](conventions/index.md)
   - [Lessons](lessons/index.md)
   ```

   Per-category index template (example for `patterns`):

   ```markdown
   ---
   title: "Knowledge — Patterns"
   ---

   <!-- Auto-generated section index for knowledge/patterns stubs.
        Bullets below are generated from scanner records in lexical order. -->

   # Knowledge — Patterns

   - [MEM001](MEM001.md)
   - [MEM002](MEM002.md)
   …
   ```

   Build the bullet list by walking the scanner records for the matching category in lexical order. Title falls back to basename-sans-`.md` if no scanner title is present (same pattern as P01 section indexes).

3. **Open `scripts/wiki/wiki-generate-nav.sh`**. Locate the state machine that emits the marker-bounded nav block. Find the position where the existing `Knowledge:` entry (pointing at the single KNOWLEDGE.md stub) is emitted. After emitting that entry (and before `Milestone Summary:`), emit a new `Knowledge Entries:` subtree. The nav block is assembled from scanner records in a single forward pass (P01 pattern); emit the new subtree by scanning the cached record list for `knowledge:*` categories:

   ```bash
   # ---- Knowledge Entries subtree (M012/P02/T02) ------------------------------
   emit_line "      - Knowledge Entries:"
   for sub in patterns conventions lessons; do
     label=$(nav_label_for_sub "$sub")    # "Patterns" | "Conventions" | "Lessons"
     emit_line "          - $label:"
     emit_line "              - wiki/docs/knowledge/$sub/index.md"
     # Walk the scanner's /tmp record list for matching category.
     while IFS='|' read -r c r t; do
       [ "$c" = "knowledge:$sub" ] || continue
       mem_id=$(basename "$r" .md)
       emit_line "              - $mem_id: wiki/docs/knowledge/$sub/$mem_id.md"
     done < "$SCAN_RECORDS_TMP"
   done
   ```

   Notes:
   - `$SCAN_RECORDS_TMP` is the scanner-output cache the P01 generator already builds (parallel /tmp list files scoped by PID, from P01 patterns). Reuse it; do not re-invoke the scanner.
   - Indentation matches P01's nav convention (`      -` for top-level nav entries under `nav:`; `          -` for category-level; `              -` for leaf entries — three-level indentation).
   - The outer `emit_line` function is P01's existing nav emitter (writes to the staged nav file).

4. **Preserve P01 markers and atomic write**. The nav generator already uses the marker-bounded atomic-write pattern (P01 T04). T02's edits live inside the existing marker region — no new markers.

5. **Regenerate stubs and nav from scratch**:

   ```bash
   bash scripts/wiki/wiki-generate-stubs.sh
   bash scripts/wiki/wiki-generate-nav.sh
   ```

   Expect:
   - `wiki/docs/knowledge/patterns/MEM001.md` through `MEM011.md` created.
   - `wiki/docs/knowledge/conventions/MEM012.md` through `MEM020.md` created.
   - `wiki/docs/knowledge/lessons/MEM021.md` through `MEM025.md` created.
   - Four section indexes created.
   - `wiki/mkdocs.yml` nav block now contains a `Knowledge Entries:` subtree.

6. **Verify P01 gates STILL pass after T02 extensions** — these extensions are additive, not destructive. Run:

   ```bash
   bash scripts/verify/m012-p01-phase-suite.sh
   ```

   Expect 9/9 gates PASS. Most relevant P01 gates to watch:
   - `m012-p01-include-plugin.sh` — every new stub must carry an `include-markdown` directive whose target resolves. The `canonical_rel` value (`../../../knowledge/<sub>/<MEM>.md`) must resolve from `wiki/docs/knowledge/<sub>/<MEM>.md` back to the canonical file at repo root.
   - `m012-p01-ssot.sh` — every new stub ≤ 25 lines, exactly one `include-markdown` directive, no body copy. Section indexes are ≤ 25 lines in practice (11 + 9 + 5 entries per category).
   - `m012-p01-nav-structure.sh` — top-level order still Home / Constitution / Decisions / Knowledge / Milestone Summary / Milestones / Archive. The new `Knowledge Entries:` subtree is nested under a DIFFERENT top-level marker than the single `Knowledge:` entry the P01 gate asserts — so P01's top-level check passes. T05's `m012-p02-mem-stubs.sh` gate asserts the new subtree exists.
   - `m012-p01-exclusion-policy.sh` — scanner output still passes exclusion policy. The new `knowledge:<category>` records are NOT under `.orchestrator/scratch|tmp|config/` and ARE `.md` files.
   - `m012-p01-bash32-compat.sh` — both generators still Bash 3.2 compatible.

7. **Optional MEM-anchor probe** (if `mkdocs` is installed locally):

   ```bash
   bash scripts/wiki/wiki-serve.sh --probe
   ```

   This produces a throwaway `site/` directory (P01 `--probe` behavior). Manually inspect the rendered `site/<path-to-KNOWLEDGE-stub>/index.html` for heading anchor ids; note which MEM IDs have matching `#mem-NNNN` anchors. Record the finding in your execution log or task notes — T04 uses this input to write the resolution-policy section in `wiki/README.md` (in particular: whether `KNOWLEDGE.md#mem-NNNN` anchors work against the consolidated file or whether the policy must steer readers to `knowledge/<cat>/MEM###.md` file-path links).

   If `mkdocs` is not installed, skip this step; T04 will document the anchor policy conservatively (file-path references are the canonical link target; anchor references work when the consolidated file carries a matching heading).

## Must-Haves

- `scripts/wiki/wiki-generate-stubs.sh` writes one stub to `wiki/docs/knowledge/<category>/<MEM###>.md` for every `knowledge:<category>` scanner record.
- Each MEM stub is ≤ 25 lines, has exactly one `include-markdown` directive, contains no canonical content body.
- Four section-index files (`wiki/docs/knowledge/index.md` plus three per-category indexes) exist and carry the `Auto-generated section index` comment probe.
- `scripts/wiki/wiki-generate-nav.sh` emits a `Knowledge Entries:` subtree inside the marker-bounded nav block, nested between the existing `Knowledge:` entry and `Milestone Summary:` entry.
- Every MEM stub path appears exactly once in the generated nav block.
- All four section-index paths appear in the nav block (top index under `Knowledge Entries:`; three sub indexes as leading entries under each category).
- `bash scripts/verify/m012-p01-phase-suite.sh` exits 0 after T02 regeneration.
- Both generators remain Bash 3.2 compatible.

## Verification

- `bash scripts/wiki/wiki-generate-stubs.sh` — exits 0 with no stderr warnings.
- `bash scripts/wiki/wiki-generate-nav.sh` — exits 0; `wiki/mkdocs.yml` unchanged outside the marker-bounded region.
- `bash scripts/verify/m012-p01-phase-suite.sh` — 9/9 gates PASS.
- Manual: `find wiki/docs/knowledge -name 'MEM*.md' -not -name 'index.md'` line count equals the count of `knowledge/**/MEM*.md` files on disk (`find knowledge -name 'MEM*.md' -type f`). Any mismatch indicates a missed scanner record or a stub write failure.
- Manual: open one MEM stub (e.g., `wiki/docs/knowledge/patterns/MEM001.md`); confirm the include directive reads (in `include-markdown` form) `"../../../knowledge/patterns/MEM001.md"` with correct `../` count.
- T05's `m012-p02-mem-stubs.sh` gate (authored later) provides the mechanical assertion; T02 verification is gated on the P01 suite staying green.

## Inputs

### From Previous Tasks

- `scripts/wiki/wiki-scan-sources.sh` (from T01)
  - Key API: `bash scripts/wiki/wiki-scan-sources.sh [--root PROJECT_ROOT]` emits `<category>|<rel-path>|<title>` records to stdout. Post-T01 record categories: `top:constitution`, `top:decisions`, `top:knowledge`, `top:milestone-summary`, `milestone:M###`, `archive:M###`, `knowledge:patterns`, `knowledge:conventions`, `knowledge:lessons`.
  - Ordering: `.orchestrator/` records (P01 order) first; `knowledge:patterns` (lexical MEM id) next; then `knowledge:conventions`; then `knowledge:lessons`.
  - Rel-path format: repo-root relative (e.g., `knowledge/patterns/MEM001.md`).
- `wiki/mkdocs.yml` (from T01)
  - Key API (settings T02 relies on): `rewrite_relative_urls: true` on the include-markdown plugin is what makes relative links inside included bodies rewrite to the stub's rendered route (so T04's link-check gate can verify end-to-end resolution).
  - Marker pair `# >>> M012-P01 nav` / `# <<< M012-P01 nav end` bounds the nav block. T02 edits add lines strictly inside this region; markers and atomic-write pattern are preserved.

### From Disk (Pre-existing)

- `scripts/wiki/wiki-generate-stubs.sh` — P01 generator. Key internals:
  - Reads scanner stdout into a /tmp cache (PID-suffixed).
  - Writes thin include stubs via a `write_stub` helper (or equivalent inline template).
  - Emits section indexes for `milestones/`, `archive/`, per-M###, per-P##.
- `scripts/wiki/wiki-generate-nav.sh` — P01 generator. Key internals:
  - Reads scanner stdout cache (same /tmp file).
  - Assembles a nav block via single-forward-pass awk state machine.
  - Atomic write via same-directory staged temp + `mv`.
  - Respects marker pair for splice region.
- `knowledge/patterns/MEM001.md` through `MEM011.md`, `knowledge/conventions/MEM012.md` through `MEM020.md`, `knowledge/lessons/MEM021.md` through `MEM025.md` — canonical MEM entry files. Each has YAML frontmatter + `# MEMNNN: <Title>` H1 + body paragraphs.

## Constraints

- **Bash 3.2** — both generators must stay compatible. No `declare -A`, no `mapfile`, no process substitution, no `&>`. MEM001, MEM021 (P01 patterns).
- **AD-3 SSOT** — every new stub is thin (≤ 25 lines, one include directive, no body). Section indexes are legitimately longer but contain only bullet lists, not canonical content. No file under `wiki/docs/knowledge/` has a byte-equal twin under `.orchestrator/` or `knowledge/`.
- **AD-6 nav completeness** — every `knowledge:*` scanner record has exactly one nav leaf in the generated nav block. Duplicates fail T05's `m012-p02-mem-stubs.sh` count-match gate.
- **No modification to P01-visible surfaces beyond the additive extensions** — T02 MUST NOT alter existing `.orchestrator/` stubs under `wiki/docs/`, the existing top-level `Knowledge:` nav entry (which points at the consolidated KNOWLEDGE.md stub), or the marker-bounded structure. A diff of `wiki/mkdocs.yml` outside the nav markers and outside T01's two additions must be empty.
- **Regeneration is idempotent** — running both generators twice produces byte-identical output (P01 idempotency invariant carried forward).
- **Surgical precision (Constitution XV)** — T02 touches exactly two scripts (`wiki-generate-stubs.sh`, `wiki-generate-nav.sh`) and creates the `wiki/docs/knowledge/` subtree plus modifies `wiki/mkdocs.yml`'s nav block region. Nothing else.

## Expected Output

After T02 completes:

1. **Stubs created** — one `.md` per `knowledge/**/MEM*.md` file, under `wiki/docs/knowledge/<category>/<MEM###>.md`. 25 entries total (11 patterns + 9 conventions + 5 lessons, per current repo state).
2. **Section indexes created** — `wiki/docs/knowledge/index.md` plus three per-category `index.md` files.
3. **Nav updated** — `wiki/mkdocs.yml` contains a `Knowledge Entries:` subtree inside the marker-bounded nav block. The subtree has three category branches (Patterns, Conventions, Lessons); each lists its per-category index first and every MEM entry after, in lexical order.
4. **P01 suite STILL green** — `bash scripts/verify/m012-p01-phase-suite.sh` exits 0.
5. **Generators idempotent** — re-running both in sequence produces no diff (`git diff --stat wiki/docs/ wiki/mkdocs.yml` empty after a second run).
6. **Anchor probe note captured** (optional when `mkdocs` absent) — for T04's documentation input.
