#!/usr/bin/env bash
# scripts/diagnostics/check-orphaned.sh — Detect orphaned knowledge artifacts
# Finds index entries without detail files and detail files without index entries.
#
# Bash 3.2 compatible. Read-only (never modifies knowledge/index files).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../knowledge/lib/index-utils.sh
source "$SCRIPT_DIR/../knowledge/lib/index-utils.sh"

root="$(get_project_root)"
index_path="$(get_index_path)"
knowledge_dir="$root/knowledge"

if [ ! -f "$index_path" ]; then
    echo "PASS: No index file (no knowledge entries to check)"
    exit 0
fi

if [ ! -d "$knowledge_dir" ]; then
    echo "PASS: No knowledge directory"
    exit 0
fi

found_issues=false

# Check 1: Index entries without detail files
while IFS= read -r line; do
    # Skip header/comment lines
    case "$line" in \#*|"<!--"*|"") continue ;; esac

    entry_id="$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$1); print $1}')"
    [ -z "$entry_id" ] && continue

    # Search for detail file in any category subdirectory (excluding archive)
    file_found=false
    for f in "$knowledge_dir"/*/"${entry_id}.md"; do
        if [ -f "$f" ]; then
            case "$f" in */archive/*) continue ;; esac
            file_found=true
            break
        fi
    done

    if [ "$file_found" = false ]; then
        echo "WARNING: Index entry $entry_id has no detail file — suggest rebuilding index or creating the file"
        found_issues=true
    fi
done < "$index_path"

# Check 2: Detail files without index entries
for f in "$knowledge_dir"/*/*.md; do
    [ -f "$f" ] || continue
    case "$f" in */archive/*|*/.gitkeep) continue ;; esac

    basename_file="$(basename "$f" .md)"
    case "$basename_file" in MEM*) ;; *) continue ;; esac

    if ! index_has_entry "$basename_file"; then
        echo "WARNING: Detail file $f has no index entry — suggest running rebuild-index.sh"
        found_issues=true
    fi
done

if [ "$found_issues" = false ]; then
    echo "PASS: No orphaned artifacts found."
fi
