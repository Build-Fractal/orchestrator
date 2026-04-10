#!/usr/bin/env bash
# scripts/diagnostics/check-scope.sh — Detect scope issues in knowledge entries
# Flags entries with no scope tags (these get injected into ALL dispatches).
#
# Bash 3.2 compatible. Read-only (never modifies knowledge/index files).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../knowledge/lib/index-utils.sh
source "$SCRIPT_DIR/../knowledge/lib/index-utils.sh"

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

    scope_tag="$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2}')"

    # Check for missing/empty scope tag
    if [ -z "$scope_tag" ]; then
        echo "WARNING: $entry_id has no scope tag — will be injected into ALL dispatches. Suggest adding [project] or [milestone:M###]"
        found_issues=true
    fi
done < "$index_path"

if [ "$found_issues" = false ]; then
    echo "PASS: All entries have scope tags."
fi
