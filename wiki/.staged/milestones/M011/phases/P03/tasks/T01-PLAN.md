---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M011"
name: "Re-ingest change detection (lookup + hash compare + classification)"
depends_on: []
---

## Prerequisites

P02 is complete. The following state exists on disk:

- `scripts/knowledge/ingest-spec.sh` parses markdown specs into chunks and calls `create_chunk` for every classified item. On first ingest it emits `CREATED: <id>`. On a repeat run it already emits `SKIPPED: <id> (unchanged)` because `create-entry.sh` returns `EXISTS:` for any ID whose detail file already exists.
- Every existing spec entry in `knowledge/spec/<type>/<id>.md` has a populated `content_hash: "sha256:<64-hex>"` frontmatter field (wired by P02/T03).
- `scripts/knowledge/lib/detail-utils.sh` exports `find_detail_file <id>` (prints path to `knowledge/*/ID.md` or returns non-zero), `fm_field <file> <field>` (reads a YAML frontmatter scalar), and `sed_i` (BSD/GNU portable `sed -i`).
- `scripts/lib/hash.sh` exports `compute_content_hash <string>` returning `sha256:<64-hex>`.
- `scripts/knowledge/lib/index-utils.sh` exports `get_project_root` (respects `PROJECT_ROOT` env var) — already sourced by `ingest-spec.sh` as `INGEST_PROJECT_ROOT`.

No re-ingest classification layer exists yet. `ingest-spec.sh` has no concept of `CHANGED` or `REMOVED` — it only produces `CREATED:` or `SKIPPED: (unchanged)` lines.

## Description

Add a **classification layer** to `ingest-spec.sh` that, for every chunk the classifiers emit, decides whether the chunk is `NEW`, `UNCHANGED`, or `CHANGED` by comparing the newly computed normalized-body hash against the existing entry's `content_hash`. Also build an **observed-ID set** during the run so T02 can diff it against the pre-existing on-disk IDs to detect `REMOVED` chunks.

This task does **not** yet wire supersession calls or REMOVED-marking (that is T02). It ends with `create_chunk` emitting one of four decision prefixes to stdout: `DECIDE-NEW:`, `DECIDE-UNCHANGED:`, `DECIDE-CHANGED:`, plus writing every observed ID to an append-only file at `$INGEST_PROJECT_ROOT/.orchestrator/tmp/ingest-spec-observed.<pid>` for T02 to consume.

Why a temp file rather than an in-memory set: Bash 3.2 has no associative arrays (MEM001), and the classifiers pass through multiple nested `while-read <<EOF` loops where subshell-scoped variables would lose state. An append-only text file is the portable cross-loop sink.

The final `SUPERSEDED:` / `REMOVED:` / `SKIPPED:` / `CREATED:` output that callers will see is assembled in T02. T01 only has to land the decision logic and the observed-ID log.

## Steps

### Step 1: Add a tmp-dir helper and observed-ID log

Near the top of `ingest-spec.sh` (after `INGEST_PROJECT_ROOT` resolution, around line 67), add:

```bash
# --- Observed-ID log for re-ingest diff detection ---
INGEST_TMP_DIR="$INGEST_PROJECT_ROOT/.orchestrator/tmp"
mkdir -p "$INGEST_TMP_DIR"
INGEST_OBSERVED_LOG="$INGEST_TMP_DIR/ingest-spec-observed.$$"
: > "$INGEST_OBSERVED_LOG"
trap 'rm -f "$INGEST_OBSERVED_LOG"' EXIT
```

### Step 2: Add a `classify_chunk_decision` helper

Insert this helper immediately before `create_chunk` (around line 80). It takes the chunk ID and the new normalized-body hash, looks up the existing entry (if any), and echoes one of `NEW`, `UNCHANGED`, `CHANGED`:

```bash
# --- classify_chunk_decision <id> <new-hash> ---
# Echoes one of: NEW | UNCHANGED | CHANGED
# NEW       — no existing entry for this ID
# UNCHANGED — existing entry's content_hash equals the new hash
# CHANGED   — existing entry's content_hash differs from the new hash
classify_chunk_decision() {
  local chunk_id="$1"
  local new_hash="$2"
  local existing_file=""
  existing_file="$(find_detail_file "$chunk_id" 2>/dev/null)" || {
    echo "NEW"
    return 0
  }
  local existing_hash=""
  existing_hash="$(fm_field "$existing_file" "content_hash")"
  if [ -z "$existing_hash" ]; then
    # No hash recorded (pre-P02 entry) — treat as CHANGED to force refresh
    echo "CHANGED"
    return 0
  fi
  if [ "$existing_hash" = "$new_hash" ]; then
    echo "UNCHANGED"
    return 0
  fi
  echo "CHANGED"
}
```

### Step 3: Rewire `create_chunk` to use the decision layer

Replace the body of `create_chunk` (currently lines 81–139) with a decision-first flow. The new shape:

```bash
create_chunk() {
  local chunk_id="$1"
  local category="$2"
  local source_section="$3"
  local description="$4"
  local body="$5"
  local relates_to="${6:-}"

  # Compute content hash on normalized body
  local normalized_body=""
  normalized_body="$(normalize_for_hash "$body")"
  local content_hash=""
  content_hash="$(compute_content_hash "$normalized_body")" || true

  # Record ID in the observed log so T02 can diff for REMOVED entries
  echo "$chunk_id|$category" >> "$INGEST_OBSERVED_LOG"

  # Decide what to do based on hash comparison
  local decision=""
  decision="$(classify_chunk_decision "$chunk_id" "$content_hash")"

  case "$decision" in
    NEW)
      _do_create_chunk "$chunk_id" "$category" "$source_section" \
        "$description" "$body" "$relates_to" "$content_hash"
      echo "DECIDE-NEW: $chunk_id"
      ;;
    UNCHANGED)
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
      echo "DECIDE-UNCHANGED: $chunk_id"
      ;;
    CHANGED)
      # T02 will wire supersession here; for T01 just mark and record
      echo "DECIDE-CHANGED: $chunk_id"
      ;;
  esac
}
```

### Step 4: Extract the existing creation body into `_do_create_chunk`

Move the existing `create-entry.sh` invocation plus post-creation hash patching (lines 95–138 of the pre-T01 script) into a helper named `_do_create_chunk`. Its signature:

```
_do_create_chunk <id> <category> <source_section> <description> <body> <relates_to> <content_hash>
```

Keep the logic identical to the P02 version except:
- It always runs `create-entry.sh` (no decision branching inside)
- It does the same `CREATED:` counter increment and content-hash sed_i patch on success
- On `EXISTS:` output it increments `SKIPPED_COUNT` but does NOT print anything (the decision layer owns stdout)

### Step 5: Expose `dump_observed_log` for T02

Also add a helper T02 will call during its post-section diff pass. Place it near the bottom helpers:

```bash
# --- dump_observed_log ---
# Echoes "id|category" for every chunk observed during this ingest run.
# Consumed by T02's REMOVED-detection pass.
dump_observed_log() {
  if [ -f "$INGEST_OBSERVED_LOG" ]; then
    cat "$INGEST_OBSERVED_LOG"
  fi
}
```

### Step 6: Update the summary line

The final `INGEST: ...` summary line currently prints `created=$CREATED_COUNT skipped=$SKIPPED_COUNT`. For T01, keep that behavior unchanged — T02 will add `superseded=` and `removed=` counters.

## Must-Haves

- A new helper `classify_chunk_decision <id> <new-hash>` exists in `ingest-spec.sh` and echoes one of `NEW`, `UNCHANGED`, `CHANGED`
- `create_chunk` emits one of `DECIDE-NEW:`, `DECIDE-UNCHANGED:`, or `DECIDE-CHANGED:` per call based on the classification
- A per-process observed-ID log at `$INGEST_PROJECT_ROOT/.orchestrator/tmp/ingest-spec-observed.<pid>` is appended to with `id|category` for every observed chunk, and is cleaned up on EXIT via trap
- A helper `dump_observed_log` returns the observed-ID log contents to stdout
- For an unchanged spec, re-running ingest produces only `DECIDE-UNCHANGED:` lines for every chunk (no `DECIDE-CHANGED:`, no `DECIDE-NEW:`)
- For a spec where one requirement's text has changed, re-running ingest produces one `DECIDE-CHANGED:` line for the modified chunk and `DECIDE-UNCHANGED:` lines for every other chunk
- `ingest-spec.sh` passes `bash -n` syntax check under Bash 3.2 with no `declare -A` or mapfile usage

## Verification

```
bash scripts/verify/m011-p03-bash32-compat.sh
bash -n scripts/knowledge/ingest-spec.sh
```

Additionally, T01 introduces three early-gate checks (their verify scripts will be created here; T02/T03 will tighten them further):

```
bash scripts/verify/m011-p03-skip-unchanged.sh
bash scripts/verify/m011-p03-supersede-on-change.sh
```

At T01 completion, `m011-p03-skip-unchanged.sh` must observe `DECIDE-UNCHANGED:` for every chunk on a no-op re-ingest and print `PASS:`. `m011-p03-supersede-on-change.sh` at T01 may accept either `DECIDE-CHANGED:` or `SUPERSEDED:` in its grep pattern (T02 will tighten to `SUPERSEDED:` only). Write both scripts now with that permissive pattern.

## Inputs

### From Previous Tasks

None within P03. T01 is the first task of the phase.

### From Disk (Pre-existing)

- `scripts/knowledge/ingest-spec.sh` (from P02)
  - Key API: `ingest-spec.sh --spec-path <path> --slug <slug> [--scope-tags <tags>]`
  - Current structure: argument parsing, counters (`CREATED_COUNT`, `SKIPPED_COUNT`, `US_SEQ`, `FR_SEQ`, `CON_SEQ`, `NG_SEQ`, `AC_SEQ`, `NFR_SEQ`), `normalize_for_hash`, `create_chunk`, six `classify_*_section` functions with `_emit_*` helpers, a section splitter `while`-loop, and a final `rebuild-index.sh` call
  - `create_chunk <id> <category> <source_section> <description> <body> [relates_to]` currently calls `create-entry.sh` and patches `content_hash` via `sed_i`
  - Sources: `scripts/lib/hash.sh`, `scripts/knowledge/lib/index-utils.sh`, `scripts/knowledge/lib/detail-utils.sh`
- `scripts/knowledge/lib/detail-utils.sh`
  - `find_detail_file <id>` — prints path to `knowledge/*/ID.md` on stdout and returns 0 when found; returns non-zero (no stdout) when not found. Must be wrapped in `|| { ...; }` since `set -e` is active.
  - `fm_field <file> <field>` — reads a YAML frontmatter scalar, strips surrounding quotes.
  - `sed_i "<expr>" <file>` — BSD/GNU-portable in-place sed.
- `scripts/lib/hash.sh`
  - `compute_content_hash <string>` — returns `sha256:<64-hex>`; returns empty and exit 1 for empty input.
- `scripts/knowledge/lib/index-utils.sh`
  - `get_project_root` — returns the project root, respects `PROJECT_ROOT` env var. Already invoked once as `INGEST_PROJECT_ROOT`.
- `scripts/knowledge/create-entry.sh`
  - Accepts `--id --category --scope-tags --source-unit --source-type --description --body [--relates-to] [--supersedes]`. Prints `CREATED: <id> at knowledge/<category>/<id>.md` on create, `EXISTS: <id> already exists ..., skipping` if the file exists. Exit 0 on both.

## Constraints

- Bash 3.2 compatible: no `declare -A`, no `mapfile`, no `readarray`. Use parallel indexed arrays or append-only text files for cross-loop state (MEM001).
- AD-19 discipline for verify-script `Check:` commands — single-script-file invocations only (no inline subshells, no `$(...)` containing pipes, no compound bash). The verify scripts themselves can use any bash internally; the restriction is on the phase plan's `Check:` commands.
- The observed-ID log must be per-PID (`.$$` suffix) and cleaned up by the EXIT trap. Do not reuse a well-known path — concurrent ingests of two different specs would collide.
- Do not modify `create-entry.sh`, `supersede-entry.sh`, or the classifier functions (`classify_stories_section`, etc.). The change is entirely inside `create_chunk` plus two new helpers.
- The decision output prefixes `DECIDE-NEW:` / `DECIDE-UNCHANGED:` / `DECIDE-CHANGED:` are intermediate — T02 will replace them with the final `CREATED:` / `SKIPPED:` / `SUPERSEDED:` prefixes that match the demo sentence. Leaving them intermediate lets T01 be verified in isolation.
- Scope: do not touch `REMOVED:` logic, do not call `supersede-entry.sh`, do not emit `REVIEW:` lines — all three belong to T02.

## Expected Output

- `scripts/knowledge/ingest-spec.sh` modified: adds `INGEST_OBSERVED_LOG` plus trap, `classify_chunk_decision` helper, `_do_create_chunk` extraction, `dump_observed_log` helper, and a rewritten `create_chunk` that emits `DECIDE-*:` prefixes.
- `scripts/verify/m011-p03-bash32-compat.sh` (create) — runs `bash -n scripts/knowledge/ingest-spec.sh` and greps for forbidden `declare -A` / `mapfile` / `readarray`, prints `PASS:` or `FAIL:`.
- `scripts/verify/m011-p03-skip-unchanged.sh` (create) — ingests a small test spec into a `PROJECT_ROOT=$(mktemp -d)` sandbox, re-ingests, asserts every chunk shows `DECIDE-UNCHANGED:` (or `SKIPPED:` after T02 lands) and zero `DECIDE-CHANGED:` / `DECIDE-NEW:`.
- `scripts/verify/m011-p03-supersede-on-change.sh` (create) — ingests a spec with one requirement, modifies that requirement's text, re-ingests, asserts one `DECIDE-CHANGED:` (or `SUPERSEDED:`) line matches the modified ID. Permissive grep pattern so T02 can tighten without rewriting this script.
- All three verify scripts print `PASS:` and exit 0.
