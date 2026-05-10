---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M005"
name: "Hash-aware rebuild in rebuild-index.sh"
depends_on: ["T01"]
---

## Description

Update `scripts/knowledge/rebuild-index.sh` to compare each knowledge entry
file's stored `content_hash` frontmatter value against a freshly computed
hash of its body content. This enables the orchestrator to distinguish between
"index was rebuilt but nothing actually changed" and "index was rebuilt and
N entries have new content" -- the stagnation signal for knowledge-layer
health.

The rebuild script currently regenerates the entire KNOWLEDGE-INDEX.md from
detail files without tracking what changed. After this update, the rebuild
output will report three counts:
- **changed**: entries whose stored hash differs from recomputed body hash
  (content was modified since the hash was last written)
- **unchanged**: entries whose stored hash matches recomputed body hash
- **no-hash**: entries that lack a `content_hash` field (legacy entries
  created before P01)

When a changed entry is detected, the script updates its `content_hash`
frontmatter field to the freshly computed value (making the rebuild
self-healing for hash drift).

## Steps

### Step 1 -- Source hash.sh

Add a source line for hash.sh after the existing source of index-utils.sh
(line 14).

Insert after line 14 (`source "$SCRIPT_DIR/lib/index-utils.sh"`):

```bash
# shellcheck source=../lib/hash.sh
source "$SCRIPT_DIR/../lib/hash.sh"
```

### Step 2 -- Add a portable sed_i helper

The rebuild script does not currently have `sed_i` (unlike update-entry.sh).
Add it after the hash.sh source line, before the argument parsing:

```bash
# --- Portable sed -i helper (BSD/GNU compatible) ---
sed_i() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}
```

### Step 3 -- Initialize change tracking counters

After the `entry_count=0` line (currently around line 52), add:

```bash
changed_count=0
unchanged_count=0
nohash_count=0
```

### Step 4 -- Add hash comparison inside the file scan loop

Inside the `for file in "$knowledge_dir"/*/*.md; do` loop, after the
existing frontmatter extraction block (after `superseded_by` is read,
around line 86), add hash comparison logic:

```bash
  # --- Content hash comparison (P01) ---
  stored_hash="$(fm_field "$file" "content_hash")"
  if [ -z "$stored_hash" ]; then
    nohash_count=$((nohash_count + 1))
  else
    computed_hash="$(compute_file_body_hash "$file")"
    if [ "$stored_hash" = "$computed_hash" ]; then
      unchanged_count=$((unchanged_count + 1))
    else
      changed_count=$((changed_count + 1))
      # Self-healing: update the stored hash to match current body
      if [ -n "$computed_hash" ]; then
        sed_i "s|^content_hash: .*|content_hash: \"${computed_hash}\"|" "$file"
      fi
    fi
  fi
```

This block goes after the `superseded_by` check (the `if [ -n
"$superseded_by" ]; then continue; fi` block), so it only runs for
active (non-superseded) entries.

### Step 5 -- Update the output message

Replace the existing output line (currently line 121):

```bash
echo "REBUILT: KNOWLEDGE-INDEX.md with $entry_count entries"
```

With:

```bash
echo "REBUILT: KNOWLEDGE-INDEX.md with $entry_count entries (changed=$changed_count unchanged=$unchanged_count no-hash=$nohash_count)"
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "rebuild-index.sh detects changed vs unchanged entries via
  hash comparison", "rebuild-index.sh reports changed and unchanged counts
  in its output."
- **Artifacts**: modified `scripts/knowledge/rebuild-index.sh`.
- **Key Links**: `scripts/lib/hash.sh -> scripts/knowledge/rebuild-index.sh`.

## Verification

Run both verification scripts:

```bash
bash scripts/verify/p01-rebuild-detects.sh
bash scripts/verify/p01-rebuild-counts.sh
```

Expected output:
```
PASS: rebuild-index.sh detects changes via content_hash
PASS: rebuild-index.sh reports changed/unchanged counts
```

### Files Touched By This Task

- `scripts/knowledge/rebuild-index.sh` (modify -- add hash.sh source, sed_i
  helper, hash comparison inside scan loop, change tracking counters, updated
  output message)

## Inputs

### From Previous Tasks

- `scripts/lib/hash.sh` (from T01) -- provides:
  - `compute_file_body_hash "$filepath"` -- returns `sha256:{64-hex}` for a
    file's body content (excluding frontmatter). Returns empty string if file
    has no body.

### From Disk (Pre-existing)

- `scripts/knowledge/rebuild-index.sh` -- the file to modify. Current structure:
  - Lines 1-15: shebang, script dir, source index-utils.sh
  - Lines 17-29: argument parsing (--root)
  - Lines 31-39: `fm_field()` helper (extract YAML frontmatter values)
  - Lines 41-48: resolve project root, check knowledge/ directory
  - Lines 50-111: scan loop (iterate knowledge/*/*.md, extract frontmatter,
    skip archive, skip superseded, format index entries)
  - Lines 113-119: sort entries, write full index
  - Line 121: echo REBUILT count

  Key existing functionality:
  - `fm_field "$file" "field_name"` -- reads a YAML frontmatter field value
  - `format_index_entry` and `write_full_index` from index-utils.sh
  - The loop already processes every non-archived, non-superseded MEM*.md file
  - `superseded_by` check is already in place (skip superseded entries)

## Expected Output

After completing this task:

1. `scripts/knowledge/rebuild-index.sh` sources `scripts/lib/hash.sh`.
2. Running `bash scripts/knowledge/rebuild-index.sh --root .` reports
   `REBUILT: KNOWLEDGE-INDEX.md with N entries (changed=X unchanged=Y no-hash=Z)`.
3. For entries with valid `content_hash` that matches their body, the
   `unchanged` count increments.
4. For entries with `content_hash` that differs from their body, the
   `changed` count increments and the stored hash is updated.
5. For entries without `content_hash` (legacy), the `no-hash` count
   increments.
6. `bash scripts/verify/p01-rebuild-detects.sh` prints PASS.
7. `bash scripts/verify/p01-rebuild-counts.sh` prints PASS.
8. `git status` shows 1 modified file. Nothing else touched.
