---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M005"
name: "Create manifest-builder.sh"
depends_on: ["T01"]
---

## Description

Create the manifest builder library at `scripts/lib/manifest-builder.sh`
with pure functions for constructing the manifest table that appears at the
top of every dispatch payload.

Currently, manifest construction logic is inline in two places:

1. `scripts/dispatch/build-context.sh` -- `_bc_assemble_manifest_and_emit()`
   (line 512) builds the manifest table header, computes line ranges and token
   counts per section, formats each row, and assembles the final table with
   a total row.

2. `scripts/dispatch/compress-payload.sh` -- the "Rebuild the payload" block
   (line 593) reconstructs the manifest after compression, computing new line
   ranges, token counts, and priorities for remaining sections.

Both share the same table format:

```
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| <name> | <start>-<end> | ~<tokens> | <priority> |
| **Total** | | **~<total>** | |
```

This task extracts that shared logic into pure functions that take arguments
and return formatted strings on stdout.

Functions to create:

1. `build_manifest_header` -- no arguments, returns the two-line header
   (column names + separator).

2. `compute_section_tokens <section_text>` -- takes section content as an
   argument, returns estimated token count. Sources `estimate_tokens` from
   `scripts/lib/payload-transforms.sh` (created in T01).

3. `format_manifest_row <name> <start_line> <end_line> <tokens> <priority>`
   -- takes five arguments, returns one formatted manifest table row.

4. `assemble_manifest_table <section_count> <names_pipe> <priorities_pipe>
   <line_counts_space> <token_counts_space> <content_start_line>` -- takes
   section metadata, computes line ranges, and returns the complete manifest
   table (header + data rows + total row). This is the main orchestration
   function that calls `build_manifest_header` and `format_manifest_row`
   internally.

The library follows the double-sourcing guard pattern:

```
[ -n "${_MANIFEST_BUILDER_SOURCED:-}" ] && return 0
_MANIFEST_BUILDER_SOURCED=1
```

It sources `scripts/lib/payload-transforms.sh` for `estimate_tokens` (the
single source of truth for token estimation, created in T01).

Architectural constraint (AD-5): no file I/O inside function bodies.
Arguments in, stdout out.

## Steps

### Step 1 -- Create `scripts/lib/manifest-builder.sh`

Create the file with the following structure:

```bash
#!/usr/bin/env bash
# scripts/lib/manifest-builder.sh — Pure manifest table construction.
# All functions take arguments and return stdout. No file I/O.
# Sourced by build-context.sh, compress-payload.sh, and test harnesses.
#
# Functions:
#   build_manifest_header                 — returns table header rows
#   compute_section_tokens <text>         — returns estimated token count
#   format_manifest_row <n> <s> <e> <t> <p> — returns one table row
#   assemble_manifest_table <count> <names> <priorities> <line_counts>
#       <token_counts> <content_start>    — returns complete table
#
# Bash 3.2 compatible (NFR-200). No jq required.

# --- Double-sourcing guard (NFR-203 / AP-003) ---
[ -n "${_MANIFEST_BUILDER_SOURCED:-}" ] && return 0
_MANIFEST_BUILDER_SOURCED=1

# Source payload-transforms.sh for estimate_tokens (single source of truth).
_MB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_MB_DIR/payload-transforms.sh"

# build_manifest_header
# Returns the two-line manifest table header (column names + separator).
build_manifest_header() {
  printf '| Section | Lines | Est. Tokens | Priority |\n'
  printf '|---------|-------|-------------|----------|\n'
}

# compute_section_tokens <text>
# Delegates to estimate_tokens from payload-transforms.sh.
# Returns the estimated token count for the given text.
compute_section_tokens() {
  estimate_tokens "$1"
}

# format_manifest_row <name> <start_line> <end_line> <tokens> <priority>
# Returns one formatted manifest table row.
format_manifest_row() {
  local name="$1"
  local start_line="$2"
  local end_line="$3"
  local tokens="$4"
  local priority="$5"
  printf '| %s | %s-%s | ~%s | %s |\n' "$name" "$start_line" "$end_line" "$tokens" "$priority"
}

# format_manifest_total <total_tokens>
# Returns the total row for the manifest table.
format_manifest_total() {
  local total="$1"
  printf '| **Total** | | **~%s** | |\n' "$total"
}

# assemble_manifest_table <section_count> <names_pipe> <priorities_pipe>
#   <line_counts_space> <token_counts_space> <content_start_line>
#
# Builds the complete manifest table from section metadata.
#   section_count:      integer, number of sections
#   names_pipe:         pipe-delimited section names (e.g. "Knowledge|Decisions|Scope")
#   priorities_pipe:    pipe-delimited priorities (e.g. "filtered|filtered|required")
#   line_counts_space:  space-delimited line counts per section (e.g. "3 5 12")
#   token_counts_space: space-delimited token counts per section (e.g. "100 200 500")
#   content_start_line: integer, line number where first section content starts
#
# Returns the complete manifest table on stdout (header + data rows + total).
assemble_manifest_table() {
  local section_count="$1"
  local names_pipe="$2"
  local priorities_pipe="$3"
  local line_counts_space="$4"
  local token_counts_space="$5"
  local content_start="$6"

  local S_NAMES S_PRIORITIES
  IFS='|' read -ra S_NAMES <<EOF_N
$names_pipe
EOF_N
  IFS='|' read -ra S_PRIORITIES <<EOF_P
$priorities_pipe
EOF_P

  build_manifest_header

  local current_line="$content_start"
  local total_tokens=0
  local idx=0
  local i sec_lc sec_tc sec_name sec_pri end_line
  for i in $(seq 1 "$section_count"); do
    sec_lc="$(printf '%s' "$line_counts_space" | awk -v n="$i" '{print $n}')"
    sec_tc="$(printf '%s' "$token_counts_space" | awk -v n="$i" '{print $n}')"
    sec_name="${S_NAMES[$idx]}"
    sec_pri="${S_PRIORITIES[$idx]}"

    end_line=$((current_line + sec_lc - 1))
    format_manifest_row "$sec_name" "$current_line" "$end_line" "$sec_tc" "$sec_pri"
    total_tokens=$((total_tokens + sec_tc))
    current_line=$((end_line + 2))
    idx=$((idx + 1))
  done

  format_manifest_total "$total_tokens"
}
```

Make executable:

```bash
chmod +x scripts/lib/manifest-builder.sh
```

### Step 2 -- Smoke test manifest-builder.sh

Source the library and test key functions:

```bash
source scripts/lib/manifest-builder.sh

# Test build_manifest_header
build_manifest_header
# Expected:
# | Section | Lines | Est. Tokens | Priority |
# |---------|-------|-------------|----------|

# Test format_manifest_row
format_manifest_row "Knowledge" "20" "25" "200" "filtered"
# Expected: | Knowledge | 20-25 | ~200 | filtered |

# Test format_manifest_total
format_manifest_total "1500"
# Expected: | **Total** | | **~1500** | |

# Test assemble_manifest_table
assemble_manifest_table 2 "Knowledge|Scope" "filtered|required" "3 5" "100 200" 20
# Expected: complete table with header, two rows, and total
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "manifest-builder.sh exists with double-sourcing guard and
  exports build_manifest_header, compute_section_tokens, format_manifest_row".
- **Artifacts**: `scripts/lib/manifest-builder.sh`.

## Verification

Run the verification script:

```bash
bash scripts/verify/p03-manifest-builder-lib.sh
```

Should print PASS. The remaining verification scripts for delegation
(p03-build-context-delegates.sh, p03-compress-delegates.sh) will FAIL until
T03/T04 complete. This is expected.

### Files Touched By This Task

- `scripts/lib/manifest-builder.sh` (create)

## Inputs

### From Previous Tasks

- T01: `scripts/lib/payload-transforms.sh` must exist. manifest-builder.sh
  sources it for `estimate_tokens`.

### From Disk (Pre-existing)

- `scripts/lib/errors.sh` -- reference for the double-sourcing guard pattern.

- `scripts/dispatch/build-context.sh` -- contains inline manifest table
  construction in `_bc_assemble_manifest_and_emit()` (lines 512-636).
  Key logic to port:
  - Table header format: `| Section | Lines | Est. Tokens | Priority |`
  - Row format: `| <name> | <start>-<end> | ~<tokens> | <priority> |`
  - Total row: `| **Total** | | **~<total>** | |`
  - Line range computation: tracks `current_line`, adds `sec_lc` for each
    section, gap of 2 lines between sections.

- `scripts/dispatch/compress-payload.sh` -- contains manifest rebuild in the
  "Rebuild the payload" block (lines 593-695). Same table format. The rebuild
  logic after compression recomputes line ranges for remaining sections.

## Expected Output

After completing this task:

1. `scripts/lib/manifest-builder.sh` exists, is chmod +x, has the
   double-sourcing guard `_MANIFEST_BUILDER_SOURCED`, and defines four
   functions: `build_manifest_header`, `compute_section_tokens`,
   `format_manifest_row`, `format_manifest_total`, and
   `assemble_manifest_table`.
2. `build_manifest_header` returns the two-line table header.
3. `format_manifest_row "Test" "1" "10" "500" "required"` returns
   `| Test | 1-10 | ~500 | required |`.
4. `assemble_manifest_table` with valid arguments returns a complete table.
5. `bash scripts/verify/p03-manifest-builder-lib.sh` prints PASS.
6. `git status` shows 1 new file. Nothing else touched.
