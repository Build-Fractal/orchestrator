---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M003"
name: "Adapter Interface Contract & Intermediate Data Format"
depends_on: []
---

## Description

Define the adapter interface that all source adapters (gsd2, gsd1, speckit) must implement, and specify the intermediate data format that adapters produce and transformers consume. This is the foundational contract that gates all other migration work.

The adapter interface is a Bash script that:
1. Documents the contract (what functions each adapter must implement)
2. Defines the intermediate data format (section-delimited text output)
3. Provides shared utility functions for adapter implementations
4. Enforces the read-only constraint on source directories

## Steps

### Step 1: Create the directory structure

```bash
mkdir -p scripts/migrate/adapters
mkdir -p scripts/migrate/lib
mkdir -p scripts/migrate/transform
```

### Step 2: Create `scripts/migrate/adapter-interface.sh`

This file serves as both documentation and shared code. It defines:

**Adapter Contract** — Each adapter script must implement these functions:

```bash
# detect_source <path>
#   Returns: "yes" or "no" to stdout
#   Purpose: Determine if the given path contains this adapter's source format
#   Example: GSD2 adapter checks for .gsd/gsd.db or .gsd/memories-snapshot.json

# extract_knowledge <source_path> <output_dir>
#   Writes: <output_dir>/knowledge.dat
#   Format: One record per entry, fields tab-separated, sections newline-delimited
#   Fields: id, category, content, confidence, hit_count, source_unit_id,
#           created_at, updated_at, superseded_by

# extract_decisions <source_path> <output_dir>
#   Writes: <output_dir>/decisions.dat
#   Fields: seq, id, when_context, scope, decision, choice, rationale,
#           revisable, made_by, superseded_by

# extract_requirements <source_path> <output_dir>
#   Writes: <output_dir>/requirements.dat
#   Fields: id, class, status, description, validation_status, validated_by,
#           superseded_by

# extract_milestones <source_path> <output_dir>
#   Writes: <output_dir>/milestones.dat (milestone metadata)
#   Writes: <output_dir>/slices.dat (slice/phase data)
#   Writes: <output_dir>/tasks.dat (task data)
#   Milestone fields: id, title, status, vision, created_at, completed_at
#   Slice fields: milestone_id, id, title, status, goal, demo
#   Task fields: milestone_id, slice_id, id, title, status, description

# extract_telemetry <source_path> <output_dir>
#   Writes: <output_dir>/telemetry.dat
#   Fields: milestone_id, slice_id, task_id, command, exit_code, verdict,
#           duration_ms, created_at
```

**Intermediate Data Format** — The format uses:
- Tab-separated values (TSV) for structured data (parseable with `awk -F'\t'`)
- One record per line
- Header line as first line of each `.dat` file (field names, tab-separated)
- Newlines within field values escaped as `\\n` (literal backslash-n)
- Tab characters within field values escaped as `\\t` (literal backslash-t)
- Empty fields represented as empty string (two adjacent tabs)

**Shared Utility Functions** to include in the script:

```bash
#!/usr/bin/env bash
# scripts/migrate/adapter-interface.sh — Adapter interface contract
# Defines the common interface that all source adapters must implement.
#
# ADAPTER CONTRACT
# ================
# Each adapter is a standalone script in scripts/migrate/adapters/ that
# sources this file and implements the following functions:
#
#   detect_source <path>        — echo "yes" or "no"
#   extract_knowledge <src> <out>  — write <out>/knowledge.dat
#   extract_decisions <src> <out>  — write <out>/decisions.dat
#   extract_requirements <src> <out> — write <out>/requirements.dat
#   extract_milestones <src> <out>  — write <out>/milestones.dat,
#                                      <out>/slices.dat, <out>/tasks.dat
#   extract_telemetry <src> <out>  — write <out>/telemetry.dat
#
# READ-ONLY CONSTRAINT
# ====================
# Adapters MUST NOT modify or write to the source directory. All output
# goes to the <output_dir> (a temporary directory created by the CLI).
# This is a non-negotiable safety guarantee (AD-10, NFR-201).
#
# INTERMEDIATE DATA FORMAT
# ========================
# All .dat files use tab-separated values (TSV):
#   - First line is a header with field names
#   - One record per line
#   - Newlines in values escaped as literal \n
#   - Tabs in values escaped as literal \t
#   - Empty fields are empty strings (adjacent tabs)
#
# Downstream transformers (P02-P04) parse these files with:
#   awk -F'\t' '{...}' file.dat
#   while IFS=$'\t' read -r field1 field2 ...; do ... done < file.dat
#
# SECTION MARKERS (for adapter-interface validation)
# ===================================================
# SECTION_KNOWLEDGE  — knowledge.dat
# SECTION_DECISIONS  — decisions.dat
# SECTION_REQUIREMENTS — requirements.dat
# SECTION_MILESTONES — milestones.dat + slices.dat + tasks.dat
# SECTION_TELEMETRY  — telemetry.dat

set -euo pipefail

ADAPTER_INTERFACE_VERSION="1.0"

# --- Shared utility: escape field value for TSV ---
# Escapes newlines and tabs within a field value so it fits on one TSV line.
# Usage: escaped=$(escape_field "$raw_value")
escape_field() {
  local val="$1"
  # Replace literal backslashes first (to avoid double-escaping)
  val="${val//\\/\\\\}"
  # Replace tabs with literal \t
  val="$(printf '%s' "$val" | tr '\t' '\007' | sed 's/\x07/\\t/g')"
  # Replace newlines with literal \n
  val="$(printf '%s' "$val" | tr '\n' '\007' | sed 's/\x07/\\n/g')"
  printf '%s' "$val"
}

# --- Shared utility: unescape field value from TSV ---
# Reverses the escaping done by escape_field.
# Usage: raw=$(unescape_field "$escaped_value")
unescape_field() {
  local val="$1"
  # Replace literal \n with newlines
  val="$(printf '%s' "$val" | sed 's/\\n/\
/g')"
  # Replace literal \t with tabs
  val="$(printf '%s' "$val" | sed 's/\\t/\t/g')"
  # Replace literal \\ with backslash
  val="${val//\\\\/\\}"
  printf '%s' "$val"
}

# --- Shared utility: write TSV header ---
# Usage: write_header <output_file> field1 field2 field3 ...
write_header() {
  local output_file="$1"
  shift
  local IFS=$'\t'
  echo "$*" > "$output_file"
}

# --- Shared utility: append TSV record ---
# Usage: append_record <output_file> value1 value2 value3 ...
# Values should already be escaped via escape_field if they may contain
# tabs or newlines.
append_record() {
  local output_file="$1"
  shift
  local IFS=$'\t'
  echo "$*" >> "$output_file"
}

# --- Shared utility: validate adapter implements all required functions ---
# Usage: validate_adapter (call after sourcing an adapter script)
validate_adapter() {
  local missing=""
  for fn in detect_source extract_knowledge extract_decisions \
            extract_requirements extract_milestones extract_telemetry; do
    if ! type "$fn" >/dev/null 2>&1; then
      missing="$missing $fn"
    fi
  done
  if [[ -n "$missing" ]]; then
    echo "ERROR: Adapter missing required functions:$missing" >&2
    return 1
  fi
  return 0
}

# --- Shared utility: create output directory structure ---
# Usage: init_output_dir <output_dir>
init_output_dir() {
  local output_dir="$1"
  mkdir -p "$output_dir"
}

# --- Shared utility: emit a structured warning record ---
# Warnings are appended to <output_dir>/warnings.dat in TSV format.
# Downstream report generation (P06) aggregates these.
# Usage: emit_warning <output_dir> <category> <message> [<raw_data>]
#   category: one of skip, malformed, fallback, inference, missing_ref
emit_warning() {
  local output_dir="$1"
  local category="$2"
  local message="$3"
  local raw_data="${4:-}"
  local warnings_file="$output_dir/warnings.dat"
  if [[ ! -f "$warnings_file" ]]; then
    write_header "$warnings_file" "timestamp" "category" "message" "raw_data"
  fi
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
  append_record "$warnings_file" "$ts" "$category" "$(escape_field "$message")" "$(escape_field "$raw_data")"
}

# --- Data format field definitions (for reference and validation) ---

KNOWLEDGE_FIELDS="id	category	content	confidence	hit_count	source_unit_id	created_at	updated_at	superseded_by"
DECISIONS_FIELDS="seq	id	when_context	scope	decision	choice	rationale	revisable	made_by	superseded_by"
REQUIREMENTS_FIELDS="id	class	status	description	validation_status	validated_by	superseded_by"
MILESTONES_FIELDS="id	title	status	vision	created_at	completed_at"
SLICES_FIELDS="milestone_id	id	title	status	goal	demo"
TASKS_FIELDS="milestone_id	slice_id	id	title	status	description"
TELEMETRY_FIELDS="milestone_id	slice_id	task_id	command	exit_code	verdict	duration_ms	created_at"
```

The complete file should be created exactly as specified above (with the shebang, comment block, `set -euo pipefail`, and all functions).

### Step 3: Make the script executable

```bash
chmod +x scripts/migrate/adapter-interface.sh
```

### Step 4: Verify

```bash
# Verify the file exists and has required content
test -f scripts/migrate/adapter-interface.sh && echo "PASS: file exists"
wc -l < scripts/migrate/adapter-interface.sh  # should be >= 80
grep -q "extract_knowledge" scripts/migrate/adapter-interface.sh && echo "PASS: extract_knowledge"
grep -q "extract_decisions" scripts/migrate/adapter-interface.sh && echo "PASS: extract_decisions"
grep -q "extract_requirements" scripts/migrate/adapter-interface.sh && echo "PASS: extract_requirements"
grep -q "extract_milestones" scripts/migrate/adapter-interface.sh && echo "PASS: extract_milestones"
grep -q "extract_telemetry" scripts/migrate/adapter-interface.sh && echo "PASS: extract_telemetry"
grep -qi "read.only\|never.*modif\|non.destructive" scripts/migrate/adapter-interface.sh && echo "PASS: read-only constraint"
grep -q "SECTION_KNOWLEDGE" scripts/migrate/adapter-interface.sh && echo "PASS: section markers"

# Verify Bash 3.2 compliance
! grep -n 'declare -A\||&\|${[a-zA-Z_]*,,}' scripts/migrate/adapter-interface.sh && echo "PASS: Bash 3.2 compatible"

# Source and test utility functions
bash -c 'source scripts/migrate/adapter-interface.sh && echo "PASS: sources cleanly"'
```

## Must-Haves

This task addresses these phase must-haves:

**Truths:**
- The adapter interface defines a standard contract with detect, extract_knowledge, extract_decisions, extract_requirements, extract_milestones, and extract_telemetry functions
- The intermediate data format uses section markers that downstream transformers can parse with grep/sed
- Source directories are never modified (read-only access enforced in adapter interface documentation)
- Bash 3.2 compatibility: no associative arrays, no `|&` pipe operator, no `${var,,}` case conversion
- All scripts use `#!/usr/bin/env bash` shebang and `set -euo pipefail` for safety

**Artifacts:**
- `scripts/migrate/adapter-interface.sh` (min 80 lines, contains "extract_knowledge")

## Verification

```bash
# All of these should return exit 0:
test -f scripts/migrate/adapter-interface.sh
test "$(wc -l < scripts/migrate/adapter-interface.sh)" -ge 80
grep -q "extract_knowledge" scripts/migrate/adapter-interface.sh
grep -qi "read.only\|never.*modif\|non.destructive" scripts/migrate/adapter-interface.sh
grep -qE 'SECTION_KNOWLEDGE|SECTION_DECISIONS' scripts/migrate/adapter-interface.sh
bash -c 'source scripts/migrate/adapter-interface.sh'
! grep -n 'declare -A\||&' scripts/migrate/adapter-interface.sh
```

## Inputs

### From Previous Tasks

None -- this is the first task in the phase.

### From Disk (Pre-existing)

- `scripts/state/derive-phase.sh` -- reference for script conventions (shebang, `set -euo pipefail`, comment style, argument validation patterns)
- `specs/003-migration-tool/spec.md` -- FR-200 (pluggable adapter architecture), FR-201 (GSD2 adapter with SQLite preferred, JSON fallback), NFR-201 (non-destructive), NFR-203 (Bash 3.2)
- `.specify/orchestrator/milestones/M003/M003-CONTEXT.md` -- AD-1 (pluggable adapter architecture), AD-9 (Bash 3.2 constraints), AD-10 (non-destructive migration), AD-12 (constitution alignment)

## Expected Output

A single file `scripts/migrate/adapter-interface.sh` that:
1. Documents the full adapter contract (6 functions each adapter must implement)
2. Defines the intermediate data format (TSV with header lines, escaping rules)
3. Provides shared utility functions: `escape_field`, `unescape_field`, `write_header`, `append_record`, `validate_adapter`, `init_output_dir`, `emit_warning`
4. Defines field name constants for each data section
5. Is executable and sources cleanly in Bash 3.2

Plus the empty directory structure: `scripts/migrate/adapters/`, `scripts/migrate/lib/`, `scripts/migrate/transform/`.
