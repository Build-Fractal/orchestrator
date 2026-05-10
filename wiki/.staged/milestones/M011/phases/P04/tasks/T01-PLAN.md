---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M011"
name: "Extend scope-filter.sh with spec scope-tag resolution + graph-neighbor expansion"
depends_on: []
---

## Prerequisites

P01 is complete. The following is on disk:

- `scripts/dispatch/scope-filter.sh` is a Bash 3.2 script that filters KNOWLEDGE-INDEX.md / DECISIONS.md / flat KNOWLEDGE.md. It already:
  - Accepts `--include-non-goals` flag (AD-7 from P01) and by default excludes `spec/non-goal` entries in both index and graph modes.
  - Supports `--graph` mode which queries `knowledge.db` via `scripts/knowledge/lib/graph-db.sh` (sourced lazily when `--graph` is active).
  - Parses positional args `<file-path> <scope-context>` where `scope-context` is `M###/P##`.
  - Honors `--category <cat>` and `--min-confidence`.
- `scripts/knowledge/traverse-graph.sh --id <id> [--hops 1] [--max-entries 5]` emits related entry IDs (one per line) to stdout using SQLite recursive CTEs on `knowledge.db` `relates_to` edges. Exit 0 always.
- `scripts/knowledge/lib/graph-db.sh` exports `get_db_path` and `db_query <db_path> <sql>` helpers.
- `.orchestrator/knowledge/spec/<type>/<SPEC-XX-NNN>.md` entries exist after P02/P03 ingest. Their frontmatter includes `scope_tags`, `category` (e.g. `spec/requirement`), `relates_to`, `supersedes`, `superseded_by`, and `content_hash`. Every non-superseded entry has `superseded_by: ""` (or missing); superseded entries have `superseded_by: "<new-id>"` or `superseded_by: "REMOVED"`.
- `knowledge.db` is rebuilt by `scripts/knowledge/rebuild-index.sh`. The schema has `entries(id TEXT PRIMARY KEY, category TEXT, confidence REAL, ..., superseded_by TEXT)` and `scope_tags(entry_id TEXT, tag TEXT)`.

No scope-filter understanding of `spec/*` scope tags exists yet. Today, passing `scope_tags: [spec/requirement/SPEC-FR-003]` through a task plan has no effect — the dispatch pipeline has no code path that maps `spec/<cat>/<ID>` tokens to knowledge entries.

## Description

Add a new `--spec-scope-tags "<comma-or-space-separated-tag-list>"` argument to `scripts/dispatch/scope-filter.sh` that:

1. Parses each tag of the form `spec/<category>/<SPEC-XX-NNN>` (e.g. `spec/requirement/SPEC-FR-003`, `spec/story/SPEC-US-002`).
2. For each parsed tag, resolves the referenced SPEC- entry ID by checking that:
   - An entry with that ID exists in `knowledge.db` (or, if the DB is absent, by stat'ing `knowledge/<category>/<id>.md` — same split layout that `rebuild-index.sh` scans).
   - The entry's `superseded_by` is empty (skip superseded tips silently — consumers want the live chunk, not a back-version; a `WARN: superseded SPEC-FR-003 skipped` line goes to stderr for observability).
   - The entry is not a `spec/non-goal` (unless `--include-non-goals` is passed — reuse the P01 flag).
3. For each surviving SPEC- ID, invokes `bash scripts/knowledge/traverse-graph.sh --id <id> --hops 1` to collect 1-hop `relates_to` graph neighbors.
4. Merges (initial IDs ∪ neighbor IDs), deduplicates, and emits one ID per line to stdout in input order (initial IDs first, then neighbors in traversal order — ties broken by sort).

When `--spec-scope-tags` is supplied, scope-filter operates in an **ID-emission mode** distinct from the existing knowledge-filter mode. The existing positional-arg and `--type` logic is not used: `--spec-scope-tags` is self-sufficient. If the caller passes both `--spec-scope-tags` and `<file-path> <scope-context>`, the spec-scope-tags mode takes precedence and positional args are ignored (but still tolerated — no argument-validation error).

Rationale for emitting IDs (not entry content): `build-context.sh` in T02 already has a resolver pipeline pattern (scope-filter → extract IDs → traverse-graph → resolve-entries). This task mirrors that pipeline but compressed into scope-filter for the spec-specific case, so the caller only needs one invocation per task.

## Steps

### Step 1: Add argument parsing for `--spec-scope-tags`

In the argument-parsing `while` loop around lines 34-60 of `scripts/dispatch/scope-filter.sh`, add a new variable `SPEC_SCOPE_TAGS=""` near the other initializers (around line 33), and a new case arm:

```bash
    --spec-scope-tags)
      SPEC_SCOPE_TAGS="$2"; shift 2 ;;
```

Update the header comment-block usage line to document the new flag.

### Step 2: Add a `filter_spec_scope_tags` function

Place this function near the other `filter_*` functions (after `filter_knowledge_graph`, around line 442). It is self-contained — it does not use `FILE_PATH` or `SCOPE_CONTEXT`.

```bash
# ========================================================================
# Spec scope-tag resolution (ID emission mode for build-context.sh)
# ========================================================================
# Given a comma/space-separated list of spec/<cat>/<SPEC-XX-NNN> tags,
# emits one entry ID per line: first the directly-referenced IDs, then
# their 1-hop relates_to graph neighbors (deduped, superseded tips skipped,
# non-goals excluded unless --include-non-goals is passed).
filter_spec_scope_tags() {
  # Lazy-source graph-db.sh for DB lookups
  if [ -z "${_GRAPH_DB_SOURCED:-}" ]; then
    # shellcheck source=../knowledge/lib/graph-db.sh
    source "$SCRIPT_DIR/../knowledge/lib/graph-db.sh"
    _GRAPH_DB_SOURCED=1
  fi

  local db_path
  db_path="$(get_db_path 2>/dev/null || true)"

  # Tokenize the tag list (accept both comma and whitespace separators)
  local tag_list
  tag_list="$(printf '%s' "$SPEC_SCOPE_TAGS" | tr ',' ' ' | tr -s ' ')"

  # Pass 1: resolve each tag to its SPEC- ID if live + allowed
  local initial_ids_file neighbor_ids_file
  initial_ids_file="$(mktemp)"
  neighbor_ids_file="$(mktemp)"

  local tag spec_id spec_cat superseded category
  for tag in $tag_list; do
    # Parse spec/<cat>/<SPEC-XX-NNN>
    case "$tag" in
      spec/*/SPEC-*)
        spec_cat="$(printf '%s' "$tag" | awk -F/ '{print $2}')"
        spec_id="$(printf '%s' "$tag" | awk -F/ '{print $3}')"
        ;;
      *)
        echo "scope-filter.sh: WARN: ignoring non-spec scope tag '$tag'" >&2
        continue
        ;;
    esac
    [ -z "$spec_id" ] && continue

    # Non-goal gate
    if [ "$INCLUDE_NON_GOALS" != true ] && [ "$spec_cat" = "non-goal" ]; then
      continue
    fi

    # Liveness check — skip superseded tips
    superseded=""
    category=""
    if [ -n "$db_path" ] && [ -f "$db_path" ]; then
      # SQL lookup
      local sql safe_id
      safe_id="$(printf '%s' "$spec_id" | sed "s/'/''/g")"
      sql="SELECT COALESCE(superseded_by, '') || '|' || COALESCE(category, '') FROM entries WHERE id = '${safe_id}' LIMIT 1;"
      local row
      row="$(db_query "$db_path" "$sql" 2>/dev/null || true)"
      if [ -n "$row" ]; then
        superseded="$(printf '%s' "$row" | awk -F'|' '{print $1}')"
        category="$(printf '%s' "$row" | awk -F'|' '{print $2}')"
      fi
    else
      # Fallback: check file existence + read frontmatter
      local candidate="$SCRIPT_DIR/../../knowledge/spec/$spec_cat/$spec_id.md"
      if [ -f "$candidate" ]; then
        superseded="$(grep -E '^superseded_by:' "$candidate" | sed 's/^superseded_by:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')"
        category="spec/$spec_cat"
      fi
    fi

    # Skip if superseded (has a non-empty superseded_by)
    if [ -n "$superseded" ]; then
      echo "scope-filter.sh: WARN: superseded $spec_id skipped" >&2
      continue
    fi

    echo "$spec_id" >> "$initial_ids_file"
  done

  # Pass 2: collect 1-hop relates_to neighbors for each initial ID
  local id
  if [ -s "$initial_ids_file" ]; then
    while IFS= read -r id; do
      [ -z "$id" ] && continue
      bash "$SCRIPT_DIR/../knowledge/traverse-graph.sh" \
        --id "$id" --hops 1 --max-entries 10 2>/dev/null \
        >> "$neighbor_ids_file" || true
    done < "$initial_ids_file"
  fi

  # Emit: initial IDs first (preserving order), then sorted unique neighbors
  # that are not already in initial set
  if [ -s "$initial_ids_file" ]; then
    cat "$initial_ids_file"
  fi
  if [ -s "$neighbor_ids_file" ]; then
    local seen_file
    seen_file="$(mktemp)"
    [ -s "$initial_ids_file" ] && cat "$initial_ids_file" > "$seen_file"
    sort -u "$neighbor_ids_file" | while IFS= read -r id; do
      [ -z "$id" ] && continue
      if ! grep -Fxq "$id" "$seen_file" 2>/dev/null; then
        echo "$id"
      fi
    done
    rm -f "$seen_file"
  fi

  rm -f "$initial_ids_file" "$neighbor_ids_file"
}
```

### Step 3: Dispatch to `filter_spec_scope_tags` before positional-arg validation

Near the top of the script (just after argument parsing, before the "Validate required arguments" block around line 63), add:

```bash
# --- Spec scope-tag mode bypasses positional arg validation ---
if [ -n "$SPEC_SCOPE_TAGS" ]; then
  filter_spec_scope_tags
  exit 0
fi
```

Do NOT move this check after the positional-args validation — this mode is self-sufficient and must not require `<file-path> <scope-context>`.

### Step 4: Update usage comment block

Update the header comment (lines 3-17) to document the new flag:

```
# Usage: scope-filter.sh <file-path> <scope-context> [--type knowledge|decisions] [--depends P01,P03]
#                        [--min-confidence CONF] [--category CAT] [--graph] [--include-non-goals]
#        scope-filter.sh --spec-scope-tags "spec/requirement/SPEC-FR-003,spec/story/SPEC-US-002" [--include-non-goals]
#   ...
#   --spec-scope-tags: comma/space-separated list of spec/<cat>/<SPEC-XX-NNN> tags;
#                      emits resolved SPEC- IDs + 1-hop relates_to neighbors, one per line
```

## Must-Haves

- `scope-filter.sh` accepts `--spec-scope-tags "<tag-list>"` without requiring `<file-path>` or `<scope-context>`
- For input `spec/requirement/SPEC-FR-003`, the script emits `SPEC-FR-003` as the first line
- For input `spec/requirement/SPEC-FR-003` where SPEC-FR-003 has a `relates_to` edge to `SPEC-AC-007`, the script emits both IDs (SPEC-FR-003 first, SPEC-AC-007 after)
- For input `spec/non-goal/SPEC-NG-001` without `--include-non-goals`, the script emits no IDs and no error
- For input `spec/requirement/SPEC-FR-003` where SPEC-FR-003 has `superseded_by: SPEC-FR-003-v2`, the script emits no IDs for that tag and writes a `WARN:` line to stderr
- The function `filter_spec_scope_tags` is defined in `scripts/dispatch/scope-filter.sh`
- `scripts/dispatch/scope-filter.sh` passes `bash -n` syntax check with no `declare -A` / `mapfile` / `readarray` usage

## Verification

```
bash scripts/verify/m011-p04-bash32-compat.sh
bash scripts/verify/m011-p04-spec-scope-tag-resolve.sh
bash scripts/verify/m011-p04-spec-scope-tag-graph-neighbors.sh
bash scripts/verify/m011-p04-requirement-pulls-neighbors.sh
bash scripts/verify/m011-p04-spec-scope-excludes-non-goals.sh
bash scripts/verify/m011-p04-spec-scope-skips-superseded.sh
```

Every verify script must print `PASS:` and exit 0. T01 creates ALL six verify scripts above. T03 tightens `m011-p04-bash32-compat.sh` to also scan `build-context.sh` and `section-handlers.sh`; T01 initially scans only `scope-filter.sh`.

### Fixture preparation pattern (for every verify script)

All T01 verify scripts use a `PROJECT_ROOT="$(mktemp -d)"` sandbox. Inside:

1. Create `$PROJECT_ROOT/knowledge/spec/requirement/SPEC-FR-001.md` (and other fixture entries) with valid frontmatter — set `scope_tags: "[milestone:M999]"`, `category: spec/requirement`, `relates_to: [SPEC-AC-001]`, `superseded_by: ""`.
2. Create related entries (`knowledge/spec/acceptance/SPEC-AC-001.md`, `knowledge/spec/constraint/SPEC-CON-001.md`) referencing the parent via `relates_to`.
3. Run `PROJECT_ROOT=$PROJECT_ROOT bash $SCRIPT_DIR/../knowledge/rebuild-index.sh` to build `knowledge.db`.
4. Invoke `PROJECT_ROOT=$PROJECT_ROOT bash scripts/dispatch/scope-filter.sh --spec-scope-tags "spec/requirement/SPEC-FR-001"` and assert on stdout.

For the superseded-tip test, set `superseded_by: "SPEC-FR-001-v2"` on SPEC-FR-001's frontmatter, rebuild the index, and assert stdout is empty (or does not contain `SPEC-FR-001`).

### Check script shapes (AD-19 compliance)

Every `m011-p04-*.sh` verify script is a standalone bash file. Inside the scripts themselves, use standard bash freely. The AD-19 rule applies only to the one-line `Check:` commands in phase plans (like the ones above), not to the internal logic of verify scripts. Follow the P03 pattern in `scripts/verify/m011-p03-supersede-on-change.sh` as reference.

## Inputs

### From Previous Tasks

None within P04. T01 is the first task of the phase.

### From Disk (Pre-existing)

- `scripts/dispatch/scope-filter.sh` (from P01)
  - Key API: `scope-filter.sh <file-path> <scope-context> [--type knowledge|decisions] [--depends P01,P03] [--min-confidence CONF] [--category CAT] [--graph] [--include-non-goals]`
  - Sources `scripts/knowledge/lib/graph-db.sh` lazily when `--graph` mode active
  - Exports: `FILE_PATH`, `SCOPE_CONTEXT`, `FILE_TYPE`, `DEPENDS`, `MIN_CONFIDENCE`, `FILTER_CATEGORY`, `USE_EFFECTIVE_CONFIDENCE`, `GRAPH_MODE`, `INCLUDE_NON_GOALS` as script-scope vars
- `scripts/knowledge/traverse-graph.sh`
  - Key API: `traverse-graph.sh --id <entry-id> [--hops <N>] [--max-entries <N>] [--ranked] [--provenance]`
  - Default output: one related entry ID per line. Exit 0 always.
- `scripts/knowledge/lib/graph-db.sh`
  - `get_db_path` — echoes path to `knowledge.db` (respects `$PROJECT_ROOT` via `get_project_root` from `index-utils.sh`)
  - `db_query <db_path> <sql>` — runs SQLite3 query, returns pipe-delimited rows on stdout
  - Schema: `entries(id TEXT PRIMARY KEY, category TEXT, confidence REAL, created_at TEXT, last_verified TEXT, hit_count INTEGER, description TEXT, superseded_by TEXT, ...)`; `scope_tags(entry_id TEXT, tag TEXT)`; `relates_to(from_id TEXT, to_id TEXT)`
- `scripts/knowledge/rebuild-index.sh`
  - Rebuilds `knowledge.db` by scanning `knowledge/*/*.md` and `knowledge/*/*/*.md`. Respects `$PROJECT_ROOT`.
- `scripts/knowledge/lib/index-utils.sh`
  - `get_project_root` — echoes `$PROJECT_ROOT` if set, else walks up from script location. Used indirectly via graph-db.sh.

## Constraints

- Bash 3.2 compatible: no `declare -A`, no `mapfile`, no `readarray`, no `<(...)` process substitution. Use parallel indexed arrays, `mktemp` files, or while-read loops from real files (MEM001).
- AD-19 discipline for `Check:` commands — every verify-script invocation in the phase plan is a single `bash scripts/verify/<name>.sh` line. Inside verify scripts, any bash is allowed.
- AP-004 compliance — no `$(...)` containing pipes, no brace expansion, no compound `&&`/`||`/`;` chains in Bash tool calls that execution agents will run.
- Do NOT modify `traverse-graph.sh`, `resolve-entries.sh`, `rebuild-index.sh`, or `graph-db.sh`. T01 only extends `scope-filter.sh`.
- Do NOT touch `build-context.sh` or `section-handlers.sh` — both belong to T02.
- The warning for a superseded or non-existent spec ID goes to stderr (`>&2`) with prefix `scope-filter.sh: WARN:`. Do not exit non-zero — the script must still exit 0 so callers do not cascade-fail on a single bad tag.
- Concurrent safety: use `mktemp` for any per-invocation temp file. No fixed `/tmp/scope-filter-*` paths.
- The fallback file-existence path (when `knowledge.db` is absent) scans `knowledge/spec/<cat>/<id>.md` via `$SCRIPT_DIR/../../knowledge/spec/...`. This matches the project-root knowledge layout (NOT `.orchestrator/knowledge/`).
- Scope: do not change the existing `filter_knowledge`, `filter_knowledge_index`, `filter_decisions`, or `filter_knowledge_graph` functions. All new logic is in the new `filter_spec_scope_tags` function and the thin dispatch check before positional-arg validation.

## Expected Output

- `scripts/dispatch/scope-filter.sh` modified: adds `SPEC_SCOPE_TAGS=""` initializer, `--spec-scope-tags` case arm, `filter_spec_scope_tags` function (~70 lines), and early dispatch to the new mode before positional-arg validation.
- `scripts/verify/m011-p04-spec-scope-tag-resolve.sh` (create) — creates a sandbox `knowledge/spec/requirement/SPEC-FR-001.md` with no `relates_to` neighbors, calls scope-filter with `--spec-scope-tags "spec/requirement/SPEC-FR-001"`, asserts stdout contains exactly `SPEC-FR-001` on a line of its own, prints `PASS:` or `FAIL:`.
- `scripts/verify/m011-p04-spec-scope-tag-graph-neighbors.sh` (create) — creates SPEC-FR-002 with `relates_to: [SPEC-AC-002]` and SPEC-AC-002 entry, rebuilds index, calls scope-filter, asserts stdout contains both `SPEC-FR-002` and `SPEC-AC-002`.
- `scripts/verify/m011-p04-requirement-pulls-neighbors.sh` (create) — richer fixture with 3 requirements, 2 acceptances, 1 constraint; asserts scope-filter on `spec/requirement/SPEC-FR-003` returns SPEC-FR-003 plus related AC + related CON but NOT other requirements.
- `scripts/verify/m011-p04-spec-scope-excludes-non-goals.sh` (create) — fixture with SPEC-NG-001; asserts `--spec-scope-tags "spec/non-goal/SPEC-NG-001"` (no flag) returns empty; with `--include-non-goals` returns `SPEC-NG-001`.
- `scripts/verify/m011-p04-spec-scope-skips-superseded.sh` (create) — fixture with SPEC-FR-003 superseded by SPEC-FR-003-v2; asserts `--spec-scope-tags "spec/requirement/SPEC-FR-003"` emits no `SPEC-FR-003` on stdout and writes a `WARN:` line to stderr.
- `scripts/verify/m011-p04-bash32-compat.sh` (create) — T01 version: runs `bash -n scripts/dispatch/scope-filter.sh` and greps for forbidden `declare -A` / `mapfile` / `readarray`; prints `PASS:` or `FAIL:`. T03 expands to cover build-context.sh and section-handlers.sh.
- All six verify scripts print `PASS:` and exit 0.
