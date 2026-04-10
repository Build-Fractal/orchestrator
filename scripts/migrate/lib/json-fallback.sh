#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# json-fallback.sh — JSON/Filesystem Fallback Reader Library
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+ (no associative arrays, no pipe-ampersand, no lowercase expansion)
#
# Reads migration data from memories-snapshot.json, state-manifest.json,
# and filesystem scanning when gsd.db is unavailable.
#
# Requires: adapter-interface.sh sourced first (provides escape_field,
#           write_header, append_record, emit_warning, field constants)
#
# JSON parsing strategy:
#   - Uses jq when available for reliable JSON parsing
#   - Falls back to grep/sed/awk line-by-line parsing otherwise
#   - Both paths produce identical TSV output
# =============================================================================

# Detect jq availability at source time
_jq_available=false
if command -v jq >/dev/null 2>&1; then
    _jq_available=true
fi

# -----------------------------------------------------------------------------
# _resolve_gsd_dir <source_path>
#   Resolve the actual .gsd directory path. Accepts either:
#     - A path ending in .gsd (direct)
#     - A parent project path (appends /.gsd)
# -----------------------------------------------------------------------------
_resolve_gsd_dir() {
    local src="$1"
    if [ -d "$src" ]; then
        # If the path itself is a directory named .gsd, use it directly
        case "$src" in
            */.gsd|*/.gsd/)
                printf '%s' "${src%/}"
                return 0
                ;;
        esac
        # Otherwise try appending .gsd
        if [ -d "${src}/.gsd" ]; then
            printf '%s' "${src}/.gsd"
            return 0
        fi
        # Maybe the path IS the .gsd dir but not named that way (unlikely)
        printf '%s' "${src%/}"
        return 0
    fi
    printf '%s' "$src"
    return 1
}

# -----------------------------------------------------------------------------
# has_json_fallback <source_path>
#   Check if memories-snapshot.json exists. Returns 0 if found, 1 otherwise.
# -----------------------------------------------------------------------------
has_json_fallback() {
    local src="$1"
    local gsd_dir
    gsd_dir="$(_resolve_gsd_dir "$src")" || true

    if [ -f "${gsd_dir}/memories-snapshot.json" ]; then
        return 0
    fi
    if [ -f "${gsd_dir}/state-manifest.json" ]; then
        return 0
    fi
    return 1
}

# =============================================================================
# Internal helpers — jq extraction
# =============================================================================

# _jq_read_knowledge <gsd_dir> <output_dir>
_jq_read_knowledge() {
    local gsd_dir="$1"
    local output_dir="$2"
    local dat="${output_dir}/knowledge.dat"
    local json="${gsd_dir}/memories-snapshot.json"

    write_header "$dat" "$KNOWLEDGE_FIELDS"

    if [ ! -f "$json" ]; then
        emit_warning "$output_dir" "MISSING_FILE" "memories-snapshot.json not found" "$json"
        return 0
    fi

    # jq @tsv escapes tabs as \t and newlines as \n — same convention as
    # escape_field(), so we append output directly (no while-read loop which
    # would collapse consecutive empty tab fields).
    jq -r '.active[] |
        [
            (.id // ""),
            (.category // ""),
            ((.content // "")[0:80]),
            (.content // ""),
            ((.source_unit_type // "") + "/" + (.source_unit_id // "")),
            ((.confidence // 0) | tostring),
            ((.hit_count // 0) | tostring),
            (.created_at // ""),
            (.updated_at // ""),
            (.superseded_by // "")
        ] | @tsv' "$json" >> "$dat"
}

# _jq_read_decisions <gsd_dir> <output_dir>
_jq_read_decisions() {
    local gsd_dir="$1"
    local output_dir="$2"
    local dat="${output_dir}/decisions.dat"
    local json="${gsd_dir}/state-manifest.json"

    write_header "$dat" "$DECISIONS_FIELDS"

    if [ ! -f "$json" ]; then
        emit_warning "$output_dir" "MISSING_FILE" "state-manifest.json not found" "$json"
        return 0
    fi

    jq -r '.decisions[]? |
        [
            (.id // ""),
            (.decision // ""),
            (if (.superseded_by // "") != "" then "superseded" elif .revisable == "Yes" then "open" elif .revisable == "No" then "closed" else "open" end),
            "",
            (.when_context // ""),
            (.choice // ""),
            (.rationale // ""),
            (.revisable // ""),
            (.made_by // ""),
            (.superseded_by // "")
        ] | @tsv' "$json" >> "$dat"
}

# _jq_read_requirements <gsd_dir> <output_dir>
_jq_read_requirements() {
    local gsd_dir="$1"
    local output_dir="$2"
    local dat="${output_dir}/requirements.dat"
    local json="${gsd_dir}/state-manifest.json"

    write_header "$dat" "$REQUIREMENTS_FIELDS"

    if [ ! -f "$json" ]; then
        emit_warning "$output_dir" "MISSING_FILE" "state-manifest.json not found" "$json"
        return 0
    fi

    # state-manifest.json may not have a requirements key
    local has_reqs
    has_reqs="$(jq 'has("requirements")' "$json")"
    if [ "$has_reqs" = "false" ]; then
        emit_warning "$output_dir" "NO_REQUIREMENTS" "No requirements section in state-manifest.json" "$json"
        return 0
    fi

    jq -r '.requirements[]? |
        [
            (.id // ""),
            (.type // ""),
            (.priority // ""),
            (.title // ""),
            (.description // ""),
            (.acceptance_criteria // ""),
            (.source // ""),
            (.validation_status // ""),
            (.validated_by // ""),
            (.superseded_by // "")
        ] | @tsv' "$json" >> "$dat"
}

# _jq_read_milestones <gsd_dir> <output_dir>
_jq_read_milestones() {
    local gsd_dir="$1"
    local output_dir="$2"
    local dat="${output_dir}/milestones.dat"
    local json="${gsd_dir}/state-manifest.json"

    write_header "$dat" "$MILESTONES_FIELDS"

    if [ ! -f "$json" ]; then
        emit_warning "$output_dir" "MISSING_FILE" "state-manifest.json not found" "$json"
        return 0
    fi

    jq -r '.milestones[]? |
        [
            (.id // ""),
            (.title // ""),
            (.status // ""),
            (.vision // ""),
            (.created_at // ""),
            (.completed_at // "")
        ] | @tsv' "$json" >> "$dat"
}

# _jq_read_slices <gsd_dir> <output_dir>
_jq_read_slices() {
    local gsd_dir="$1"
    local output_dir="$2"
    local dat="${output_dir}/slices.dat"
    local json="${gsd_dir}/state-manifest.json"

    write_header "$dat" "$SLICES_FIELDS"

    if [ ! -f "$json" ]; then
        emit_warning "$output_dir" "MISSING_FILE" "state-manifest.json not found" "$json"
        return 0
    fi

    jq -r '.slices[]? |
        [
            (.id // ""),
            (.milestone_id // ""),
            (.title // ""),
            (.status // ""),
            (.goal // ""),
            ((.sequence // 0) | tostring)
        ] | @tsv' "$json" >> "$dat"
}

# _jq_read_tasks <gsd_dir> <output_dir>
_jq_read_tasks() {
    local gsd_dir="$1"
    local output_dir="$2"
    local dat="${output_dir}/tasks.dat"
    local json="${gsd_dir}/state-manifest.json"

    write_header "$dat" "$TASKS_FIELDS"

    if [ ! -f "$json" ]; then
        emit_warning "$output_dir" "MISSING_FILE" "state-manifest.json not found" "$json"
        return 0
    fi

    jq -r '.tasks[]? |
        [
            (.id // ""),
            (.slice_id // ""),
            (.milestone_id // ""),
            (.title // ""),
            (.status // ""),
            (.description // ""),
            "",
            ""
        ] | @tsv' "$json" >> "$dat"
}

# _jq_read_telemetry <gsd_dir> <output_dir>
_jq_read_telemetry() {
    local gsd_dir="$1"
    local output_dir="$2"
    local dat="${output_dir}/telemetry.dat"
    local json="${gsd_dir}/state-manifest.json"

    write_header "$dat" "$TELEMETRY_FIELDS"

    if [ ! -f "$json" ]; then
        emit_warning "$output_dir" "MISSING_FILE" "state-manifest.json not found" "$json"
        return 0
    fi

    jq -r '.verification_evidence[]? |
        [
            ((.id // 0) | tostring),
            (.created_at // ""),
            (.verdict // ""),
            (.task_id // ""),
            "task",
            (.command // ""),
            "",
            (.milestone_id // ""),
            (.slice_id // "")
        ] | @tsv' "$json" >> "$dat"
}

# =============================================================================
# Internal helpers — no-jq (grep/sed/awk) extraction
# =============================================================================

# _nojq_extract_string <line> <field_name>
#   Extract a JSON string value from a line like:  "field": "value",
#   Returns empty string if not found.
_nojq_extract_string() {
    local line="$1"
    local field="$2"
    # Match "field": "value" — handle escaped quotes inside value
    printf '%s' "$line" | sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\(.*\)\".*/\1/p" | head -1
}

# _nojq_extract_number <line> <field_name>
#   Extract a JSON number value from a line like:  "field": 123,
_nojq_extract_number() {
    local line="$1"
    local field="$2"
    printf '%s' "$line" | sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\([0-9.]*\).*/\1/p" | head -1
}

# _nojq_parse_objects <json_file> <array_key> <callback>
#   Parse a JSON array of objects without jq. Reads the file, finds the array
#   under <array_key>, and for each object calls <callback> with the object
#   text (one line per field). Uses a state machine to track { } depth.
#
#   The callback receives the concatenated object fields as a single argument
#   with fields separated by the record separator character (ASCII 30).
_nojq_parse_objects() {
    local json_file="$1"
    local array_key="$2"
    local callback="$3"

    local in_array=0
    local depth=0
    local object_lines=""

    while IFS= read -r line; do
        # Detect array start
        if [ "$in_array" -eq 0 ]; then
            case "$line" in
                *"\"${array_key}\""*"["*)
                    in_array=1
                    # Check if opening brace is on same line
                    case "$line" in
                        *"{"*)
                            depth=1
                            object_lines=""
                            ;;
                    esac
                    continue
                    ;;
            esac
            continue
        fi

        # Inside the target array
        case "$line" in
            *"{"*)
                if [ "$depth" -eq 0 ]; then
                    depth=1
                    object_lines=""
                else
                    depth=$((depth + 1))
                    object_lines="${object_lines}${line}
"
                fi
                ;;
            *"}"*)
                depth=$((depth - 1))
                if [ "$depth" -eq 0 ]; then
                    # End of object — invoke callback
                    "$callback" "$object_lines"
                    object_lines=""
                elif [ "$depth" -lt 0 ]; then
                    # End of array
                    break
                else
                    object_lines="${object_lines}${line}
"
                fi
                ;;
            *"]"*)
                if [ "$depth" -eq 0 ]; then
                    # End of array (no trailing object)
                    break
                else
                    object_lines="${object_lines}${line}
"
                fi
                ;;
            *)
                if [ "$depth" -ge 1 ]; then
                    object_lines="${object_lines}${line}
"
                fi
                ;;
        esac
    done < "$json_file"
}

# _nojq_get_field <object_text> <field_name>
#   Extract a string field value from multi-line object text.
_nojq_get_field() {
    local text="$1"
    local field="$2"
    printf '%s' "$text" | while IFS= read -r fline; do
        case "$fline" in
            *"\"${field}\""*)
                # Try string value
                local val
                val="$(_nojq_extract_string "$fline" "$field")"
                if [ -n "$val" ]; then
                    printf '%s' "$val"
                    return 0
                fi
                # Try number value
                val="$(_nojq_extract_number "$fline" "$field")"
                if [ -n "$val" ]; then
                    printf '%s' "$val"
                    return 0
                fi
                # Try null
                case "$fline" in
                    *"null"*)
                        printf ''
                        return 0
                        ;;
                esac
                ;;
        esac
    done
}

# _nojq_read_knowledge <gsd_dir> <output_dir>
_nojq_read_knowledge() {
    local gsd_dir="$1"
    local output_dir="$2"
    local dat="${output_dir}/knowledge.dat"
    local json="${gsd_dir}/memories-snapshot.json"

    write_header "$dat" "$KNOWLEDGE_FIELDS"

    if [ ! -f "$json" ]; then
        emit_warning "$output_dir" "MISSING_FILE" "memories-snapshot.json not found" "$json"
        return 0
    fi

    _nojq_knowledge_callback() {
        local obj="$1"
        local f_id f_cat f_content f_title f_source f_priority f_stype f_sid
        local f_hit_count f_created_at f_updated_at f_superseded_by
        f_id="$(_nojq_get_field "$obj" "id")"
        f_cat="$(_nojq_get_field "$obj" "category")"
        f_content="$(_nojq_get_field "$obj" "content")"
        f_title="$(printf '%.80s' "$f_content")"
        f_stype="$(_nojq_get_field "$obj" "source_unit_type")"
        f_sid="$(_nojq_get_field "$obj" "source_unit_id")"
        f_source="${f_stype}/${f_sid}"
        f_priority="$(_nojq_get_field "$obj" "confidence")"
        if [ -z "$f_priority" ]; then
            f_priority="0"
        fi
        f_hit_count="$(_nojq_get_field "$obj" "hit_count")"
        if [ -z "$f_hit_count" ]; then
            f_hit_count="0"
        fi
        f_created_at="$(_nojq_get_field "$obj" "created_at")"
        f_updated_at="$(_nojq_get_field "$obj" "updated_at")"
        f_superseded_by="$(_nojq_get_field "$obj" "superseded_by")"
        append_record "$dat" "$f_id" "$f_cat" "$f_title" "$f_content" "$f_source" "$f_priority" "$f_hit_count" "$f_created_at" "$f_updated_at" "$f_superseded_by"
    }

    _nojq_parse_objects "$json" "active" "_nojq_knowledge_callback"
}

# _nojq_read_decisions <gsd_dir> <output_dir>
_nojq_read_decisions() {
    local gsd_dir="$1"
    local output_dir="$2"
    local dat="${output_dir}/decisions.dat"
    local json="${gsd_dir}/state-manifest.json"

    write_header "$dat" "$DECISIONS_FIELDS"

    if [ ! -f "$json" ]; then
        emit_warning "$output_dir" "MISSING_FILE" "state-manifest.json not found" "$json"
        return 0
    fi

    _nojq_decisions_callback() {
        local obj="$1"
        local f_id f_title f_status f_revisable f_ctx f_choice f_rationale
        local f_made_by f_superseded_by
        f_id="$(_nojq_get_field "$obj" "id")"
        f_title="$(_nojq_get_field "$obj" "decision")"
        f_revisable="$(_nojq_get_field "$obj" "revisable")"
        f_superseded_by="$(_nojq_get_field "$obj" "superseded_by")"
        if [ -n "$f_superseded_by" ]; then
            f_status="superseded"
        elif [ "$f_revisable" = "Yes" ]; then
            f_status="open"
        elif [ "$f_revisable" = "No" ]; then
            f_status="closed"
        else
            f_status="open"
        fi
        f_ctx="$(_nojq_get_field "$obj" "when_context")"
        f_choice="$(_nojq_get_field "$obj" "choice")"
        f_rationale="$(_nojq_get_field "$obj" "rationale")"
        f_made_by="$(_nojq_get_field "$obj" "made_by")"
        append_record "$dat" "$f_id" "$f_title" "$f_status" "" "$f_ctx" "$f_choice" "$f_rationale" "$f_revisable" "$f_made_by" "$f_superseded_by"
    }

    _nojq_parse_objects "$json" "decisions" "_nojq_decisions_callback"
}

# _nojq_read_requirements <gsd_dir> <output_dir>
_nojq_read_requirements() {
    local gsd_dir="$1"
    local output_dir="$2"
    local dat="${output_dir}/requirements.dat"
    local json="${gsd_dir}/state-manifest.json"

    write_header "$dat" "$REQUIREMENTS_FIELDS"

    if [ ! -f "$json" ]; then
        emit_warning "$output_dir" "MISSING_FILE" "state-manifest.json not found" "$json"
        return 0
    fi

    # Check if requirements key exists
    if ! grep -q '"requirements"' "$json"; then
        emit_warning "$output_dir" "NO_REQUIREMENTS" "No requirements section in state-manifest.json" "$json"
        return 0
    fi

    _nojq_requirements_callback() {
        local obj="$1"
        local f_id f_type f_pri f_title f_desc f_ac f_src
        local f_validation_status f_validated_by f_superseded_by
        f_id="$(_nojq_get_field "$obj" "id")"
        f_type="$(_nojq_get_field "$obj" "type")"
        f_pri="$(_nojq_get_field "$obj" "priority")"
        f_title="$(_nojq_get_field "$obj" "title")"
        f_desc="$(_nojq_get_field "$obj" "description")"
        f_ac="$(_nojq_get_field "$obj" "acceptance_criteria")"
        f_src="$(_nojq_get_field "$obj" "source")"
        f_validation_status="$(_nojq_get_field "$obj" "validation_status")"
        f_validated_by="$(_nojq_get_field "$obj" "validated_by")"
        f_superseded_by="$(_nojq_get_field "$obj" "superseded_by")"
        append_record "$dat" "$f_id" "$f_type" "$f_pri" "$f_title" "$f_desc" "$f_ac" "$f_src" "$f_validation_status" "$f_validated_by" "$f_superseded_by"
    }

    _nojq_parse_objects "$json" "requirements" "_nojq_requirements_callback"
}

# _nojq_read_milestones <gsd_dir> <output_dir>
_nojq_read_milestones() {
    local gsd_dir="$1"
    local output_dir="$2"
    local dat="${output_dir}/milestones.dat"
    local json="${gsd_dir}/state-manifest.json"

    write_header "$dat" "$MILESTONES_FIELDS"

    if [ ! -f "$json" ]; then
        emit_warning "$output_dir" "MISSING_FILE" "state-manifest.json not found" "$json"
        return 0
    fi

    _nojq_milestones_callback() {
        local obj="$1"
        local f_id f_title f_status f_desc f_start f_end
        f_id="$(_nojq_get_field "$obj" "id")"
        f_title="$(_nojq_get_field "$obj" "title")"
        f_status="$(_nojq_get_field "$obj" "status")"
        f_desc="$(_nojq_get_field "$obj" "vision")"
        f_start="$(_nojq_get_field "$obj" "created_at")"
        f_end="$(_nojq_get_field "$obj" "completed_at")"
        append_record "$dat" "$f_id" "$f_title" "$f_status" "$f_desc" "$f_start" "$f_end"
    }

    _nojq_parse_objects "$json" "milestones" "_nojq_milestones_callback"
}

# _nojq_read_slices <gsd_dir> <output_dir>
_nojq_read_slices() {
    local gsd_dir="$1"
    local output_dir="$2"
    local dat="${output_dir}/slices.dat"
    local json="${gsd_dir}/state-manifest.json"

    write_header "$dat" "$SLICES_FIELDS"

    if [ ! -f "$json" ]; then
        emit_warning "$output_dir" "MISSING_FILE" "state-manifest.json not found" "$json"
        return 0
    fi

    _nojq_slices_callback() {
        local obj="$1"
        local f_id f_mid f_title f_status f_desc f_order
        f_id="$(_nojq_get_field "$obj" "id")"
        f_mid="$(_nojq_get_field "$obj" "milestone_id")"
        f_title="$(_nojq_get_field "$obj" "title")"
        f_status="$(_nojq_get_field "$obj" "status")"
        f_desc="$(_nojq_get_field "$obj" "goal")"
        f_order="$(_nojq_get_field "$obj" "sequence")"
        if [ -z "$f_order" ]; then
            f_order="0"
        fi
        append_record "$dat" "$f_id" "$f_mid" "$f_title" "$f_status" "$f_desc" "$f_order"
    }

    _nojq_parse_objects "$json" "slices" "_nojq_slices_callback"
}

# _nojq_read_tasks <gsd_dir> <output_dir>
_nojq_read_tasks() {
    local gsd_dir="$1"
    local output_dir="$2"
    local dat="${output_dir}/tasks.dat"
    local json="${gsd_dir}/state-manifest.json"

    write_header "$dat" "$TASKS_FIELDS"

    if [ ! -f "$json" ]; then
        emit_warning "$output_dir" "MISSING_FILE" "state-manifest.json not found" "$json"
        return 0
    fi

    _nojq_tasks_callback() {
        local obj="$1"
        local f_id f_sid f_mid f_title f_status f_desc
        f_id="$(_nojq_get_field "$obj" "id")"
        f_sid="$(_nojq_get_field "$obj" "slice_id")"
        f_mid="$(_nojq_get_field "$obj" "milestone_id")"
        f_title="$(_nojq_get_field "$obj" "title")"
        f_status="$(_nojq_get_field "$obj" "status")"
        f_desc="$(_nojq_get_field "$obj" "description")"
        append_record "$dat" "$f_id" "$f_sid" "$f_mid" "$f_title" "$f_status" "$f_desc" "" ""
    }

    _nojq_parse_objects "$json" "tasks" "_nojq_tasks_callback"
}

# _nojq_read_telemetry <gsd_dir> <output_dir>
_nojq_read_telemetry() {
    local gsd_dir="$1"
    local output_dir="$2"
    local dat="${output_dir}/telemetry.dat"
    local json="${gsd_dir}/state-manifest.json"

    write_header "$dat" "$TELEMETRY_FIELDS"

    if [ ! -f "$json" ]; then
        emit_warning "$output_dir" "MISSING_FILE" "state-manifest.json not found" "$json"
        return 0
    fi

    _nojq_telemetry_callback() {
        local obj="$1"
        local f_id f_ts f_evt f_eid f_cmd f_mid f_sid
        f_id="$(_nojq_get_field "$obj" "id")"
        if [ -z "$f_id" ]; then
            f_id="0"
        fi
        f_ts="$(_nojq_get_field "$obj" "created_at")"
        f_evt="$(_nojq_get_field "$obj" "verdict")"
        f_eid="$(_nojq_get_field "$obj" "task_id")"
        f_cmd="$(_nojq_get_field "$obj" "command")"
        f_mid="$(_nojq_get_field "$obj" "milestone_id")"
        f_sid="$(_nojq_get_field "$obj" "slice_id")"
        append_record "$dat" "$f_id" "$f_ts" "$f_evt" "$f_eid" "task" "$f_cmd" "" "$f_mid" "$f_sid"
    }

    _nojq_parse_objects "$json" "verification_evidence" "_nojq_telemetry_callback"
}

# =============================================================================
# Public API — dispatch to jq or no-jq implementation
# =============================================================================

# json_read_knowledge <source_path> <output_dir>
#   Read memories-snapshot.json → knowledge.dat
json_read_knowledge() {
    local src="$1"
    local output_dir="$2"
    local gsd_dir
    gsd_dir="$(_resolve_gsd_dir "$src")" || true

    init_output_dir "$output_dir"

    if [ "$_jq_available" = "true" ]; then
        _jq_read_knowledge "$gsd_dir" "$output_dir"
    else
        _nojq_read_knowledge "$gsd_dir" "$output_dir"
    fi
}

# json_read_decisions <source_path> <output_dir>
#   Read state-manifest.json decisions → decisions.dat
json_read_decisions() {
    local src="$1"
    local output_dir="$2"
    local gsd_dir
    gsd_dir="$(_resolve_gsd_dir "$src")" || true

    init_output_dir "$output_dir"

    if [ "$_jq_available" = "true" ]; then
        _jq_read_decisions "$gsd_dir" "$output_dir"
    else
        _nojq_read_decisions "$gsd_dir" "$output_dir"
    fi
}

# json_read_requirements <source_path> <output_dir>
#   Read state-manifest.json requirements → requirements.dat
json_read_requirements() {
    local src="$1"
    local output_dir="$2"
    local gsd_dir
    gsd_dir="$(_resolve_gsd_dir "$src")" || true

    init_output_dir "$output_dir"

    if [ "$_jq_available" = "true" ]; then
        _jq_read_requirements "$gsd_dir" "$output_dir"
    else
        _nojq_read_requirements "$gsd_dir" "$output_dir"
    fi
}

# json_read_milestones <source_path> <output_dir>
#   Read state-manifest.json milestones → milestones.dat
json_read_milestones() {
    local src="$1"
    local output_dir="$2"
    local gsd_dir
    gsd_dir="$(_resolve_gsd_dir "$src")" || true

    init_output_dir "$output_dir"

    if [ "$_jq_available" = "true" ]; then
        _jq_read_milestones "$gsd_dir" "$output_dir"
    else
        _nojq_read_milestones "$gsd_dir" "$output_dir"
    fi
}

# json_read_slices <source_path> <output_dir>
#   Read state-manifest.json slices → slices.dat
json_read_slices() {
    local src="$1"
    local output_dir="$2"
    local gsd_dir
    gsd_dir="$(_resolve_gsd_dir "$src")" || true

    init_output_dir "$output_dir"

    if [ "$_jq_available" = "true" ]; then
        _jq_read_slices "$gsd_dir" "$output_dir"
    else
        _nojq_read_slices "$gsd_dir" "$output_dir"
    fi
}

# json_read_tasks <source_path> <output_dir>
#   Read state-manifest.json tasks → tasks.dat
json_read_tasks() {
    local src="$1"
    local output_dir="$2"
    local gsd_dir
    gsd_dir="$(_resolve_gsd_dir "$src")" || true

    init_output_dir "$output_dir"

    if [ "$_jq_available" = "true" ]; then
        _jq_read_tasks "$gsd_dir" "$output_dir"
    else
        _nojq_read_tasks "$gsd_dir" "$output_dir"
    fi
}

# json_read_telemetry <source_path> <output_dir>
#   Read verification_evidence from state-manifest.json → telemetry.dat
json_read_telemetry() {
    local src="$1"
    local output_dir="$2"
    local gsd_dir
    gsd_dir="$(_resolve_gsd_dir "$src")" || true

    init_output_dir "$output_dir"

    if [ "$_jq_available" = "true" ]; then
        _jq_read_telemetry "$gsd_dir" "$output_dir"
    else
        _nojq_read_telemetry "$gsd_dir" "$output_dir"
    fi
}

# scan_milestone_dirs <source_path> <output_dir>
#   Filesystem scan of milestone directories for discovery.
#   Appends any milestone directories found on disk that are not already
#   present in milestones.dat.
scan_milestone_dirs() {
    local src="$1"
    local output_dir="$2"
    local gsd_dir
    gsd_dir="$(_resolve_gsd_dir "$src")" || true

    init_output_dir "$output_dir"

    local milestone_dir="${gsd_dir}/milestones"
    if [ ! -d "$milestone_dir" ]; then
        emit_warning "$output_dir" "NO_MILESTONE_DIR" "No milestones directory found" "$milestone_dir"
        return 0
    fi

    local dat="${output_dir}/milestones.dat"

    # Create header if file doesn't exist yet
    if [ ! -f "$dat" ]; then
        write_header "$dat" "$MILESTONES_FIELDS"
    fi

    # Collect existing milestone IDs from the dat file (skip header)
    local existing_ids=""
    if [ -f "$dat" ]; then
        existing_ids="$(tail -n +2 "$dat" | cut -f1 | tr '\n' '|')"
    fi

    # Scan for milestone directories (M followed by digits)
    for dir in "$milestone_dir"/M[0-9]*; do
        if [ ! -d "$dir" ]; then
            continue
        fi
        local dir_name
        dir_name="$(basename "$dir")"

        # Skip if already in dat file
        case "|${existing_ids}" in
            *"|${dir_name}|"*) continue ;;
        esac

        # Add discovered milestone with minimal info
        append_record "$dat" "$dir_name" "" "discovered" "Discovered from filesystem scan" "" ""
        emit_warning "$output_dir" "FS_DISCOVERED" "Milestone ${dir_name} found on disk but not in state-manifest.json" "$dir"
    done
}
