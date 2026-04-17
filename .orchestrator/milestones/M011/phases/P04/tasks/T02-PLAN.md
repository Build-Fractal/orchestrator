---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M011"
name: "Wire build-context.sh to emit Spec Context section from task-plan scope_tags"
depends_on: [T01]
---

## Prerequisites

T01 is complete. The following behaviors are on disk:

- `bash scripts/dispatch/scope-filter.sh --spec-scope-tags "spec/requirement/SPEC-FR-003"` emits SPEC-FR-003 plus its 1-hop `relates_to` neighbors (one ID per line). It respects `--include-non-goals` (default excludes `spec/non-goal`) and skips superseded tips with a stderr `WARN:` line.
- `scripts/dispatch/scope-filter.sh` also still supports its previous knowledge-filter modes unchanged.
- `scripts/knowledge/resolve-entries.sh` accepts IDs on stdin (one per line) or as arguments, and echoes the full body of each resolved knowledge entry to stdout, separated by blank lines. It scans `knowledge/*/*.md` and, for spec entries, relies on the two-level layout reachable via `lib/detail-utils.sh find_detail_file` (extended in P03 to scan nested dirs).

No spec-context emission path exists in `build-context.sh`. Task plans with `scope_tags: [spec/requirement/SPEC-FR-003]` in their frontmatter currently have no effect on the dispatch payload.

## Description

Add a new **Spec Context** section to the recipe-driven dispatch payload. When a task plan's YAML frontmatter contains a `scope_tags:` list that includes one or more `spec/*` entries, `build-context.sh` must emit a dedicated `## Spec Context` section containing the resolved chunk bodies (nothing else from the spec).

Three coordinated edits land in this task:

1. **`scripts/dispatch/lib/section-handlers.sh`** — new `handle_spec_context` handler that (a) reads task-plan frontmatter for `scope_tags`, (b) extracts `spec/*` entries, (c) invokes T01's `scope-filter.sh --spec-scope-tags` to get resolved SPEC- IDs, (d) pipes those IDs to `resolve-entries.sh`, (e) emits a `## Spec Context` header plus the resolved bodies. When no `spec/*` tags are present, the handler emits nothing (no header — the dispatcher must skip the section entirely).

2. **`scripts/dispatch/build-context.sh`** — register the new handler in `dispatch_section_handler` and the display-order/name/priority tables (`_bc_display_order`, `_bc_display_name`, `_bc_display_priority`). Add an **omit-empty** path: when `handle_spec_context` produces empty output for a task, the section MUST be omitted from both the manifest and the payload body. This is the first recipe-driven section that can omit itself; the section-loop in `build-context.sh` currently always counts every section.

3. **`templates/context-recipe.yaml`** — add a new `spec_context` section entry with `source: spec_context`, `priority: compressible`, `order: 35`, `filter: scope`, `cache_hint: semi-static`. Place it between `constraints` (order 30) and `scope` (order 40) so the display-order shim in `build-context.sh` can map it to its preferred slot.

The key invariant: when the task plan has no `spec/*` scope_tags, the payload looks identical to today's payload (no `## Spec Context` header, no extra manifest row).

## Steps

### Step 1: Add `handle_spec_context` to `scripts/dispatch/lib/section-handlers.sh`

Append this handler after `handle_decisions` (around line 391). It takes the same common coordinates as other handlers:

```bash
# handle_spec_context <orch_root> <milestone> <phase> <task>
# Emits a "## Spec Context" block containing resolved spec chunk bodies,
# scope-filtered by the task plan's frontmatter spec/* scope_tags. If the
# task plan has NO spec/* scope_tags, this handler emits nothing (empty
# output) so the caller can omit the section entirely.
handle_spec_context() {
  local orch_root="$1" milestone="$2" phase="$3" task="$4"
  local ms_dir
  ms_dir="$(_sh_resolve_milestone_dir "$orch_root" "$milestone")" || return 0

  # Only meaningful for task dispatch, not phase planning
  if [ "$task" = "PHASE_PLAN" ]; then
    return 0
  fi

  local task_plan="${ms_dir}/phases/${phase}/tasks/${task}-PLAN.md"
  if [ ! -f "$task_plan" ]; then
    return 0
  fi

  # Extract the scope_tags line from the YAML frontmatter and tokenize
  # spec/* entries. Task-plan frontmatter format (P03 convention):
  #   scope_tags: [spec/requirement/SPEC-FR-003, project]
  # We accept both bracket-list and comma lists.
  local tags_line
  tags_line="$(awk '/^---$/{c++; next} c==1 && /^scope_tags:/{print; exit}' "$task_plan" 2>/dev/null || true)"
  if [ -z "$tags_line" ]; then
    return 0
  fi

  # Strip 'scope_tags:' prefix, brackets, quotes; normalize separators to spaces
  local raw_tags
  raw_tags="$(printf '%s' "$tags_line" \
    | sed 's/^scope_tags:[[:space:]]*//' \
    | sed 's/^\[//; s/\]$//' \
    | tr ',' ' ' \
    | tr -d '"' \
    | tr -s ' ')"

  # Keep only spec/* tokens
  local spec_tags="" tok
  for tok in $raw_tags; do
    case "$tok" in
      spec/*) spec_tags="${spec_tags}${tok},";;
    esac
  done

  # Strip trailing comma
  spec_tags="$(printf '%s' "$spec_tags" | sed 's/,$//')"

  if [ -z "$spec_tags" ]; then
    return 0
  fi

  # Resolve IDs via T01's scope-filter spec-scope-tags mode
  local ids_file
  ids_file="$(mktemp)"
  bash "$_SH_SCOPE_FILTER" --spec-scope-tags "$spec_tags" \
    > "$ids_file" 2>/dev/null || true

  if [ ! -s "$ids_file" ]; then
    rm -f "$ids_file"
    return 0
  fi

  # Resolve IDs to chunk bodies
  local resolved
  resolved="$(cat "$ids_file" | bash "$_SH_RESOLVE_ENTRIES" 2>/dev/null || true)"
  local id_count
  id_count="$(wc -l < "$ids_file" | tr -d ' ')"
  rm -f "$ids_file"

  if [ -z "$resolved" ]; then
    return 0
  fi

  printf '## Spec Context\n\n'
  printf '<!-- %s spec chunks resolved from task scope_tags -->\n\n' "$id_count"
  printf '%s\n' "$resolved"
}
```

### Step 2: Register `handle_spec_context` in `dispatch_section_handler`

Update `dispatch_section_handler` at the bottom of `section-handlers.sh` (around line 429) to add a `spec_context` source arm:

```bash
    spec_context)
      handle_spec_context "$orch_root" "$milestone" "$phase" "$task"
      ;;
```

Place it before the `*.md` fallthrough arm.

### Step 3: Add `spec_context` entry to `templates/context-recipe.yaml`

Insert this block inside the `sections:` dict, between `constraints` (order 30) and `scope` (order 40):

```yaml
  spec_context:
    source: spec_context
    priority: compressible
    order: 35
    filter: scope
    cache_hint: semi-static
```

Add to `compression.protected_sections` if the task plan demands it — but per M011 spec, spec chunks are compressible, so leave `protected_sections: task_plan,scope,state` unchanged.

### Step 4: Wire display-order shim in `build-context.sh`

Update the three display helper functions (lines ~682-713) to know about `spec_context`:

```bash
_bc_display_order() {
  case "$1" in
    knowledge)   echo 1 ;;
    decisions)   echo 2 ;;
    constraints) echo 3 ;;
    spec_context) echo 4 ;;  # NEW: spec chunks after constraints, before scope
    scope)       echo 5 ;;   # shifted from 4
    upstream)    echo 6 ;;   # shifted from 5
    task_plan)   echo 7 ;;   # shifted from 6
    state)       echo 8 ;;   # shifted from 7
    *)           echo 99 ;;
  esac
}
_bc_display_name() {
  case "$1" in
    knowledge)   echo "Knowledge" ;;
    decisions)   echo "Decisions" ;;
    scope)       echo "Scope" ;;
    upstream)    echo "Upstream Context" ;;
    task_plan)   echo "Task Plan" ;;
    state)       echo "State Context" ;;
    constraints) echo "Constraints" ;;
    spec_context) echo "Spec Context" ;;
    *)           echo "$1" ;;
  esac
}
_bc_display_priority() {
  case "$1" in
    knowledge|decisions|spec_context) echo "filtered" ;;
    *) echo "required" ;;
  esac
}
```

### Step 5: Omit-empty handling in the dispatch loop

In `build-context.sh`, in the `while IFS='|' read -r disp_ord s_name s_source s_priority` loop (around lines 783-816), modify the logic so that when `handle_spec_context` produces empty output, the section is omitted.

Replace the current dispatch-or-record pattern with:

```bash
while IFS='|' read -r disp_ord s_name s_source s_priority; do
  [ -z "$s_name" ] && continue

  # Dispatch to handler (write to a staging file first, then decide)
  local staging_file="$TMPDIR_BUILD/_staging_s${idx}.txt"
  if [ "$s_source" = "phase_summaries" ]; then
    _bc_handle_phase_summaries_fixed > "$staging_file" 2>/dev/null || : > "$staging_file"
  else
    dispatch_section_handler "$s_source" "$s_name" \
      "$ORCH_ROOT" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" "$INCLUDED_IDS_FILE" \
      > "$staging_file" 2>/dev/null || : > "$staging_file"
  fi

  # Omit-empty: if spec_context produced empty output, skip the section entirely
  if [ "$s_source" = "spec_context" ] && [ ! -s "$staging_file" ]; then
    rm -f "$staging_file"
    continue
  fi

  # Commit to the real section file
  mv "$staging_file" "$TMPDIR_BUILD/s${idx}.txt"
  SECTION_COUNT=$((SECTION_COUNT + 1))
  disp_name="$(_bc_display_name "$s_name")"
  disp_pri="$(_bc_display_priority "$s_name")"
  if [ -z "$SECTION_NAMES_PIPE" ]; then
    SECTION_NAMES_PIPE="$disp_name"
    SECTION_PRIORITIES_PIPE="$disp_pri"
  else
    SECTION_NAMES_PIPE="${SECTION_NAMES_PIPE}|${disp_name}"
    SECTION_PRIORITIES_PIPE="${SECTION_PRIORITIES_PIPE}|${disp_pri}"
  fi
  idx=$((idx + 1))
done < "$SORTED_SECTIONS_FINAL"
```

Notice `SECTION_COUNT` is now incremented only when the section is committed, and `idx` is advanced only in the commit branch. This preserves the contiguous `s1.txt`, `s2.txt`, ... file naming that `_bc_assemble_manifest_and_emit` requires.

Note: `build-context.sh` uses `set -euo pipefail`. `local` is only valid inside functions — the loop above runs at top-level in the current script. Either (a) move the loop into a helper function, or (b) drop `local` and use plain assignment. Option (b) is minimal: replace `local staging_file=...` with `staging_file=...` at top level. Do not use `local` outside a function.

### Step 6: Update the error-suppression trap cleanup

The existing `_bc_cleanup_and_result` function only removes `$TMPDIR_BUILD` and `$INCLUDED_IDS_FILE`. Since `$TMPDIR_BUILD` is cleaned wholesale, no extra cleanup is needed for staging files.

## Must-Haves

- `handle_spec_context` exists in `scripts/dispatch/lib/section-handlers.sh` and is routed from `dispatch_section_handler` on `source: spec_context`
- `templates/context-recipe.yaml` has a `spec_context` section with `source: spec_context`, `order: 35`, `priority: compressible`, `filter: scope`, `cache_hint: semi-static`
- `build-context.sh` `_bc_display_order`, `_bc_display_name`, `_bc_display_priority` include a `spec_context` case
- `build-context.sh` omits the `Spec Context` section (manifest row + body) entirely when `handle_spec_context` produces empty output
- When a task plan's frontmatter has `scope_tags: [spec/requirement/SPEC-FR-003]` (and the fixture knowledge tree contains a matching entry), the dispatch payload contains `## Spec Context` with SPEC-FR-003's body
- When a task plan's frontmatter has no `spec/*` entries in `scope_tags`, the dispatch payload has no `## Spec Context` section at all
- When a task plan's frontmatter lists `spec/requirement/SPEC-FR-003` and the fixture also contains SPEC-FR-001 and SPEC-FR-002 (unrelated), neither SPEC-FR-001 nor SPEC-FR-002 bodies appear in the payload
- All modified scripts pass `bash -n` with no `declare -A` / `mapfile` / `readarray` / `<(...)` usage

## Verification

```
bash scripts/verify/m011-p04-bash32-compat.sh
bash scripts/verify/m011-p04-dispatch-includes-spec-context.sh
bash scripts/verify/m011-p04-dispatch-omits-spec-context-when-unused.sh
bash scripts/verify/m011-p04-dispatch-excludes-out-of-scope.sh
```

T02 creates the three `m011-p04-dispatch-*.sh` verify scripts and tightens `m011-p04-bash32-compat.sh` to also scan `build-context.sh` and `section-handlers.sh`. It also re-runs T01's verify scripts to confirm no regression in scope-filter behavior.

### Fixture preparation pattern

Each dispatch verify script builds a minimal milestone fixture inside a `mktemp` sandbox:

1. `$FIXTURE/.orchestrator/milestones/M999/M999-ROADMAP.md` — minimal roadmap with a P01 entry.
2. `$FIXTURE/.orchestrator/milestones/M999/phases/P01/P01-PLAN.md` — empty phase plan scaffold.
3. `$FIXTURE/.orchestrator/milestones/M999/phases/P01/tasks/T01-PLAN.md` — task plan with `scope_tags: [spec/requirement/SPEC-FR-003]` in frontmatter.
4. `$FIXTURE/knowledge/spec/requirement/SPEC-FR-003.md` and a related `SPEC-AC-007.md` with `relates_to: [SPEC-FR-003]`.
5. `PROJECT_ROOT=$FIXTURE bash scripts/knowledge/rebuild-index.sh` to populate `knowledge.db`.
6. `bash scripts/dispatch/build-context.sh $FIXTURE/.orchestrator M999 P01 T01` → capture stdout.
7. Assert stdout contains `## Spec Context` + `SPEC-FR-003` body; assert it does NOT contain `SPEC-FR-001` or `SPEC-FR-002` bodies.

For the `omits-spec-context-when-unused` script, use the same fixture but set `scope_tags: [project]` (no `spec/*` tag). Assert stdout does NOT contain `## Spec Context`.

## Inputs

### From Previous Tasks

- `scripts/dispatch/scope-filter.sh` (from T01)
  - Key API: `scope-filter.sh --spec-scope-tags "<comma-or-space-sep spec/<cat>/<SPEC-ID> list>" [--include-non-goals]`
  - Emits resolved SPEC- IDs + 1-hop `relates_to` neighbors, one per line, to stdout
  - Respects non-goal exclusion, skips superseded tips (with stderr `WARN:` lines)
  - Exit 0 even when input tag list is empty or contains only bad tags
  - Existing modes (positional-args knowledge/decisions filter + `--graph` + `--category`) are unchanged

### From Disk (Pre-existing)

- `scripts/dispatch/build-context.sh` (existing)
  - Key API: `build-context.sh <orch_root> <milestone> <phase> <task> [--config-defaults <f>] [--recipe <f>]`
  - Two branches: IS_PLANNING=true (task == `PHASE_PLAN`) and task-dispatch (recipe-driven)
  - Task-dispatch branch parses the recipe via `parse_recipe_sections`, runs each section through `dispatch_section_handler`, and assembles a manifest-prefixed payload via `_bc_assemble_manifest_and_emit`
  - Reads task plan at `${ms_dir}/phases/${phase}/tasks/${task}-PLAN.md` and phase plan at `${ms_dir}/phases/${phase}/${phase}-PLAN.md`
- `scripts/dispatch/lib/section-handlers.sh` (existing)
  - Handlers: `handle_computed`, `handle_phase_summaries`, `handle_phase_plan`, `handle_task_plan`, `handle_template`, `handle_knowledge`, `handle_decisions`, `handle_file`
  - `dispatch_section_handler <source> <section_name> <orch_root> <milestone> <phase> <task> [<included_ids_file>]` routes by source
  - Provides `_SH_SCOPE_FILTER`, `_SH_TRAVERSE_GRAPH`, `_SH_RESOLVE_ENTRIES`, `_SH_READ_ROADMAP` path constants
- `scripts/knowledge/resolve-entries.sh`
  - Key API: echo IDs on stdin (one per line) → emit full chunk bodies to stdout, blank-line separated
- `templates/context-recipe.yaml` (existing)
  - YAML with `sections:` dict — each entry has `source`, `priority`, `order`, `filter`, `cache_hint`
  - `compression:` block with `protected_sections` list
- `scripts/lib/recipe-parser.sh` (existing)
  - `parse_recipe_sections <recipe-file>` → stdout pipe-delimited `name|source|priority|order|filter|cache` rows sorted by order

## Constraints

- Bash 3.2 compatible: no `declare -A`, no `mapfile`, no `readarray`, no `<(...)`. Parallel indexed arrays or temp files for cross-scope state (MEM001).
- AD-19 discipline for `Check:` commands — one `bash scripts/verify/<name>.sh` invocation per line in the phase plan. Internal verify-script contents can use any bash.
- AP-004 compliance in execution-agent bash calls: no `$(...)` containing pipes in the scripts' own commands that agents might run from compound shells. (The internal `create_chunk` and handler functions use `$(...)` internally, which is fine — the constraint is on what execution agents invoke.)
- The handler MUST emit empty output (exit 0, zero bytes to stdout) when no `spec/*` tags are present. It MUST NOT emit an empty `## Spec Context` header.
- The `omit-empty` mechanism in `build-context.sh` is specific to `spec_context`. Do NOT generalize to other sections — other handlers always emit their header (even for "No X in scope" content) and that contract is relied upon by existing tests.
- Do NOT modify `handle_computed`, `handle_phase_summaries`, `handle_phase_plan`, `handle_task_plan`, `handle_template`, `handle_knowledge`, `handle_decisions`, or `handle_file`. Only the new `handle_spec_context` and the `dispatch_section_handler` routing table are touched.
- Do NOT modify `scripts/knowledge/resolve-entries.sh`, `scripts/knowledge/traverse-graph.sh`, or `scripts/lib/recipe-parser.sh`.
- Preserve the existing manifest-line-counting math in `_bc_assemble_manifest_and_emit`. The omit-empty path must not leave gaps in the `s1.txt`, `s2.txt`, ... sequence — use staging files and only mv-commit when keeping.
- `local` is only valid inside functions. Do not use `local` at the top-level section-dispatch loop. Use plain assignments.
- Do NOT touch the planning-payload branch (`_bc_assemble_planning_payload`) — spec context is a dispatch-time feature only, not a planning-time feature.
- Scope: no verify-script tightening or new E2E demo — those are T03.

## Expected Output

- `scripts/dispatch/lib/section-handlers.sh` modified: adds `handle_spec_context` (~60 lines) and one new arm in `dispatch_section_handler`.
- `scripts/dispatch/build-context.sh` modified: updates `_bc_display_order` / `_bc_display_name` / `_bc_display_priority` tables; rewrites the section-dispatch loop to support omit-empty via staging files.
- `templates/context-recipe.yaml` modified: adds `spec_context` section entry.
- `scripts/verify/m011-p04-dispatch-includes-spec-context.sh` (create) — end-to-end: build fixture milestone + knowledge tree, invoke `build-context.sh`, assert stdout contains `## Spec Context` and SPEC-FR-003's body.
- `scripts/verify/m011-p04-dispatch-omits-spec-context-when-unused.sh` (create) — same fixture, task plan with no `spec/*` scope tag, assert stdout does NOT contain `## Spec Context`.
- `scripts/verify/m011-p04-dispatch-excludes-out-of-scope.sh` (create) — fixture with SPEC-FR-001, SPEC-FR-002, SPEC-FR-003; task scoped to SPEC-FR-003; assert stdout contains SPEC-FR-003 body and does NOT contain SPEC-FR-001 or SPEC-FR-002 bodies.
- `scripts/verify/m011-p04-bash32-compat.sh` (modify) — extend to also scan `build-context.sh` and `section-handlers.sh`.
- All three new verify scripts print `PASS:` and exit 0. Every T01 verify script continues to pass (no regression).
