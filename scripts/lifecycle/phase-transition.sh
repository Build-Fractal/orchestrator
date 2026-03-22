#!/usr/bin/env bash
# scripts/lifecycle/phase-transition.sh — Automate mechanical phase transition steps
# Reads all task summaries from a completed phase, derives summary field values,
# runs external mod check, syncs roadmap, and outputs structured key=value pairs
# that can be passed directly to write-summary.sh.
#
# Usage: phase-transition.sh <milestone-dir> <phase-id> [--lock-file <path>]
#
# Output (stdout):
#   Key=value pairs for write-summary.sh fields, then a status line:
#   TRANSITION:READY phase=P## fields_derived=N
#   TRANSITION:ERROR <reason>
#
# Exit codes:
#   0 — success, fields derived
#   1 — usage error or missing phase directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SYNC_ROADMAP="$PROJECT_ROOT/scripts/lifecycle/sync-roadmap.sh"
CHECK_EXTERNAL="$PROJECT_ROOT/scripts/verify/check-external-mods.sh"

# --- Argument parsing ---
if [[ $# -lt 2 ]]; then
  echo "phase-transition.sh: requires <milestone-dir> <phase-id> [--lock-file <path>]" >&2
  exit 1
fi

MILESTONE_DIR="$1"
PHASE_ID="$2"
shift 2

LOCK_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --lock-file)
      LOCK_FILE="$2"; shift 2 ;;
    *)
      echo "phase-transition.sh: unknown option: $1" >&2
      exit 1
      ;;
  esac
done

PHASE_DIR="$MILESTONE_DIR/phases/$PHASE_ID"
TASKS_DIR="$PHASE_DIR/tasks"

if [[ ! -d "$PHASE_DIR" ]]; then
  echo "TRANSITION:ERROR phase directory not found: $PHASE_DIR" >&2
  exit 1
fi

# --- Derive milestone ID ---
MILESTONE_ID="$(basename "$MILESTONE_DIR")"
detected_id=$(find "$MILESTONE_DIR" -maxdepth 1 -name 'M[0-9]*-*' -print 2>/dev/null \
  | head -1 \
  | xargs -I{} basename {} \
  | grep -oE '^M[0-9]+' || true)
if [[ -n "$detected_id" ]]; then
  MILESTONE_ID="$detected_id"
fi

# --- External modification check ---
external_mods=""
if [[ -n "$LOCK_FILE" && -f "$LOCK_FILE" ]]; then
  external_mods=$(bash "$CHECK_EXTERNAL" "$LOCK_FILE" --scope ".specify/" 2>/dev/null) || true
fi
echo "external_mods=$external_mods"

# --- Read all task summaries and derive field values ---
provides_list=""
requires_list=""
affects_list=""
key_files_list=""
key_decisions_list=""
patterns_list=""
drill_down_list=""
duration_total=0
task_count=0
body_parts=""

if [[ -d "$TASKS_DIR" ]]; then
  for summary_file in "$TASKS_DIR"/T*-SUMMARY.md; do
    [[ -f "$summary_file" ]] || continue
    task_count=$((task_count + 1))
    task_id=$(basename "$summary_file" | sed 's/-SUMMARY\.md$//')

    # Extract frontmatter fields using grep/sed (no jq dependency)
    extract_field() {
      local file="$1"
      local field="$2"
      # Match "field: " or "  - " values under field
      local value=""
      value=$(sed -n "/^${field}:/,/^[a-z_]*:/{ /^  - /s/^  - //p; /^${field}: /s/^${field}: //p; }" "$file" | tr -d '"' | head -5)
      if [[ -z "$value" ]]; then
        # Try single-line format
        value=$(grep -E "^${field}:" "$file" | head -1 | sed "s/^${field}:[[:space:]]*//" | tr -d '"')
      fi
      echo "$value"
    }

    # Accumulate provides
    p=$(extract_field "$summary_file" "provides")
    if [[ -n "$p" ]]; then
      provides_list="${provides_list:+$provides_list, }$p"
    fi

    # Accumulate requires
    r=$(extract_field "$summary_file" "requires")
    if [[ -n "$r" && "$r" != "none" ]]; then
      requires_list="${requires_list:+$requires_list, }$r"
    fi

    # Accumulate affects
    a=$(extract_field "$summary_file" "affects")
    if [[ -n "$a" && "$a" != "none" ]]; then
      affects_list="${affects_list:+$affects_list, }$a"
    fi

    # Accumulate key_files
    kf=$(extract_field "$summary_file" "key_files")
    if [[ -n "$kf" ]]; then
      key_files_list="${key_files_list:+$key_files_list, }$kf"
    fi

    # Accumulate key_decisions
    kd=$(extract_field "$summary_file" "key_decisions")
    if [[ -n "$kd" && "$kd" != "none" ]]; then
      key_decisions_list="${key_decisions_list:+$key_decisions_list, }$kd"
    fi

    # Accumulate patterns
    pat=$(extract_field "$summary_file" "patterns_established")
    if [[ -n "$pat" && "$pat" != "none" ]]; then
      patterns_list="${patterns_list:+$patterns_list, }$pat"
    fi

    # Accumulate drill_down_paths
    drill_down_list="${drill_down_list:+$drill_down_list, }$TASKS_DIR/${task_id}-SUMMARY.md"

    # Extract duration (best-effort numeric parsing)
    dur=$(extract_field "$summary_file" "duration")
    if [[ -n "$dur" ]]; then
      # Try to extract minutes from formats like "25m", "1h30m", "90"
      mins=$(echo "$dur" | grep -oE '[0-9]+' | head -1)
      if [[ -n "$mins" ]]; then
        duration_total=$((duration_total + mins))
      fi
    fi

    # Accumulate body for synthesis
    body_text=$(sed -n '/^---$/,/^---$/d; /^$/,$p' "$summary_file" | head -5)
    if [[ -n "$body_text" ]]; then
      body_parts="${body_parts:+$body_parts\n}[$task_id]: $body_text"
    fi
  done
fi

# --- Output derived fields ---
echo "id=$PHASE_ID"
echo "parent=$MILESTONE_ID"
echo "milestone=$MILESTONE_ID"
echo "provides=$provides_list"
echo "requires=${requires_list:-none}"
echo "affects=${affects_list:-none}"
echo "key_files=$key_files_list"
echo "key_decisions=${key_decisions_list:-none}"
echo "patterns_established=${patterns_list:-none}"
echo "drill_down_paths=$drill_down_list"
echo "duration=${duration_total}m"
echo "completed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "task_count=$task_count"

# --- Sync roadmap ---
ROADMAP_FILE="$MILESTONE_DIR/${MILESTONE_ID}-ROADMAP.md"
if [[ -f "$ROADMAP_FILE" ]]; then
  sync_output=$(bash "$SYNC_ROADMAP" "$ROADMAP_FILE" "$MILESTONE_DIR" --fix 2>/dev/null) || true
  echo "roadmap_sync=$sync_output"
fi

echo "TRANSITION:READY phase=$PHASE_ID fields_derived=$task_count"
