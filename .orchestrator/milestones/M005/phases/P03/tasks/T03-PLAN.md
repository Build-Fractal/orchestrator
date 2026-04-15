---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M005"
name: "Refactor build-context.sh to delegate to lib functions"
depends_on: ["T01", "T02"]
---

## Description

Refactor `scripts/dispatch/build-context.sh` to source the new lib files
(`scripts/lib/payload-transforms.sh` and `scripts/lib/manifest-builder.sh`)
and delegate transform logic to them, replacing inline definitions.

Currently `build-context.sh` defines `estimate_tokens()` inline (line 189)
and contains the entire manifest assembly logic in
`_bc_assemble_manifest_and_emit()` (line 512). After this refactoring:

1. The inline `estimate_tokens()` function definition is removed.
2. `scripts/lib/payload-transforms.sh` is sourced (provides `estimate_tokens`,
   `raw_token_count`).
3. `scripts/lib/manifest-builder.sh` is sourced (provides
   `build_manifest_header`, `compute_section_tokens`, `format_manifest_row`,
   `format_manifest_total`, `assemble_manifest_table`).
4. `_bc_assemble_manifest_and_emit()` is refactored to call
   `assemble_manifest_table` from manifest-builder.sh instead of building the
   table inline.

The output of build-context.sh must remain byte-for-byte identical for the
same inputs. This is a pure mechanical extraction -- no behavior change.

Architectural constraint (AD-5): the lib functions are pure (no file I/O).
build-context.sh remains the caller that handles all file reads and passes
data to the lib functions as arguments.

## Steps

### Step 1 -- Add lib source lines

Add source lines for both lib files near the top of build-context.sh, after
the existing library sources (after line 38 where recipe-parser.sh is
sourced):

```bash
. "$PROJECT_ROOT/scripts/lib/payload-transforms.sh"
. "$PROJECT_ROOT/scripts/lib/manifest-builder.sh"
```

### Step 2 -- Remove inline estimate_tokens

Delete the inline `estimate_tokens()` function definition at lines 189-199
of build-context.sh. The function is now provided by
`scripts/lib/payload-transforms.sh` (sourced in Step 1).

The existing call sites in `_bc_assemble_manifest_and_emit()` remain
unchanged -- they call `estimate_tokens` by name, which now resolves to the
sourced lib function.

### Step 3 -- Refactor _bc_assemble_manifest_and_emit

Replace the inline manifest table construction in
`_bc_assemble_manifest_and_emit()` with calls to manifest-builder.sh
functions.

**Current inline logic** (lines 512-636) does:
1. Parse pipe-delimited names/priorities into arrays
2. Loop through sections computing line counts and token counts
3. Compute `content_start` from frontmatter lines + manifest overhead
4. Build manifest table string row by row
5. Assemble final payload with frontmatter + title + manifest + sections
6. Emit to stdout and report budget to stderr

**Refactored logic** replaces steps 3-4 with a call to
`assemble_manifest_table`:

```bash
_bc_assemble_manifest_and_emit() {
  local section_count="$1"
  local section_names="$2"
  local section_priorities="$3"
  local frontmatter="$4"
  local title="$5"

  # Count lines in frontmatter
  local fm_lines
  fm_lines="$(echo "$frontmatter" | wc -l | tr -d ' ')"

  # Parse pipe-delimited name and priority lists into parallel arrays
  local S_NAMES S_PRIORITIES
  IFS='|' read -ra S_NAMES <<EOF_NAMES
$section_names
EOF_NAMES
  IFS='|' read -ra S_PRIORITIES <<EOF_PRIOS
$section_priorities
EOF_PRIOS

  # Collect line counts + token counts for each section
  local section_line_counts=""
  local section_token_counts=""
  local total_tokens=0
  local i sec_file sec_lines sec_content sec_tokens
  for i in $(seq 1 "$section_count"); do
    sec_file="$TMPDIR_BUILD/s${i}.txt"
    sec_lines="$(wc -l < "$sec_file" | tr -d ' ')"
    sec_content="$(cat "$sec_file")"
    sec_tokens="$(estimate_tokens "$sec_content")"
    section_line_counts="$section_line_counts $sec_lines"
    section_token_counts="$section_token_counts $sec_tokens"
    total_tokens=$((total_tokens + sec_tokens))
  done

  # Knowledge section entry count annotation
  local idx=0
  local annotated_names=""
  for i in $(seq 1 "$section_count"); do
    local sec_name="${S_NAMES[$idx]}"
    if [ "$sec_name" = "Knowledge" ] && [ -s "$INCLUDED_IDS_FILE" ]; then
      local entry_ct
      entry_ct="$(grep -c 'MEM' "$INCLUDED_IDS_FILE" 2>/dev/null || echo 0)"
      sec_name="Knowledge ($entry_ct entries)"
    fi
    if [ -z "$annotated_names" ]; then
      annotated_names="$sec_name"
    else
      annotated_names="${annotated_names}|${sec_name}"
    fi
    idx=$((idx + 1))
  done

  # Layout math (matches pre-refactor formula)
  local offset=$((fm_lines + 1))
  local manifest_lines=$((5 + section_count + 2))
  local content_start=$((offset + manifest_lines))

  # Build manifest table via lib function
  local manifest_table
  manifest_table="$(assemble_manifest_table \
    "$section_count" \
    "$annotated_names" \
    "$section_priorities" \
    "$section_line_counts" \
    "$section_token_counts" \
    "$content_start")"

  # Assemble final payload
  local payload="$frontmatter

$title
## Manifest
$manifest_table
"

  for i in $(seq 1 "$section_count"); do
    sec_file="$TMPDIR_BUILD/s${i}.txt"
    payload="$payload
$(cat "$sec_file")
"
  done

  # Emit payload to stdout
  echo "$payload"

  # --- Increment hit counts for included knowledge entries ---
  if [ -s "$INCLUDED_IDS_FILE" ]; then
    local eid
    while IFS= read -r eid; do
      [ -z "$eid" ] && continue
      bash "$INCREMENT_HITS" --id "$eid" 2>/dev/null || true
    done < "$INCLUDED_IDS_FILE"
  fi

  # --- Report context budget to stderr ---
  local payload_bytes
  payload_bytes="$(echo "$payload" | wc -c | tr -d ' ')"

  local total_bytes=0
  local _tmp_filelist
  _tmp_filelist="$(mktemp)"
  find "$MILESTONE_DIR" -type f \( -name "*.md" -o -name "*.yml" -o -name "*.yaml" -o -name "*.sh" \) 2>/dev/null > "$_tmp_filelist"
  local f file_size
  while IFS= read -r f; do
    if [ -f "$f" ]; then
      file_size="$(wc -c < "$f" | tr -d ' ')"
      total_bytes=$((total_bytes + file_size))
    fi
  done < "$_tmp_filelist"
  rm -f "$_tmp_filelist"

  local budget_pct=0
  if [ "$total_bytes" -gt 0 ]; then
    budget_pct=$((payload_bytes * 100 / total_bytes))
  fi

  echo "Context payload: $payload_bytes bytes (${budget_pct}% of total artifacts)" >&2
}
```

Note: The file I/O (reading `$TMPDIR_BUILD/s${i}.txt`, writing to temp
files, `find`) stays in `_bc_assemble_manifest_and_emit`. Only the manifest
table formatting is delegated to the pure lib function. The budget reporting
also stays as-is since it requires filesystem access.

### Step 4 -- Verify output parity

Run the existing test suite to confirm no behavioral regression:

```bash
bash tests/test-build-context.sh
```

All pre-existing test assertions must continue to pass. The output of
build-context.sh for the same inputs must be identical before and after this
refactoring.

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "build-context.sh sources manifest-builder.sh and delegates
  manifest table construction to lib functions", "Token estimation function
  (estimate_tokens) is defined in exactly one lib file and sourced by both
  dispatch scripts (no duplication)".
- **Artifacts**: `scripts/dispatch/build-context.sh` (modified).

## Verification

Run the verification scripts:

```bash
bash scripts/verify/p03-build-context-delegates.sh
bash scripts/verify/p03-no-duplicate-estimate.sh
```

Both should print PASS.

Also run the existing build-context test suite to confirm no regression:

```bash
bash tests/test-build-context.sh
```

All assertions must pass.

### Files Touched By This Task

- `scripts/dispatch/build-context.sh` (modify)

## Inputs

### From Previous Tasks

- T01: `scripts/lib/payload-transforms.sh` must exist with `estimate_tokens`
  and `raw_token_count`.
- T02: `scripts/lib/manifest-builder.sh` must exist with
  `build_manifest_header`, `compute_section_tokens`, `format_manifest_row`,
  `format_manifest_total`, and `assemble_manifest_table`.

### From Disk (Pre-existing)

- `scripts/dispatch/build-context.sh` -- the file being refactored. Key
  sections:
  - Lines 34-38: existing library source lines (add new sources after these)
  - Lines 189-199: inline `estimate_tokens()` definition (to be removed)
  - Lines 512-636: `_bc_assemble_manifest_and_emit()` function (to be
    refactored to use `assemble_manifest_table`)
  - Lines 641-837: recipe-driven task branch and planning branch (unchanged)

- `tests/test-build-context.sh` -- existing test suite for regression check.

## Expected Output

After completing this task:

1. `scripts/dispatch/build-context.sh` sources both
   `scripts/lib/payload-transforms.sh` and `scripts/lib/manifest-builder.sh`.
2. The inline `estimate_tokens()` function definition is removed from
   build-context.sh.
3. `_bc_assemble_manifest_and_emit()` calls `assemble_manifest_table` from
   manifest-builder.sh for table construction.
4. `bash scripts/verify/p03-build-context-delegates.sh` prints PASS.
5. `bash scripts/verify/p03-no-duplicate-estimate.sh` prints PASS.
6. `bash tests/test-build-context.sh` passes all existing assertions.
7. `git status` shows 1 modified file (`build-context.sh`). Nothing else
   touched.
