---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M002"
name: "Implement resolve-entries.sh — detail file content resolver"
depends_on: [T02]
---

## Prerequisites

- T01 has created 3 verification scripts (`m002-p03-resolve-*.sh`) that test this script's behavior.
- T02 has delivered `scripts/knowledge/traverse-graph.sh` (graph traversal outputs entry IDs — this script resolves those IDs to full content).
- P01 delivered `scripts/knowledge/lib/detail-utils.sh` with `find_detail_file` and `fm_field`.

## Description

Create `scripts/knowledge/resolve-entries.sh` that takes a list of entry IDs and outputs their detail file content for injection into dispatch payloads. This is the final step in the knowledge retrieval pipeline: scope-filter selects IDs from the index, traverse-graph optionally expands with related IDs, and resolve-entries reads the actual content.

The script:
1. Accepts entry IDs as positional arguments OR reads them from stdin (one per line).
2. For each ID, locates the detail file using `find_detail_file`.
3. Outputs the file content with a clear delimiter/header containing the entry ID for traceability (FR-111).
4. Skips missing entries with a warning to stderr (does not fail).
5. Exits 0 even if some entries are missing (graceful degradation).

## Steps

### Step 1: Create the script file

Create `scripts/knowledge/resolve-entries.sh`:

```bash
#!/usr/bin/env bash
# scripts/knowledge/resolve-entries.sh — Resolve entry IDs to detail file content
# Given a list of entry IDs, reads their detail files and outputs content
# for injection into dispatch payloads.
#
# Usage: resolve-entries.sh <entry-id> [entry-id...]
#    or: echo "MEM001\nMEM002" | resolve-entries.sh --stdin
#
# Output: concatenated detail file content with entry ID headers.
# Each entry is delimited by:
#   <!-- BEGIN entry-id -->
#   (file content)
#   <!-- END entry-id -->
#
# Exit 0 on success (including when some entries are missing — warnings to stderr).
# Exit 1 on no input (no IDs provided at all).
#
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/index-utils.sh
source "$SCRIPT_DIR/lib/index-utils.sh"
# shellcheck source=lib/detail-utils.sh
source "$SCRIPT_DIR/lib/detail-utils.sh"
```

### Step 2: Implement argument parsing and ID collection

```bash
USE_STDIN=false
entry_ids=""

while [ $# -gt 0 ]; do
  case "$1" in
    --stdin) USE_STDIN=true; shift ;;
    -*) echo "resolve-entries.sh: unknown option '$1'" >&2; exit 1 ;;
    *)
      if [ -z "$entry_ids" ]; then
        entry_ids="$1"
      else
        entry_ids="$entry_ids $1"
      fi
      shift ;;
  esac
done

# Read from stdin if --stdin flag or no positional args with stdin available
if [ "$USE_STDIN" = true ]; then
  while IFS= read -r line; do
    line="$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
    [ -z "$line" ] && continue
    if [ -z "$entry_ids" ]; then
      entry_ids="$line"
    else
      entry_ids="$entry_ids $line"
    fi
  done
fi

if [ -z "$entry_ids" ]; then
  echo "resolve-entries.sh: no entry IDs provided" >&2
  echo "Usage: resolve-entries.sh <entry-id> [entry-id...]" >&2
  exit 1
fi
```

### Step 3: Resolve each entry ID to content

```bash
resolved_count=0
missing_count=0

for entry_id in $entry_ids; do
  # Locate the detail file
  detail_file=""
  detail_file="$(find_detail_file "$entry_id" 2>/dev/null)" || {
    echo "WARNING: entry '$entry_id' not found, skipping" >&2
    missing_count=$((missing_count + 1))
    continue
  }

  # Skip archived entries (they should not be injected into payloads)
  case "$detail_file" in
    */archive/*)
      echo "WARNING: entry '$entry_id' is archived, skipping" >&2
      missing_count=$((missing_count + 1))
      continue
      ;;
  esac

  # Output with traceability delimiters
  echo "<!-- BEGIN $entry_id -->"
  cat "$detail_file"
  echo ""
  echo "<!-- END $entry_id -->"
  echo ""
  resolved_count=$((resolved_count + 1))
done

# Summary to stderr
if [ "$missing_count" -gt 0 ]; then
  echo "resolve-entries.sh: resolved $resolved_count entries, $missing_count missing" >&2
fi
```

### Step 4: Verify the 3 resolve verification scripts pass

Run each:
```
bash scripts/verify/m002-p03-resolve-outputs-content.sh
bash scripts/verify/m002-p03-resolve-skips-missing.sh
bash scripts/verify/m002-p03-resolve-preserves-ids.sh
```

All 3 must print `PASS:` and exit 0.

### Step 5: Run ALL 8 P03 verification scripts to confirm full phase pass

```
bash scripts/verify/m002-p03-traverse-reads-relates.sh
bash scripts/verify/m002-p03-traverse-max-cap.sh
bash scripts/verify/m002-p03-traverse-cycle-safe.sh
bash scripts/verify/m002-p03-traverse-one-hop.sh
bash scripts/verify/m002-p03-traverse-no-relates.sh
bash scripts/verify/m002-p03-resolve-outputs-content.sh
bash scripts/verify/m002-p03-resolve-skips-missing.sh
bash scripts/verify/m002-p03-resolve-preserves-ids.sh
```

All 8 must output `PASS:` and exit 0.

## Must-Haves

This task addresses these phase truths:
- resolve-entries.sh accepts a list of entry IDs and outputs their detail file content
- resolve-entries.sh skips missing entries with a warning to stderr (does not fail)
- resolve-entries.sh preserves entry IDs in output for traceability (FR-111)

## Verification

```
bash scripts/verify/m002-p03-resolve-outputs-content.sh
bash scripts/verify/m002-p03-resolve-skips-missing.sh
bash scripts/verify/m002-p03-resolve-preserves-ids.sh
```

All 3 must output `PASS:` and exit 0.

## Inputs

### From Previous Tasks

- `scripts/knowledge/traverse-graph.sh` (from T02) — outputs entry IDs (one per line) that can be piped into resolve-entries.sh via `--stdin`. API: `traverse-graph.sh <seed-id> [--max N]` outputs related entry IDs to stdout, one per line.
- `scripts/verify/m002-p03-resolve-outputs-content.sh` (from T01) — creates MEM001 and MEM002 fixtures, runs resolve-entries.sh with both IDs, asserts body text appears in stdout.
- `scripts/verify/m002-p03-resolve-skips-missing.sh` (from T01) — creates MEM001 only, runs resolve-entries.sh with MEM001 and MEM999, asserts exit 0, MEM001 content in stdout, MEM999 warning in stderr.
- `scripts/verify/m002-p03-resolve-preserves-ids.sh` (from T01) — creates MEM001 and MEM002, runs resolve-entries.sh, asserts `<!-- BEGIN MEM001 -->` and `<!-- BEGIN MEM002 -->` appear in stdout.

### From Disk (Pre-existing)

- `scripts/knowledge/lib/index-utils.sh` — provides `get_project_root()` (supports `PROJECT_ROOT` env var override). Source this first.
- `scripts/knowledge/lib/detail-utils.sh` — provides `find_detail_file(entry_id)` which scans `knowledge/*/ID.md` returning the full path, returns exit 1 if not found. Also checks `knowledge/archive/`. Requires index-utils.sh sourced first.
- Detail file format: YAML frontmatter between `---` delimiters, then markdown body starting with `# MEM###: description` heading followed by the entry content.

## Constraints

- Bash 3.2 compatible: no associative arrays, no `mapfile`, no `readarray`.
- Must accept IDs both as positional arguments and from stdin (`--stdin` flag).
- Output must include `<!-- BEGIN entry-id -->` / `<!-- END entry-id -->` delimiters for each entry so that downstream consumers (build-context.sh in P04) can locate individual entries in the payload.
- Missing entries produce a WARNING to stderr but do NOT cause a non-zero exit code.
- Archived entries are treated as missing (skipped with warning).
- Idempotent: running twice with same input produces identical output.
- `cat` for file reading is acceptable — these are small markdown files.

## Expected Output

One new file: `scripts/knowledge/resolve-entries.sh` (executable, ~50-70 lines).

When run with two valid entry IDs:
```
$ bash scripts/knowledge/resolve-entries.sh MEM001 MEM002
<!-- BEGIN MEM001 -->
---
id: MEM001
...frontmatter...
---

# MEM001: Some description

Body text.

<!-- END MEM001 -->

<!-- BEGIN MEM002 -->
---
id: MEM002
...frontmatter...
---

# MEM002: Another description

Body text.

<!-- END MEM002 -->
```

When composed with traverse-graph.sh:
```
$ bash scripts/knowledge/traverse-graph.sh MEM001 | bash scripts/knowledge/resolve-entries.sh --stdin
<!-- BEGIN MEM002 -->
...content...
<!-- END MEM002 -->
```
