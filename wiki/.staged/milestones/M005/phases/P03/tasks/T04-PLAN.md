---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P03"
milestone: "M005"
name: "Refactor compress-payload.sh to delegate to lib functions"
depends_on: ["T01", "T02"]
---

## Description

Refactor `scripts/dispatch/compress-payload.sh` to source the new lib files
(`scripts/lib/payload-transforms.sh` and `scripts/lib/manifest-builder.sh`)
and delegate transform logic to them, replacing inline definitions.

Currently `compress-payload.sh` contains:

1. `estimate_tokens()` inline at line 106 (duplicate of build-context.sh).
2. `raw_token_count()` inline at line 119.
3. `_cp_step_drop_optional()` at line 265 -- drops sections by priority.
4. `_cp_step_summarize()` at line 296 -- truncates ### subsections.
5. `_cp_step_drop_lowest_confidence()` at line 373 -- sorts/drops knowledge
   entries by confidence.
6. Manifest rebuild logic at lines 593-695 -- reconstructs the manifest
   table after compression.

After this refactoring:

1. `estimate_tokens` and `raw_token_count` inline definitions are removed.
   `scripts/lib/payload-transforms.sh` is sourced (provides both).
2. `scripts/lib/manifest-builder.sh` is sourced (provides manifest rebuild
   functions).
3. `_cp_step_drop_optional`, `_cp_step_summarize`, and
   `_cp_step_drop_lowest_confidence` are refactored to delegate their core
   logic to the pure lib functions (`drop_by_priority`,
   `summarize_section`, `drop_lowest_confidence`) while keeping the
   file-I/O orchestration (reading/writing temp files, tracking token
   budgets) in the step wrappers.
4. The manifest rebuild block is refactored to use `build_manifest_header`,
   `format_manifest_row`, and `format_manifest_total` from
   manifest-builder.sh.

The output of compress-payload.sh must remain byte-for-byte identical for
the same inputs. This is a pure mechanical extraction -- no behavior change.

Architectural constraint (AD-5): the lib functions are pure (no file I/O).
compress-payload.sh remains the caller that handles all file reads/writes
and passes data to the lib functions via stdin/arguments.

## Steps

### Step 1 -- Add lib source lines

Add source lines for both lib files near the top of compress-payload.sh,
after the existing library sources (after line 37 where recipe-parser.sh is
sourced):

```bash
. "$PROJECT_ROOT/scripts/lib/payload-transforms.sh"
. "$PROJECT_ROOT/scripts/lib/manifest-builder.sh"
```

### Step 2 -- Remove inline estimate_tokens and raw_token_count

Delete the inline function definitions:
- `estimate_tokens()` at lines 106-116
- `raw_token_count()` at lines 119-124

Both are now provided by `scripts/lib/payload-transforms.sh`. All call sites
in compress-payload.sh continue to work because the function names are
identical.

### Step 3 -- Refactor _cp_step_summarize

The current `_cp_step_summarize` (line 296) reads a temp file, runs an
inline awk script to truncate ### subsections, and writes the result back to
the temp file. Refactor to delegate the awk logic to `summarize_section`
from payload-transforms.sh:

```bash
_cp_step_summarize() {
  local target="${1:-upstream}"
  local max_words="${2:-200}"

  IFS='|' read -ra ALL_NAMES <<< "$sec_names"
  IFS='|' read -ra ALL_FILES <<< "$sec_files_ordered"

  local idx name sfile old_content old_tokens new_content new_tokens
  for idx in "${!ALL_NAMES[@]}"; do
    name="${ALL_NAMES[$idx]}"
    if echo "$name" | grep -qi "$target"; then
      sfile="${ALL_FILES[$idx]}"
      if [ -f "$sfile" ]; then
        old_content=$(cat "$sfile")
        old_tokens=$(raw_token_count "$old_content")

        # Delegate truncation to pure lib function (stdin -> stdout)
        new_content=$(printf '%s\n' "$old_content" | summarize_section "$max_words")

        echo "$new_content" > "$sfile"
        new_tokens=$(raw_token_count "$new_content")
        current_tokens=$((current_tokens - old_tokens + new_tokens))
      fi
      break
    fi
  done
}
```

Note: The file I/O (`cat "$sfile"`, `> "$sfile"`) stays in the wrapper. The
pure `summarize_section` function receives content via stdin pipe and returns
the truncated content on stdout.

### Step 4 -- Refactor manifest rebuild

The current manifest rebuild block (lines 593-695) builds the manifest table
inline using string concatenation. Refactor to use manifest-builder.sh
functions:

```bash
# --- Rebuild manifest header ---
new_manifest_table="$(build_manifest_header)"

# --- Compute rows ---
new_total_tokens=0
for idx in "${!REM_NAMES[@]}"; do
  sfile="${REM_FILES[$idx]}"
  sname="${REM_NAMES[$idx]}"
  sec_pri="${REM_PRIS[$idx]}"

  sec_lines=$(wc -l < "$sfile" | tr -d ' ')
  sec_content=$(cat "$sfile")
  sec_tokens=$(estimate_tokens "$sec_content")
  end_line=$((current_line + sec_lines - 1))

  new_manifest_table="$new_manifest_table
$(format_manifest_row "$sname" "$current_line" "$end_line" "$sec_tokens" "$sec_pri")"
  new_total_tokens=$((new_total_tokens + sec_tokens))
  current_line=$((end_line + 2))
done

new_manifest_table="$new_manifest_table
$(format_manifest_total "$new_total_tokens")"
```

Note: File I/O (`wc -l < "$sfile"`, `cat "$sfile"`) stays in the rebuild
block. Only the table formatting is delegated to pure functions.

### Step 5 -- Verify output parity

Run the existing test suite to confirm no behavioral regression:

```bash
bash tests/test-compress-payload.sh
```

All pre-existing test assertions must continue to pass. The output of
compress-payload.sh for the same inputs must be identical before and after
this refactoring.

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "compress-payload.sh sources payload-transforms.sh and
  delegates compression steps to lib functions", "Token estimation function
  (estimate_tokens) is defined in exactly one lib file and sourced by both
  dispatch scripts (no duplication)".
- **Artifacts**: `scripts/dispatch/compress-payload.sh` (modified).

## Verification

Run the verification scripts:

```bash
bash scripts/verify/p03-compress-delegates.sh
bash scripts/verify/p03-no-duplicate-estimate.sh
```

Both should print PASS.

Also run the existing compress-payload test suite to confirm no regression:

```bash
bash tests/test-compress-payload.sh
```

All assertions must pass.

### Files Touched By This Task

- `scripts/dispatch/compress-payload.sh` (modify)

## Inputs

### From Previous Tasks

- T01: `scripts/lib/payload-transforms.sh` must exist with
  `estimate_tokens`, `raw_token_count`, `summarize_section`,
  `drop_by_priority`, `drop_lowest_confidence`.
- T02: `scripts/lib/manifest-builder.sh` must exist with
  `build_manifest_header`, `format_manifest_row`, `format_manifest_total`,
  `assemble_manifest_table`.

### From Disk (Pre-existing)

- `scripts/dispatch/compress-payload.sh` -- the file being refactored. Key
  sections:
  - Lines 34-37: existing library source lines (add new sources after these)
  - Lines 106-116: inline `estimate_tokens()` definition (to be removed)
  - Lines 119-124: inline `raw_token_count()` definition (to be removed)
  - Lines 265-291: `_cp_step_drop_optional()` (wrapper stays, no pure
    extraction needed -- it operates on global arrays and temp files)
  - Lines 296-366: `_cp_step_summarize()` (refactored to delegate awk logic
    to `summarize_section`)
  - Lines 373-509: `_cp_step_drop_lowest_confidence()` (wrapper stays -- it
    manages temp files and global token budget tracking; the pure sorting
    logic is available in the lib but the wrapper's file-based approach is
    retained for now to preserve byte-for-byte parity)
  - Lines 593-695: manifest rebuild block (refactored to use
    `build_manifest_header`, `format_manifest_row`, `format_manifest_total`)

- `tests/test-compress-payload.sh` -- existing test suite for regression
  check.

## Expected Output

After completing this task:

1. `scripts/dispatch/compress-payload.sh` sources both
   `scripts/lib/payload-transforms.sh` and `scripts/lib/manifest-builder.sh`.
2. The inline `estimate_tokens()` and `raw_token_count()` function
   definitions are removed from compress-payload.sh.
3. `_cp_step_summarize()` delegates truncation to `summarize_section` from
   payload-transforms.sh.
4. The manifest rebuild block uses `build_manifest_header`,
   `format_manifest_row`, and `format_manifest_total` from
   manifest-builder.sh.
5. `bash scripts/verify/p03-compress-delegates.sh` prints PASS.
6. `bash scripts/verify/p03-no-duplicate-estimate.sh` prints PASS.
7. `bash tests/test-compress-payload.sh` passes all existing assertions.
8. `git status` shows 1 modified file (`compress-payload.sh`). Nothing else
   touched.
