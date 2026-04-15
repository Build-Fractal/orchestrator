---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M003"
name: "SQLite Reader Library"
depends_on: ["T01"]
---

## Description

Build the SQLite query helper library that the GSD2 adapter uses to read from `gsd.db` tables. This library wraps `sqlite3` CLI calls into reusable functions that extract data from each GSD2 database table and write it to the intermediate TSV format defined by the adapter interface.

The library must:
1. Use `sqlite3` CLI only (ships with macOS) -- no python3
2. Handle database availability detection (file exists + is valid SQLite)
3. Query each relevant table: memories, decisions, requirements, milestones, slices, tasks, verification_evidence
4. Output TSV data using the escape/write utilities from `adapter-interface.sh`
5. Maintain Bash 3.2 compatibility

## Steps

### Step 1: Create `scripts/migrate/lib/sqlite-reader.sh`

```bash
#!/usr/bin/env bash
# scripts/migrate/lib/sqlite-reader.sh — SQLite query helpers for GSD2 adapter
# Uses sqlite3 CLI (ships with macOS) to read from gsd.db tables.
# All functions write TSV data to output files using adapter-interface utilities.
#
# Usage: Source this file after sourcing adapter-interface.sh
#   source scripts/migrate/adapter-interface.sh
#   source scripts/migrate/lib/sqlite-reader.sh
#
# Prerequisites: sqlite3 must be available on PATH

set -euo pipefail

# --- Check sqlite3 availability ---
check_sqlite3() {
  if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "ERROR: sqlite3 not found on PATH" >&2
    return 1
  fi
  return 0
}

# --- Check if a file is a valid SQLite database ---
# Usage: is_valid_sqlite <db_path>
# Returns: 0 if valid, 1 if not
is_valid_sqlite() {
  local db_path="$1"
  if [[ ! -f "$db_path" ]]; then
    return 1
  fi
  # Check SQLite magic bytes (first 16 bytes contain "SQLite format 3")
  if ! head -c 16 "$db_path" 2>/dev/null | grep -q "SQLite format 3"; then
    return 1
  fi
  # Verify we can run a basic query
  if ! sqlite3 "$db_path" "SELECT 1;" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

# --- Read knowledge entries from memories table ---
# Usage: sqlite_read_knowledge <db_path> <output_dir>
# Writes: <output_dir>/knowledge.dat
sqlite_read_knowledge() {
  local db_path="$1"
  local output_dir="$2"
  local output_file="$output_dir/knowledge.dat"

  write_header "$output_file" "id" "category" "content" "confidence" \
    "hit_count" "source_unit_id" "created_at" "updated_at" "superseded_by"

  # Use -separator with a control character, then process with awk
  # to handle content that may contain tabs
  # sqlite3 -separator outputs fields separated by the chosen char
  # We use ASCII 0x1F (unit separator) as field delimiter from sqlite3
  local sep=$'\x1f'

  sqlite3 -separator "$sep" "$db_path" \
    "SELECT id, category, content, confidence, hit_count,
            COALESCE(source_unit_id, ''), created_at, updated_at,
            COALESCE(superseded_by, '')
     FROM memories
     ORDER BY seq;" 2>/dev/null | while IFS="$sep" read -r f_id f_cat f_content f_conf f_hits f_src f_created f_updated f_superseded; do
    # Escape each field for TSV
    local e_content
    e_content="$(escape_field "$f_content")"
    append_record "$output_file" \
      "$f_id" "$f_cat" "$e_content" "$f_conf" "$f_hits" \
      "$f_src" "$f_created" "$f_updated" "$f_superseded"
  done
}

# --- Read decisions from decisions table ---
# Usage: sqlite_read_decisions <db_path> <output_dir>
# Writes: <output_dir>/decisions.dat
sqlite_read_decisions() {
  local db_path="$1"
  local output_dir="$2"
  local output_file="$output_dir/decisions.dat"

  write_header "$output_file" "seq" "id" "when_context" "scope" "decision" \
    "choice" "rationale" "revisable" "made_by" "superseded_by"

  local sep=$'\x1f'

  sqlite3 -separator "$sep" "$db_path" \
    "SELECT seq, id, when_context, scope, decision, choice, rationale,
            revisable, made_by, COALESCE(superseded_by, '')
     FROM decisions
     ORDER BY seq;" 2>/dev/null | while IFS="$sep" read -r f_seq f_id f_when f_scope f_decision f_choice f_rationale f_revisable f_made f_superseded; do
    local e_decision e_choice e_rationale
    e_decision="$(escape_field "$f_decision")"
    e_choice="$(escape_field "$f_choice")"
    e_rationale="$(escape_field "$f_rationale")"
    append_record "$output_file" \
      "$f_seq" "$f_id" "$f_when" "$f_scope" "$e_decision" \
      "$e_choice" "$e_rationale" "$f_revisable" "$f_made" "$f_superseded"
  done
}

# --- Read requirements from requirements table ---
# Usage: sqlite_read_requirements <db_path> <output_dir>
# Writes: <output_dir>/requirements.dat
sqlite_read_requirements() {
  local db_path="$1"
  local output_dir="$2"
  local output_file="$output_dir/requirements.dat"

  write_header "$output_file" "id" "class" "status" "description" \
    "validation_status" "validated_by" "superseded_by"

  local sep=$'\x1f'

  sqlite3 -separator "$sep" "$db_path" \
    "SELECT id, class, status, description, validation,
            COALESCE(supporting_slices, ''), COALESCE(superseded_by, '')
     FROM requirements
     ORDER BY id;" 2>/dev/null | while IFS="$sep" read -r f_id f_class f_status f_desc f_validation f_validated_by f_superseded; do
    local e_desc
    e_desc="$(escape_field "$f_desc")"
    append_record "$output_file" \
      "$f_id" "$f_class" "$f_status" "$e_desc" \
      "$f_validation" "$f_validated_by" "$f_superseded"
  done
}

# --- Read milestones from milestones table ---
# Usage: sqlite_read_milestones <db_path> <output_dir>
# Writes: <output_dir>/milestones.dat
sqlite_read_milestones() {
  local db_path="$1"
  local output_dir="$2"
  local output_file="$output_dir/milestones.dat"

  write_header "$output_file" "id" "title" "status" "vision" \
    "created_at" "completed_at"

  local sep=$'\x1f'

  sqlite3 -separator "$sep" "$db_path" \
    "SELECT id, title, status, vision, created_at,
            COALESCE(completed_at, '')
     FROM milestones
     ORDER BY id;" 2>/dev/null | while IFS="$sep" read -r f_id f_title f_status f_vision f_created f_completed; do
    local e_title e_vision
    e_title="$(escape_field "$f_title")"
    e_vision="$(escape_field "$f_vision")"
    append_record "$output_file" \
      "$f_id" "$e_title" "$f_status" "$e_vision" "$f_created" "$f_completed"
  done
}

# --- Read slices from slices table ---
# Usage: sqlite_read_slices <db_path> <output_dir>
# Writes: <output_dir>/slices.dat
sqlite_read_slices() {
  local db_path="$1"
  local output_dir="$2"
  local output_file="$output_dir/slices.dat"

  write_header "$output_file" "milestone_id" "id" "title" "status" "goal" "demo"

  local sep=$'\x1f'

  sqlite3 -separator "$sep" "$db_path" \
    "SELECT milestone_id, id, title, status, goal, demo
     FROM slices
     ORDER BY milestone_id, id;" 2>/dev/null | while IFS="$sep" read -r f_mid f_id f_title f_status f_goal f_demo; do
    local e_title e_goal e_demo
    e_title="$(escape_field "$f_title")"
    e_goal="$(escape_field "$f_goal")"
    e_demo="$(escape_field "$f_demo")"
    append_record "$output_file" \
      "$f_mid" "$f_id" "$e_title" "$f_status" "$e_goal" "$e_demo"
  done
}

# --- Read tasks from tasks table ---
# Usage: sqlite_read_tasks <db_path> <output_dir>
# Writes: <output_dir>/tasks.dat
sqlite_read_tasks() {
  local db_path="$1"
  local output_dir="$2"
  local output_file="$output_dir/tasks.dat"

  write_header "$output_file" "milestone_id" "slice_id" "id" "title" \
    "status" "description"

  local sep=$'\x1f'

  sqlite3 -separator "$sep" "$db_path" \
    "SELECT milestone_id, slice_id, id, title, status, description
     FROM tasks
     ORDER BY milestone_id, slice_id, id;" 2>/dev/null | while IFS="$sep" read -r f_mid f_sid f_id f_title f_status f_desc; do
    local e_title e_desc
    e_title="$(escape_field "$f_title")"
    e_desc="$(escape_field "$f_desc")"
    append_record "$output_file" \
      "$f_mid" "$f_sid" "$f_id" "$e_title" "$f_status" "$e_desc"
  done
}

# --- Read telemetry from verification_evidence table ---
# Usage: sqlite_read_telemetry <db_path> <output_dir>
# Writes: <output_dir>/telemetry.dat
sqlite_read_telemetry() {
  local db_path="$1"
  local output_dir="$2"
  local output_file="$output_dir/telemetry.dat"

  write_header "$output_file" "milestone_id" "slice_id" "task_id" \
    "command" "exit_code" "verdict" "duration_ms" "created_at"

  local sep=$'\x1f'

  sqlite3 -separator "$sep" "$db_path" \
    "SELECT milestone_id, slice_id, task_id, command, exit_code,
            verdict, duration_ms, created_at
     FROM verification_evidence
     ORDER BY id;" 2>/dev/null | while IFS="$sep" read -r f_mid f_sid f_tid f_cmd f_exit f_verdict f_dur f_created; do
    local e_cmd
    e_cmd="$(escape_field "$f_cmd")"
    append_record "$output_file" \
      "$f_mid" "$f_sid" "$f_tid" "$e_cmd" "$f_exit" \
      "$f_verdict" "$f_dur" "$f_created"
  done
}
```

### Step 2: Make executable

```bash
chmod +x scripts/migrate/lib/sqlite-reader.sh
```

### Step 3: Verify against the real GSD2 database

```bash
# Test with the lakeledger gsd.db
cd /path/to/spec-kit-orchestrator
source scripts/migrate/adapter-interface.sh
source scripts/migrate/lib/sqlite-reader.sh

# Check sqlite3 availability
check_sqlite3 && echo "PASS: sqlite3 available"

# Validate against lakeledger's gsd.db
GSD_DB="/Users/brettkellgren/Sites/lakeledger/.gsd/gsd.db"
is_valid_sqlite "$GSD_DB" && echo "PASS: valid SQLite db"

# Test knowledge extraction
TMPDIR=$(mktemp -d)
sqlite_read_knowledge "$GSD_DB" "$TMPDIR"
head -2 "$TMPDIR/knowledge.dat"  # should show header + first record
wc -l < "$TMPDIR/knowledge.dat"  # should be 153 (152 entries + 1 header)
rm -rf "$TMPDIR"
```

## Must-Haves

This task addresses these phase must-haves:

**Truths:**
- The SQLite reader uses the `sqlite3` CLI only (no python3 or other database tools)
- All scripts use `#!/usr/bin/env bash` shebang and `set -euo pipefail` for safety
- Bash 3.2 compatibility: no associative arrays, no `|&` pipe operator, no `${var,,}` case conversion

**Artifacts:**
- `scripts/migrate/lib/sqlite-reader.sh` (min 60 lines, contains "sqlite3")

**Key Links:**
- `scripts/migrate/adapters/gsd2.sh` -> `scripts/migrate/lib/sqlite-reader.sh` (adapter uses SQLite reader)

## Verification

```bash
# File exists and meets size requirement
test -f scripts/migrate/lib/sqlite-reader.sh
test "$(wc -l < scripts/migrate/lib/sqlite-reader.sh)" -ge 60

# Contains sqlite3 references
grep -q "sqlite3" scripts/migrate/lib/sqlite-reader.sh

# No python3 dependency
! grep -q "python3\|python " scripts/migrate/lib/sqlite-reader.sh

# Bash 3.2 compliance
! grep -n 'declare -A\||&\|${[a-zA-Z_]*,,}' scripts/migrate/lib/sqlite-reader.sh

# Sources cleanly
bash -c 'source scripts/migrate/adapter-interface.sh && source scripts/migrate/lib/sqlite-reader.sh && echo "PASS"'

# Functions are defined
bash -c 'source scripts/migrate/adapter-interface.sh && source scripts/migrate/lib/sqlite-reader.sh && type sqlite_read_knowledge >/dev/null && type sqlite_read_decisions >/dev/null && type sqlite_read_requirements >/dev/null && type sqlite_read_milestones >/dev/null && type sqlite_read_telemetry >/dev/null && echo "PASS: all functions defined"'
```

## Inputs

### From Previous Tasks

- `scripts/migrate/adapter-interface.sh` (from T01)
  - Key API: `escape_field(value)` -- escapes newlines/tabs in field values for TSV output; `write_header(output_file, field1, field2, ...)` -- writes TSV header line; `append_record(output_file, val1, val2, ...)` -- appends one TSV data line; `emit_warning(output_dir, category, message, [raw_data])` -- logs a structured warning
  - Key types: TSV format with tab-separated fields, one record per line, header as first line
  - Behavioral contract: All field values containing tabs or newlines must be escaped via `escape_field` before passing to `append_record`. The `write_header` function creates/overwrites the output file; `append_record` appends.

### From Disk (Pre-existing)

- `gsd.db` (GSD2 SQLite database in source project's `.gsd/` directory) -- tables: `memories` (id, category, content, confidence, hit_count, source_unit_id, created_at, updated_at, superseded_by), `decisions` (seq, id, when_context, scope, decision, choice, rationale, revisable, made_by, superseded_by), `requirements` (id, class, status, description, validation, supporting_slices, superseded_by), `milestones` (id, title, status, vision, created_at, completed_at), `slices` (milestone_id, id, title, status, goal, demo), `tasks` (milestone_id, slice_id, id, title, status, description), `verification_evidence` (milestone_id, slice_id, task_id, command, exit_code, verdict, duration_ms, created_at)

## Expected Output

A single file `scripts/migrate/lib/sqlite-reader.sh` that:
1. Provides `check_sqlite3()` to verify sqlite3 CLI is available
2. Provides `is_valid_sqlite(db_path)` to validate a file is a readable SQLite database
3. Provides 7 reader functions: `sqlite_read_knowledge`, `sqlite_read_decisions`, `sqlite_read_requirements`, `sqlite_read_milestones`, `sqlite_read_slices`, `sqlite_read_tasks`, `sqlite_read_telemetry`
4. Each reader writes a properly-formatted TSV file to the output directory
5. Uses ASCII unit separator (0x1F) as the sqlite3 field delimiter to avoid conflicts with tab/comma in data
6. Is executable and sources cleanly after `adapter-interface.sh`
