#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# decisions.sh — Transform extracted decisions TSV into DECISIONS.md
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+
#
# Usage: decisions.sh <intermediate_dir> <target_project_root>
#   intermediate_dir:    directory containing decisions.dat (adapter output)
#   target_project_root: where to write DECISIONS.md
#
# Reads the intermediate decisions.dat TSV and produces a markdown table
# in the orchestrator DECISIONS.md format. Superseded decisions have
# "(Superseded by D###)" appended to their Rationale column.
#
# Idempotent: re-running overwrites the output file.
# =============================================================================

# --- Resolve script directory and source dependencies ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"
INTERFACE="${SCRIPT_DIR}/../adapter-interface.sh"

# Source adapter interface (provides unescape_field, DECISIONS_FIELDS)
# shellcheck source=../adapter-interface.sh
source "$INTERFACE"

# Source decision numbering helpers
# shellcheck source=../lib/decision-numbering.sh
source "${LIB_DIR}/decision-numbering.sh"

# --- Parse arguments ---
intermediate_dir="${1:?Usage: decisions.sh <intermediate_dir> <target_project_root>}"
target_root="${2:?Usage: decisions.sh <intermediate_dir> <target_project_root>}"

decisions_dat="${intermediate_dir}/decisions.dat"
if [ ! -f "$decisions_dat" ]; then
    echo "ERROR: decisions.dat not found at $decisions_dat" >&2
    exit 1
fi

# --- Migration date (today) ---
migration_date="$(date '+%Y-%m-%d')"

# --- Truncate helper ---
# truncate_field <value> <max_len>
#   Truncate a string to max_len characters, appending "..." if truncated.
truncate_field() {
    local val="$1"
    local max_len="$2"
    if [ "${#val}" -gt "$max_len" ]; then
        printf '%s...' "$(printf '%.'"$((max_len - 3))"'s' "$val")"
    else
        printf '%s' "$val"
    fi
}

# --- Escape pipes in markdown table cells ---
# escape_pipes <value>
#   Replace literal pipe characters with unicode equivalent to avoid
#   breaking markdown table formatting.
escape_pipes() {
    printf '%s' "$1" | sed 's/|/\&#124;/g'
}

# --- Get max decision ID for header ---
max_id="$(get_max_decision_id "$decisions_dat")"

# --- Count data rows ---
total_rows="$(tail -n +2 "$decisions_dat" | grep -c '.' || true)"
if [ "$total_rows" -eq 0 ]; then
    echo "No decisions to transform (0 data rows in decisions.dat)"
    # Write an empty DECISIONS.md with just the header
    mkdir -p "$target_root"
    cat > "${target_root}/DECISIONS.md" <<EOF
# Decisions Register

> No decisions found in source data.

| ID | Scope | When | Decision | Choice | Rationale | Revisable? |
|----|-------|------|----------|--------|-----------|------------|
EOF
    exit 0
fi

# --- Generate migration header ---
header_line="$(format_migration_header "$max_id" "gsd2" "$migration_date")"

# --- Build output in temp file ---
mkdir -p "$target_root"
tmpfile="$(mktemp "${target_root}/DECISIONS.md.XXXXXX")"

# Write markdown header
cat > "$tmpfile" <<EOF
# Decisions Register

> ${header_line}

| ID | Scope | When | Decision | Choice | Rationale | Revisable? |
|----|-------|------|----------|--------|-----------|------------|
EOF

# --- Process each decision row ---
# Fields (10 total):
#   1=id, 2=title(decision text), 3=status, 4=date(when_context),
#   5=context(scope), 6=decision(choice), 7=consequences(rationale),
#   8=revisable, 9=made_by, 10=superseded_by
count=0
tail -n +2 "$decisions_dat" | while IFS= read -r line; do
    [ -z "$line" ] && continue

    # Parse TSV fields using awk
    f_id="$(printf '%s' "$line" | awk -F'\t' '{print $1}')"
    f_title="$(printf '%s' "$line" | awk -F'\t' '{print $2}')"
    # f_status is $3 but we derive superseded from $10
    f_date="$(printf '%s' "$line" | awk -F'\t' '{print $4}')"
    f_context="$(printf '%s' "$line" | awk -F'\t' '{print $5}')"
    f_choice="$(printf '%s' "$line" | awk -F'\t' '{print $6}')"
    f_rationale="$(printf '%s' "$line" | awk -F'\t' '{print $7}')"
    f_revisable="$(printf '%s' "$line" | awk -F'\t' '{print $8}')"
    # f_made_by is $9 — not displayed in table
    f_superseded_by="$(printf '%s' "$line" | awk -F'\t' '{print $10}')"

    # Skip entries with empty id
    if [ -z "$f_id" ]; then
        continue
    fi

    # Unescape fields
    f_title="$(unescape_field "$f_title")"
    f_date="$(unescape_field "$f_date")"
    f_context="$(unescape_field "$f_context")"
    f_choice="$(unescape_field "$f_choice")"
    f_rationale="$(unescape_field "$f_rationale")"
    f_revisable="$(unescape_field "$f_revisable")"
    f_superseded_by="$(unescape_field "$f_superseded_by")"

    # Append supersession note to rationale if superseded
    if [ -n "$f_superseded_by" ]; then
        f_rationale="${f_rationale} (Superseded by ${f_superseded_by})"
    fi

    # Truncate long fields for table readability
    f_title="$(truncate_field "$f_title" 60)"
    f_context="$(truncate_field "$f_context" 30)"
    f_date="$(truncate_field "$f_date" 30)"
    f_choice="$(truncate_field "$f_choice" 60)"
    f_rationale="$(truncate_field "$f_rationale" 80)"

    # Escape pipe characters in all fields
    f_id="$(escape_pipes "$f_id")"
    f_title="$(escape_pipes "$f_title")"
    f_context="$(escape_pipes "$f_context")"
    f_date="$(escape_pipes "$f_date")"
    f_choice="$(escape_pipes "$f_choice")"
    f_rationale="$(escape_pipes "$f_rationale")"
    f_revisable="$(escape_pipes "$f_revisable")"

    # Write table row
    printf '| %s | %s | %s | %s | %s | %s | %s |\n' \
        "$f_id" "$f_context" "$f_date" "$f_title" "$f_choice" "$f_rationale" "$f_revisable" >> "$tmpfile"

    count=$((count + 1))
done

# Atomic move
mv "$tmpfile" "${target_root}/DECISIONS.md"

echo "TRANSFORMED: ${total_rows} decisions -> ${target_root}/DECISIONS.md"
