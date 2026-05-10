---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M011"
name: "Supersession wiring + REMOVED marking + phase-impact review"
depends_on: [T01]
---

## Prerequisites

T01 is complete. The following exists in `scripts/knowledge/ingest-spec.sh`:

- An `INGEST_OBSERVED_LOG` file that every `create_chunk` invocation appends `id|category` to, cleaned up via EXIT trap
- A `classify_chunk_decision <id> <new-hash>` helper returning `NEW` / `UNCHANGED` / `CHANGED`
- A `_do_create_chunk <id> <category> <source_section> <description> <body> <relates_to> <content_hash>` helper that runs `create-entry.sh` and patches the `content_hash` frontmatter field
- A `create_chunk` function that, based on the decision, emits `DECIDE-NEW:` / `DECIDE-UNCHANGED:` / `DECIDE-CHANGED:` and either calls `_do_create_chunk` (for NEW) or does nothing else (for UNCHANGED / CHANGED)
- A `dump_observed_log` helper returning the observed-ID log contents on stdout

On disk:

- `scripts/knowledge/supersede-entry.sh` accepts `--old-id <id> --new-id <id>`. It sets `superseded_by: "<new-id>"` on the old entry, `supersedes: "<old-id>"` on the new entry, and removes the old entry from `KNOWLEDGE-INDEX.md`. Prints `SUPERSEDED: <old> by <new>` or `ALREADY_SUPERSEDED: <old> by <new>`.
- `scripts/knowledge/traverse-graph.sh --provenance --id <id>` follows supersession chains and prints them with origin/superseded/current labels.
- `scripts/knowledge/lib/detail-utils.sh` exports `find_detail_file`, `fm_field`, `sed_i`.

## Description

Wire T01's decision layer to the actual supersession and removal actions, and add phase-impact `REVIEW:` emission.

Three behaviors land in this task:

1. **CHANGED -> SUPERSEDED**: for a `CHANGED` decision, `create_chunk` must (a) derive a versioned new ID by appending `-v<N>` (N = existing chain length + 1), (b) create the new chunk via `_do_create_chunk` with that versioned ID, (c) call `supersede-entry.sh --old-id <id> --new-id <id>-v<N>`, (d) emit `SUPERSEDED: <old-id> -> <new-id>` in place of `DECIDE-CHANGED:`, (e) check the old entry's `scope_tags` for a phase reference and emit a `REVIEW:` line if one exists.

2. **REMOVED detection**: after the main section-splitter loop finishes (in the top-level script body, before the final `rebuild-index.sh` call), diff the observed-ID log against all `SPEC-*` entries on disk under `$INGEST_PROJECT_ROOT/knowledge/spec/*/`. For each on-disk `SPEC-*` entry whose ID does not appear in the observed log AND whose `superseded_by` field is currently empty, patch `superseded_by: "REMOVED"` via `sed_i` and emit `REMOVED: <id>`. Also run the same phase-impact check and emit `REVIEW:` if the removed chunk's scope_tags reference a phase.

3. **Output cleanup**: replace T01's `DECIDE-UNCHANGED:` with `SKIPPED: <id>` and `DECIDE-NEW:` with `CREATED: <id>` (the latter already comes from `create-entry.sh` via `_do_create_chunk`; just ensure no `DECIDE-*` prefix leaks to stdout). Update the final `INGEST:` summary line to include `superseded=` and `removed=` counters.

## Steps

### Step 1: Add counters and versioning helper

Near the existing counters (around line 52–60), add:

```bash
SUPERSEDED_COUNT=0
REMOVED_COUNT=0
REVIEW_COUNT=0
```

Add a helper that walks the supersession chain to derive the next version suffix. Place it near `classify_chunk_decision`:

```bash
# --- next_version_id <old-id> ---
# Walks the supersession chain forward from old-id and returns the next
# version suffix. If old-id has no -v suffix and no successor, returns
# old-id-v2. If old-id is already -vN, returns the base with -v(N+1).
# If old-id already has a successor (old-id -> old-id-v2), walks forward
# until it finds the tip, then appends the next suffix.
next_version_id() {
  local cursor="$1"
  local cursor_file=""
  while :; do
    cursor_file="$(find_detail_file "$cursor" 2>/dev/null)" || break
    local successor=""
    successor="$(fm_field "$cursor_file" "superseded_by")"
    if [ -z "$successor" ] || [ "$successor" = "REMOVED" ]; then
      break
    fi
    cursor="$successor"
  done

  # Derive next suffix from the tip
  case "$cursor" in
    *-v[0-9]*)
      local base="${cursor%-v*}"
      local n="${cursor##*-v}"
      echo "${base}-v$((n + 1))"
      ;;
    *)
      echo "${cursor}-v2"
      ;;
  esac
}
```

### Step 2: Add a phase-impact helper

Insert near `classify_chunk_decision`:

```bash
# --- emit_phase_impact <old-id> <new-id-or-REMOVED> ---
# If old-id's scope_tags contain a phase reference (e.g. [phase:P02] or
# [milestone:M011/P02]), emits `REVIEW: P## affected by <old-id> supersession`
# for each distinct phase found. Silent when no phase tags are present.
emit_phase_impact() {
  local old_id="$1"
  local existing_file=""
  existing_file="$(find_detail_file "$old_id" 2>/dev/null)" || return 0
  local tags=""
  tags="$(fm_field "$existing_file" "scope_tags")"
  if [ -z "$tags" ]; then
    return 0
  fi
  # Extract P## references. Two accepted patterns:
  #   [phase:P##]
  #   [milestone:M###/P##]
  # Emit one REVIEW line per distinct phase found.
  local phases=""
  phases="$(printf '%s\n' "$tags" \
    | grep -oE '(phase:|M[0-9]+/)P[0-9]+' \
    | sed 's/^.*P/P/' \
    | sort -u)"
  if [ -z "$phases" ]; then
    return 0
  fi
  local pline=""
  while IFS= read -r pline || [ -n "$pline" ]; do
    if [ -n "$pline" ]; then
      echo "REVIEW: $pline affected by $old_id supersession"
      REVIEW_COUNT=$((REVIEW_COUNT + 1))
    fi
  done <<EOF_PHASES
$phases
EOF_PHASES
}
```

Note: this helper uses a plain `grep -oE` followed by `sed` and `sort -u` in a single pipeline — this is inside a shell-function body, not a `Check:` command, so AD-19 does not apply.

### Step 3: Rewire the CHANGED branch in `create_chunk`

Replace T01's `DECIDE-CHANGED:` branch with real supersession logic:

```bash
    CHANGED)
      local new_id=""
      new_id="$(next_version_id "$chunk_id")"
      _do_create_chunk "$new_id" "$category" "$source_section" \
        "$description" "$body" "$relates_to" "$content_hash"
      # Wire the supersession chain
      local sup_out=""
      sup_out="$(bash "$SCRIPT_DIR/supersede-entry.sh" \
        --old-id "$chunk_id" --new-id "$new_id" 2>&1)" || true
      case "$sup_out" in
        SUPERSEDED:*|ALREADY_SUPERSEDED:*) : ;;
        *) echo "ERROR: supersede-entry.sh failed for $chunk_id -> $new_id: $sup_out" >&2 ;;
      esac
      SUPERSEDED_COUNT=$((SUPERSEDED_COUNT + 1))
      echo "SUPERSEDED: $chunk_id -> $new_id"
      emit_phase_impact "$chunk_id" "$new_id"
      ;;
```

### Step 4: Clean up intermediate DECIDE-* prefixes

Replace T01's `DECIDE-NEW:` branch with no extra output — the `CREATED:` line already comes from `_do_create_chunk`'s invocation of `create-entry.sh`. Replace `DECIDE-UNCHANGED:` with `SKIPPED: <id>`:

```bash
    NEW)
      _do_create_chunk "$chunk_id" "$category" "$source_section" \
        "$description" "$body" "$relates_to" "$content_hash"
      ;;
    UNCHANGED)
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
      echo "SKIPPED: $chunk_id"
      ;;
```

Confirm `_do_create_chunk` still prints `CREATED: <id> at knowledge/<category>/<id>.md` for new chunks (that is the pre-existing output from `create-entry.sh`).

### Step 5: Add REMOVED-detection pass

Immediately after the final section dispatch (after `dispatch_section "$current_h2" "$current_h2_body"` near line 593) and before the `rebuild-index.sh` call, add:

```bash
# --- REMOVED detection pass ---
# For every SPEC-* entry on disk whose ID was not observed during this
# ingest, mark it superseded_by: REMOVED and emit REVIEW lines for any
# phase-scoped tags.
detect_removed_entries() {
  local spec_dir="$INGEST_PROJECT_ROOT/knowledge/spec"
  if [ ! -d "$spec_dir" ]; then
    return 0
  fi

  # Build the observed-ID set (one ID per line, category stripped)
  local observed_ids=""
  observed_ids="$(dump_observed_log | awk -F'|' '{print $1}' | sort -u)"

  # Walk every SPEC-*.md under spec/*/, check if its ID appears in observed
  local disk_file=""
  for disk_file in "$spec_dir"/*/SPEC-*.md; do
    [ -f "$disk_file" ] || continue
    local disk_id=""
    disk_id="$(basename "$disk_file" .md)"

    # Skip versioned entries like SPEC-FR-003-v2 — those were produced by
    # this ingest as successors and are not candidates for REMOVED.
    case "$disk_id" in
      *-v[0-9]*) continue ;;
    esac

    # Skip entries already superseded (including REMOVED)
    local existing_sup=""
    existing_sup="$(fm_field "$disk_file" "superseded_by")"
    if [ -n "$existing_sup" ]; then
      continue
    fi

    # Check observed set membership
    local found=""
    found="$(printf '%s\n' "$observed_ids" | grep -x "$disk_id" || true)"
    if [ -n "$found" ]; then
      continue
    fi

    # Unobserved and not already superseded — mark REMOVED
    sed_i "s|^superseded_by: .*|superseded_by: \"REMOVED\"|" "$disk_file"
    REMOVED_COUNT=$((REMOVED_COUNT + 1))
    echo "REMOVED: $disk_id"
    emit_phase_impact "$disk_id" "REMOVED"
  done
}

detect_removed_entries
```

### Step 6: Update the summary line

Replace the final summary line with:

```bash
echo "INGEST: $SLUG complete. created=$CREATED_COUNT skipped=$SKIPPED_COUNT superseded=$SUPERSEDED_COUNT removed=$REMOVED_COUNT review=$REVIEW_COUNT"
```

### Step 7: Write the five new verify scripts

Create each under `scripts/verify/` following the P02 verify-script pattern (sandboxed `PROJECT_ROOT=$(mktemp -d)`, create required `knowledge/spec/<type>/` directories, write a small fixture spec, invoke `ingest-spec.sh` twice — once to seed, once to re-ingest after modification — and assert specific stdout patterns or frontmatter fields):

- `scripts/verify/m011-p03-removed-on-deletion.sh` — seed spec has FR-001 and FR-002; re-ingest with FR-002 removed; assert stdout contains `REMOVED: SPEC-FR-002` and does not contain `REMOVED: SPEC-FR-001`.
- `scripts/verify/m011-p03-supersede-frontmatter.sh` — seed + modify FR-001's body; after re-ingest open `knowledge/spec/requirement/SPEC-FR-001.md`, assert `superseded_by: "SPEC-FR-001-v2"`; open `SPEC-FR-001-v2.md`, assert `supersedes: "SPEC-FR-001"`.
- `scripts/verify/m011-p03-removed-frontmatter.sh` — seed with FR-001 and FR-002; re-ingest with FR-002 removed; assert `SPEC-FR-002.md` frontmatter has `superseded_by: "REMOVED"`.
- `scripts/verify/m011-p03-phase-impact-review.sh` — seed with a requirement whose `scope_tags` includes `[phase:P05]` (override via `--scope-tags "[spec:test][phase:P05]"`); modify the requirement; re-ingest; assert stdout contains `REVIEW: P05 affected by SPEC-FR-001 supersession`.
- Tighten `scripts/verify/m011-p03-supersede-on-change.sh` (created in T01) to require a `SUPERSEDED:` line specifically (replace the permissive `DECIDE-CHANGED\|SUPERSEDED` grep with strict `^SUPERSEDED:`).
- Tighten `scripts/verify/m011-p03-skip-unchanged.sh` (created in T01) to require `^SKIPPED:` instead of `DECIDE-UNCHANGED:`.

## Must-Haves

- For `CHANGED` decisions, `create_chunk` calls `_do_create_chunk` with a versioned new ID (`<old-id>-v<N>`) and then calls `supersede-entry.sh --old-id <old-id> --new-id <new-id>`
- Output contains `SUPERSEDED: <old-id> -> <new-id>` (not `DECIDE-CHANGED:`) for each changed chunk
- Output contains `SKIPPED: <id>` (not `DECIDE-UNCHANGED:`) for each unchanged chunk
- After ingest, the old entry's `superseded_by` frontmatter field equals the new versioned ID; the new entry's `supersedes` field equals the old ID
- A `detect_removed_entries` pass runs after section dispatch and before rebuild-index, marking `superseded_by: "REMOVED"` on any pre-existing `SPEC-*` entry whose ID was not observed during this run and is not already superseded, and emits `REMOVED: <id>` to stdout
- The REMOVED pass skips versioned entries (`*-v[0-9]*`) so successors created during this run are not themselves marked REMOVED
- When a superseded or removed entry's `scope_tags` contain a phase reference (either `[phase:P##]` or `[milestone:M###/P##]`), a `REVIEW: P## affected by <id> supersession` line is emitted
- The final `INGEST:` summary line reports `created=`, `skipped=`, `superseded=`, `removed=`, and `review=` counters
- `ingest-spec.sh` passes `bash -n` syntax check under Bash 3.2

## Verification

```
bash scripts/verify/m011-p03-skip-unchanged.sh
bash scripts/verify/m011-p03-supersede-on-change.sh
bash scripts/verify/m011-p03-removed-on-deletion.sh
bash scripts/verify/m011-p03-supersede-frontmatter.sh
bash scripts/verify/m011-p03-removed-frontmatter.sh
bash scripts/verify/m011-p03-phase-impact-review.sh
bash scripts/verify/m011-p03-bash32-compat.sh
```

All must print `PASS:` and exit 0.

## Inputs

### From Previous Tasks

- `scripts/knowledge/ingest-spec.sh` (from T01)
  - Key API (unchanged): `ingest-spec.sh --spec-path <path> --slug <slug> [--scope-tags <tags>]`
  - New helpers: `classify_chunk_decision`, `_do_create_chunk`, `dump_observed_log`
  - New state: `INGEST_OBSERVED_LOG` path, EXIT trap cleanup
  - Current `create_chunk` emits `DECIDE-NEW:` / `DECIDE-UNCHANGED:` / `DECIDE-CHANGED:` — T02 replaces those prefixes with real `CREATED:` (via passthrough), `SKIPPED:`, `SUPERSEDED:` lines
- `scripts/verify/m011-p03-skip-unchanged.sh` (from T01) — permissive pattern; tighten to `^SKIPPED:` here
- `scripts/verify/m011-p03-supersede-on-change.sh` (from T01) — permissive pattern; tighten to `^SUPERSEDED:` here
- `scripts/verify/m011-p03-bash32-compat.sh` (from T01) — already exists; re-run here to confirm no regression

### From Disk (Pre-existing)

- `scripts/knowledge/supersede-entry.sh`
  - API: `supersede-entry.sh --old-id <id> --new-id <id>`
  - Output: `SUPERSEDED: <old> by <new>` on first call, `ALREADY_SUPERSEDED: <old> by <new>` on a no-op repeat. Exit 0 in both cases.
  - Side effects: sets `superseded_by` on old file, `supersedes` on new file (both via `sed_i`), removes old entry from `KNOWLEDGE-INDEX.md`.
- `scripts/knowledge/lib/detail-utils.sh`
  - `find_detail_file <id>` — returns 0 + path on stdout, or non-zero (caller must wrap in `|| { ...; }` under `set -e`)
  - `fm_field <file> <field>` — reads scalar YAML frontmatter values
  - `sed_i <expr> <file>` — portable `sed -i`
- `scripts/knowledge/create-entry.sh`
  - When called with `--id SPEC-FR-001-v2 --category spec/requirement ...`, creates `knowledge/spec/requirement/SPEC-FR-001-v2.md`. Accepts arbitrary ID suffixes as long as the SPEC- prefix rule (SPEC-* IDs require `--category spec/*`) holds.

## Constraints

- Bash 3.2 compatible. No `declare -A`, no `mapfile` / `readarray`.
- AD-19: all `Check:` commands in the phase plan are single-script-file invocations. Inside the verify scripts, keep any pipelines, subshells, `$(...)` with pipes, etc. — those run under `bash scripts/verify/...` which is already a single-script-file shape at the phase-plan level.
- Do not modify `supersede-entry.sh`, `create-entry.sh`, `traverse-graph.sh`, or `lib/detail-utils.sh`. This task only extends `ingest-spec.sh` and creates verify scripts.
- The versioned-ID convention is `<old-id>-v<N>` where `N` = chain length + 1. First supersession of `SPEC-FR-003` produces `SPEC-FR-003-v2`; a second supersession of the chain tip (`SPEC-FR-003-v2`) produces `SPEC-FR-003-v3`. The `next_version_id` helper in Step 1 implements this.
- REMOVED detection must skip `*-v[0-9]*` entries. Without this guard, the versioned successor created during the current run (e.g., `SPEC-FR-003-v2`) would itself be flagged `REMOVED` because the classifiers emit the base ID `SPEC-FR-003`, not the versioned ID, into the observed log.
- The observed-ID log is written during classification in `create_chunk` — any `CHANGED` decision appends the base ID (`SPEC-FR-003`), not the versioned new ID. The REMOVED diff is therefore base-ID to base-ID.
- Scope: `traverse-graph.sh --provenance` integration is not called from within `ingest-spec.sh`. It must simply work when invoked after ingest — which it will, because `supersede-entry.sh` writes the fields it reads.

## Expected Output

- `scripts/knowledge/ingest-spec.sh` modified: adds `SUPERSEDED_COUNT` / `REMOVED_COUNT` / `REVIEW_COUNT` counters, `next_version_id` helper, `emit_phase_impact` helper, `detect_removed_entries` helper, rewired CHANGED branch in `create_chunk`, cleaned-up NEW/UNCHANGED branches, post-dispatch REMOVED pass, updated `INGEST:` summary line.
- 4 new verify scripts: `m011-p03-removed-on-deletion.sh`, `m011-p03-supersede-frontmatter.sh`, `m011-p03-removed-frontmatter.sh`, `m011-p03-phase-impact-review.sh`.
- 2 tightened verify scripts from T01: `m011-p03-skip-unchanged.sh` (now requires `^SKIPPED:`), `m011-p03-supersede-on-change.sh` (now requires `^SUPERSEDED:`).
- All 7 verify scripts print `PASS:` and exit 0.
