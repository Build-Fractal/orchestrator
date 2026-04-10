#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# telemetry-aggregator.sh — Aggregate raw telemetry into per-milestone metrics
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+ (no associative arrays, no readarray)
#
# Usage: telemetry-aggregator.sh <intermediate_dir> <target_root>
#
# Reads telemetry.dat and milestones.dat, groups verification evidence by
# milestone, computes per-milestone aggregate metrics, and writes
# EXECUTION-HISTORY.md to the target root.
#
# Telemetry fields (extended):
#   id, timestamp, event_type, entity_id, entity_type, details,
#   source_file, milestone_id, slice_id
#
# The details field contains: command|exit=N|dur=Nms
#
# Idempotent: output file is overwritten on each run.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INTERFACE="${SCRIPT_DIR}/../adapter-interface.sh"

# shellcheck source=../adapter-interface.sh
source "$INTERFACE"

# --- Parse arguments ---
intermediate_dir="${1:?Usage: telemetry-aggregator.sh <intermediate_dir> <target_root>}"
target_root="${2:?Usage: telemetry-aggregator.sh <intermediate_dir> <target_root>}"

telemetry_dat="${intermediate_dir}/telemetry.dat"
milestones_dat="${intermediate_dir}/milestones.dat"
output_file="${target_root}/EXECUTION-HISTORY.md"

migration_date="$(date '+%Y-%m-%d')"

mkdir -p "$target_root"

# --- Collect milestone IDs in reverse order (highest first) ---
milestone_ids=""
if [ -f "$milestones_dat" ]; then
    milestone_ids="$(tail -n +2 "$milestones_dat" | awk -F'\t' '{print $1}' | sort -t'M' -k1.2 -rn)"
fi

# --- Write header ---
cat > "$output_file" <<EOF
# Execution History

> Aggregated from GSD2 telemetry data. Migrated on ${migration_date}.

| Milestone | Verifications | Avg Duration | Pass Rate | Notable |
|-----------|--------------|-------------|-----------|---------|
EOF

# --- Process each milestone ---
total_milestones=0
total_verifications=0

if [ -f "$telemetry_dat" ]; then
    # Process milestones in reverse ID order
    for mid in $milestone_ids; do
        # Extract rows for this milestone (field 8 = milestone_id)
        mid_rows="$(tail -n +2 "$telemetry_dat" | awk -F'\t' -v mid="$mid" '$8 == mid')"

        if [ -z "$mid_rows" ]; then
            continue
        fi

        # Count total verifications
        ver_count="$(printf '%s\n' "$mid_rows" | wc -l | tr -d ' ')"

        # Count passes (event_type/verdict contains "pass")
        pass_count="$(printf '%s\n' "$mid_rows" | awk -F'\t' 'tolower($3) ~ /pass/' | wc -l | tr -d ' ')"

        # Calculate pass rate
        if [ "$ver_count" -gt 0 ]; then
            pass_rate="$(( (pass_count * 100) / ver_count ))"
        else
            pass_rate=0
        fi

        # Extract durations from details field (field 6)
        # Details format: command|exit=N|dur=Nms
        total_dur=0
        dur_count=0
        while IFS= read -r row; do
            details="$(printf '%s' "$row" | awk -F'\t' '{print $6}')"
            # Extract duration: dur=NNNms
            dur_val="$(printf '%s' "$details" | sed -n 's/.*dur=\([0-9]*\)ms.*/\1/p')"
            if [ -n "$dur_val" ] && [ "$dur_val" -gt 0 ] 2>/dev/null; then
                total_dur=$((total_dur + dur_val))
                dur_count=$((dur_count + 1))
            fi
        done <<ROWEOF
${mid_rows}
ROWEOF

        avg_dur="0"
        if [ "$dur_count" -gt 0 ]; then
            avg_dur_ms="$(( total_dur / dur_count ))"
            if [ "$avg_dur_ms" -ge 1000 ]; then
                avg_dur_s="$(( avg_dur_ms / 1000 ))"
                avg_dur="${avg_dur_s}s"
            else
                avg_dur="${avg_dur_ms}ms"
            fi
        fi

        # Notable: detect failures
        notable="-"
        fail_count="$(printf '%s\n' "$mid_rows" | awk -F'\t' 'tolower($3) ~ /fail/' | wc -l | tr -d ' ')"
        if [ "$fail_count" -gt 0 ]; then
            notable="${fail_count} failure(s)"
        fi

        printf '| %s | %d | %s | %d%% | %s |\n' \
            "$mid" "$ver_count" "$avg_dur" "$pass_rate" "$notable" >> "$output_file"

        total_milestones=$((total_milestones + 1))
        total_verifications=$((total_verifications + ver_count))
    done
fi

# --- Write footer ---
cat >> "$output_file" <<EOF

## Summary
- **Milestones with telemetry**: ${total_milestones}
- **Total verifications**: ${total_verifications}
- **Migration date**: ${migration_date}
- **Source**: GSD2 verification_evidence table
EOF

echo "TELEMETRY: Aggregated ${total_verifications} verifications across ${total_milestones} milestones"
