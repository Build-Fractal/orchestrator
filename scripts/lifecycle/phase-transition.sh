#!/usr/bin/env bash
# scripts/lifecycle/phase-transition.sh — Automate mechanical phase transition steps
# Reads all task summaries from a completed phase, derives summary field values,
# runs external mod check, syncs roadmap, and outputs structured key=value pairs
# that can be passed directly to write-summary.sh.
#
# Usage: phase-transition.sh <milestone-dir> <phase-id> [--lock-file <path>] [--output-file=<path>]
#        [--write --body=<text> --body-file=<path> --observability_surfaces=<text> [--verification_result=<pass|fail>]]
#
# When --output-file is set, structured output is written to a file instead of
# stdout. This avoids command substitution at the caller (AD-19).
# When --body-file is set, body text is read from the file instead of a quoted
# argument, avoiding multiline quoted payloads (AD-19).
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

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="$(cd "$_SCRIPT_DIR/../lib" && pwd)"
. "$_LIB_DIR/errors.sh"
. "$_LIB_DIR/events.sh"

_PT_RESULT_EMITTED=0
_pt_final_result() {
  local rc=$?
  if [ "$_PT_RESULT_EMITTED" -eq 0 ] && [ -n "${ORCH_RUN_ID:-}" ]; then
    if [ "$rc" -eq 0 ]; then
      emit_result ok "" "phase transition ready" >&2
    else
      emit_result error STATE "phase-transition failed rc=$rc" >&2
    fi
    _PT_RESULT_EMITTED=1
  fi
}
trap _pt_final_result EXIT

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
WRITE_MODE=false
BODY=""
OBS_SURFACES=""
VERIF_RESULT="pass"
OUTPUT_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --lock-file)
      LOCK_FILE="$2"; shift 2 ;;
    --write)
      WRITE_MODE=true; shift ;;
    --body=*)
      BODY="${1#--body=}"; shift ;;
    --body-file=*)
      _body_file="${1#--body-file=}"
      if [[ -f "$_body_file" ]]; then BODY="$(cat "$_body_file")"; fi
      shift ;;
    --observability_surfaces=*)
      OBS_SURFACES="${1#--observability_surfaces=}"; shift ;;
    --verification_result=*)
      VERIF_RESULT="${1#--verification_result=}"; shift ;;
    --output-file=*)
      OUTPUT_FILE="${1#--output-file=}"; shift ;;
    --output-file)
      OUTPUT_FILE="$2"; shift 2 ;;
    *)
      echo "phase-transition.sh: unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# --- Output routing: file-based to avoid command substitution at caller ---
_pt_output() {
  if [[ -n "$OUTPUT_FILE" ]]; then
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    printf '%s\n' "$1" >> "$OUTPUT_FILE"
  else
    echo "$1"
  fi
}

# Truncate output file at start if set (append during run via _pt_output)
if [[ -n "$OUTPUT_FILE" ]]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  : > "$OUTPUT_FILE"
fi

PHASE_DIR="$MILESTONE_DIR/phases/$PHASE_ID"
TASKS_DIR="$PHASE_DIR/tasks"

if [[ ! -d "$PHASE_DIR" ]]; then
  echo "TRANSITION:ERROR phase directory not found: $PHASE_DIR" >&2
  exit 1
fi

# --- Derive milestone ID ---
_PT_PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DETECT_MILESTONE="$_PT_PROJECT_ROOT/scripts/util/detect-milestone-id.sh"
if [[ -f "$DETECT_MILESTONE" ]]; then
  MILESTONE_ID="$(bash "$DETECT_MILESTONE" "$MILESTONE_DIR")"
else
  MILESTONE_ID="$(basename "$MILESTONE_DIR")"
fi

if [ -n "${ORCH_RUN_ID:-}" ]; then
  emit_event PHASE_START stage=transition milestone="$MILESTONE_ID" phase="$PHASE_ID" >&2
fi

# --- External modification check ---
external_mods=""
if [[ -n "$LOCK_FILE" && -f "$LOCK_FILE" ]]; then
  external_mods=$(bash "$CHECK_EXTERNAL" "$LOCK_FILE" --scope ".specify/" 2>/dev/null) || true
fi
_pt_output "external_mods=$external_mods"

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

    # Extract duration (best-effort numeric parsing — tolerates non-numeric
    # values like "unreported" by contributing zero)
    dur=$(extract_field "$summary_file" "duration") || true
    if [[ -n "$dur" ]]; then
      # Try to extract minutes from formats like "25m", "1h30m", "90"
      mins=$(printf '%s' "$dur" | grep -oE '[0-9]+' | head -1 || true)
      if [[ -n "$mins" ]]; then
        duration_total=$((duration_total + mins))
      fi
    fi

    # Accumulate body for synthesis. `sed | head` risks SIGPIPE under
    # `set -o pipefail`; tolerate with `|| true` so non-fatal head-close
    # doesn't abort the loop.
    body_text=$(sed -n '/^---$/,/^---$/d; /^$/,$p' "$summary_file" 2>/dev/null | head -5 || true)
    if [[ -n "$body_text" ]]; then
      body_parts="${body_parts:+$body_parts\n}[$task_id]: $body_text"
    fi
  done
fi

# --- Output derived fields ---
_pt_output "id=$PHASE_ID"
_pt_output "parent=$MILESTONE_ID"
_pt_output "milestone=$MILESTONE_ID"
_pt_output "provides=$provides_list"
_pt_output "requires=${requires_list:-none}"
_pt_output "affects=${affects_list:-none}"
_pt_output "key_files=$key_files_list"
_pt_output "key_decisions=${key_decisions_list:-none}"
_pt_output "patterns_established=${patterns_list:-none}"
_pt_output "drill_down_paths=$drill_down_list"
_pt_output "duration=${duration_total}m"
_pt_output "completed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
_pt_output "task_count=$task_count"

# --- Write summary if --write is set ---
ROADMAP_FILE="$MILESTONE_DIR/${MILESTONE_ID}-ROADMAP.md"

if [[ "$WRITE_MODE" = "true" ]]; then
  WRITE_SUMMARY="$PROJECT_ROOT/scripts/knowledge/write-summary.sh"
  if [[ ! -f "$WRITE_SUMMARY" ]]; then
    echo "TRANSITION:ERROR write-summary.sh not found: $WRITE_SUMMARY" >&2
    exit 1
  fi

  if [[ -z "$BODY" ]]; then
    echo "TRANSITION:ERROR --write requires --body=<text>" >&2
    exit 1
  fi

  SUMMARY_FILE="$PHASE_DIR/${PHASE_ID}-SUMMARY.md"
  completed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  bash "$WRITE_SUMMARY" phase "$SUMMARY_FILE" \
    "--id=$PHASE_ID" \
    "--parent=$MILESTONE_ID" \
    "--milestone=$MILESTONE_ID" \
    "--provides=$provides_list" \
    "--requires=${requires_list:-none}" \
    "--affects=${affects_list:-none}" \
    "--key_files=$key_files_list" \
    "--key_decisions=${key_decisions_list:-none}" \
    "--patterns_established=${patterns_list:-none}" \
    "--drill_down_paths=$drill_down_list" \
    "--duration=${duration_total}m" \
    "--verification_result=$VERIF_RESULT" \
    "--completed_at=$completed_at" \
    "--observability_surfaces=${OBS_SURFACES:-none}" \
    "--body=$BODY"

  _pt_output "TRANSITION:WRITTEN phase=$PHASE_ID summary=$SUMMARY_FILE"
fi

# --- Sync roadmap (after writing summary so checkboxes reflect new state) ---
if [[ -f "$ROADMAP_FILE" ]]; then
  sync_output=$(bash "$SYNC_ROADMAP" "$ROADMAP_FILE" "$MILESTONE_DIR" --fix 2>/dev/null) || true
  _pt_output "roadmap_sync=$sync_output"
fi

if [ -n "${ORCH_RUN_ID:-}" ]; then
  emit_event PHASE_COMPLETE stage=transition phase="$PHASE_ID" task_count="$task_count" >&2
fi

_pt_output "TRANSITION:READY phase=$PHASE_ID fields_derived=$task_count"
