---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M003"
name: "JSON Fallback Reader Library"
depends_on: ["T01"]
---

## Description

Build the JSON/filesystem fallback reader for when `gsd.db` is unavailable (missing, corrupted, or unreadable). This library reads from `memories-snapshot.json` for knowledge entries and `state-manifest.json` for decisions, requirements, milestones, slices, and tasks. It also scans the milestone filesystem for plan/summary/UAT files.

The library must:
1. Parse JSON without a `jq` hard dependency (use grep/sed/awk; jq as optional enhancement)
2. Read `memories-snapshot.json` (103KB, 152 entries with nested JSON objects)
3. Read `state-manifest.json` (6.8MB, complete project state) for decisions, requirements, milestones
4. Scan `.gsd/milestones/M###/` directories for plan, summary, UAT files
5. Output TSV data using the escape/write utilities from `adapter-interface.sh`
6. Maintain Bash 3.2 compatibility

## Steps

### Step 1: Create `scripts/migrate/lib/json-fallback.sh`

The script should implement the following architecture:

**JSON Parsing Strategy:**
- Check if `jq` is available with `command -v jq >/dev/null 2>&1`
- If jq is available, use it for reliable parsing (preferred path)
- If jq is unavailable, use a line-by-line grep/sed/awk parser that handles the specific JSON structures found in GSD2 files
- Set a module-level flag `_jq_available` that all functions check

**Key Functions to Implement:**

```bash
#!/usr/bin/env bash
# scripts/migrate/lib/json-fallback.sh — JSON/filesystem fallback reader
# Used when gsd.db is unavailable. Reads from:
#   - memories-snapshot.json (knowledge entries)
#   - state-manifest.json (decisions, requirements, milestones, slices, tasks)
#   - Milestone directories (filesystem scan for plans, summaries, UATs)
#
# JSON parsing uses jq if available, falls back to grep/sed/awk.
# This file must be sourced after adapter-interface.sh.
#
# Usage:
#   source scripts/migrate/adapter-interface.sh
#   source scripts/migrate/lib/json-fallback.sh

set -euo pipefail

# Detect jq availability once at source time
_jq_available=false
if command -v jq >/dev/null 2>&1; then
  _jq_available=true
fi

# --- Check if JSON fallback files are available ---
# Usage: has_json_fallback <source_path>
# Returns 0 if memories-snapshot.json exists
has_json_fallback() {
  local source_path="$1"
  local gsd_dir="$source_path"
  # Accept both .gsd/ path and parent project path
  if [[ -f "$gsd_dir/memories-snapshot.json" ]]; then
    return 0
  fi
  if [[ -f "$gsd_dir/.gsd/memories-snapshot.json" ]]; then
    return 0
  fi
  return 1
}

# --- Resolve the actual .gsd directory ---
# Usage: resolve_gsd_dir <source_path>
# Echoes the path to the .gsd directory
_resolve_gsd_dir() {
  local source_path="$1"
  if [[ -f "$source_path/memories-snapshot.json" ]]; then
    echo "$source_path"
  elif [[ -f "$source_path/.gsd/memories-snapshot.json" ]]; then
    echo "$source_path/.gsd"
  else
    echo "$source_path"
  fi
}
```

**For the `jq` path**, use straightforward jq filters:
```bash
# jq path for knowledge extraction from memories-snapshot.json:
jq -r '.[] | [.id, .category, .content, .confidence, .hit_count,
  (.source_unit_id // ""), .created_at, .updated_at,
  (.superseded_by // "")] | @tsv' "$json_file"
```

**For the no-jq fallback path**, implement a simple state-machine parser:
- Read memories-snapshot.json line by line
- Track when inside an object (between `{` and `}`)
- Extract fields by matching `"field_name": "value"` or `"field_name": value` patterns
- When a closing `}` is encountered, emit the accumulated record
- Handle multiline content fields by accumulating until the closing quote

**Functions to implement for JSON fallback:**

```
json_read_knowledge <source_path> <output_dir>    -> knowledge.dat
json_read_decisions <source_path> <output_dir>    -> decisions.dat
json_read_requirements <source_path> <output_dir> -> requirements.dat
json_read_milestones <source_path> <output_dir>   -> milestones.dat
json_read_slices <source_path> <output_dir>       -> slices.dat
json_read_tasks <source_path> <output_dir>        -> tasks.dat
json_read_telemetry <source_path> <output_dir>    -> telemetry.dat
```

**Filesystem scanning function:**
```
scan_milestone_dirs <source_path> <output_dir>
```
This scans `.gsd/milestones/M###/` directories to discover milestone IDs and their slices/tasks when state-manifest.json is unavailable or incomplete. It reads:
- `M###/slices/S##/S##-PLAN.md` for slice plans
- `M###/slices/S##/S##-SUMMARY.md` for slice summaries
- `M###/slices/S##/S##-UAT.md` for UAT files
- `M###/slices/S##/tasks/T##-*.json` for task files

### Step 2: Make executable

```bash
chmod +x scripts/migrate/lib/json-fallback.sh
```

### Step 3: Verify

Test that the script handles both jq-available and jq-unavailable paths.

## Must-Haves

This task addresses these phase must-haves:

**Truths:**
- JSON fallback parsing works without a `jq` hard dependency (uses grep/sed/awk, with jq as optional enhancement)
- All scripts use `#!/usr/bin/env bash` shebang and `set -euo pipefail` for safety
- Bash 3.2 compatibility: no associative arrays, no `|&` pipe operator, no `${var,,}` case conversion
- Source directories are never modified (read-only access)

**Artifacts:**
- `scripts/migrate/lib/json-fallback.sh` (min 60 lines, contains "memories-snapshot")

**Key Links:**
- `scripts/migrate/adapters/gsd2.sh` -> `scripts/migrate/lib/json-fallback.sh` (adapter uses JSON fallback)

## Verification

```bash
# File exists and meets size requirement
test -f scripts/migrate/lib/json-fallback.sh
test "$(wc -l < scripts/migrate/lib/json-fallback.sh)" -ge 60

# Contains key references
grep -q "memories-snapshot" scripts/migrate/lib/json-fallback.sh
grep -qE 'command -v jq|which jq|type jq|_jq_available|JQ_AVAILABLE|has_jq' scripts/migrate/lib/json-fallback.sh

# No hard jq dependency (must handle missing jq)
grep -qE '_jq_available|JQ_AVAILABLE|has_jq' scripts/migrate/lib/json-fallback.sh

# Bash 3.2 compliance
! grep -n 'declare -A\||&\|${[a-zA-Z_]*,,}' scripts/migrate/lib/json-fallback.sh

# Sources cleanly
bash -c 'source scripts/migrate/adapter-interface.sh && source scripts/migrate/lib/json-fallback.sh && echo "PASS"'

# Key functions are defined
bash -c 'source scripts/migrate/adapter-interface.sh && source scripts/migrate/lib/json-fallback.sh && type json_read_knowledge >/dev/null && type json_read_decisions >/dev/null && type has_json_fallback >/dev/null && echo "PASS: functions defined"'
```

## Inputs

### From Previous Tasks

- `scripts/migrate/adapter-interface.sh` (from T01)
  - Key API: `escape_field(value)` -- escapes newlines/tabs for TSV; `write_header(output_file, field1, field2, ...)` -- writes TSV header line; `append_record(output_file, val1, val2, ...)` -- appends TSV data line; `emit_warning(output_dir, category, message, [raw_data])` -- logs structured warnings
  - Key types: TSV format with tab-separated fields, one record per line, header as first line. Field names for each section defined in `*_FIELDS` constants: `KNOWLEDGE_FIELDS`, `DECISIONS_FIELDS`, `REQUIREMENTS_FIELDS`, `MILESTONES_FIELDS`, `SLICES_FIELDS`, `TASKS_FIELDS`, `TELEMETRY_FIELDS`
  - Behavioral contract: All field values containing tabs or newlines must be escaped via `escape_field` before passing to `append_record`. Output files must match the exact same TSV schema as the SQLite reader (T02) -- transformers do not know which reader produced the data.

### From Disk (Pre-existing)

- `memories-snapshot.json` (in source project's `.gsd/` directory) -- JSON array of memory objects, each with fields: id, category, content, confidence, hit_count, source_unit_id, created_at, updated_at, superseded_by. Example: `[{"id": "MEM001", "category": "gotcha", "content": "...", "confidence": 0.95, ...}, ...]`. 103KB, 152 entries (128 active, 24 superseded).
- `state-manifest.json` (in source project's `.gsd/` directory) -- JSON object with top-level keys including `decisions`, `requirements`, `milestones` (each containing arrays or objects of records). 6.8MB. Structure mirrors the database tables.
- `.gsd/milestones/M###/` directories -- 43 directories containing slice subdirectories with plan/summary/UAT markdown files and task JSON files.

## Expected Output

A single file `scripts/migrate/lib/json-fallback.sh` that:
1. Detects jq availability at source time and sets `_jq_available` flag
2. Provides `has_json_fallback(source_path)` to check if JSON fallback files exist
3. Provides 7 reader functions: `json_read_knowledge`, `json_read_decisions`, `json_read_requirements`, `json_read_milestones`, `json_read_slices`, `json_read_tasks`, `json_read_telemetry`
4. Provides `scan_milestone_dirs(source_path, output_dir)` for filesystem-based discovery
5. Each reader writes TSV data in the exact same schema as the SQLite reader functions (T02)
6. Works both with and without jq installed
7. Never modifies the source directory
