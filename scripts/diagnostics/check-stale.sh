#!/usr/bin/env bash
# scripts/diagnostics/check-stale.sh — Detect stale knowledge entries
# Flags entries not verified in 90+ days with low hit counts, and entries
# with very low effective confidence.
#
# Bash 3.2 compatible. Read-only (never modifies knowledge/index files).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../knowledge/lib/index-utils.sh
source "$SCRIPT_DIR/../knowledge/lib/index-utils.sh"
# shellcheck source=../knowledge/lib/staleness.sh
source "$SCRIPT_DIR/../knowledge/lib/staleness.sh"

# Configurable thresholds
STALE_DAYS=90
EFFECTIVE_CONF_THRESHOLD=0.50

root="$(get_project_root)"
index_path="$(get_index_path)"

if [ ! -f "$index_path" ]; then
    echo "PASS: No index file"
    exit 0
fi

found_issues=false

while IFS= read -r line; do
    case "$line" in \#*|"<!--"*|"") continue ;; esac

    entry_id="$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$1); print $1}')"
    [ -z "$entry_id" ] && continue

    confidence="$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$4); print $4}')"
    verified_raw="$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$6); print $6}')"
    hits_raw="$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$7); print $7}')"

    # Parse verified:YYYY-MM-DD
    last_verified="$(echo "$verified_raw" | sed 's/^verified://')"
    # Parse hits:N
    hit_count="$(echo "$hits_raw" | sed 's/^hits://')"
    hit_count="${hit_count:-0}"

    [ -z "$last_verified" ] && continue
    [ -z "$confidence" ] && continue

    # Compute days since verified
    days="$(days_since "$last_verified")" || continue

    # Compute effective confidence
    eff_conf="$(compute_effective_confidence "$confidence" "$last_verified")"

    # Check if stale
    if [ "$days" -ge "$STALE_DAYS" ]; then
        # Entries with >10 hits are exempt from archival warning (keep-alive)
        if [ "$hit_count" -le 10 ]; then
            echo "WARNING: $entry_id is stale ($days days since verified, effective confidence: $eff_conf, hits: $hit_count) — suggest reviewing or archiving"
            found_issues=true
        fi
    fi

    # Check if effective confidence is very low
    eff_int="$(echo "$eff_conf" | awk '{printf "%d", $1 * 100}')"
    threshold_int="$(echo "$EFFECTIVE_CONF_THRESHOLD" | awk '{printf "%d", $1 * 100}')"
    if [ "$eff_int" -le "$threshold_int" ] && [ "$hit_count" -le 10 ]; then
        echo "WARNING: $entry_id has very low effective confidence ($eff_conf) — suggest archiving"
        found_issues=true
    fi
done < "$index_path"

if [ "$found_issues" = false ]; then
    echo "PASS: No stale entries detected (threshold: $STALE_DAYS days)."
fi
