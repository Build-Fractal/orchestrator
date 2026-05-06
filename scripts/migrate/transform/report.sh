#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# report.sh — Generate MIGRATION-REPORT.md from migration output
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+
#
# Usage: report.sh <intermediate_dir> <target_root> <source_type>
#
# Reads extracted .dat files and transformed output to produce a summary
# report at <target_root>/MIGRATION-REPORT.md.
#
# Idempotent: overwrites the report on re-run.
# =============================================================================

intermediate_dir="${1:?Usage: report.sh <intermediate_dir> <target_root> <source_type>}"
target_root="${2:?Usage: report.sh <intermediate_dir> <target_root> <source_type>}"
source_type="${3:?Usage: report.sh <intermediate_dir> <target_root> <source_type>}"

# --- Helpers ---

# count_files <dir> <pattern> — count files matching a glob in a directory
count_files() {
    local dir="$1"
    local pattern="$2"
    local count=0
    if [ -d "$dir" ]; then
        # Use find to count, avoiding glob expansion issues
        count=$(find "$dir" -maxdepth 1 -name "$pattern" 2>/dev/null | wc -l | tr -d ' ')
    fi
    echo "$count"
}

# count_files_recursive <dir> <pattern> — count files matching a glob recursively
count_files_recursive() {
    local dir="$1"
    local pattern="$2"
    local count=0
    if [ -d "$dir" ]; then
        count=$(find "$dir" -name "$pattern" 2>/dev/null | wc -l | tr -d ' ')
    fi
    echo "$count"
}

# count_dat_records <file> — count data records in a TSV (lines minus header)
count_dat_records() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "0"
        return
    fi
    local total
    total="$(wc -l < "$file" | tr -d ' ')"
    if [ "$total" -le 1 ]; then
        echo "0"
    else
        echo "$(( total - 1 ))"
    fi
}

# count_file_lines <file> — count lines in a file
count_file_lines() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "0"
        return
    fi
    wc -l < "$file" | tr -d ' '
}

# --- Gather statistics ---

# Knowledge
knowledge_active=$(find "$target_root/knowledge" -name "MEM*.md" -not -path "*/archive/*" 2>/dev/null | wc -l | tr -d ' ')
knowledge_archived=$(find "$target_root/knowledge/archive" -name "MEM*.md" 2>/dev/null | wc -l | tr -d ' ')

# Knowledge categories (count per category directory)
knowledge_categories=""
if [ -d "$target_root/knowledge" ]; then
    for cat_dir in "$target_root/knowledge"/*/; do
        if [ -d "$cat_dir" ]; then
            cat_name="$(basename "$cat_dir")"
            if [ "$cat_name" = "archive" ]; then
                continue
            fi
            cat_count=$(find "$cat_dir" -maxdepth 1 -name "MEM*.md" 2>/dev/null | wc -l | tr -d ' ')
            if [ "$cat_count" -gt 0 ]; then
                if [ -n "$knowledge_categories" ]; then
                    knowledge_categories="${knowledge_categories}, ${cat_name} (${cat_count})"
                else
                    knowledge_categories="${cat_name} (${cat_count})"
                fi
            fi
        fi
    done
fi

# Decisions
decisions_count=$(count_dat_records "${intermediate_dir}/decisions.dat")
# Find the highest decision number from DECISIONS.md
next_decision=""
if [ -f "$target_root/DECISIONS.md" ]; then
    # Look for D### patterns and find the max
    last_d=$(grep -oE 'D[0-9]+' "$target_root/DECISIONS.md" 2>/dev/null | sed 's/D//' | sort -n | tail -1)
    if [ -n "$last_d" ]; then
        next_decision="D$(( last_d + 1 ))"
    fi
fi

# Requirements
requirements_active=0
requirements_archived=0
if [ -f "$target_root/REQUIREMENTS.md" ]; then
    # Count table rows (lines starting with |R or | R)
    requirements_active=$(grep -cE '^\| *R[0-9]' "$target_root/REQUIREMENTS.md" 2>/dev/null || echo "0")
fi
if [ -f "$target_root/REQUIREMENTS-ARCHIVE.md" ]; then
    requirements_archived=$(grep -cE '^\| *R[0-9]' "$target_root/REQUIREMENTS-ARCHIVE.md" 2>/dev/null || echo "0")
fi

# Milestones
milestone_active=0
milestone_recent=0
milestone_historical=0
milestone_total=0
if [ -f "$target_root/.migration-tiers.dat" ]; then
    # .migration-tiers.dat format: milestone_id<TAB>tier<TAB>...
    milestone_active=$(grep -c "	active	" "$target_root/.migration-tiers.dat" 2>/dev/null || echo "0")
    milestone_recent=$(grep -c "	recent	" "$target_root/.migration-tiers.dat" 2>/dev/null || echo "0")
    milestone_historical=$(grep -c "	historical	" "$target_root/.migration-tiers.dat" 2>/dev/null || echo "0")
    milestone_total=$(count_dat_records "${intermediate_dir}/milestones.dat")
fi

# Telemetry
telemetry_count=$(count_dat_records "${intermediate_dir}/telemetry.dat")

# Warnings
warnings=""
warning_count=0
if [ -f "${intermediate_dir}/warnings.dat" ]; then
    warning_count=$(count_dat_records "${intermediate_dir}/warnings.dat")
    if [ "$warning_count" -gt 0 ]; then
        warnings=$(tail -n +2 "${intermediate_dir}/warnings.dat" 2>/dev/null | while IFS="	" read -r ts code msg src; do
            echo "- **[$code]** $msg"
            if [ -n "$src" ]; then
                echo "  Source: \`$src\`"
            fi
        done)
    fi
fi

# --- Generate date ---
migration_date="$(date +%Y-%m-%d)"

# --- Write report atomically ---
tmp_report="${target_root}/MIGRATION-REPORT.md.tmp.$$"
cat > "$tmp_report" <<REPORT
# Migration Report

> Migrated from ${source_type} on ${migration_date}

## Source Summary
- **Type**: ${source_type}
- **Intermediate data**: ${intermediate_dir}

## Knowledge
- Active entries migrated: ${knowledge_active}
- Superseded entries archived: ${knowledge_archived}
- Categories: ${knowledge_categories:-none}

## Decisions
- Migrated: ${decisions_count}
- Numbering continues from: ${next_decision:-N/A}

## Requirements
- Active: ${requirements_active}
- Archived: ${requirements_archived}

## Milestones
- Active (full conversion): ${milestone_active}
- Recent (summary): ${milestone_recent}
- Historical (rollup): ${milestone_historical}
- Total extracted: ${milestone_total}

## Telemetry
- Execution units aggregated: ${telemetry_count}

## Warnings
REPORT

if [ "$warning_count" -gt 0 ]; then
    echo "$warnings" >> "$tmp_report"
else
    echo "No warnings." >> "$tmp_report"
fi

cat >> "$tmp_report" <<'REPORT'

## Next Steps
1. Review the migrated knowledge entries in `knowledge/`
2. Check DECISIONS.md for accuracy
3. Run `/orchestrator-status` to verify orchestrator state
4. Begin your next milestone with the orchestrator
REPORT

mv "$tmp_report" "${target_root}/MIGRATION-REPORT.md"
