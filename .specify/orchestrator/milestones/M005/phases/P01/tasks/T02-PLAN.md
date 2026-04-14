---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M005"
name: "Integrate hash into create-entry.sh"
depends_on: ["T01"]
---

## Description

Update `scripts/knowledge/create-entry.sh` to source `scripts/lib/hash.sh`,
compute the SHA-256 content hash from the `--body` argument at creation time,
and write `content_hash: sha256:{64-hex}` into the YAML frontmatter of the
new detail file.

The hash is computed from the body text only (not from the rendered file
including frontmatter), matching AD-1's body-only hashing convention. This
means the hash in frontmatter represents a commitment to the body content
below -- any future body change requires hash recomputation (handled by T03).

The hash is inserted into the frontmatter heredoc after `relates_to` and
before the closing `---`.

## Steps

### Step 1 -- Source hash.sh

Add a source line for hash.sh after the existing source of index-utils.sh.
The script directory (`$SCRIPT_DIR`) is `scripts/knowledge/`, so hash.sh is
at `$SCRIPT_DIR/../lib/hash.sh`.

Insert after line 16 (`source "$SCRIPT_DIR/lib/index-utils.sh"`):

```bash
# shellcheck source=../lib/hash.sh
source "$SCRIPT_DIR/../lib/hash.sh"
```

### Step 2 -- Compute content hash before writing the file

After the `today="$(date +%Y-%m-%d)"` line (currently line 117) and before
the `mkdir -p "$detail_dir"` line (currently line 120), add:

```bash
# --- Compute content hash (AD-1: body-only, sha256:{hex} format) ---
content_hash="$(compute_content_hash "$body")"
```

### Step 3 -- Add content_hash to the frontmatter heredoc

In the `cat > "$detail_file" <<EOF` heredoc (currently lines 122-141),
add `content_hash: $content_hash` after the `relates_to:` line.

The frontmatter section should become:

```
---
id: $entry_id
scope_tags: "$scope_tags"
category: $category
confidence: $confidence
created_at: $today
last_verified: $today
hit_count: 0
source_unit: "$source_unit"
source_type: $source_type
supersedes: "$supersedes"
superseded_by: ""
relates_to: $relates_to_yaml
content_hash: "$content_hash"
---
```

Note: the content_hash value is quoted in the frontmatter to handle the
colon in `sha256:`.

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "create-entry.sh writes content_hash field in frontmatter
  when creating entries."
- **Artifacts**: modified `scripts/knowledge/create-entry.sh`.
- **Key Links**: `scripts/lib/hash.sh -> scripts/knowledge/create-entry.sh`.

## Verification

Run the verification script:

```bash
bash scripts/verify/p01-create-hash.sh
```

Expected output: `PASS: create-entry.sh writes content_hash`

### Files Touched By This Task

- `scripts/knowledge/create-entry.sh` (modify -- add hash.sh source, compute
  hash, add content_hash to frontmatter)

## Inputs

### From Previous Tasks

- `scripts/lib/hash.sh` (from T01) -- provides `compute_content_hash` function.
  Usage: `compute_content_hash "$body"` returns `sha256:{64-hex}`.

### From Disk (Pre-existing)

- `scripts/knowledge/create-entry.sh` -- the file to modify. Current structure:
  - Lines 1-16: shebang, script dir, source index-utils.sh
  - Lines 18-28: defaults (entry_id, category, confidence, scope_tags, etc.)
  - Lines 30-78: argument parsing (while/case loop)
  - Lines 80-91: required field validation
  - Lines 94-96: auto-generate ID
  - Lines 98-107: resolve project root, idempotency check
  - Lines 109-117: format relates_to, get today's date
  - Lines 120-141: create detail file (mkdir, heredoc write)
  - Lines 143-147: update index, echo CREATED
  Body content is available in the `$body` variable from argument parsing.

- `scripts/knowledge/lib/index-utils.sh` -- already sourced. Provides
  `get_project_root`, `format_index_entry`, `index_add_entry`.

## Expected Output

After completing this task:

1. `scripts/knowledge/create-entry.sh` sources `scripts/lib/hash.sh`.
2. Running `bash scripts/knowledge/create-entry.sh --category test
   --scope-tags "test" --source-unit "M005/P01/T02" --description "test entry"
   --body "test body content"` creates a detail file whose frontmatter
   contains `content_hash: "sha256:{64-hex}"`.
3. The hash value is the SHA-256 of `"test body content"` (the raw --body
   argument), not of the entire rendered file.
4. `bash scripts/verify/p01-create-hash.sh` prints PASS.
5. `git status` shows 1 modified file. Nothing else touched.
