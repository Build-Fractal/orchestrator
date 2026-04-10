#!/usr/bin/env bash
[ -n "${_SUPERSESSION_CHAIN_SOURCED:-}" ] && return 0
_SUPERSESSION_CHAIN_SOURCED=1
set -euo pipefail

# =============================================================================
# supersession-chain.sh — Resolve supersession chains
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+
#
# Usage: source this file, then call resolve_supersession_chains <knowledge_dat> <output_dir>
# Writes: <output_dir>/active_entries.dat and <output_dir>/superseded_entries.dat
# Both files have the same TSV format as knowledge.dat (same header).
# =============================================================================

resolve_supersession_chains() {
    local knowledge_dat="$1"
    local output_dir="$2"

    # Read the header line
    local header
    header="$(head -1 "$knowledge_dat")"

    # Write headers to both output files
    echo "$header" > "${output_dir}/active_entries.dat"
    echo "$header" > "${output_dir}/superseded_entries.dat"

    # Process data rows (skip header)
    # superseded_by is field 10 based on the extended KNOWLEDGE_FIELDS
    tail -n +2 "$knowledge_dat" | while IFS= read -r line; do
        [ -z "$line" ] && continue

        # Extract superseded_by field (column 10, tab-separated)
        local superseded_by
        superseded_by="$(echo "$line" | awk -F'\t' '{print $10}')"

        if [ -z "$superseded_by" ]; then
            echo "$line" >> "${output_dir}/active_entries.dat"
        else
            echo "$line" >> "${output_dir}/superseded_entries.dat"
        fi
    done
}
