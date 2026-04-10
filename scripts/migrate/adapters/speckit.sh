#!/usr/bin/env bash
# scripts/migrate/adapters/speckit.sh — Standard spec-kit source adapter
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+ (no associative arrays, no pipe-ampersand)
#
# Implements the full adapter interface contract for standard spec-kit sources.
# Spec-kit stores specs in specs/{NNN-name}/ with spec.md, plan.md, tasks.md.
#
# File layout:
#   specs/
#     001-my-feature/
#       spec.md    -- feature specification with user stories
#       plan.md    -- implementation plan
#       tasks.md   -- task breakdown
#   .specify/      -- spec-kit config directory (optional)
#
# Prerequisites:
#   source adapter-interface.sh   (must be sourced before this file)
# =============================================================================
set -euo pipefail

# =============================================================================
# detect_source <path>
#   Echo "yes" if path contains a spec-kit project (specs/ or .specify/),
#   "no" otherwise.
# =============================================================================
detect_source() {
    local path="$1"
    # Spec-kit uses specs/ directory with numbered subdirectories
    if [ -d "${path}/specs" ] || [ -d "${path}/.specify" ]; then
        echo "yes"
    else
        echo "no"
    fi
    return 0
}

# =============================================================================
# extract_knowledge <source_path> <output_dir>
#   Standard spec-kit has no knowledge store.
#   Writes header-only file.
# =============================================================================
extract_knowledge() {
    local source_path="$1"
    local output_dir="$2"
    init_output_dir "$output_dir"

    write_header "${output_dir}/knowledge.dat" "$KNOWLEDGE_FIELDS"
    emit_warning "$output_dir" "unsupported" \
        "Standard spec-kit does not have a knowledge store; knowledge.dat is header-only" \
        "$source_path"
}

# =============================================================================
# extract_decisions <source_path> <output_dir>
#   Standard spec-kit has no decision log.
#   Writes header-only file.
# =============================================================================
extract_decisions() {
    local source_path="$1"
    local output_dir="$2"
    init_output_dir "$output_dir"

    write_header "${output_dir}/decisions.dat" "$DECISIONS_FIELDS"
    emit_warning "$output_dir" "unsupported" \
        "Standard spec-kit does not have a decision log; decisions.dat is header-only" \
        "$source_path"
}

# =============================================================================
# extract_requirements <source_path> <output_dir>
#   Scan spec.md files for user stories and acceptance criteria.
#   Each user story becomes a requirement entry.
# =============================================================================
extract_requirements() {
    local source_path="$1"
    local output_dir="$2"
    init_output_dir "$output_dir"

    write_header "${output_dir}/requirements.dat" "$REQUIREMENTS_FIELDS"

    local specs_dir="${source_path}/specs"
    if [ ! -d "$specs_dir" ]; then
        emit_warning "$output_dir" "missing" \
            "No specs/ directory found" "$source_path"
        return 0
    fi

    local req_num=0

    # Scan each spec directory
    for spec_dir in "$specs_dir"/*/; do
        if [ ! -d "$spec_dir" ]; then
            continue
        fi

        local spec_file="${spec_dir}spec.md"
        if [ ! -f "$spec_file" ]; then
            continue
        fi

        local spec_name
        spec_name="$(basename "$spec_dir")"

        # Parse spec.md for user stories
        # Common patterns:
        #   ## User Story N
        #   As a <role>, I can <action>.
        #   - or -
        #   **US1**: As a <role>, I can <action>
        local in_story=0
        local story_title=""
        local story_content=""
        local story_acceptance=""
        local in_acceptance=0

        while IFS= read -r line || [ -n "$line" ]; do
            # Detect user story heading or inline story
            case "$line" in
                "## User Story"*|"## US"*|"**US"*)
                    # Save previous story
                    if [ -n "$story_title" ]; then
                        req_num=$((req_num + 1))
                        local req_id
                        req_id="$(printf 'REQ%03d' $req_num)"
                        append_record "${output_dir}/requirements.dat" \
                            "$req_id" "user-story" "medium" "$story_title" \
                            "$story_content" "$story_acceptance" \
                            "$spec_name" "" "" ""
                    fi
                    in_story=1
                    in_acceptance=0
                    story_title="$(echo "$line" | sed 's/^## //;s/^\*\*//;s/\*\*.*$//')"
                    story_content=""
                    story_acceptance=""
                    ;;
                "### Acceptance"*|"**Acceptance"*|"#### AC"*)
                    in_acceptance=1
                    ;;
                "## "*|"# "*)
                    # New section -- save previous story and reset
                    if [ -n "$story_title" ] && [ "$in_story" -eq 1 ]; then
                        req_num=$((req_num + 1))
                        local req_id
                        req_id="$(printf 'REQ%03d' $req_num)"
                        append_record "${output_dir}/requirements.dat" \
                            "$req_id" "user-story" "medium" "$story_title" \
                            "$story_content" "$story_acceptance" \
                            "$spec_name" "" "" ""
                    fi
                    in_story=0
                    in_acceptance=0
                    story_title=""
                    story_content=""
                    story_acceptance=""
                    ;;
                *)
                    if [ "$in_story" -eq 1 ] && [ -n "$line" ]; then
                        if [ "$in_acceptance" -eq 1 ]; then
                            if [ -n "$story_acceptance" ]; then
                                story_acceptance="${story_acceptance} ${line}"
                            else
                                story_acceptance="$line"
                            fi
                        else
                            # Check if this line IS a user story (As a...)
                            case "$line" in
                                "As a "*)
                                    story_content="$line"
                                    ;;
                                *)
                                    if [ -n "$story_content" ]; then
                                        story_content="${story_content} ${line}"
                                    else
                                        story_content="$line"
                                    fi
                                    ;;
                            esac
                        fi
                    fi
                    ;;
            esac
        done < "$spec_file"

        # Save last story from this file
        if [ -n "$story_title" ] && [ "$in_story" -eq 1 ]; then
            req_num=$((req_num + 1))
            local req_id
            req_id="$(printf 'REQ%03d' $req_num)"
            append_record "${output_dir}/requirements.dat" \
                "$req_id" "user-story" "medium" "$story_title" \
                "$story_content" "$story_acceptance" \
                "$spec_name" "" "" ""
        fi
    done

    if [ "$req_num" -eq 0 ]; then
        emit_warning "$output_dir" "empty" \
            "No user stories found in spec files" "$specs_dir"
    fi
}

# =============================================================================
# extract_milestones <source_path> <output_dir>
#   Each spec directory becomes a milestone entry.
#   Status inferred from presence of plan.md/tasks.md.
#   Also produces slices.dat and tasks.dat (header-only for spec-kit).
# =============================================================================
extract_milestones() {
    local source_path="$1"
    local output_dir="$2"
    init_output_dir "$output_dir"

    write_header "${output_dir}/milestones.dat" "$MILESTONES_FIELDS"
    write_header "${output_dir}/slices.dat" "$SLICES_FIELDS"
    write_header "${output_dir}/tasks.dat" "$TASKS_FIELDS"

    local specs_dir="${source_path}/specs"
    if [ ! -d "$specs_dir" ]; then
        emit_warning "$output_dir" "missing" \
            "No specs/ directory found" "$source_path"
        return 0
    fi

    local found_any=0

    for spec_dir in "$specs_dir"/*/; do
        if [ ! -d "$spec_dir" ]; then
            continue
        fi
        found_any=1

        local spec_name
        spec_name="$(basename "$spec_dir")"

        # Extract milestone ID from directory name (e.g., 001-my-feature -> M001)
        local spec_num
        spec_num="$(echo "$spec_name" | grep -oE '^[0-9]+' | head -1)"
        local m_id
        if [ -n "$spec_num" ]; then
            # Remove leading zeros and reformat
            spec_num="$(echo "$spec_num" | sed 's/^0*//')"
            if [ -z "$spec_num" ]; then
                spec_num="0"
            fi
            m_id="$(printf 'M%03d' "$spec_num")"
        else
            m_id="M_${spec_name}"
        fi

        # Extract title from spec.md heading or directory name
        local m_title="$spec_name"
        local m_description=""
        local m_status="draft"
        local spec_file="${spec_dir}spec.md"

        if [ -f "$spec_file" ]; then
            # Get title from first # heading
            local heading
            heading="$(grep -m1 '^# ' "$spec_file" | sed 's/^# //' || true)"
            if [ -n "$heading" ]; then
                m_title="$heading"
            fi

            # Try to find status in frontmatter or body
            local status_line
            status_line="$(grep -iE '^\*\*Status\*\*:|^Status:' "$spec_file" | head -1 || true)"
            if [ -n "$status_line" ]; then
                m_status="$(echo "$status_line" | sed 's/.*:[[:space:]]*//' | sed 's/\*//g' | tr '[:upper:]' '[:lower:]')"
            fi

            # Extract description from first paragraph after heading
            local past_heading=0
            while IFS= read -r line || [ -n "$line" ]; do
                case "$line" in
                    "# "*)
                        past_heading=1
                        continue
                        ;;
                esac
                if [ "$past_heading" -eq 1 ] && [ -n "$line" ]; then
                    case "$line" in
                        "## "*|"**"*|"---"*)
                            break
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
            done < "$spec_file"
        fi

        # Infer status from file presence if not explicitly set
        if [ "$m_status" = "draft" ]; then
            if [ -f "${spec_dir}tasks.md" ]; then
                m_status="in-progress"
            elif [ -f "${spec_dir}plan.md" ]; then
                m_status="planned"
            fi
        fi

        append_record "${output_dir}/milestones.dat" \
            "$m_id" "$m_title" "$m_status" "$m_description" "" ""
    done

    if [ "$found_any" -eq 0 ]; then
        emit_warning "$output_dir" "empty" \
            "specs/ directory exists but contains no spec subdirectories" \
            "$specs_dir"
    fi
}

# =============================================================================
# extract_telemetry <source_path> <output_dir>
#   Standard spec-kit has no telemetry data.
#   Writes header-only file.
# =============================================================================
extract_telemetry() {
    local source_path="$1"
    local output_dir="$2"
    init_output_dir "$output_dir"

    write_header "${output_dir}/telemetry.dat" "$TELEMETRY_FIELDS"
    emit_warning "$output_dir" "unsupported" \
        "Standard spec-kit does not have telemetry data; telemetry.dat is header-only" \
        "$source_path"
}

# =============================================================================
# Self-validation -- confirm all required adapter functions are defined
# Guard against re-entry when validate_adapter sources this file in subshells.
# =============================================================================
if [ -z "${_SPECKIT_VALIDATING:-}" ]; then
    _SPECKIT_VALIDATING=1
    export _SPECKIT_VALIDATING
    validate_adapter "${BASH_SOURCE[0]}"
    unset _SPECKIT_VALIDATING
fi
