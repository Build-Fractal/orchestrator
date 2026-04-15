#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# milestone-tiering.sh — Classify milestones into tiers and transform
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+ (no associative arrays, no readarray)
#
# Usage: milestone-tiering.sh <intermediate_dir> <target_root> [--recent-count N]
#
# Classifies milestones into 4 tiers:
#   Active:     status contains "in_progress", "active", or "in-progress"
#   Recent:     last N completed milestones (default 3)
#   Historical: all other completed milestones
#   Archived:   raw artifact paths preserved in rollup documents
#
# Writes classification file: <target_root>/.migration-tiers.dat
# Calls sub-transforms for each milestone based on tier.
#
# Idempotent: all output files are overwritten on re-run.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INTERFACE="${SCRIPT_DIR}/../adapter-interface.sh"

# shellcheck source=../adapter-interface.sh
source "$INTERFACE"

# --- Parse arguments ---
intermediate_dir="${1:?Usage: milestone-tiering.sh <intermediate_dir> <target_root> [--recent-count N]}"
target_root="${2:?Usage: milestone-tiering.sh <intermediate_dir> <target_root> [--recent-count N]}"
shift 2

recent_count=3

while [ $# -gt 0 ]; do
    case "$1" in
        --recent-count)
            recent_count="${2:-3}"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

milestones_dat="${intermediate_dir}/milestones.dat"

if [ ! -f "$milestones_dat" ]; then
    echo "ERROR: milestones.dat not found at $milestones_dat" >&2
    exit 1
fi

# --- Create output directories ---
mkdir -p "${target_root}/milestones/summaries"
mkdir -p "${target_root}/milestones/rollups"

# --- Classify milestones ---
# Collect active and completed milestones separately
active_ids=""
active_count=0
completed_lines=""
completed_count=0

while IFS= read -r line; do
    ms_id="$(printf '%s' "$line" | awk -F'\t' '{print $1}')"
    ms_title="$(printf '%s' "$line" | awk -F'\t' '{print $2}')"
    ms_status="$(printf '%s' "$line" | awk -F'\t' '{print $3}')"
    ms_end="$(printf '%s' "$line" | awk -F'\t' '{print $6}')"

    # Skip header
    if [ "$ms_id" = "id" ]; then
        continue
    fi

    # Classify by status
    case "$ms_status" in
        *in_progress*|*active*|*in-progress*)
            active_ids="${active_ids}${ms_id}	${ms_title}
"
            active_count=$((active_count + 1))
            ;;
        *complete*|*done*|*closed*)
            # Store with end_date and ID for sorting
            completed_lines="${completed_lines}${ms_id}	${ms_title}	${ms_end}
"
            completed_count=$((completed_count + 1))
            ;;
        *)
            # Unknown status -- treat as historical
            completed_lines="${completed_lines}${ms_id}	${ms_title}	${ms_end}
"
            completed_count=$((completed_count + 1))
            ;;
    esac
done < "$milestones_dat"

# --- Sort completed milestones by end_date descending, then by ID number descending ---
# Extract numeric part of ID for sorting
sorted_completed=""
if [ -n "$completed_lines" ]; then
    # Sort by end_date descending (field 3), then by numeric ID descending
    # The ID is like M013, M041 etc. We sort by the number after M.
    sorted_completed="$(printf '%s' "$completed_lines" | grep -v '^$' | sort -t'	' -k3 -r | sort -s -t'	' -k3 -r)"

    # If end_dates are identical or empty, fall back to ID-based sorting
    # Re-sort by extracting numeric ID
    sorted_completed="$(printf '%s' "$completed_lines" | grep -v '^$' | while IFS='	' read -r cid ctitle cend; do
        cnum="$(printf '%s' "$cid" | sed 's/^M0*//')"
        printf '%s\t%s\t%s\t%s\n' "$cnum" "$cid" "$ctitle" "$cend"
    done | sort -t'	' -k1 -rn | cut -f2-)"
fi

# --- Determine recent vs historical ---
recent_ids=""
historical_ids=""
idx=0

if [ -n "$sorted_completed" ]; then
    printf '%s\n' "$sorted_completed" | while IFS='	' read -r cid ctitle cend; do
        [ -z "$cid" ] && continue
        idx=$((idx + 1))
        if [ "$idx" -le "$recent_count" ]; then
            printf 'recent\t%s\t%s\n' "$cid" "$ctitle"
        else
            printf 'historical\t%s\t%s\n' "$cid" "$ctitle"
        fi
    done > "${intermediate_dir}/_tier_classifications.tmp"
fi

# --- Write classification file ---
tiers_file="${target_root}/.migration-tiers.dat"
printf 'milestone_id\ttier\ttitle\n' > "$tiers_file"

# Active milestones
if [ -n "$active_ids" ]; then
    printf '%s' "$active_ids" | while IFS='	' read -r aid atitle; do
        [ -z "$aid" ] && continue
        printf '%s\tactive\t%s\n' "$aid" "$atitle" >> "$tiers_file"
    done
fi

# Recent and historical
if [ -f "${intermediate_dir}/_tier_classifications.tmp" ]; then
    while IFS='	' read -r ctier cid ctitle; do
        [ -z "$cid" ] && continue
        printf '%s\t%s\t%s\n' "$cid" "$ctier" "$ctitle" >> "$tiers_file"
    done < "${intermediate_dir}/_tier_classifications.tmp"
fi

# --- Report classification ---
recent_actual=0
historical_actual=0
if [ -f "${intermediate_dir}/_tier_classifications.tmp" ]; then
    recent_actual="$(awk -F'\t' '$1 == "recent"' "${intermediate_dir}/_tier_classifications.tmp" | wc -l | tr -d ' ')"
    historical_actual="$(awk -F'\t' '$1 == "historical"' "${intermediate_dir}/_tier_classifications.tmp" | wc -l | tr -d ' ')"
fi

echo "TIERING: ${active_count} active, ${recent_actual} recent, ${historical_actual} historical"

# --- Select the primary active milestone for full conversion ---
# Pick the highest-numbered active milestone as the primary one to convert to M001
primary_active=""
if [ -n "$active_ids" ]; then
    primary_active="$(printf '%s' "$active_ids" | grep -v '^$' | while IFS='	' read -r aid atitle; do
        anum="$(printf '%s' "$aid" | sed 's/^M0*//')"
        printf '%s\t%s\n' "$anum" "$aid"
    done | sort -t'	' -k1 -rn | head -1 | cut -f2)"
fi

# --- Execute sub-transforms ---

# Active milestone -> full orchestrator conversion
if [ -n "$primary_active" ]; then
    echo "TIERING: Converting primary active milestone ${primary_active} -> M001"
    bash "${SCRIPT_DIR}/active-milestone.sh" "$intermediate_dir" "$target_root" "$primary_active"
fi

# Recent milestones -> summaries
if [ -f "${intermediate_dir}/_tier_classifications.tmp" ]; then
    while IFS='	' read -r ctier cid ctitle; do
        [ -z "$cid" ] && continue
        if [ "$ctier" = "recent" ]; then
            bash "${SCRIPT_DIR}/milestone-rollup.sh" "$intermediate_dir" "$target_root" "$cid" --tier recent
        fi
    done < "${intermediate_dir}/_tier_classifications.tmp"
fi

# Historical milestones -> rollups
if [ -f "${intermediate_dir}/_tier_classifications.tmp" ]; then
    while IFS='	' read -r ctier cid ctitle; do
        [ -z "$cid" ] && continue
        if [ "$ctier" = "historical" ]; then
            bash "${SCRIPT_DIR}/milestone-rollup.sh" "$intermediate_dir" "$target_root" "$cid" --tier historical
        fi
    done < "${intermediate_dir}/_tier_classifications.tmp"
fi

# Telemetry aggregation
echo "TIERING: Running telemetry aggregation..."
bash "${SCRIPT_DIR}/telemetry-aggregator.sh" "$intermediate_dir" "$target_root"

# --- Cleanup temp files ---
rm -f "${intermediate_dir}/_tier_classifications.tmp"

echo "TIERING: Complete. Output at ${target_root}"
