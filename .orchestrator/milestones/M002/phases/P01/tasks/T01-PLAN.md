---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M002"
name: "Directory Structure and Shared Library"
depends_on: []
---

## Description

Create the knowledge directory tree (`knowledge/{category}/`, `knowledge/archive/`), the shared staleness decay helper library, and the shared index utility library. These are the foundational pieces that all subsequent CRUD scripts depend on.

## Steps

### Step 1: Create the knowledge directory structure

Create the directory tree with `.gitkeep` files so empty directories are tracked by git:

```
knowledge/
  archive/
    .gitkeep
  .gitkeep
```

Commands:
```bash
mkdir -p knowledge/archive
touch knowledge/.gitkeep
touch knowledge/archive/.gitkeep
```

### Step 2: Create the shared library directory

```bash
mkdir -p scripts/knowledge/lib
```

### Step 3: Create `scripts/knowledge/lib/staleness.sh`

This is a sourceable library (not directly executable) providing the `compute_effective_confidence` function. It implements the staleness decay formula from AD-5:

```
effective_confidence = confidence * max(0.5, 1.0 - (days_since_verified / 180))
```

Write the following file at `scripts/knowledge/lib/staleness.sh`:

```bash
#!/usr/bin/env bash
# scripts/knowledge/lib/staleness.sh — Staleness decay helper library
# Source this file to use compute_effective_confidence().
#
# Formula (AD-5, FR-105):
#   effective_confidence = confidence * max(0.5, 1.0 - (days_since_verified / 180))
#
# The floor of 0.5 prevents entries from decaying to zero.
# The 180-day window is the default staleness horizon.
#
# Bash 3.2 compatible — uses only POSIX arithmetic and bc for floating point.

# Compute days between two ISO dates (YYYY-MM-DD format).
# Usage: days_since <past_date> [<reference_date>]
# If reference_date is omitted, uses today.
# Returns integer days to stdout.
days_since() {
  local past_date="$1"
  local ref_date="${2:-$(date +%Y-%m-%d)}"

  # Convert dates to epoch seconds
  # macOS date (BSD) uses -j -f, Linux date uses -d
  local past_epoch ref_epoch
  if date -j -f "%Y-%m-%d" "$past_date" "+%s" >/dev/null 2>&1; then
    # BSD/macOS date
    past_epoch=$(date -j -f "%Y-%m-%d" "$past_date" "+%s" 2>/dev/null)
    ref_epoch=$(date -j -f "%Y-%m-%d" "$ref_date" "+%s" 2>/dev/null)
  else
    # GNU/Linux date
    past_epoch=$(date -d "$past_date" "+%s" 2>/dev/null)
    ref_epoch=$(date -d "$ref_date" "+%s" 2>/dev/null)
  fi

  if [ -z "$past_epoch" ] || [ -z "$ref_epoch" ]; then
    echo "0"
    return 1
  fi

  local diff_seconds=$(( ref_epoch - past_epoch ))
  local diff_days=$(( diff_seconds / 86400 ))
  # Ensure non-negative
  if [ "$diff_days" -lt 0 ]; then
    diff_days=0
  fi
  echo "$diff_days"
}

# Compute effective confidence after staleness decay.
# Usage: compute_effective_confidence <confidence> <last_verified_date> [<reference_date>]
# confidence: float 0.0 to 1.0 (e.g., 0.90)
# last_verified_date: YYYY-MM-DD format
# reference_date: optional, defaults to today
#
# Output: float effective confidence to stdout (e.g., 0.72)
# Uses bc if available, falls back to awk for floating-point math.
compute_effective_confidence() {
  local confidence="$1"
  local last_verified="$2"
  local ref_date="${3:-$(date +%Y-%m-%d)}"

  local days
  days=$(days_since "$last_verified" "$ref_date")

  # decay_factor = max(0.5, 1.0 - (days / 180))
  # effective_confidence = confidence * decay_factor
  if command -v bc >/dev/null 2>&1; then
    echo "$confidence $days" | awk '{
      days = $2
      conf = $1
      decay = 1.0 - (days / 180.0)
      if (decay < 0.5) decay = 0.5
      printf "%.2f\n", conf * decay
    }'
  else
    # awk-only fallback (always available)
    echo "$confidence $days" | awk '{
      days = $2
      conf = $1
      decay = 1.0 - (days / 180.0)
      if (decay < 0.5) decay = 0.5
      printf "%.2f\n", conf * decay
    }'
  fi
}
```

Note: Both branches use awk intentionally — bc is checked but awk is used uniformly for simplicity and Bash 3.2 compatibility. The bc check is reserved for future use if higher precision is needed.

### Step 4: Create `scripts/knowledge/lib/index-utils.sh`

This is a sourceable library providing shared functions for reading and writing the KNOWLEDGE-INDEX.md file. All CRUD scripts source this library.

Write the following file at `scripts/knowledge/lib/index-utils.sh`:

```bash
#!/usr/bin/env bash
# scripts/knowledge/lib/index-utils.sh — Shared index read/write utilities
# Source this file to use index helper functions.
#
# Index format (AD-2, FR-101):
#   MEM### | [scope_tags] | category | confidence | created_at | verified:date | hits:N | description
#
# The index file (KNOWLEDGE-INDEX.md) has a header section (lines starting with # or |)
# followed by data lines (one per entry). Data lines use pipe delimiters.
#
# All index writes use the atomic temp-file-then-mv pattern (FR-109).
# Bash 3.2 compatible.

# Default index path relative to project root
DEFAULT_INDEX_PATH="KNOWLEDGE-INDEX.md"

# Get the project root (walk up from script location to find extension.yml)
get_project_root() {
  local dir
  if [ -n "${PROJECT_ROOT:-}" ]; then
    echo "$PROJECT_ROOT"
    return
  fi
  dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  # Walk up to find extension.yml
  local candidate="$dir"
  while [ "$candidate" != "/" ]; do
    if [ -f "$candidate/extension.yml" ]; then
      echo "$candidate"
      return
    fi
    candidate="$(dirname "$candidate")"
  done
  # Fallback: two levels up from lib/
  echo "$dir"
}

# Get the index file path
get_index_path() {
  local root
  root="$(get_project_root)"
  echo "$root/$DEFAULT_INDEX_PATH"
}

# Initialize the index file if it doesn't exist
# Creates the header with format documentation
init_index() {
  local index_path
  index_path="$(get_index_path)"

  if [ -f "$index_path" ]; then
    return 0
  fi

  cat > "$index_path" <<'HEADER'
# Knowledge Index
<!-- Generated artifact — rebuild with: bash scripts/knowledge/rebuild-index.sh -->
<!-- Format: id | scope_tags | category | confidence | created_at | verified:date | hits:N | description -->
HEADER
}

# Add an entry line to the index atomically
# Usage: index_add_entry <entry_line>
# The entry_line should be pre-formatted: MEM### | [tags] | cat | conf | date | verified:date | hits:N | desc
index_add_entry() {
  local entry_line="$1"
  local index_path
  index_path="$(get_index_path)"

  init_index

  local tmp_file="${index_path}.tmp.$$"
  # Copy existing index and append new entry
  cp "$index_path" "$tmp_file"
  echo "$entry_line" >> "$tmp_file"
  mv "$tmp_file" "$index_path"
}

# Remove an entry from the index by ID atomically
# Usage: index_remove_entry <entry_id>
index_remove_entry() {
  local entry_id="$1"
  local index_path
  index_path="$(get_index_path)"

  if [ ! -f "$index_path" ]; then
    return 0
  fi

  local tmp_file="${index_path}.tmp.$$"
  # Copy everything except lines starting with the entry ID
  grep -v "^${entry_id} |" "$index_path" > "$tmp_file" || true
  mv "$tmp_file" "$index_path"
}

# Update an entry in the index atomically (remove old, add new)
# Usage: index_update_entry <entry_id> <new_entry_line>
index_update_entry() {
  local entry_id="$1"
  local new_entry_line="$2"
  local index_path
  index_path="$(get_index_path)"

  if [ ! -f "$index_path" ]; then
    index_add_entry "$new_entry_line"
    return
  fi

  local tmp_file="${index_path}.tmp.$$"
  # Remove old entry and add new one
  grep -v "^${entry_id} |" "$index_path" > "$tmp_file" || true
  echo "$new_entry_line" >> "$tmp_file"
  mv "$tmp_file" "$index_path"
}

# Check if an entry exists in the index
# Usage: index_has_entry <entry_id>
# Returns 0 if found, 1 if not
index_has_entry() {
  local entry_id="$1"
  local index_path
  index_path="$(get_index_path)"

  if [ ! -f "$index_path" ]; then
    return 1
  fi

  grep -q "^${entry_id} |" "$index_path"
}

# Read an entry line from the index
# Usage: index_get_entry <entry_id>
# Outputs the full pipe-delimited line to stdout
index_get_entry() {
  local entry_id="$1"
  local index_path
  index_path="$(get_index_path)"

  if [ ! -f "$index_path" ]; then
    return 1
  fi

  grep "^${entry_id} |" "$index_path"
}

# Format an index entry line from individual fields
# Usage: format_index_entry <id> <scope_tags> <category> <confidence> <created_at> <last_verified> <hit_count> <description>
format_index_entry() {
  local id="$1"
  local scope_tags="$2"
  local category="$3"
  local confidence="$4"
  local created_at="$5"
  local last_verified="$6"
  local hit_count="$7"
  local description="$8"

  echo "${id} | ${scope_tags} | ${category} | ${confidence} | ${created_at} | verified:${last_verified} | hits:${hit_count} | ${description}"
}

# Get the next available MEM### ID by scanning the index
# Usage: next_entry_id
# Output: MEM### where ### is the next sequential number
next_entry_id() {
  local index_path
  index_path="$(get_index_path)"

  local max_num=0
  if [ -f "$index_path" ]; then
    # Extract all MEM### IDs and find the highest number
    local num
    while IFS= read -r line; do
      num=$(echo "$line" | grep -oE '^MEM[0-9]+' | sed 's/MEM//')
      if [ -n "$num" ]; then
        # Remove leading zeros for arithmetic
        num=$(echo "$num" | sed 's/^0*//')
        num="${num:-0}"
        if [ "$num" -gt "$max_num" ] 2>/dev/null; then
          max_num="$num"
        fi
      fi
    done < "$index_path"
  fi

  # Also scan detail files in case index is out of date
  local root
  root="$(get_project_root)"
  if [ -d "$root/knowledge" ]; then
    local file num
    for file in "$root"/knowledge/*/MEM*.md "$root"/knowledge/archive/MEM*.md; do
      if [ -f "$file" ]; then
        num=$(basename "$file" .md | sed 's/MEM//')
        num=$(echo "$num" | sed 's/^0*//')
        num="${num:-0}"
        if [ "$num" -gt "$max_num" ] 2>/dev/null; then
          max_num="$num"
        fi
      fi
    done
  fi

  local next_num=$((max_num + 1))
  printf "MEM%03d\n" "$next_num"
}

# Write the complete index from scratch (used by rebuild-index.sh)
# Usage: write_full_index <entries_string>
# entries_string: newline-separated entry lines
write_full_index() {
  local entries="$1"
  local index_path
  index_path="$(get_index_path)"

  local tmp_file="${index_path}.tmp.$$"

  cat > "$tmp_file" <<'HEADER'
# Knowledge Index
<!-- Generated artifact — rebuild with: bash scripts/knowledge/rebuild-index.sh -->
<!-- Format: id | scope_tags | category | confidence | created_at | verified:date | hits:N | description -->
HEADER

  if [ -n "$entries" ]; then
    echo "$entries" >> "$tmp_file"
  fi

  mv "$tmp_file" "$index_path"
}
```

### Step 5: Make library files non-executable (they are sourced, not run directly)

```bash
chmod 644 scripts/knowledge/lib/staleness.sh
chmod 644 scripts/knowledge/lib/index-utils.sh
```

## Must-Haves

This task addresses the following phase must-haves:

**Truths:**
- All scripts are Bash 3.2 compatible (no associative arrays, no readarray, no mapfile)
- The staleness decay helper computes effective_confidence = confidence * max(0.5, 1.0 - (days_since_verified / 180))
- All index writes use the atomic temp-file-then-mv pattern

**Artifacts:**
- knowledge/.gitkeep
- knowledge/archive/.gitkeep
- scripts/knowledge/lib/staleness.sh (min 20 lines, contains "effective_confidence")
- scripts/knowledge/lib/index-utils.sh (min 80 lines, contains "KNOWLEDGE-INDEX")

## Verification

Run these commands from the project root to verify:

```bash
# Directory structure exists
test -d knowledge && echo "PASS: knowledge/ exists"
test -d knowledge/archive && echo "PASS: knowledge/archive/ exists"
test -f knowledge/.gitkeep && echo "PASS: knowledge/.gitkeep exists"
test -f knowledge/archive/.gitkeep && echo "PASS: knowledge/archive/.gitkeep exists"

# Library files exist with expected content
test -f scripts/knowledge/lib/staleness.sh && echo "PASS: staleness.sh exists"
test -f scripts/knowledge/lib/index-utils.sh && echo "PASS: index-utils.sh exists"
grep -q "effective_confidence" scripts/knowledge/lib/staleness.sh && echo "PASS: staleness.sh has effective_confidence"
grep -q "KNOWLEDGE-INDEX" scripts/knowledge/lib/index-utils.sh && echo "PASS: index-utils.sh references KNOWLEDGE-INDEX"
grep -q "mv.*tmp" scripts/knowledge/lib/index-utils.sh && echo "PASS: index-utils.sh uses atomic mv"

# Bash 3.2 compatibility
! grep -rE 'declare -A|readarray|mapfile' scripts/knowledge/lib/ && echo "PASS: no Bash 4+ features"

# Staleness decay test (source and call)
source scripts/knowledge/lib/staleness.sh
result=$(compute_effective_confidence 0.90 "2026-01-01" "2026-04-09")
echo "Staleness test: 0.90 confidence, ~98 days stale = $result"
```

## Inputs

### From Previous Tasks

None — this is the first task in P01.

### From Disk (Pre-existing)

- `scripts/knowledge/` — directory already exists (contains append-knowledge.sh, consolidate-artifacts.sh, write-summary.sh from M001). New files are added alongside existing ones.
- `scripts/util/json-field.sh` — existing utility library. Follow the same pattern (sourceable function library) for the new libraries.

## Expected Output

After this task completes:

1. `knowledge/` and `knowledge/archive/` directories exist with `.gitkeep` files
2. `scripts/knowledge/lib/staleness.sh` exists with `days_since()` and `compute_effective_confidence()` functions
3. `scripts/knowledge/lib/index-utils.sh` exists with `get_index_path()`, `init_index()`, `index_add_entry()`, `index_remove_entry()`, `index_update_entry()`, `index_has_entry()`, `index_get_entry()`, `format_index_entry()`, `next_entry_id()`, and `write_full_index()` functions
4. All functions use Bash 3.2 compatible syntax
5. All index writes go through temp-file-then-mv
