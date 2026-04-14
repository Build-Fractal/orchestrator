---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M005"
name: "Add body update and hash recomputation to update-entry.sh"
depends_on: ["T01"]
---

## Description

Update `scripts/knowledge/update-entry.sh` to:

1. Accept a `--body` flag that replaces the body content of an existing
   knowledge entry (everything after the closing `---` frontmatter delimiter).
2. When `--body` is provided, recompute `content_hash` from the new body
   content using `compute_content_hash` from hash.sh and update the
   frontmatter field.
3. Accept a `--recompute-hash` flag that recomputes the content_hash from
   the current body content (for cases where body was modified by external
   means -- e.g., manual edit -- and the hash needs to be refreshed).

The script already has the `sed_i` and `fm_field` helpers needed for
frontmatter manipulation. The body replacement uses a temp-file approach:
write the frontmatter section to a temp file, append the new body, then
move the temp file into place.

## Steps

### Step 1 -- Source hash.sh

Add a source line for hash.sh after the existing source of index-utils.sh
(line 13).

Insert after line 13 (`source "$SCRIPT_DIR/lib/index-utils.sh"`):

```bash
# shellcheck source=../lib/hash.sh
source "$SCRIPT_DIR/../lib/hash.sh"
```

### Step 2 -- Add --body and --recompute-hash to argument parsing

In the argument parsing while/case block (currently lines 49-83), add two
new cases before the `*)` catch-all:

```bash
    --body)
      new_body="$2"
      shift 2
      ;;
    --recompute-hash)
      recompute_hash=true
      shift
      ;;
```

Add the corresponding variable defaults after the existing defaults
(after line 54):

```bash
new_body=""
recompute_hash=false
```

### Step 3 -- Update the validation check

The existing validation (lines 91-93) checks that at least one update
field is specified. Update the condition to include `--body` and
`--recompute-hash`:

```bash
if [ -z "$new_confidence" ] && [ -z "$new_last_verified" ] && [ -z "$new_hit_count" ] && [ "$increment_hits" = false ] && [ -z "$new_body" ] && [ "$recompute_hash" = false ]; then
  echo "ERROR: No fields specified to update" >&2
  exit 1
fi
```

### Step 4 -- Implement body replacement

After the existing increment-hits block (after line 134) and before the
`changed_fields` cleanup, add the body replacement logic:

```bash
# --- Update body content ---
if [ -n "$new_body" ]; then
  # Extract frontmatter (everything between first and second --- lines)
  local tmp_file="${detail_file}.tmp.$$"
  local in_frontmatter=0
  local frontmatter_done=0
  {
    while IFS= read -r line; do
      if [ "$frontmatter_done" -eq 1 ]; then
        # Skip old body lines
        continue
      elif [ "$in_frontmatter" -eq 0 ] && [ "$line" = "---" ]; then
        in_frontmatter=1
        echo "$line"
      elif [ "$in_frontmatter" -eq 1 ] && [ "$line" = "---" ]; then
        frontmatter_done=1
        echo "$line"
      else
        echo "$line"
      fi
    done < "$detail_file"
    # Write new body
    echo ""
    printf '%s\n' "$new_body"
  } > "$tmp_file"
  mv "$tmp_file" "$detail_file"
  changed_fields="${changed_fields}body, "

  # Recompute content_hash from new body
  local new_hash
  new_hash="$(compute_content_hash "$new_body")"
  sed_i "s|^content_hash: .*|content_hash: \"${new_hash}\"|" "$detail_file"
  changed_fields="${changed_fields}content_hash, "
fi
```

Note: uses `sed_i` with `|` delimiter instead of `/` to avoid conflicts
with the `sha256:` colon in the hash value.

### Step 5 -- Implement hash recomputation

After the body replacement block, add recompute-hash logic:

```bash
# --- Recompute content_hash from current body (without body change) ---
if [ "$recompute_hash" = true ] && [ -z "$new_body" ]; then
  local current_hash
  current_hash="$(compute_file_body_hash "$detail_file")"
  if [ -n "$current_hash" ]; then
    # Check if content_hash field exists in frontmatter
    if grep -q "^content_hash:" "$detail_file"; then
      sed_i "s|^content_hash: .*|content_hash: \"${current_hash}\"|" "$detail_file"
    else
      # Insert content_hash before the closing ---
      sed_i "/^---$/,/^---$/{
        /^---$/{
          x
          /^---$/{
            i\\
content_hash: \"${current_hash}\"
          }
          x
        }
      }" "$detail_file"
    fi
    changed_fields="${changed_fields}content_hash, "
  fi
fi
```

IMPORTANT: The sed pattern above is complex and may not work on BSD sed.
A simpler approach for inserting `content_hash` into existing files that
lack the field: use awk or the temp-file-rewrite approach. The simpler
fallback:

```bash
# --- Recompute content_hash from current body (without body change) ---
if [ "$recompute_hash" = true ] && [ -z "$new_body" ]; then
  local current_hash
  current_hash="$(compute_file_body_hash "$detail_file")"
  if [ -n "$current_hash" ]; then
    if grep -q "^content_hash:" "$detail_file"; then
      sed_i "s|^content_hash: .*|content_hash: \"${current_hash}\"|" "$detail_file"
    else
      # Insert content_hash before relates_to (last known field before ---)
      sed_i "/^relates_to:/a\\
content_hash: \"${current_hash}\"" "$detail_file"
    fi
    changed_fields="${changed_fields}content_hash, "
  fi
fi
```

Note: on BSD sed (macOS), the `\a` (append after) command requires a
literal newline after the backslash. If this causes issues, use the
temp-file-rewrite approach instead -- read the file, find the closing
`---`, insert the field before it, write back.

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "update-entry.sh recomputes content_hash when body content
  changes via --body flag."
- **Artifacts**: modified `scripts/knowledge/update-entry.sh`.
- **Key Links**: `scripts/lib/hash.sh -> scripts/knowledge/update-entry.sh`.

## Verification

Run the verification script:

```bash
bash scripts/verify/p01-update-hash.sh
```

Expected output: `PASS: update-entry.sh handles content_hash on body change`

### Files Touched By This Task

- `scripts/knowledge/update-entry.sh` (modify -- add hash.sh source, --body
  flag, --recompute-hash flag, body replacement with hash update)

## Inputs

### From Previous Tasks

- `scripts/lib/hash.sh` (from T01) -- provides:
  - `compute_content_hash "$body"` -- returns `sha256:{64-hex}` for a string.
  - `compute_file_body_hash "$filepath"` -- returns `sha256:{64-hex}` for a
    file's body content (excluding frontmatter).

### From Disk (Pre-existing)

- `scripts/knowledge/update-entry.sh` -- the file to modify. Current structure:
  - Lines 1-13: shebang, script dir, source index-utils.sh
  - Lines 16-22: `sed_i()` helper (portable BSD/GNU sed -i)
  - Lines 25-40: `find_detail_file()` helper (locate entry by ID)
  - Lines 43-47: `fm_field()` helper (extract YAML frontmatter values)
  - Lines 49-83: argument parsing (--id, --confidence, --last-verified,
    --hit-count, --increment-hits)
  - Lines 85-93: validation (--id required, at least one update field)
  - Lines 96-101: find detail file
  - Lines 103-134: apply updates (confidence, last_verified, hit_count,
    increment hits)
  - Lines 137-154: re-read fields, update index, echo UPDATED

  Key helper functions already available:
  - `sed_i "s/pattern/replacement/" "$file"` -- portable sed -i
  - `fm_field "$file" "field_name"` -- read YAML frontmatter field

- `scripts/knowledge/lib/index-utils.sh` -- already sourced. Provides
  `format_index_entry`, `index_update_entry`.

## Expected Output

After completing this task:

1. `scripts/knowledge/update-entry.sh` sources `scripts/lib/hash.sh`.
2. `--body` flag is accepted. When provided, the body content of the detail
   file is replaced and `content_hash` is recomputed from the new body.
3. `--recompute-hash` flag is accepted. When provided without `--body`, the
   hash is recomputed from the current body on disk.
4. Running `--body "new content"` on an existing entry updates both the body
   text and the `content_hash` frontmatter field.
5. `bash scripts/verify/p01-update-hash.sh` prints PASS.
6. `git status` shows 1 modified file. Nothing else touched.
