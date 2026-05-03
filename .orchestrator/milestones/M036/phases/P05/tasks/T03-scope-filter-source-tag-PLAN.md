---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P05"
milestone: "M036"
name: "Scope-filter extension (--tag '[source:<cite_id>]' across spec/memory/reference)"
depends_on: []
---

## Prerequisites

- `references/file-formats.md` line 656 declares the `source:<cite_id>` scope tag (P00 T03 deliverable). Verified at plan-authoring time.
- `scripts/dispatch/scope-filter.sh` exists. Three matching sites currently bake the pre-P05 tag namespace:
  - Line 155: `filter_knowledge` extracts `\[[a-z]+:[A-Za-z0-9/]+\]|\[project\]`. The character class `[A-Za-z0-9/]` does **not** include `-` or `_`, so `[source:cms-pbj-2024-q3]` is **not** matched today.
  - Lines 200-294: `filter_knowledge_index` reuses the same matching logic on pipe-delimited rows.
  - Lines 357-454: `filter_knowledge_graph` (graph mode) builds a `scope_clause` with no `source:` branch.

## Description

Extend `scripts/dispatch/scope-filter.sh` so an operator can invoke `bash scripts/dispatch/scope-filter.sh <index-path> <scope-context> --tag '[source:<cite_id>]'` and receive every chunk (spec, memory, or reference) whose `scope_tags` frontmatter contains the matching tag literal.

Two additive surfaces:

1. **A new top-level `--tag <tag-literal>` flag** that overrides the per-line scope-tag computation with a literal-match filter. When set, every emission decision is "does this row's `scope_tags` cell contain `<tag-literal>`?" The flag composes with existing `--type knowledge|decisions` auto-detection but bypasses the `MILESTONE_ID` / `PHASE_ID` matching logic — `--tag` is operator-asserted, not derivation-asserted.

2. **A widened scope-tag regex** so the existing scope-derivation paths (no `--tag`) also recognize the new namespace where it appears alongside the old ones in mixed entries. The regex change is a strict superset (extending the character class to include `-`, `_`, and `.`); any tag matched by the old regex is still matched by the new one.

The CON-5 invariant requires that for any KNOWLEDGE-INDEX row that does **not** declare a `[source:...]` tag, scope-filter output is byte-identical pre- and post-P05. The regression guard `tools/verify/m036-p05-scope-filter-baseline.sh` (T04) enforces this.

`--tag` is the demo flag. The widened regex is the upstream-derivation correctness fix (so a future entry tagged `[source:cms-pbj-2024-q3]` survives normal derivation matching).

## Steps

1. **Add `--tag` argument parsing** to the existing argument-parsing loop (lines 38-66). After the existing `--include-non-goals` case:
   ```bash
       --tag)
         FILTER_TAG="$2"; shift 2 ;;
   ```
   Add `FILTER_TAG=""` to the variable initializers at lines 27-36.

2. **Widen the scope-tag character class** at line 155 (and the same line in `filter_knowledge_index` at ~272 for index entries). Current:
   ```bash
   scope_tag=$(echo "$line" | grep -oE '\[[a-z]+:[A-Za-z0-9/]+\]|\[project\]' || true)
   ```
   New:
   ```bash
   scope_tag=$(echo "$line" | grep -oE '\[[a-z]+:[A-Za-z0-9/_.-]+\]|\[project\]' || true)
   ```
   This adds `_`, `.`, and `-` to the character class. The new tag namespace `[source:cms-pbj-2024-q3]` matches because hyphens and digits are now in the class. Pre-existing tags (`[milestone:M001]`, `[phase:M001/P02]`) remain unchanged because their character set is a subset of the new one.

3. **Branch each filter function on `FILTER_TAG`.** When `FILTER_TAG` is non-empty, replace the include/exclude decision with a literal substring match against the row's scope-tag column.

   `filter_knowledge` (line 135-194) — at the start of the entry-detection branch (where `scope_tag` is assigned), if `FILTER_TAG` is non-empty:
   ```bash
   if [[ -n "$FILTER_TAG" ]]; then
     # Literal-tag mode: include iff the entry header line contains the tag literal
     if echo "$line" | grep -qF "$FILTER_TAG"; then
       include=true
     else
       include=false
     fi
   else
     # ... existing include logic unchanged ...
   fi
   ```
   `grep -qF` is fixed-string match — no regex escaping concerns for `[source:cms-pbj-2024-q3]` (the bracket characters would otherwise need escaping).

   `filter_knowledge_index` (line 200-295) — at the scope-tag-filter section (around line 263), the same shape: if `FILTER_TAG` is non-empty, check the parsed `scope_tag` field for `grep -qF "$FILTER_TAG"`. The parsed `scope_tag` is the `$2` awk field of the pipe-delimited row, so a substring match against it covers entries with multiple tags.

   `filter_knowledge_graph` (line 357-454) — the SQL path. Add a branch: when `FILTER_TAG` is non-empty, replace the `scope_clause` construction with a literal `scope_tags.tag = '<safe_tag>'` join condition:
   ```bash
   if [ -n "$FILTER_TAG" ]; then
     safe_tag="$(printf '%s' "$FILTER_TAG" | sed "s/'/''/g")"
     scope_clause="AND st.tag = '${safe_tag}'"
   fi
   ```
   This bypasses milestone/phase derivation entirely and matches the literal tag.

4. **Author `tools/verify/m036-p05-scope-filter-source-tag.sh`** — single-script-file verifier. Stages a fixture KNOWLEDGE-INDEX.md fragment under `mktemp` containing three rows:
   - `MEM001 | [project] | patterns | 0.9 | 2026-01-01 | verified:2026-01-01 | hits:1 | A`
   - `MEM002 | [source:cms-pbj-2024-q3] | patterns | 0.9 | 2026-01-01 | verified:2026-01-01 | hits:1 | B`
   - `SPEC-FR-7 | [source:cms-pbj-2024-q3] | spec/requirement | 0.9 | 2026-01-01 | verified:2026-01-01 | hits:1 | C`

   Invokes `bash scripts/dispatch/scope-filter.sh <fixture-path> M036/P05 --type knowledge --tag '[source:cms-pbj-2024-q3]'`. Asserts:
   - Output contains both `MEM002` and `SPEC-FR-7` (cross-category match — memory + spec).
   - Output does NOT contain `MEM001` (no matching tag).

5. **Author `tools/verify/m036-p05-scope-filter-baseline.sh`** — CON-5 regression guard. Stages a fixture KNOWLEDGE-INDEX.md fragment containing only pre-P05 tag namespaces:
   - `MEM001 | [project] | patterns | 0.95 | ...`
   - `MEM002 | [milestone:M001] | patterns | 0.90 | ...`
   - `MEM003 | [phase:M001/P02] | patterns | 0.95 | ...`

   Invokes `bash scripts/dispatch/scope-filter.sh <fixture> M001/P02 --type knowledge` (no `--tag` flag). Diffs against a checked-in baseline file at `tests/fixtures/m036-p05-baseline/scope-filter-default.expected.txt`. Any diff exits 1.

   Same baseline-capture sequencing constraint as T02's regression guard: capture the baseline BEFORE editing `scope-filter.sh`. Run the unmodified script once against the fixture, save stdout verbatim. Then make the edits. Then re-run; the diff must be empty.

## Must-Haves

Truths from the phase plan addressed by this task:

- "`scope-filter.sh` accepts `--tag '[source:<cite_id>]'` and returns chunks bearing that tag" — covered by step 4.
- "`scope-filter.sh` invoked without `--tag` produces output byte-identical to pre-P05 for a fixture KNOWLEDGE-INDEX.md (CON-5 regression guard)" — covered by step 5.

## Verification

```bash
bash tools/verify/m036-p05-scope-filter-source-tag.sh
```

```bash
bash tools/verify/m036-p05-scope-filter-baseline.sh
```

## Inputs

### From Previous Tasks

(None — T03 is independent of T01 and T02; scope-filter reads the flat KNOWLEDGE-INDEX.md or `knowledge.db`'s `scope_tags` table, not the `edges` table that T01/T02 touch.)

### From Disk (Pre-existing)

- `scripts/dispatch/scope-filter.sh` — the file to modify. Key behavior:
  - Three filter functions: `filter_knowledge` (markdown headings), `filter_knowledge_index` (pipe-delimited), `filter_knowledge_graph` (SQLite).
  - Auto-detects type from filename (knowledge/decisions); explicit `--type` overrides.
  - Existing `--graph` flag switches to SQLite-backed mode (queries `scope_tags` table).
  - Returns exit 0 even on missing file (for graceful no-op).
- `references/file-formats.md` — line 656 declares the `source:<cite_id>` scope tag namespace as the SSOT for the format.
- `scripts/knowledge/lib/graph-db.sh` (T01-modified) — the `scope_tags` table is unchanged by T01/P05 (only `edges` was touched). The graph-mode filter just adds a WHERE clause.

## Constraints

- **CON-5 byte-equality** — for any input that does NOT declare a `[source:...]` tag and where `--tag` is not passed, output is byte-identical to pre-P05. The regression guard in step 5 enforces.
- **Regex widening is a strict superset** — every old-tag pattern continues to match. Verified by character-class inclusion: `[A-Za-z0-9/]` ⊂ `[A-Za-z0-9/_.-]`. (No removal, only addition.)
- **`--tag` does NOT inherit `MILESTONE_ID` / `PHASE_ID` filtering** — the flag is operator-asserted scope-by-tag, not scope-by-derivation. An entry tagged `[source:cms-pbj-2024-q3]` is returned regardless of which milestone/phase the operator is dispatching from. Rationale: the use case is "find all chunks scoped to this source across the whole corpus."
- **`grep -qF` for literal match** — never `grep -qE` against `FILTER_TAG`. Bracket characters are regex metacharacters and would silently match wrong things if interpreted as a regex.
- **`--tag` composes with `--type` and `--include-non-goals`** but supersedes derivation-based matching. Document this clearly in the script's usage line (line 6-9).
- **Bash 3.2 / POSIX-sh** — same as T01/T02. The argument-parsing pattern is unchanged.

## Expected Output

`m036-p05-scope-filter-source-tag.sh` prints `PASS: m036-p05-scope-filter-source-tag (2 chunks across spec+memory)` on success.

`m036-p05-scope-filter-baseline.sh` prints `PASS: m036-p05-scope-filter-baseline (CON-5 byte-identical)` on success.

After T03 lands, an operator can run:
```bash
bash scripts/dispatch/scope-filter.sh knowledge/KNOWLEDGE-INDEX.md M036/P05 --type knowledge --tag '[source:cms-pbj-2024-q3]'
```
and receive every chunk in the index that bears that source tag, regardless of category. This is the second half of the demo sentence from the phase plan.
