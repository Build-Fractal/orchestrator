---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M003"
name: "GSD2 Adapter Implementation"
depends_on: ["T02", "T03"]
---

## Description

Implement the GSD2 adapter that orchestrates SQLite-preferred, JSON-fallback data extraction using the adapter interface contract from T01, the SQLite reader from T02, and the JSON fallback reader from T03. This is the main adapter script that downstream phases (P02-P04) will invoke to extract data from a GSD2 source project.

The adapter must:
1. Implement all 6 functions from the adapter interface contract: `detect_source`, `extract_knowledge`, `extract_decisions`, `extract_requirements`, `extract_milestones`, `extract_telemetry`
2. Auto-detect whether to use SQLite or JSON fallback based on `gsd.db` availability
3. Source the adapter interface, SQLite reader, and JSON fallback reader
4. Emit warnings when falling back from SQLite to JSON
5. Handle corrupted or missing data gracefully (skip-and-warn, per AD-8)
6. Never modify the source directory (AD-10)

## Steps

### Step 1: Create `scripts/migrate/adapters/gsd2.sh`

```bash
#!/usr/bin/env bash
# scripts/migrate/adapters/gsd2.sh — GSD2 source adapter
# Implements the adapter interface for GSD2 projects (.gsd/ directory).
#
# Data source priority (AD-2):
#   1. SQLite gsd.db (preferred — structured, indexed, authoritative)
#   2. JSON fallback: memories-snapshot.json + state-manifest.json
#   3. Filesystem scan: milestone directories for plans/summaries/UATs
#
# Usage:
#   source scripts/migrate/adapter-interface.sh
#   source scripts/migrate/adapters/gsd2.sh
#   detect_source "/path/to/project/.gsd"  # echoes "yes" or "no"
#   extract_knowledge "/path/to/project/.gsd" "/tmp/output"
#
# READ-ONLY: This adapter NEVER modifies the source .gsd/ directory.

set -euo pipefail

# Resolve script directory for sourcing dependencies
_GSD2_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_GSD2_ROOT="$(cd "$_GSD2_SCRIPT_DIR/../.." && pwd)"

# Source dependencies (adapter-interface.sh must be sourced first by the caller,
# but we source the libraries ourselves)
source "$_GSD2_SCRIPT_DIR/../lib/sqlite-reader.sh"
source "$_GSD2_SCRIPT_DIR/../lib/json-fallback.sh"
```

**Function implementations to include:**

```bash
# --- detect_source ---
# Checks if the given path is a GSD2 source directory.
# GSD2 is identified by: gsd.db present OR memories-snapshot.json present
# within a .gsd/ directory (or the path IS the .gsd/ directory).
detect_source() {
  local path="$1"
  # Direct .gsd directory
  if [[ -f "$path/gsd.db" ]] || [[ -f "$path/memories-snapshot.json" ]]; then
    echo "yes"
    return 0
  fi
  # Project root containing .gsd/
  if [[ -f "$path/.gsd/gsd.db" ]] || [[ -f "$path/.gsd/memories-snapshot.json" ]]; then
    echo "yes"
    return 0
  fi
  echo "no"
  return 0
}
```

For each `extract_*` function, follow this pattern:
1. Determine the actual `.gsd` directory path
2. Check if `gsd.db` exists and is valid SQLite (using `is_valid_sqlite` from T02)
3. If SQLite is available, use the `sqlite_read_*` function
4. If SQLite is unavailable, emit a "fallback" warning and use the `json_read_*` function
5. If neither is available, emit a "missing" warning and write an empty data file (header only)

```bash
# --- Internal: resolve .gsd path and determine data source ---
_gsd2_resolve() {
  local source_path="$1"
  local output_dir="$2"

  # Resolve to .gsd directory
  if [[ -d "$source_path/.gsd" ]]; then
    _gsd_dir="$source_path/.gsd"
  else
    _gsd_dir="$source_path"
  fi

  # Determine data source
  _gsd_db="$_gsd_dir/gsd.db"
  _use_sqlite=false
  if [[ -f "$_gsd_db" ]] && is_valid_sqlite "$_gsd_db"; then
    _use_sqlite=true
  else
    if [[ -f "$_gsd_db" ]]; then
      emit_warning "$output_dir" "fallback" \
        "gsd.db exists but is not a valid SQLite database; falling back to JSON"
    fi
  fi
}

# --- extract_knowledge ---
extract_knowledge() {
  local source_path="$1"
  local output_dir="$2"
  _gsd2_resolve "$source_path" "$output_dir"

  if [[ "$_use_sqlite" = true ]]; then
    sqlite_read_knowledge "$_gsd_db" "$output_dir"
  elif has_json_fallback "$_gsd_dir"; then
    emit_warning "$output_dir" "fallback" \
      "Using JSON fallback for knowledge extraction (gsd.db unavailable)"
    json_read_knowledge "$_gsd_dir" "$output_dir"
  else
    emit_warning "$output_dir" "missing" \
      "No knowledge data source found (no gsd.db, no memories-snapshot.json)"
    write_header "$output_dir/knowledge.dat" "id" "category" "content" \
      "confidence" "hit_count" "source_unit_id" "created_at" "updated_at" \
      "superseded_by"
  fi
}

# (Similar pattern for extract_decisions, extract_requirements,
#  extract_milestones, extract_telemetry — each checks _use_sqlite,
#  falls back to json_read_*, and handles missing data with header-only output)
```

The `extract_milestones` function is unique because it produces three output files (milestones.dat, slices.dat, tasks.dat):

```bash
extract_milestones() {
  local source_path="$1"
  local output_dir="$2"
  _gsd2_resolve "$source_path" "$output_dir"

  if [[ "$_use_sqlite" = true ]]; then
    sqlite_read_milestones "$_gsd_db" "$output_dir"
    sqlite_read_slices "$_gsd_db" "$output_dir"
    sqlite_read_tasks "$_gsd_db" "$output_dir"
  elif has_json_fallback "$_gsd_dir"; then
    emit_warning "$output_dir" "fallback" \
      "Using JSON fallback for milestone extraction (gsd.db unavailable)"
    json_read_milestones "$_gsd_dir" "$output_dir"
    json_read_slices "$_gsd_dir" "$output_dir"
    json_read_tasks "$_gsd_dir" "$output_dir"
    # Supplement with filesystem scan
    scan_milestone_dirs "$_gsd_dir" "$output_dir"
  else
    # Headers only
    write_header "$output_dir/milestones.dat" "id" "title" "status" "vision" \
      "created_at" "completed_at"
    write_header "$output_dir/slices.dat" "milestone_id" "id" "title" "status" \
      "goal" "demo"
    write_header "$output_dir/tasks.dat" "milestone_id" "slice_id" "id" "title" \
      "status" "description"
    emit_warning "$output_dir" "missing" \
      "No milestone data source found"
  fi
}
```

At the end of the script, validate the adapter:
```bash
# Validate that all required interface functions are implemented
validate_adapter
```

### Step 2: Make executable

```bash
chmod +x scripts/migrate/adapters/gsd2.sh
```

### Step 3: Verify

```bash
# Source and validate
bash -c '
  cd /path/to/orchestrator
  source scripts/migrate/adapter-interface.sh
  source scripts/migrate/adapters/gsd2.sh
  echo "PASS: adapter loaded"
'

# Test detection against real GSD2 directory
bash -c '
  cd /path/to/orchestrator
  source scripts/migrate/adapter-interface.sh
  source scripts/migrate/adapters/gsd2.sh
  result=$(detect_source "/Users/brettkellgren/Sites/lakeledger/.gsd")
  [[ "$result" = "yes" ]] && echo "PASS: detects GSD2"
'

# Test full extraction pipeline
bash -c '
  cd /path/to/orchestrator
  source scripts/migrate/adapter-interface.sh
  source scripts/migrate/adapters/gsd2.sh
  tmpdir=$(mktemp -d)
  extract_knowledge "/Users/brettkellgren/Sites/lakeledger/.gsd" "$tmpdir"
  extract_decisions "/Users/brettkellgren/Sites/lakeledger/.gsd" "$tmpdir"
  extract_requirements "/Users/brettkellgren/Sites/lakeledger/.gsd" "$tmpdir"
  extract_milestones "/Users/brettkellgren/Sites/lakeledger/.gsd" "$tmpdir"
  extract_telemetry "/Users/brettkellgren/Sites/lakeledger/.gsd" "$tmpdir"
  ls -la "$tmpdir"/*.dat
  echo "Knowledge records: $(( $(wc -l < "$tmpdir/knowledge.dat") - 1 ))"
  echo "Decision records: $(( $(wc -l < "$tmpdir/decisions.dat") - 1 ))"
  rm -rf "$tmpdir"
'
```

## Must-Haves

This task addresses these phase must-haves:

**Truths:**
- The GSD2 adapter prefers SQLite (`gsd.db`) and falls back to JSON (`memories-snapshot.json`) when the database is unavailable
- Source directories are never modified (read-only access enforced)
- All scripts use `#!/usr/bin/env bash` shebang and `set -euo pipefail` for safety
- Bash 3.2 compatibility

**Artifacts:**
- `scripts/migrate/adapters/gsd2.sh` (min 120 lines, contains "sqlite3")

**Key Links:**
- `scripts/migrate/adapters/gsd2.sh` -> `scripts/migrate/adapter-interface.sh` (adapter sources the interface)
- `scripts/migrate/adapters/gsd2.sh` -> `scripts/migrate/lib/sqlite-reader.sh` (adapter uses SQLite reader)
- `scripts/migrate/adapters/gsd2.sh` -> `scripts/migrate/lib/json-fallback.sh` (adapter uses JSON fallback)

## Verification

```bash
# File exists and meets size requirement
test -f scripts/migrate/adapters/gsd2.sh
test "$(wc -l < scripts/migrate/adapters/gsd2.sh)" -ge 120

# Contains required references
grep -q "sqlite3" scripts/migrate/adapters/gsd2.sh
grep -q "gsd\.db\|gsd_db" scripts/migrate/adapters/gsd2.sh
grep -q "memories-snapshot\.json\|json-fallback\|json_fallback" scripts/migrate/adapters/gsd2.sh
grep -q "fallback" scripts/migrate/adapters/gsd2.sh

# References upstream scripts
grep -q "adapter-interface\|adapter_interface" scripts/migrate/adapters/gsd2.sh
grep -q "sqlite-reader\|sqlite_reader" scripts/migrate/adapters/gsd2.sh
grep -q "json-fallback\|json_fallback" scripts/migrate/adapters/gsd2.sh

# Bash 3.2 compliance
! grep -n 'declare -A\||&\|${[a-zA-Z_]*,,}' scripts/migrate/adapters/gsd2.sh

# Sources and validates cleanly
bash -c 'source scripts/migrate/adapter-interface.sh && source scripts/migrate/adapters/gsd2.sh && echo "PASS"'
```

## Inputs

### From Previous Tasks

- `scripts/migrate/adapter-interface.sh` (from T01)
  - Key API: `escape_field(value)`, `write_header(file, ...)`, `append_record(file, ...)`, `validate_adapter()`, `emit_warning(output_dir, category, message, [raw_data])`, `init_output_dir(dir)`
  - Key types: TSV format, field constants (`KNOWLEDGE_FIELDS`, `DECISIONS_FIELDS`, etc.)
  - Behavioral contract: `validate_adapter()` checks that all 6 required functions (`detect_source`, `extract_knowledge`, `extract_decisions`, `extract_requirements`, `extract_milestones`, `extract_telemetry`) are defined. Fails with error if any are missing.

- `scripts/migrate/lib/sqlite-reader.sh` (from T02)
  - Key API: `check_sqlite3()` -- returns 0 if sqlite3 CLI is available; `is_valid_sqlite(db_path)` -- returns 0 if file is a readable SQLite database; `sqlite_read_knowledge(db_path, output_dir)`, `sqlite_read_decisions(db_path, output_dir)`, `sqlite_read_requirements(db_path, output_dir)`, `sqlite_read_milestones(db_path, output_dir)`, `sqlite_read_slices(db_path, output_dir)`, `sqlite_read_tasks(db_path, output_dir)`, `sqlite_read_telemetry(db_path, output_dir)` -- each writes a TSV `.dat` file to output_dir
  - Behavioral contract: All functions assume `adapter-interface.sh` has been sourced. Output files use exact TSV schema with headers matching the `*_FIELDS` constants.

- `scripts/migrate/lib/json-fallback.sh` (from T03)
  - Key API: `has_json_fallback(source_path)` -- returns 0 if `memories-snapshot.json` exists; `json_read_knowledge(source_path, output_dir)`, `json_read_decisions(source_path, output_dir)`, `json_read_requirements(source_path, output_dir)`, `json_read_milestones(source_path, output_dir)`, `json_read_slices(source_path, output_dir)`, `json_read_tasks(source_path, output_dir)`, `json_read_telemetry(source_path, output_dir)` -- each writes a TSV `.dat` file; `scan_milestone_dirs(source_path, output_dir)` -- supplements milestone data from filesystem
  - Behavioral contract: Same TSV output schema as SQLite reader. Detects jq availability automatically. Works without jq.

### From Disk (Pre-existing)

- `.gsd/gsd.db` (target project's GSD2 SQLite database) -- the primary data source
- `.gsd/memories-snapshot.json` (target project's JSON snapshot) -- fallback for knowledge entries
- `.gsd/state-manifest.json` (target project's state manifest) -- fallback for decisions, requirements, milestones
- `.gsd/milestones/M###/` (target project's milestone directories) -- fallback for filesystem scanning

## Expected Output

A single file `scripts/migrate/adapters/gsd2.sh` that:
1. Sources `sqlite-reader.sh` and `json-fallback.sh` from its relative `../lib/` path
2. Implements all 6 adapter interface functions: `detect_source`, `extract_knowledge`, `extract_decisions`, `extract_requirements`, `extract_milestones`, `extract_telemetry`
3. Uses SQLite reader when `gsd.db` is available and valid, JSON fallback otherwise
4. Emits structured warnings on fallback or missing data
5. Writes empty (header-only) data files when no data source is available
6. Passes `validate_adapter()` check
7. Is executable and sources cleanly
