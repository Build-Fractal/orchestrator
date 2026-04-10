#!/usr/bin/env bash
# scripts/migrate/adapters/gsd1.sh — GSD v1 source adapter
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+ (no associative arrays, no pipe-ampersand)
#
# Implements the full adapter interface contract for GSD v1 sources.
# GSD v1 stores data in a .planning/ directory with flat markdown files:
#
#   .planning/
#     KNOWLEDGE.md          -- flat markdown list of knowledge entries
#     DECISIONS.md          -- markdown table of decisions
#     milestones/
#       M001/
#         SUMMARY.md        -- milestone summary
#         slices/
#           S01/
#             PLAN.md       -- slice plan
#
# Prerequisites:
#   source adapter-interface.sh   (must be sourced before this file)
# =============================================================================
set -euo pipefail

# Resolve script directory and source dependencies
_GSD1_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_GSD1_SCRIPT_DIR}/../lib/category-inferrer.sh"

# =============================================================================
# _gsd1_resolve_planning_dir <source_path>
#   Resolve the .planning directory from a project path.
#   Echoes the resolved path.
# =============================================================================
_gsd1_resolve_planning_dir() {
    local source_path="$1"
    if [ -d "${source_path}/.planning" ]; then
        echo "${source_path}/.planning"
    else
        echo "$source_path"
    fi
}

# =============================================================================
# detect_source <path>
#   Echo "yes" if path contains a GSD v1 project (.planning/ directory),
#   "no" otherwise.
# =============================================================================
detect_source() {
    local path="$1"
    # GSD v1 uses .planning/ directory
    if [ -d "${path}/.planning" ]; then
        echo "yes"
    elif [ -d "${path}" ] && [ -f "${path}/KNOWLEDGE.md" ] 2>/dev/null; then
        # Path IS the .planning dir
        echo "yes"
    else
        echo "no"
    fi
    return 0
}

# =============================================================================
# extract_knowledge <source_path> <output_dir>
#   Extract knowledge records from KNOWLEDGE.md.
#   Parses ## headings as entry boundaries.
# =============================================================================
extract_knowledge() {
    local source_path="$1"
    local output_dir="$2"
    init_output_dir "$output_dir"

    local planning_dir
    planning_dir="$(_gsd1_resolve_planning_dir "$source_path")"

    write_header "${output_dir}/knowledge.dat" "$KNOWLEDGE_FIELDS"

    local knowledge_file="${planning_dir}/KNOWLEDGE.md"
    if [ ! -f "$knowledge_file" ]; then
        emit_warning "$output_dir" "missing" "No KNOWLEDGE.md found" "$knowledge_file"
        return 0
    fi

    # Parse flat markdown: entries start with ## headings
    # Format: "## K001: Title" followed by body paragraphs
    local entry_id=""
    local entry_content=""
    local entry_num=0

    while IFS= read -r line || [ -n "$line" ]; do
        # Detect entry headers: ## K### or ## MEM### or any ## [A-Z]...
        if echo "$line" | grep -qE '^## [A-Z]'; then
            # Save previous entry
            if [ -n "$entry_id" ] && [ -n "$entry_content" ]; then
                local cat
                cat="$(infer_category "$entry_content")"
                local title
                title="$(printf '%s' "$entry_content" | head -1 | head -c 80)"
                append_record "${output_dir}/knowledge.dat" \
                    "$entry_id" "$cat" "$title" "$entry_content" \
                    "" "0.80" "0" "" "" ""
            fi
            # Start new entry
            entry_num=$((entry_num + 1))
            entry_id="$(echo "$line" | grep -oE '[A-Z]+[0-9]+' | head -1)"
            if [ -z "$entry_id" ]; then
                entry_id="$(printf 'MEM%03d' $entry_num)"
            fi
            entry_content="$(echo "$line" | sed 's/^## [A-Za-z0-9]*:[[:space:]]*//')"
        elif [ -n "$entry_id" ]; then
            if [ -n "$line" ]; then
                entry_content="${entry_content}
${line}"
            fi
        fi
    done < "$knowledge_file"

    # Save last entry
    if [ -n "$entry_id" ] && [ -n "$entry_content" ]; then
        local cat
        cat="$(infer_category "$entry_content")"
        local title
        title="$(printf '%s' "$entry_content" | head -1 | head -c 80)"
        append_record "${output_dir}/knowledge.dat" \
            "$entry_id" "$cat" "$title" "$entry_content" \
            "" "0.80" "0" "" "" ""
    fi
}

# =============================================================================
# extract_decisions <source_path> <output_dir>
#   Extract decision records from DECISIONS.md markdown table.
#   Parses pipe-separated table rows, skipping header and separator lines.
# =============================================================================
extract_decisions() {
    local source_path="$1"
    local output_dir="$2"
    init_output_dir "$output_dir"

    local planning_dir
    planning_dir="$(_gsd1_resolve_planning_dir "$source_path")"

    write_header "${output_dir}/decisions.dat" "$DECISIONS_FIELDS"

    local decisions_file="${planning_dir}/DECISIONS.md"
    if [ ! -f "$decisions_file" ]; then
        emit_warning "$output_dir" "missing" "No DECISIONS.md found" "$decisions_file"
        return 0
    fi

    # Parse markdown table with | separators
    # Expected columns: ID | Decision | Choice | Scope | When | Rationale
    # Map to: id, title (Decision), status (accepted), date (empty),
    #         context (Scope+When), decision (Choice), consequences (empty),
    #         revisable (true), made_by (empty), superseded_by (empty)
    local in_table=0
    local header_skipped=0

    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and non-table lines
        case "$line" in
            *"|"*)
                # This is a table line
                ;;
            *)
                # Reset table state on non-table line if we were in a table
                if [ "$in_table" -eq 1 ]; then
                    in_table=0
                    header_skipped=0
                fi
                continue
                ;;
        esac

        # Skip separator lines (|---|---|...)
        if echo "$line" | grep -qE '^\|[[:space:]]*[-:]+'; then
            in_table=1
            continue
        fi

        # Skip the header row (first row before separator)
        if [ "$in_table" -eq 0 ]; then
            # This is the header row; mark that we've seen it but don't skip yet
            # The separator line will set in_table=1
            continue
        fi

        # Parse data row: | col1 | col2 | col3 | ... |
        # Strip leading/trailing pipes and split
        local stripped
        stripped="$(echo "$line" | sed 's/^[[:space:]]*|//;s/|[[:space:]]*$//')"

        # Extract fields using awk with | delimiter
        local d_id d_decision d_choice d_scope d_when d_rationale
        d_id="$(echo "$stripped" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1); print $1}')"
        d_decision="$(echo "$stripped" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')"
        d_choice="$(echo "$stripped" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3); print $3}')"
        d_scope="$(echo "$stripped" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4); print $4}')"
        d_when="$(echo "$stripped" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $5); print $5}')"
        d_rationale="$(echo "$stripped" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $6); print $6}')"

        # Skip if no ID
        if [ -z "$d_id" ]; then
            continue
        fi

        # Map to intermediate format
        # title = Decision text, decision = Choice, context = "Scope: $scope, When: $when"
        local context="Scope: ${d_scope}, When: ${d_when}"
        append_record "${output_dir}/decisions.dat" \
            "$d_id" "$d_decision" "accepted" "" \
            "$context" "$d_choice" "$d_rationale" \
            "true" "" ""
    done < "$decisions_file"
}

# =============================================================================
# extract_requirements <source_path> <output_dir>
#   GSD v1 typically has no structured requirements file.
#   Writes header-only file and emits warning.
# =============================================================================
extract_requirements() {
    local source_path="$1"
    local output_dir="$2"
    init_output_dir "$output_dir"

    write_header "${output_dir}/requirements.dat" "$REQUIREMENTS_FIELDS"
    emit_warning "$output_dir" "unsupported" \
        "GSD v1 does not have structured requirements; requirements.dat is header-only" \
        "$source_path"
}

# =============================================================================
# extract_milestones <source_path> <output_dir>
#   Scan .planning/milestones/M###/ directories. Each directory with a
#   SUMMARY.md represents a milestone. Extract title, status, and description.
#   Also produces slices.dat and tasks.dat (header-only for GSD v1).
# =============================================================================
extract_milestones() {
    local source_path="$1"
    local output_dir="$2"
    init_output_dir "$output_dir"

    local planning_dir
    planning_dir="$(_gsd1_resolve_planning_dir "$source_path")"

    write_header "${output_dir}/milestones.dat" "$MILESTONES_FIELDS"
    write_header "${output_dir}/slices.dat" "$SLICES_FIELDS"
    write_header "${output_dir}/tasks.dat" "$TASKS_FIELDS"

    local milestones_dir="${planning_dir}/milestones"
    if [ ! -d "$milestones_dir" ]; then
        emit_warning "$output_dir" "missing" \
            "No milestones/ directory found in .planning" "$milestones_dir"
        return 0
    fi

    # Scan for milestone directories (M001, M002, etc.)
    local found_any=0
    for m_dir in "$milestones_dir"/M[0-9]*/; do
        # Check that the glob matched (Bash 3.2: glob may not expand)
        if [ ! -d "$m_dir" ]; then
            continue
        fi
        found_any=1

        local m_id
        m_id="$(basename "$m_dir")"

        local summary_file="${m_dir}SUMMARY.md"
        local m_title=""
        local m_status=""
        local m_description=""

        if [ -f "$summary_file" ]; then
            # Parse SUMMARY.md for title, status, and description
            # Expected format:
            #   # M001: Title Here
            #   Status: complete
            #   Description text follows...

            local parsing_header=1
            while IFS= read -r line || [ -n "$line" ]; do
                # Extract title from first # heading
                if [ -z "$m_title" ]; then
                    case "$line" in
                        "# "*)
                            m_title="$(echo "$line" | sed 's/^# [A-Z0-9]*:[[:space:]]*//')"
                            # If sed didn't match the pattern, use full heading
                            if [ "$m_title" = "$line" ]; then
                                m_title="$(echo "$line" | sed 's/^# //')"
                            fi
                            continue
                            ;;
                    esac
                fi

                # Extract status line
                if [ -z "$m_status" ]; then
                    case "$line" in
                        [Ss]tatus:*)
                            m_status="$(echo "$line" | sed 's/^[Ss]tatus:[[:space:]]*//')"
                            # Normalize to lowercase
                            m_status="$(printf '%s' "$m_status" | tr '[:upper:]' '[:lower:]')"
                            continue
                            ;;
                    esac
                fi

                # Remaining non-empty lines are description
                if [ -n "$m_title" ] && [ -n "$line" ]; then
                    case "$line" in
                        "# "*|[Ss]tatus:*)
                            # Skip heading/status lines
                            ;;
                        *)
                            if [ -n "$m_description" ]; then
                                m_description="${m_description} ${line}"
                            else
                                m_description="$line"
                            fi
                            ;;
                    esac
                fi
            done < "$summary_file"
        fi

        # Default title if none found
        if [ -z "$m_title" ]; then
            m_title="$m_id"
        fi
        # Default status if none found
        if [ -z "$m_status" ]; then
            m_status="unknown"
        fi

        append_record "${output_dir}/milestones.dat" \
            "$m_id" "$m_title" "$m_status" "$m_description" "" ""

        # Scan for slices within this milestone
        local slices_dir="${m_dir}slices"
        if [ -d "$slices_dir" ]; then
            local slice_order=0
            for s_dir in "$slices_dir"/S[0-9]*/; do
                if [ ! -d "$s_dir" ]; then
                    continue
                fi
                slice_order=$((slice_order + 1))
                local s_id
                s_id="$(basename "$s_dir")"
                local s_title="$s_id"
                local s_status="unknown"
                local s_description=""

                # Try to parse PLAN.md for slice info
                local plan_file="${s_dir}PLAN.md"
                if [ -f "$plan_file" ]; then
                    # Extract title from first heading
                    s_title="$(grep -m1 '^# ' "$plan_file" | sed 's/^# //' || echo "$s_id")"
                    if [ -z "$s_title" ]; then
                        s_title="$s_id"
                    fi
                fi

                append_record "${output_dir}/slices.dat" \
                    "$s_id" "$m_id" "$s_title" "$s_status" "$s_description" "$slice_order"
            done
        fi
    done

    if [ "$found_any" -eq 0 ]; then
        emit_warning "$output_dir" "empty" \
            "milestones/ directory exists but contains no M### subdirectories" \
            "$milestones_dir"
    fi
}

# =============================================================================
# extract_telemetry <source_path> <output_dir>
#   GSD v1 has no telemetry data.
#   Writes header-only file.
# =============================================================================
extract_telemetry() {
    local source_path="$1"
    local output_dir="$2"
    init_output_dir "$output_dir"

    write_header "${output_dir}/telemetry.dat" "$TELEMETRY_FIELDS"
    emit_warning "$output_dir" "unsupported" \
        "GSD v1 does not have telemetry data; telemetry.dat is header-only" \
        "$source_path"
}

# =============================================================================
# Self-validation -- confirm all required adapter functions are defined
# Guard against re-entry when validate_adapter sources this file in subshells.
# =============================================================================
if [ -z "${_GSD1_VALIDATING:-}" ]; then
    _GSD1_VALIDATING=1
    export _GSD1_VALIDATING
    validate_adapter "${BASH_SOURCE[0]}"
    unset _GSD1_VALIDATING
fi
