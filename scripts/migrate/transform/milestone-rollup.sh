#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# milestone-rollup.sh — Generate rollup/summary documents for non-active milestones
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+ (no associative arrays, no readarray)
#
# Usage: milestone-rollup.sh <intermediate_dir> <target_root> <milestone_id> [--tier recent|historical]
#
# Output for recent milestones:
#   <target_root>/.specify/orchestrator/milestones/summaries/<milestone_id>-SUMMARY.md
# Output for historical milestones:
#   <target_root>/.specify/orchestrator/milestones/rollups/<milestone_id>-ROLLUP.md
#
# Recent milestones include more detail (full slice descriptions, task counts).
# Historical milestones keep it compact (just what shipped, key decisions).
#
# Idempotent: existing files are overwritten.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INTERFACE="${SCRIPT_DIR}/../adapter-interface.sh"

# shellcheck source=../adapter-interface.sh
source "$INTERFACE"

# --- Parse arguments ---
intermediate_dir="${1:?Usage: milestone-rollup.sh <intermediate_dir> <target_root> <milestone_id> [--tier recent|historical]}"
target_root="${2:?Usage: milestone-rollup.sh <intermediate_dir> <target_root> <milestone_id> [--tier recent|historical]}"
milestone_id="${3:?Usage: milestone-rollup.sh <intermediate_dir> <target_root> <milestone_id> [--tier recent|historical]}"
shift 3

tier="historical"
while [ $# -gt 0 ]; do
    case "$1" in
        --tier)
            tier="${2:-historical}"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

milestones_dat="${intermediate_dir}/milestones.dat"
slices_dat="${intermediate_dir}/slices.dat"
tasks_dat="${intermediate_dir}/tasks.dat"
decisions_dat="${intermediate_dir}/decisions.dat"

migration_date="$(date '+%Y-%m-%d')"

# --- Read milestone metadata ---
ms_title=""
ms_desc=""
ms_status=""
ms_start=""
ms_end=""

if [ -f "$milestones_dat" ]; then
    while IFS= read -r line; do
        local_id="$(printf '%s' "$line" | awk -F'\t' '{print $1}')"
        if [ "$local_id" = "$milestone_id" ]; then
            ms_title="$(printf '%s' "$line" | awk -F'\t' '{print $2}')"
            ms_status="$(printf '%s' "$line" | awk -F'\t' '{print $3}')"
            ms_desc="$(printf '%s' "$line" | awk -F'\t' '{print $4}')"
            ms_start="$(printf '%s' "$line" | awk -F'\t' '{print $5}')"
            ms_end="$(printf '%s' "$line" | awk -F'\t' '{print $6}')"
            break
        fi
    done < "$milestones_dat"
fi

ms_title="$(unescape_field "$ms_title")"
ms_desc="$(unescape_field "$ms_desc")"

if [ -z "$ms_title" ]; then
    ms_title="Milestone ${milestone_id}"
fi

# Extract just the date portion from ISO timestamps
ms_end_date=""
if [ -n "$ms_end" ]; then
    ms_end_date="$(printf '%s' "$ms_end" | cut -c1-10)"
fi

# --- Determine output path ---
if [ "$tier" = "recent" ]; then
    out_dir="${target_root}/.specify/orchestrator/milestones/summaries"
    out_file="${out_dir}/${milestone_id}-SUMMARY.md"
    doc_type="summary"
else
    out_dir="${target_root}/.specify/orchestrator/milestones/rollups"
    out_file="${out_dir}/${milestone_id}-ROLLUP.md"
    doc_type="rollup"
fi

mkdir -p "$out_dir"

# --- Collect slices for this milestone ---
slice_table=""
completed_slices=""
slice_count=0
completed_count=0

if [ -f "$slices_dat" ]; then
    while IFS= read -r line; do
        s_mid="$(printf '%s' "$line" | awk -F'\t' '{print $2}')"
        if [ "$s_mid" = "$milestone_id" ]; then
            slice_count=$((slice_count + 1))
            s_id="$(printf '%s' "$line" | awk -F'\t' '{print $1}')"
            s_title="$(printf '%s' "$line" | awk -F'\t' '{print $3}')"
            s_status="$(printf '%s' "$line" | awk -F'\t' '{print $4}')"
            s_desc="$(printf '%s' "$line" | awk -F'\t' '{print $5}')"

            s_title="$(unescape_field "$s_title")"
            s_desc="$(unescape_field "$s_desc")"

            # Count tasks for this slice
            task_count=0
            if [ -f "$tasks_dat" ]; then
                task_count="$(awk -F'\t' -v sid="$s_id" -v mid="$milestone_id" '$2 == sid && $3 == mid' "$tasks_dat" | wc -l | tr -d ' ')"
            fi

            slice_table="${slice_table}| ${s_id} | ${s_title} | ${s_status} | ${task_count} |
"
            if [ "$s_status" = "complete" ] || [ "$s_status" = "completed" ]; then
                completed_count=$((completed_count + 1))
                completed_slices="${completed_slices}- ${s_title}
"
            fi
        fi
    done < "$slices_dat"
fi

# --- Count total tasks ---
total_tasks=0
if [ -f "$tasks_dat" ]; then
    total_tasks="$(awk -F'\t' -v mid="$milestone_id" '$3 == mid' "$tasks_dat" | wc -l | tr -d ' ')"
fi

# --- Write the document ---
cat > "$out_file" <<EOF
---
id: ${milestone_id}
title: "${ms_title}"
tier: ${tier}
migrated_from: gsd2
started_at: "${ms_start}"
completed_at: "${ms_end_date}"
total_slices: ${slice_count}
total_tasks: ${total_tasks}
drill_down_paths:
  - archive/gsd-raw/${milestone_id}/
---

# ${milestone_id}: ${ms_title}
EOF

# --- What Shipped ---
printf '\n## What Shipped\n' >> "$out_file"
if [ -n "$completed_slices" ]; then
    printf '%s' "$completed_slices" >> "$out_file"
else
    printf 'No completed slices recorded.\n' >> "$out_file"
fi

# --- Description (recent only) ---
if [ "$tier" = "recent" ] && [ -n "$ms_desc" ]; then
    printf '\n## Vision\n%s\n' "$ms_desc" >> "$out_file"
fi

# --- Slice Summary ---
printf '\n## Slice Summary\n' >> "$out_file"
if [ -n "$slice_table" ]; then
    printf '| Slice | Title | Status | Tasks |\n' >> "$out_file"
    printf '|-------|-------|--------|-------|\n' >> "$out_file"
    printf '%s' "$slice_table" >> "$out_file"
else
    printf 'No slices recorded.\n' >> "$out_file"
fi

# --- Metrics ---
printf '\n## Metrics\n' >> "$out_file"
printf -- '- Total slices: %d (%d completed)\n' "$slice_count" "$completed_count" >> "$out_file"
printf -- '- Total tasks: %d\n' "$total_tasks" >> "$out_file"
if [ -n "$ms_start" ] && [ -n "$ms_end" ]; then
    printf -- '- Duration: %s to %s\n' "$(printf '%s' "$ms_start" | cut -c1-10)" "$ms_end_date" >> "$out_file"
fi

echo "ROLLUP: Generated ${tier} ${doc_type} for ${milestone_id} (${slice_count} slices, ${total_tasks} tasks)"
