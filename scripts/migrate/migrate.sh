#!/usr/bin/env bash
# scripts/migrate/migrate.sh — Migration CLI Entry Point
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+ (no associative arrays, no pipe-ampersand)
#
# Orchestrates the migration pipeline:
#   P01: Source extraction (this phase)
#   P02: Transform to spec-kit format (stub)
#   P03: Report generation (stub)
#   P04: Idempotency check (stub)
#   P05: Import into spec-kit state (stub)
#   P06: Post-migration validation (stub)
#
# Exit codes:
#   0 = success
#   1 = usage error (missing/invalid arguments)
#   2 = detection failed (unknown source format)
#   3 = adapter error (adapter load/detect/extract failure)
#   4 = state conflict (existing state + no --merge/--force)
# =============================================================================
set -euo pipefail

# Resolve script directory for sourcing dependencies
_MIGRATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies
source "${_MIGRATE_DIR}/adapter-interface.sh"
source "${_MIGRATE_DIR}/lib/detect-source.sh"
source "${_MIGRATE_DIR}/lib/idempotency.sh"

# =============================================================================
# Constants
# =============================================================================
MIGRATE_VERSION="1.0.0"
DEFAULT_RECENT_COUNT=3

# =============================================================================
# usage — Print help text and exit
# =============================================================================
usage() {
    cat <<'USAGE'
Usage: migrate.sh --path <path> [OPTIONS]

Migrate project data from GSD2, GSD1, or spec-kit sources into
the spec-kit-orchestrator intermediate format.

REQUIRED:
  --path <path>          Source project path to migrate from

OPTIONS:
  --source <format>      Source format: gsd2, gsd1, speckit
                         (auto-detected if omitted)
  --recent-count <N>     Recent milestones at summary level (default: 3)
  --output <path>        Output directory for extracted data
                         (default: temp directory)
  --merge                Merge with existing state in output
  --force                Overwrite existing state in output
  --abort                Cancel if state exists in output (default)
  --help                 Show this help message
  --version              Show version

EXIT CODES:
  0  Success
  1  Usage error (missing or invalid arguments)
  2  Detection failed (unknown source format)
  3  Adapter error (load, detect, or extract failure)
  4  State conflict (existing state without --merge or --force)

EXAMPLES:
  # Auto-detect and extract from a project
  migrate.sh --path /path/to/project

  # Specify source format explicitly
  migrate.sh --path /path/to/project --source gsd2

  # Extract to a specific output directory
  migrate.sh --path /path/to/project --output ./migration-output

  # Merge with existing extracted state
  migrate.sh --path /path/to/project --output ./existing --merge
USAGE
}

# =============================================================================
# Logging helpers
# =============================================================================
log_info() {
    echo "[INFO]  $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_warn() {
    echo "[WARN]  $*" >&2
}

log_step() {
    echo ""
    echo "==> $*"
}

# =============================================================================
# count_records <file>
#   Count data records in a TSV file (total lines minus header).
#   Returns 0 if file does not exist.
# =============================================================================
count_records() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "0"
        return 0
    fi
    local total
    total="$(wc -l < "$file" | tr -d ' ')"
    if [ "$total" -le 1 ]; then
        echo "0"
    else
        echo "$(( total - 1 ))"
    fi
}

# =============================================================================
# Parse arguments
# =============================================================================
opt_source=""
opt_path=""
opt_recent_count="$DEFAULT_RECENT_COUNT"
opt_output=""
opt_conflict="abort"  # abort | merge | force

while [ $# -gt 0 ]; do
    case "$1" in
        --source)
            if [ $# -lt 2 ]; then
                log_error "--source requires a value (gsd2, gsd1, speckit)"
                exit 1
            fi
            opt_source="$2"
            shift 2
            ;;
        --path)
            if [ $# -lt 2 ]; then
                log_error "--path requires a value"
                exit 1
            fi
            opt_path="$2"
            shift 2
            ;;
        --recent-count)
            if [ $# -lt 2 ]; then
                log_error "--recent-count requires a numeric value"
                exit 1
            fi
            opt_recent_count="$2"
            shift 2
            ;;
        --output)
            if [ $# -lt 2 ]; then
                log_error "--output requires a path"
                exit 1
            fi
            opt_output="$2"
            shift 2
            ;;
        --merge)
            opt_conflict="merge"
            shift
            ;;
        --force)
            opt_conflict="force"
            shift
            ;;
        --abort)
            opt_conflict="abort"
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        --version)
            echo "migrate.sh version $MIGRATE_VERSION"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Run 'migrate.sh --help' for usage." >&2
            exit 1
            ;;
    esac
done

# =============================================================================
# Validate required arguments
# =============================================================================
if [ -z "$opt_path" ]; then
    log_error "--path is required"
    echo "Run 'migrate.sh --help' for usage." >&2
    exit 1
fi

if [ ! -d "$opt_path" ]; then
    log_error "Source path does not exist or is not a directory: $opt_path"
    exit 1
fi

# Validate --source if provided
if [ -n "$opt_source" ]; then
    case "$opt_source" in
        gsd2|gsd1|speckit) ;;
        *)
            log_error "Invalid source format: $opt_source (must be gsd2, gsd1, or speckit)"
            exit 1
            ;;
    esac
fi

# Validate --recent-count is numeric
case "$opt_recent_count" in
    ''|*[!0-9]*)
        log_error "--recent-count must be a positive integer, got: $opt_recent_count"
        exit 1
        ;;
esac

# =============================================================================
# P01 — Extraction Phase
# =============================================================================
log_step "Migration Pipeline — P01: Extraction"
log_info "Source path: $opt_path"

# --- Step 1: Detect source format ---
if [ -z "$opt_source" ]; then
    log_info "Auto-detecting source format..."
    opt_source="$(detect_source_type "$opt_path")"
    log_info "Detected format: $opt_source"
else
    log_info "Source format (explicit): $opt_source"
fi

if [ "$opt_source" = "unknown" ]; then
    log_error "Could not detect source format at: $opt_path"
    log_error "No recognized project indicators found (.gsd/, .planning/, .specify/, specs/)"
    exit 2
fi

# --- Step 2: Resolve source path ---
resolved_path="$(resolve_source_path "$opt_path" "$opt_source")"
log_info "Resolved source path: $resolved_path"

# --- Step 3: Load adapter ---
adapter_script="${_MIGRATE_DIR}/adapters/${opt_source}.sh"
if [ ! -f "$adapter_script" ]; then
    log_error "No adapter found for source format '$opt_source' at: $adapter_script"
    exit 3
fi

log_info "Loading adapter: ${opt_source}.sh"
source "$adapter_script"

# --- Step 4: Verify adapter detects the source ---
log_info "Verifying adapter can handle source..."
adapter_result="$(detect_source "$resolved_path")"
if [ "$adapter_result" != "yes" ]; then
    log_error "Adapter '$opt_source' cannot handle source at: $resolved_path"
    log_error "detect_source returned: $adapter_result"
    exit 3
fi
log_info "Adapter confirmed: source is valid"

# --- Step 5: Create output directory ---
if [ -n "$opt_output" ]; then
    output_dir="$opt_output"
else
    output_dir="$(mktemp -d "${TMPDIR:-/tmp}/migrate-XXXXXX")"
fi

# Check for existing state
if [ -d "$output_dir" ] && [ -n "$(ls -A "$output_dir" 2>/dev/null)" ]; then
    case "$opt_conflict" in
        abort)
            log_error "Output directory is not empty: $output_dir"
            log_error "Use --merge to merge, --force to overwrite, or choose a different --output"
            exit 4
            ;;
        force)
            log_warn "Force mode: clearing existing output at $output_dir"
            rm -rf "$output_dir"
            mkdir -p "$output_dir"
            ;;
        merge)
            log_info "Merge mode: will merge with existing state at $output_dir"
            ;;
    esac
else
    mkdir -p "$output_dir"
fi

log_info "Output directory: $output_dir"

# --- Step 6: Run extraction functions ---
extraction_failed=false

log_step "Extracting knowledge..."
if extract_knowledge "$resolved_path" "$output_dir"; then
    knowledge_count="$(count_records "${output_dir}/knowledge.dat")"
    log_info "  Knowledge records: $knowledge_count"
else
    log_error "  Knowledge extraction failed"
    extraction_failed=true
fi

log_step "Extracting decisions..."
if extract_decisions "$resolved_path" "$output_dir"; then
    decisions_count="$(count_records "${output_dir}/decisions.dat")"
    log_info "  Decision records: $decisions_count"
else
    log_error "  Decisions extraction failed"
    extraction_failed=true
fi

log_step "Extracting requirements..."
if extract_requirements "$resolved_path" "$output_dir"; then
    requirements_count="$(count_records "${output_dir}/requirements.dat")"
    log_info "  Requirement records: $requirements_count"
else
    log_error "  Requirements extraction failed"
    extraction_failed=true
fi

log_step "Extracting milestones, slices, and tasks..."
if extract_milestones "$resolved_path" "$output_dir"; then
    milestones_count="$(count_records "${output_dir}/milestones.dat")"
    slices_count="$(count_records "${output_dir}/slices.dat")"
    tasks_count="$(count_records "${output_dir}/tasks.dat")"
    log_info "  Milestone records: $milestones_count"
    log_info "  Slice records:     $slices_count"
    log_info "  Task records:      $tasks_count"
else
    log_error "  Milestones extraction failed"
    extraction_failed=true
fi

log_step "Extracting telemetry..."
if extract_telemetry "$resolved_path" "$output_dir"; then
    telemetry_count="$(count_records "${output_dir}/telemetry.dat")"
    log_info "  Telemetry records: $telemetry_count"
else
    log_error "  Telemetry extraction failed"
    extraction_failed=true
fi

# --- Step 7: Report warnings ---
warnings_file="${output_dir}/warnings.dat"
if [ -f "$warnings_file" ]; then
    warning_count="$(count_records "$warnings_file")"
    if [ "$warning_count" -gt 0 ]; then
        log_step "Warnings ($warning_count):"
        # Skip header line, print each warning
        tail -n +2 "$warnings_file" | while IFS="	" read -r ts code msg src; do
            log_warn "  [$code] $msg"
            if [ -n "$src" ]; then
                log_warn "         source: $src"
            fi
        done
    fi
fi

# --- Step 8: Summary ---
log_step "Extraction Summary"
echo "  Source format:  $opt_source"
echo "  Source path:    $resolved_path"
echo "  Output:         $output_dir"
echo "  Conflict mode:  $opt_conflict"
echo ""
echo "  Data files:"
for dat_file in "${output_dir}"/*.dat; do
    if [ -f "$dat_file" ]; then
        fname="$(basename "$dat_file")"
        rc="$(count_records "$dat_file")"
        printf "    %-25s %s records\n" "$fname" "$rc"
    fi
done

if [ "$extraction_failed" = "true" ]; then
    echo ""
    log_error "One or more extraction steps failed. Review errors above."
    exit 3
fi

# =============================================================================
# P02 — Transform Phase
# =============================================================================
log_step "Migration Pipeline — P02: Transform"

# Resolve target root via M008 5-rule resolver (AD-13).
# --output takes precedence (offline extraction path).
if [ -n "$opt_output" ]; then
    target_root="$opt_output"
    log_info "Target root (from --output): $target_root"
else
    target_root="$(bash "$(dirname "${BASH_SOURCE[0]}")/../state/resolve-root.sh" --absolute)"
    log_info "Target root (from resolve-root.sh): $target_root"
fi
export MIGRATE_TARGET_ROOT="$target_root"
mkdir -p "$target_root"

# Check for existing orchestrator state (idempotency)
enforce_conflict_policy "$target_root" "$opt_conflict"

# Knowledge
log_info "Transforming knowledge..."
if bash "${_MIGRATE_DIR}/transform/knowledge.sh" "$output_dir" "$target_root" 2>/dev/null; then
    knowledge_active=$(find "$target_root/knowledge" -name "MEM*.md" -not -path "*/archive/*" 2>/dev/null | wc -l | tr -d ' ')
    knowledge_archived=$(find "$target_root/knowledge/archive" -name "MEM*.md" 2>/dev/null | wc -l | tr -d ' ')
    log_info "  Knowledge: $knowledge_active active, $knowledge_archived archived"
else
    log_warn "  Knowledge transform failed (continuing)"
fi

# Knowledge index
log_info "Building knowledge index..."
bash "${_MIGRATE_DIR}/transform/knowledge-index.sh" "$target_root" 2>/dev/null || log_warn "  Index generation failed"

# Decisions
log_info "Transforming decisions..."
bash "${_MIGRATE_DIR}/transform/decisions.sh" "$output_dir" "$target_root" 2>/dev/null || log_warn "  Decisions transform failed"

# Requirements
log_info "Transforming requirements..."
bash "${_MIGRATE_DIR}/transform/requirements.sh" "$output_dir" "$target_root" 2>/dev/null || log_warn "  Requirements transform failed"

# Milestone tiering
log_info "Tiering milestones (recent-count: $opt_recent_count)..."
bash "${_MIGRATE_DIR}/transform/milestone-tiering.sh" "$output_dir" "$target_root" --recent-count "$opt_recent_count" 2>/dev/null || log_warn "  Milestone tiering failed"

# Telemetry aggregation
log_info "Aggregating telemetry..."
bash "${_MIGRATE_DIR}/transform/telemetry-aggregator.sh" "$output_dir" "$target_root" 2>/dev/null || log_warn "  Telemetry aggregation failed"

# =============================================================================
# P03 — Report Generation
# =============================================================================
log_step "Migration Pipeline — P03: Report"
bash "${_MIGRATE_DIR}/transform/report.sh" "$output_dir" "$target_root" "$opt_source" 2>/dev/null || log_warn "Report generation failed"

# =============================================================================
# P04 — Knowledge Index + Graph Rebuild (AD-14)
# =============================================================================
# Migrated entries emit empty relates_to. Rebuild the index and the M007
# graph DB so traverse-graph.sh works against migrated state. Semantic
# relationship inference is deferred to detect-overlap.sh per AD-14.
log_step "Migration Pipeline — P04: Knowledge Index + Graph Rebuild"
rebuild_script="$(cd "${_MIGRATE_DIR}/.." && pwd)/knowledge/rebuild-index.sh"
if [ -f "$rebuild_script" ]; then
    if bash "$rebuild_script" --root "$target_root"; then
        log_info "Knowledge index and graph DB rebuilt at: $target_root"
        if [ -s "$target_root/knowledge.db" ]; then
            log_info "Graph DB present: $target_root/knowledge.db"
        else
            log_warn "Graph DB missing or empty after rebuild (no entries?)"
        fi
    else
        log_warn "rebuild-index.sh failed; KNOWLEDGE-INDEX.md and knowledge.db may be stale"
        log_warn "Re-run manually: bash scripts/knowledge/rebuild-index.sh --root $target_root"
    fi
else
    log_warn "rebuild-index.sh not found at $rebuild_script — skipping graph rebuild"
fi

echo ""
log_info "Migration complete. Output at: $target_root"
log_info "Review MIGRATION-REPORT.md for statistics and next steps."
exit 0
