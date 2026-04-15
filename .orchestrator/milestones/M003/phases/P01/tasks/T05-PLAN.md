---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P01"
milestone: "M003"
name: "Source Detection & CLI Entry Point"
depends_on: ["T01", "T04"]
---

## Description

Build two scripts:
1. `scripts/migrate/lib/detect-source.sh` -- auto-detects the source format (gsd2, gsd1, speckit) from directory contents
2. `scripts/migrate/migrate.sh` -- the CLI entry point that parses flags, orchestrates source detection, selects the correct adapter, runs extraction, and (in later phases) invokes transformers

This task delivers the user-facing migration command infrastructure. The CLI entry point is intentionally designed as a pipeline orchestrator: P01 delivers the skeleton with source detection and adapter invocation; later phases (P02-P06) add transformer invocations, report generation, and idempotency enforcement.

## Steps

### Step 1: Create `scripts/migrate/lib/detect-source.sh`

```bash
#!/usr/bin/env bash
# scripts/migrate/lib/detect-source.sh — Auto-detect source format
# Inspects a directory to determine which migration adapter to use.
#
# Detection logic:
#   1. If .gsd/gsd.db exists (valid SQLite) → gsd2
#   2. If .gsd/ exists (without gsd.db) → gsd2 (JSON fallback mode)
#   3. If .planning/ exists → gsd1
#   4. If .specify/ or specs/ exists → speckit
#   5. Otherwise → unknown
#
# When both .gsd/ and .planning/ exist, prefers .gsd/ (gsd2).
# This matches the edge case spec: "prefer GSD2 and ignore .planning/"
#
# Usage:
#   source scripts/migrate/lib/detect-source.sh
#   result=$(detect_source_type "/path/to/project")
#   echo "$result"  # "gsd2", "gsd1", "speckit", or "unknown"

set -euo pipefail

# --- detect_source_type ---
# Determines the source format from directory contents.
# Args: <project_path> — the root directory to inspect
# Output: echoes one of: gsd2, gsd1, speckit, unknown
detect_source_type() {
  local project_path="$1"

  # Priority 1: GSD2 — .gsd/ directory with gsd.db or JSON files
  if [[ -d "$project_path/.gsd" ]]; then
    if [[ -f "$project_path/.gsd/gsd.db" ]] || \
       [[ -f "$project_path/.gsd/memories-snapshot.json" ]]; then
      echo "gsd2"
      return 0
    fi
  fi

  # Also handle case where path IS the .gsd directory
  if [[ -f "$project_path/gsd.db" ]] || \
     [[ -f "$project_path/memories-snapshot.json" ]]; then
    echo "gsd2"
    return 0
  fi

  # Priority 2: GSD v1 — .planning/ directory
  if [[ -d "$project_path/.planning" ]]; then
    echo "gsd1"
    return 0
  fi

  # Priority 3: Standard spec-kit — .specify/ or specs/ directory
  if [[ -d "$project_path/.specify" ]] || [[ -d "$project_path/specs" ]]; then
    echo "speckit"
    return 0
  fi

  # Unknown source format
  echo "unknown"
  return 0
}

# --- resolve_source_path ---
# Normalizes the source path for adapter consumption.
# If --path points to a .gsd/ directory, returns it directly.
# If --path points to a project root, returns the appropriate subdirectory.
# Args: <path> <source_type>
# Output: echoes the normalized source path
resolve_source_path() {
  local path="$1"
  local source_type="$2"

  case "$source_type" in
    gsd2)
      if [[ -d "$path/.gsd" ]]; then
        echo "$path/.gsd"
      else
        echo "$path"
      fi
      ;;
    gsd1)
      if [[ -d "$path/.planning" ]]; then
        echo "$path/.planning"
      else
        echo "$path"
      fi
      ;;
    speckit)
      echo "$path"
      ;;
    *)
      echo "$path"
      ;;
  esac
}
```

### Step 2: Create `scripts/migrate/migrate.sh`

```bash
#!/usr/bin/env bash
# scripts/migrate/migrate.sh — Migration CLI entry point
# Orchestrates the migration pipeline: detect source → select adapter →
# extract data → (future: transform → report).
#
# Usage:
#   bash scripts/migrate/migrate.sh --path /path/to/project [options]
#
# Options:
#   --source <gsd2|gsd1|speckit>  Source format (auto-detected if omitted)
#   --path <path>                  Path to source project (required)
#   --recent-count <N>             Number of recent milestones to preserve
#                                  at summary level (default: 3)
#   --merge                        Merge with existing orchestrator state
#   --force                        Overwrite existing orchestrator state
#   --abort                        Cancel if orchestrator state exists (default)
#   --output <path>                Output directory (default: .specify/orchestrator)
#   --help                         Show usage
#
# Exit codes:
#   0 — migration completed successfully
#   1 — usage error or missing arguments
#   2 — source detection failed
#   3 — adapter error during extraction
#   4 — existing state conflict (--abort mode)

set -euo pipefail

MIGRATE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies
source "$MIGRATE_SCRIPT_DIR/adapter-interface.sh"
source "$MIGRATE_SCRIPT_DIR/lib/detect-source.sh"

# --- Default configuration ---
SOURCE_TYPE=""
SOURCE_PATH=""
RECENT_COUNT=3
CONFLICT_MODE="abort"  # abort | merge | force
OUTPUT_DIR=""
SHOW_HELP=false

# --- Parse arguments ---
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source)
        SOURCE_TYPE="$2"
        shift 2
        ;;
      --path)
        SOURCE_PATH="$2"
        shift 2
        ;;
      --recent-count)
        RECENT_COUNT="$2"
        shift 2
        ;;
      --merge)
        CONFLICT_MODE="merge"
        shift
        ;;
      --force)
        CONFLICT_MODE="force"
        shift
        ;;
      --abort)
        CONFLICT_MODE="abort"
        shift
        ;;
      --output)
        OUTPUT_DIR="$2"
        shift 2
        ;;
      --help|-h)
        SHOW_HELP=true
        shift
        ;;
      *)
        echo "ERROR: Unknown option: $1" >&2
        echo "Run with --help for usage." >&2
        exit 1
        ;;
    esac
  done
}

# --- Show usage ---
show_usage() {
  cat <<'USAGE'
Usage: migrate.sh --path <source-path> [options]

Migrate project artifacts from GSD2, GSD v1, or standard spec-kit
into spec-kit-orchestrator format.

Required:
  --path <path>          Path to source project directory

Options:
  --source <type>        Source format: gsd2, gsd1, speckit (auto-detected if omitted)
  --recent-count <N>     Recent milestones to keep at summary level (default: 3)
  --merge                Merge with existing orchestrator state
  --force                Overwrite existing orchestrator state
  --abort                Cancel if orchestrator state exists (default)
  --output <path>        Output directory (default: .specify/orchestrator)
  --help                 Show this help message

Examples:
  migrate.sh --path /path/to/project
  migrate.sh --source gsd2 --path /path/to/project/.gsd
  migrate.sh --path /path/to/project --recent-count 5 --force
USAGE
}

# --- Validate arguments ---
validate_args() {
  if [[ -z "$SOURCE_PATH" ]]; then
    echo "ERROR: --path is required." >&2
    echo "Run with --help for usage." >&2
    exit 1
  fi

  if [[ ! -d "$SOURCE_PATH" ]]; then
    echo "ERROR: Source path does not exist: $SOURCE_PATH" >&2
    exit 1
  fi

  # Validate --source if provided
  if [[ -n "$SOURCE_TYPE" ]]; then
    case "$SOURCE_TYPE" in
      gsd2|gsd1|speckit) ;;
      *)
        echo "ERROR: Invalid --source value: $SOURCE_TYPE" >&2
        echo "Valid values: gsd2, gsd1, speckit" >&2
        exit 1
        ;;
    esac
  fi

  # Validate --recent-count is a positive integer
  if ! [[ "$RECENT_COUNT" =~ ^[0-9]+$ ]]; then
    echo "ERROR: --recent-count must be a non-negative integer: $RECENT_COUNT" >&2
    exit 1
  fi
}

# --- Main pipeline ---
main() {
  parse_args "$@"

  if [[ "$SHOW_HELP" = true ]]; then
    show_usage
    exit 0
  fi

  validate_args

  echo "=== spec-kit-orchestrator migration ==="
  echo ""

  # Step 1: Source detection
  if [[ -z "$SOURCE_TYPE" ]]; then
    echo "Detecting source format..."
    SOURCE_TYPE="$(detect_source_type "$SOURCE_PATH")"
    if [[ "$SOURCE_TYPE" = "unknown" ]]; then
      echo "ERROR: Could not detect source format at: $SOURCE_PATH" >&2
      echo "Provide --source <gsd2|gsd1|speckit> to specify manually." >&2
      exit 2
    fi
    echo "Detected source format: $SOURCE_TYPE"
  else
    echo "Using specified source format: $SOURCE_TYPE"
  fi

  # Step 2: Resolve source path
  local resolved_path
  resolved_path="$(resolve_source_path "$SOURCE_PATH" "$SOURCE_TYPE")"
  echo "Source path: $resolved_path"

  # Step 3: Load the adapter
  local adapter_script="$MIGRATE_SCRIPT_DIR/adapters/${SOURCE_TYPE}.sh"
  if [[ ! -f "$adapter_script" ]]; then
    echo "ERROR: Adapter not found for source type '$SOURCE_TYPE': $adapter_script" >&2
    echo "Available adapters:" >&2
    ls "$MIGRATE_SCRIPT_DIR/adapters/"*.sh 2>/dev/null | while read -r f; do
      echo "  - $(basename "$f" .sh)" >&2
    done
    exit 2
  fi
  echo "Loading adapter: $SOURCE_TYPE"
  source "$adapter_script"

  # Step 4: Verify adapter detects the source
  local detect_result
  detect_result="$(detect_source "$resolved_path")"
  if [[ "$detect_result" != "yes" ]]; then
    echo "WARNING: Adapter '$SOURCE_TYPE' does not recognize path: $resolved_path" >&2
    echo "Continuing anyway (--source was explicitly specified)." >&2
  fi

  # Step 5: Create temporary output directory for intermediate data
  local tmp_output
  tmp_output="$(mktemp -d)"
  # Ensure cleanup on exit
  trap 'rm -rf "$tmp_output"' EXIT

  echo ""
  echo "--- Extracting data ---"

  # Step 6: Run extraction pipeline
  echo "Extracting knowledge..."
  if extract_knowledge "$resolved_path" "$tmp_output"; then
    local knowledge_count
    knowledge_count="$(( $(wc -l < "$tmp_output/knowledge.dat" 2>/dev/null || echo 1) - 1 ))"
    echo "  -> $knowledge_count entries"
  else
    echo "  -> FAILED (continuing)" >&2
  fi

  echo "Extracting decisions..."
  if extract_decisions "$resolved_path" "$tmp_output"; then
    local decisions_count
    decisions_count="$(( $(wc -l < "$tmp_output/decisions.dat" 2>/dev/null || echo 1) - 1 ))"
    echo "  -> $decisions_count entries"
  else
    echo "  -> FAILED (continuing)" >&2
  fi

  echo "Extracting requirements..."
  if extract_requirements "$resolved_path" "$tmp_output"; then
    local requirements_count
    requirements_count="$(( $(wc -l < "$tmp_output/requirements.dat" 2>/dev/null || echo 1) - 1 ))"
    echo "  -> $requirements_count entries"
  else
    echo "  -> FAILED (continuing)" >&2
  fi

  echo "Extracting milestones..."
  if extract_milestones "$resolved_path" "$tmp_output"; then
    local milestones_count
    milestones_count="$(( $(wc -l < "$tmp_output/milestones.dat" 2>/dev/null || echo 1) - 1 ))"
    echo "  -> $milestones_count milestones"
  else
    echo "  -> FAILED (continuing)" >&2
  fi

  echo "Extracting telemetry..."
  if extract_telemetry "$resolved_path" "$tmp_output"; then
    local telemetry_count
    telemetry_count="$(( $(wc -l < "$tmp_output/telemetry.dat" 2>/dev/null || echo 1) - 1 ))"
    echo "  -> $telemetry_count records"
  else
    echo "  -> FAILED (continuing)" >&2
  fi

  echo ""
  echo "--- Extraction complete ---"

  # Check for warnings
  if [[ -f "$tmp_output/warnings.dat" ]]; then
    local warning_count
    warning_count="$(( $(wc -l < "$tmp_output/warnings.dat") - 1 ))"
    echo "Warnings: $warning_count"
  fi

  echo ""
  echo "Intermediate data written to: $tmp_output"
  echo ""

  # --- Future phases will add steps here ---
  # Step 7: Idempotency check (P06)
  # Step 8: Transform intermediate data to orchestrator format (P02-P04)
  # Step 9: Generate migration report (P06)
  # Step 10: Write output to target directory (P06)

  echo "NOTE: P01 delivers extraction only. Transformation and reporting"
  echo "      will be added in P02-P06."
  echo ""
  echo "=== Migration extraction complete ==="

  # In P01, keep temp dir for inspection (remove trap)
  trap - EXIT
  echo "Intermediate data preserved at: $tmp_output"
}

# Run main only if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
  main "$@"
fi
```

### Step 3: Make both scripts executable

```bash
chmod +x scripts/migrate/lib/detect-source.sh
chmod +x scripts/migrate/migrate.sh
```

### Step 4: Verify

```bash
# Source detection works
bash -c '
  source scripts/migrate/lib/detect-source.sh
  result=$(detect_source_type "/Users/brettkellgren/Sites/lakeledger")
  echo "lakeledger: $result"  # should be "gsd2"
'

# CLI shows help
bash scripts/migrate/migrate.sh --help

# CLI validates arguments
bash scripts/migrate/migrate.sh 2>&1 | grep -q "ERROR.*--path" && echo "PASS: validates --path"

# CLI detects source and runs extraction
bash scripts/migrate/migrate.sh --path /Users/brettkellgren/Sites/lakeledger
```

## Must-Haves

This task addresses these phase must-haves:

**Truths:**
- Source detection auto-detects gsd2 (gsd.db present), gsd1 (.planning/ only), and speckit (.specify/ or specs/) source types
- The CLI entry point parses --source, --path, --recent-count, --merge, --force, and --abort flags
- All scripts use `#!/usr/bin/env bash` shebang and `set -euo pipefail` for safety
- Bash 3.2 compatibility

**Artifacts:**
- `scripts/migrate/lib/detect-source.sh` (min 30 lines, contains "detect_source")
- `scripts/migrate/migrate.sh` (min 80 lines, contains "--source")

**Key Links:**
- `scripts/migrate/migrate.sh` -> `scripts/migrate/lib/detect-source.sh` (CLI uses source detection)
- `scripts/migrate/migrate.sh` -> `scripts/migrate/adapter-interface.sh` (CLI sources adapter interface)

## Verification

```bash
# detect-source.sh exists and meets requirements
test -f scripts/migrate/lib/detect-source.sh
test "$(wc -l < scripts/migrate/lib/detect-source.sh)" -ge 30
grep -q "detect_source" scripts/migrate/lib/detect-source.sh
grep -q "gsd2" scripts/migrate/lib/detect-source.sh
grep -q "gsd1" scripts/migrate/lib/detect-source.sh
grep -q "speckit" scripts/migrate/lib/detect-source.sh

# migrate.sh exists and meets requirements
test -f scripts/migrate/migrate.sh
test "$(wc -l < scripts/migrate/migrate.sh)" -ge 80
grep -q "\-\-source" scripts/migrate/migrate.sh
grep -q "\-\-path" scripts/migrate/migrate.sh
grep -q "\-\-recent-count" scripts/migrate/migrate.sh
grep -q "\-\-merge" scripts/migrate/migrate.sh
grep -q "\-\-force" scripts/migrate/migrate.sh
grep -q "\-\-abort" scripts/migrate/migrate.sh

# References upstream scripts
grep -q "detect-source\|detect_source" scripts/migrate/migrate.sh
grep -q "adapter-interface\|adapter_interface" scripts/migrate/migrate.sh

# Bash 3.2 compliance
! grep -n 'declare -A\||&\|${[a-zA-Z_]*,,}' scripts/migrate/lib/detect-source.sh scripts/migrate/migrate.sh

# Sources cleanly
bash -c 'source scripts/migrate/lib/detect-source.sh && echo "PASS"'

# Help works
bash scripts/migrate/migrate.sh --help | grep -q "Usage" && echo "PASS: help works"
```

## Inputs

### From Previous Tasks

- `scripts/migrate/adapter-interface.sh` (from T01)
  - Key API: `validate_adapter()` -- verifies adapter implements all required functions; `escape_field(value)`, `write_header(file, ...)`, `append_record(file, ...)` -- TSV utilities; `emit_warning(output_dir, category, message, [raw_data])` -- warning logging; `init_output_dir(dir)` -- creates output directory
  - Key types: Adapter contract requires 6 functions: `detect_source(path)` echoing "yes"/"no", `extract_knowledge(src, out)`, `extract_decisions(src, out)`, `extract_requirements(src, out)`, `extract_milestones(src, out)`, `extract_telemetry(src, out)` each writing `.dat` TSV files to output_dir
  - Behavioral contract: Must be sourced before any adapter script. Provides shared utilities that adapters use. The `validate_adapter()` call at the end of each adapter script verifies completeness.

- `scripts/migrate/adapters/gsd2.sh` (from T04)
  - Key API: Implements all 6 adapter interface functions. `detect_source(path)` -- echoes "yes" if path contains GSD2 artifacts (.gsd/gsd.db or .gsd/memories-snapshot.json); `extract_knowledge(source_path, output_dir)` -- writes `knowledge.dat`; `extract_decisions(source_path, output_dir)` -- writes `decisions.dat`; `extract_requirements(source_path, output_dir)` -- writes `requirements.dat`; `extract_milestones(source_path, output_dir)` -- writes `milestones.dat`, `slices.dat`, `tasks.dat`; `extract_telemetry(source_path, output_dir)` -- writes `telemetry.dat`
  - Behavioral contract: Sources `sqlite-reader.sh` and `json-fallback.sh` internally. Uses SQLite when available, falls back to JSON. Emits warnings via `emit_warning()`. Never modifies source directory.

### From Disk (Pre-existing)

- Source project directories (provided via `--path` flag) -- the migration source to detect and extract from
- `scripts/migrate/adapters/` directory -- contains adapter scripts selected by source type (e.g., `gsd2.sh` from T04; `gsd1.sh` and `speckit.sh` added in P05)

## Expected Output

Two files:

1. `scripts/migrate/lib/detect-source.sh` -- provides `detect_source_type(path)` returning "gsd2", "gsd1", "speckit", or "unknown"; provides `resolve_source_path(path, type)` normalizing the path for adapter consumption.

2. `scripts/migrate/migrate.sh` -- the CLI entry point that:
   - Parses all flags (--source, --path, --recent-count, --merge, --force, --abort, --output, --help)
   - Auto-detects source format when --source is omitted
   - Loads the correct adapter script
   - Runs all 5 extraction functions (knowledge, decisions, requirements, milestones, telemetry)
   - Reports extraction counts and warnings
   - Creates a temporary directory with intermediate data for downstream phases
   - Includes stub comments for future pipeline steps (transform, report, output)
