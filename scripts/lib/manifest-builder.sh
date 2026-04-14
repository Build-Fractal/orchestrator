#!/usr/bin/env bash
# scripts/lib/manifest-builder.sh — Pure manifest table construction.
# All functions take arguments and return stdout. No file I/O.
# Sourced by build-context.sh, compress-payload.sh, and test harnesses.
#
# Functions:
#   build_manifest_header                 — returns table header rows
#   compute_section_tokens <text>         — returns estimated token count
#   format_manifest_row <n> <s> <e> <t> <p> — returns one table row
#   format_manifest_total <total>         — returns total row
#   assemble_manifest_table <count> <names> <priorities> <line_counts>
#       <token_counts> <content_start>    — returns complete table
#
# Bash 3.2 compatible (NFR-200). No jq required.

# --- Double-sourcing guard (NFR-203 / AP-003) ---
[ -n "${_MANIFEST_BUILDER_SOURCED:-}" ] && return 0
_MANIFEST_BUILDER_SOURCED=1

# Source payload-transforms.sh for estimate_tokens (single source of truth).
_MB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_MB_DIR/payload-transforms.sh"

# build_manifest_header
# Returns the two-line manifest table header (column names + separator).
build_manifest_header() {
  printf '| Section | Lines | Est. Tokens | Priority |\n'
  printf '|---------|-------|-------------|----------|\n'
}

# compute_section_tokens <text>
# Delegates to estimate_tokens from payload-transforms.sh.
# Returns the estimated token count for the given text.
compute_section_tokens() {
  estimate_tokens "$1"
}

# format_manifest_row <name> <start_line> <end_line> <tokens> <priority>
# Returns one formatted manifest table row.
format_manifest_row() {
  local name="$1"
  local start_line="$2"
  local end_line="$3"
  local tokens="$4"
  local priority="$5"
  printf '| %s | %s-%s | ~%s | %s |\n' "$name" "$start_line" "$end_line" "$tokens" "$priority"
}

# format_manifest_total <total_tokens>
# Returns the total row for the manifest table.
format_manifest_total() {
  local total="$1"
  printf '| **Total** | | **~%s** | |\n' "$total"
}

# assemble_manifest_table <section_count> <names_pipe> <priorities_pipe>
#   <line_counts_space> <token_counts_space> <content_start_line>
#
# Builds the complete manifest table from section metadata.
#   section_count:      integer, number of sections
#   names_pipe:         pipe-delimited section names (e.g. "Knowledge|Decisions|Scope")
#   priorities_pipe:    pipe-delimited priorities (e.g. "filtered|filtered|required")
#   line_counts_space:  space-delimited line counts per section (e.g. "3 5 12")
#   token_counts_space: space-delimited token counts per section (e.g. "100 200 500")
#   content_start_line: integer, line number where first section content starts
#
# Returns the complete manifest table on stdout (header + data rows + total).
assemble_manifest_table() {
  local section_count="$1"
  local names_pipe="$2"
  local priorities_pipe="$3"
  local line_counts_space="$4"
  local token_counts_space="$5"
  local content_start="$6"

  build_manifest_header

  local current_line="$content_start"
  local total_tokens=0
  local idx=0
  local i sec_lc sec_tc sec_name sec_pri end_line

  # Parse pipe-delimited names and priorities into arrays
  local OLD_IFS="$IFS"
  IFS='|' read -ra S_NAMES <<< "$names_pipe"
  IFS='|' read -ra S_PRIORITIES <<< "$priorities_pipe"
  IFS="$OLD_IFS"

  for i in $(seq 1 "$section_count"); do
    sec_lc="$(printf '%s' "$line_counts_space" | awk -v n="$i" '{print $n}')"
    sec_tc="$(printf '%s' "$token_counts_space" | awk -v n="$i" '{print $n}')"
    sec_name="${S_NAMES[$idx]}"
    sec_pri="${S_PRIORITIES[$idx]}"

    end_line=$((current_line + sec_lc - 1))
    format_manifest_row "$sec_name" "$current_line" "$end_line" "$sec_tc" "$sec_pri"
    total_tokens=$((total_tokens + sec_tc))
    current_line=$((end_line + 2))
    idx=$((idx + 1))
  done

  format_manifest_total "$total_tokens"
}
