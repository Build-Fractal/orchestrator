#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# knowledge-index.sh — Generate KNOWLEDGE-INDEX.md from migrated detail files
# =============================================================================
#
# Version: 1.0
# Compatibility: Bash 3.2+
#
# Usage: knowledge-index.sh <target_project_root>
#
# Invokes rebuild-index.sh from the knowledge scripts (M002/P01 deliverable)
# to regenerate the KNOWLEDGE-INDEX.md from knowledge/ detail files.
# =============================================================================

target_root="${1:?Usage: knowledge-index.sh <target_project_root>}"

# Set PROJECT_ROOT so rebuild-index.sh finds the right knowledge/ directory
export PROJECT_ROOT="$target_root"

# Find rebuild-index.sh relative to this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REBUILD_SCRIPT="${SCRIPT_DIR}/../../knowledge/rebuild-index.sh"

if [ -f "$REBUILD_SCRIPT" ]; then
    bash "$REBUILD_SCRIPT" --root "$target_root"
else
    echo "ERROR: rebuild-index.sh not found at $REBUILD_SCRIPT" >&2
    echo "knowledge-index.sh requires M002/P01's rebuild-index.sh" >&2
    exit 1
fi
