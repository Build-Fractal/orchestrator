#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# active-milestone.sh — Convert active milestone to orchestrator format
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+ (no associative arrays, no readarray)
#
# Usage: active-milestone.sh <intermediate_dir> <target_root> <milestone_id>
#
# Converts the active (in-progress) milestone to orchestrator format,
# renumbered as M001. Each slice becomes a phase (S01->P01, S02->P02, etc).
# Completed slices get a SUMMARY.md; active/pending slices get a PLAN.md.
#
# Idempotent: existing files are overwritten (migration is repeatable).
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INTERFACE="${SCRIPT_DIR}/../adapter-interface.sh"

# shellcheck source=../adapter-interface.sh
source "$INTERFACE"

# --- Parse arguments ---
intermediate_dir="${1:?Usage: active-milestone.sh <intermediate_dir> <target_root> <milestone_id>}"
target_root="${2:?Usage: active-milestone.sh <intermediate_dir> <target_root> <milestone_id>}"
milestone_id="${3:?Usage: active-milestone.sh <intermediate_dir> <target_root> <milestone_id>}"

milestones_dat="${intermediate_dir}/milestones.dat"
slices_dat="${intermediate_dir}/slices.dat"
tasks_dat="${intermediate_dir}/tasks.dat"

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

# Unescape fields
ms_title="$(unescape_field "$ms_title")"
ms_desc="$(unescape_field "$ms_desc")"

# Fallback title
if [ -z "$ms_title" ]; then
    ms_title="Migrated from ${milestone_id}"
fi

# --- Create output directory ---
ms_dir="${target_root}/.specify/orchestrator/milestones/M001"
mkdir -p "${ms_dir}/phases"

# --- Write M001-EVALUATION.md ---
cat > "${ms_dir}/M001-EVALUATION.md" <<EOF
---
schema_version: "1.0"
type: evaluation
milestone: "M001"
feature_ref: "migrated-from-gsd2"
original_id: "${milestone_id}"
tier: "C"
status: "active"
created_at: "${migration_date}"
updated_at: "${migration_date}"
---

# M001: ${ms_title}

## Origin
Migrated from GSD2 milestone ${milestone_id} on ${migration_date}.

## Description
${ms_desc:-No description available.}

## Scope
Tier C (multi-phase orchestration). Automatically classified during migration.
EOF

# --- Collect slices for this milestone ---
slice_count=0
phase_lines=""

if [ -f "$slices_dat" ]; then
    while IFS= read -r line; do
        s_mid="$(printf '%s' "$line" | awk -F'\t' '{print $2}')"
        if [ "$s_mid" = "$milestone_id" ]; then
            slice_count=$((slice_count + 1))
            s_id="$(printf '%s' "$line" | awk -F'\t' '{print $1}')"
            s_title="$(printf '%s' "$line" | awk -F'\t' '{print $3}')"
            s_status="$(printf '%s' "$line" | awk -F'\t' '{print $4}')"
            s_desc="$(printf '%s' "$line" | awk -F'\t' '{print $5}')"
            s_order="$(printf '%s' "$line" | awk -F'\t' '{print $6}')"

            # Unescape
            s_title="$(unescape_field "$s_title")"
            s_desc="$(unescape_field "$s_desc")"

            # Derive phase number from slice ID (S01 -> P01)
            s_num="$(printf '%s' "$s_id" | sed 's/^S//')"
            p_id="$(printf 'P%02d' "$s_num")"

            # Accumulate for roadmap
            phase_lines="${phase_lines}${p_id}	${s_id}	${s_title}	${s_status}	${s_desc}
"

            # Create phase directory
            phase_dir="${ms_dir}/phases/${p_id}"
            mkdir -p "${phase_dir}/tasks"

            # Write phase file based on status
            if [ "$s_status" = "complete" ] || [ "$s_status" = "completed" ]; then
                # Completed slice -> SUMMARY.md
                cat > "${phase_dir}/${p_id}-SUMMARY.md" <<PEOF
---
schema_version: "1.0"
type: phase_summary
phase: "${p_id}"
milestone: "M001"
original_slice: "${s_id}"
status: "complete"
migrated_from: gsd2
created_at: "${migration_date}"
---

# ${p_id}: ${s_title}

Completed phase, migrated from GSD2 slice ${s_id}.

## Description
${s_desc:-No description available.}

## Status
This phase was completed in the source GSD2 project.
PEOF
            else
                # Active/pending slice -> PLAN.md with tasks
                cat > "${phase_dir}/${p_id}-PLAN.md" <<PEOF
---
schema_version: "1.0"
type: phase_plan
phase: "${p_id}"
milestone: "M001"
original_slice: "${s_id}"
status: "${s_status}"
migrated_from: gsd2
created_at: "${migration_date}"
---

# ${p_id}: ${s_title}

Migrated from GSD2 slice ${s_id} (status: ${s_status}).

## Description
${s_desc:-No description available.}

## Tasks
PEOF

                # Add tasks for this slice
                if [ -f "$tasks_dat" ]; then
                    task_idx=0
                    while IFS= read -r tline; do
                        t_sid="$(printf '%s' "$tline" | awk -F'\t' '{print $2}')"
                        t_mid="$(printf '%s' "$tline" | awk -F'\t' '{print $3}')"
                        if [ "$t_sid" = "$s_id" ] && [ "$t_mid" = "$milestone_id" ]; then
                            task_idx=$((task_idx + 1))
                            t_id="$(printf '%s' "$tline" | awk -F'\t' '{print $1}')"
                            t_title="$(printf '%s' "$tline" | awk -F'\t' '{print $4}')"
                            t_status="$(printf '%s' "$tline" | awk -F'\t' '{print $5}')"
                            t_desc="$(printf '%s' "$tline" | awk -F'\t' '{print $6}')"

                            t_title="$(unescape_field "$t_title")"
                            t_desc="$(unescape_field "$t_desc")"

                            t_num="$(printf '%s' "$t_id" | sed 's/^T//')"
                            new_t_id="$(printf 'T%02d' "$t_num")"

                            # Append to PLAN.md task list
                            local_check=" "
                            if [ "$t_status" = "complete" ] || [ "$t_status" = "completed" ]; then
                                local_check="x"
                            fi
                            printf -- '- [%s] %s: %s (%s)\n' "$local_check" "$new_t_id" "$t_title" "$t_status" >> "${phase_dir}/${p_id}-PLAN.md"

                            # Write individual task plan
                            cat > "${phase_dir}/tasks/${new_t_id}-PLAN.md" <<TEOF
---
schema_version: "1.0"
type: task_plan
task: "${new_t_id}"
phase: "${p_id}"
milestone: "M001"
original_task: "${t_id}"
original_slice: "${s_id}"
original_milestone: "${milestone_id}"
status: "${t_status}"
migrated_from: gsd2
created_at: "${migration_date}"
---

# ${new_t_id}: ${t_title}

## Description
${t_desc:-No description available.}

## Status
${t_status} (migrated from GSD2)
TEOF
                        fi
                    done < "$tasks_dat"

                    if [ "$task_idx" -eq 0 ]; then
                        echo "No tasks found for this phase." >> "${phase_dir}/${p_id}-PLAN.md"
                    fi
                fi
            fi
        fi
    done < "$slices_dat"
fi

# --- Write M001-ROADMAP.md ---
cat > "${ms_dir}/M001-ROADMAP.md" <<EOF
---
schema_version: "1.0"
type: roadmap
milestone: "M001"
feature_ref: "migrated-from-gsd2"
feature_spec: ""
vision: "$(printf '%s' "$ms_desc" | head -c 200)"
tier: "C"
created_at: "${migration_date}"
updated_at: "${migration_date}"
---

# M001 Roadmap: ${ms_title}

> Migrated from GSD2 milestone ${milestone_id} on ${migration_date}.

## Phases

| Phase | Original | Title | Status |
|-------|----------|-------|--------|
EOF

# Write phase rows
if [ -n "$phase_lines" ]; then
    printf '%s' "$phase_lines" | while IFS='	' read -r p_id s_id s_title s_status s_desc; do
        [ -z "$p_id" ] && continue
        printf '| %s | %s | %s | %s |\n' "$p_id" "$s_id" "$s_title" "$s_status" >> "${ms_dir}/M001-ROADMAP.md"
    done
fi

echo "ACTIVE: Converted ${milestone_id} -> M001 with ${slice_count} phases"
