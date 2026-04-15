---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M002"
name: "Implement traverse-graph.sh — knowledge graph traversal"
depends_on: [T01]
---

## Prerequisites

- T01 has created 5 verification scripts (`m002-p03-traverse-*.sh`) that test this script's behavior.
- P01 delivered `scripts/knowledge/lib/detail-utils.sh` and `scripts/knowledge/lib/index-utils.sh`.
- P01 delivered the detail file format with `relates_to` field in YAML frontmatter.

## Description

Create `scripts/knowledge/traverse-graph.sh` that implements FR-110: graph traversal via the optional `relates_to` field in knowledge entry frontmatter.

Given a seed entry ID, the script:
1. Reads the seed entry's detail file to extract its `relates_to` field.
2. For each related entry ID, checks if a warm (non-archived) detail file exists.
3. Outputs the related entry IDs to stdout (one per line).
4. Enforces a max-entries cap (default 5, configurable via `--max`).
5. Maintains a visited set to prevent cycles (the seed entry is pre-added to the visited set so it never appears in output).
6. Traverses exactly 1 hop by default — does NOT recursively follow relates_to of the discovered entries.

## Steps

### Step 1: Create the script file

Create `scripts/knowledge/traverse-graph.sh` with this structure:

```bash
#!/usr/bin/env bash
# scripts/knowledge/traverse-graph.sh — Traverse knowledge graph relationships
# Given an entry ID, reads its relates_to field and outputs related entry IDs.
#
# Usage: traverse-graph.sh <entry-id> [--max N]
#   entry-id: the seed entry (e.g., MEM001)
#   --max N:  maximum related entries to return (default: 5)
#
# Output: one entry ID per line to stdout (only warm/active entries, not archived or missing)
# Exit 0 on success (including when no relationships found — empty output is valid).
# Exit 1 on missing seed entry or invalid arguments.
#
# Bash 3.2 compatible. No associative arrays.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/index-utils.sh
source "$SCRIPT_DIR/lib/index-utils.sh"
# shellcheck source=lib/detail-utils.sh
source "$SCRIPT_DIR/lib/detail-utils.sh"
```

### Step 2: Implement argument parsing

```bash
SEED_ID=""
MAX_ENTRIES=5

while [ $# -gt 0 ]; do
  case "$1" in
    --max) MAX_ENTRIES="$2"; shift 2 ;;
    -*) echo "traverse-graph.sh: unknown option '$1'" >&2; exit 1 ;;
    *)
      if [ -z "$SEED_ID" ]; then
        SEED_ID="$1"
      fi
      shift ;;
  esac
done

if [ -z "$SEED_ID" ]; then
  echo "traverse-graph.sh: missing required entry ID" >&2
  echo "Usage: traverse-graph.sh <entry-id> [--max N]" >&2
  exit 1
fi
```

### Step 3: Locate the seed entry and extract relates_to

```bash
# Find the seed entry's detail file
seed_file=""
seed_file="$(find_detail_file "$SEED_ID")" || {
  echo "traverse-graph.sh: seed entry '$SEED_ID' not found" >&2
  exit 1
}

# Check that seed is not archived (find_detail_file returns archive paths too)
case "$seed_file" in
  */archive/*)
    echo "traverse-graph.sh: seed entry '$SEED_ID' is archived" >&2
    exit 1
    ;;
esac

# Extract relates_to field from YAML frontmatter
# Format in frontmatter: relates_to: [MEM002, MEM003] or relates_to: []
raw_relates="$(fm_field "$seed_file" "relates_to")"

# Parse the YAML inline list: strip brackets, split on comma
# Handle empty list: [] or empty string
cleaned="$(echo "$raw_relates" | sed 's/^\[//' | sed 's/\]$//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"

if [ -z "$cleaned" ]; then
  # No relationships — exit 0 with empty output
  exit 0
fi
```

### Step 4: Iterate over related IDs with cycle detection and max cap

Use a space-delimited string as a visited set (Bash 3.2 compatible, no associative arrays).

```bash
# Visited set — seed is pre-added so it never appears in output
visited=" $SEED_ID "
output_count=0

# Split comma-separated IDs
# Using a while-read loop on comma-separated values for Bash 3.2 compat
echo "$cleaned" | tr ',' '\n' | while IFS= read -r related_id; do
  # Trim whitespace
  related_id="$(echo "$related_id" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"

  # Skip empty
  [ -z "$related_id" ] && continue

  # Cycle check: skip if already visited
  case "$visited" in
    *" $related_id "*) continue ;;
  esac

  # Check max cap
  if [ "$output_count" -ge "$MAX_ENTRIES" ]; then
    break
  fi

  # Verify the entry exists as a warm (non-archived) detail file
  related_file=""
  related_file="$(find_detail_file "$related_id" 2>/dev/null)" || continue
  case "$related_file" in
    */archive/*) continue ;;
  esac

  # Output the related ID
  echo "$related_id"
  visited="$visited$related_id "
  output_count=$((output_count + 1))
done
```

**IMPORTANT**: The `while` loop runs in a subshell when piped. To make `output_count` and `visited` persist, use a process-substitution-free approach. Instead of piping into `while`, use a temp file or here-string approach compatible with Bash 3.2:

```bash
# Bash 3.2 compatible: write IDs to a temp file, then iterate
tmpfile="$(mktemp)"
trap "rm -f '$tmpfile'" EXIT
echo "$cleaned" | tr ',' '\n' > "$tmpfile"

while IFS= read -r related_id; do
  related_id="$(echo "$related_id" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
  [ -z "$related_id" ] && continue
  case "$visited" in
    *" $related_id "*) continue ;;
  esac
  if [ "$output_count" -ge "$MAX_ENTRIES" ]; then
    break
  fi
  related_file="$(find_detail_file "$related_id" 2>/dev/null)" || continue
  case "$related_file" in
    */archive/*) continue ;;
  esac
  echo "$related_id"
  visited="$visited$related_id "
  output_count=$((output_count + 1))
done < "$tmpfile"
```

### Step 5: Verify the 5 traverse verification scripts pass

Run each:
```
bash scripts/verify/m002-p03-traverse-reads-relates.sh
bash scripts/verify/m002-p03-traverse-max-cap.sh
bash scripts/verify/m002-p03-traverse-cycle-safe.sh
bash scripts/verify/m002-p03-traverse-one-hop.sh
bash scripts/verify/m002-p03-traverse-no-relates.sh
```

All 5 must print `PASS:` and exit 0.

## Must-Haves

This task addresses these phase truths:
- traverse-graph.sh reads the `relates_to` field from a detail file's YAML frontmatter and outputs related entry IDs
- traverse-graph.sh limits output to a configurable max (default 5 entries)
- traverse-graph.sh is cycle-safe — visiting A that relates to B that relates back to A outputs each entry at most once
- traverse-graph.sh traverses exactly 1 hop by default (does not follow relates_to of related entries)
- traverse-graph.sh handles entries with no relates_to field gracefully (empty output, exit 0)

## Verification

```
bash scripts/verify/m002-p03-traverse-reads-relates.sh
bash scripts/verify/m002-p03-traverse-max-cap.sh
bash scripts/verify/m002-p03-traverse-cycle-safe.sh
bash scripts/verify/m002-p03-traverse-one-hop.sh
bash scripts/verify/m002-p03-traverse-no-relates.sh
```

All 5 must output `PASS:` and exit 0.

## Inputs

### From Previous Tasks

- `scripts/verify/m002-p03-traverse-reads-relates.sh` (from T01) — tests that traverse-graph.sh reads relates_to and outputs related IDs. Creates MEM001 with relates_to: [MEM002, MEM003], expects both in stdout.
- `scripts/verify/m002-p03-traverse-max-cap.sh` (from T01) — tests that output is capped at 5 entries when relates_to has 6+ entries.
- `scripts/verify/m002-p03-traverse-cycle-safe.sh` (from T01) — tests A->B->A cycle, expects each entry at most once, seed excluded.
- `scripts/verify/m002-p03-traverse-one-hop.sh` (from T01) — tests A->B->C chain, expects only B (not C) in output.
- `scripts/verify/m002-p03-traverse-no-relates.sh` (from T01) — tests empty relates_to, expects empty stdout and exit 0.

### From Disk (Pre-existing)

- `scripts/knowledge/lib/index-utils.sh` — provides `get_project_root()` (supports `PROJECT_ROOT` env var override). Source this first.
- `scripts/knowledge/lib/detail-utils.sh` — provides `find_detail_file(entry_id)` which scans `knowledge/*/ID.md` returning the path (also checks `knowledge/archive/`), returns exit 1 if not found; `fm_field(file, field)` which extracts YAML frontmatter field value (strips quotes, trims whitespace). Requires index-utils.sh sourced first.
- Detail file format: YAML frontmatter between `---` delimiters, `relates_to` field is a YAML inline list `[MEM002, MEM003]` or `[]` for empty.

## Constraints

- Bash 3.2 compatible: no associative arrays, no `mapfile`, no `readarray`. Use space-delimited string for visited set with `case` pattern matching.
- Do not read the index — graph traversal reads detail files directly (the index does not store `relates_to`).
- The seed entry ID must NOT appear in the output (it is pre-added to the visited set).
- Archived entries (path contains `/archive/`) must be excluded from output.
- Idempotent: running twice with same input produces identical output.
- Exit 0 even when no relationships found (empty output is valid).
- Exit 1 only on genuinely bad input (missing seed entry, missing arguments).

## Expected Output

One new file: `scripts/knowledge/traverse-graph.sh` (executable, ~60-80 lines).

When run against a fixture with MEM001 relating to MEM002 and MEM003:
```
$ bash scripts/knowledge/traverse-graph.sh MEM001
MEM002
MEM003
```

When run against an entry with no relationships:
```
$ bash scripts/knowledge/traverse-graph.sh MEM050
(empty output, exit 0)
```
