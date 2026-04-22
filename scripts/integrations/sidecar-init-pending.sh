#!/usr/bin/env bash
# scripts/integrations/sidecar-init-pending.sh — write a pending-sentinel
# sidecar config to .orchestrator/integrations/github.json.
#
# Usage: sidecar-init-pending.sh [--root <project-root>]
#
# Exits 0 on successful write, 2 if the target already exists
# (refuses to clobber — delete to reset per FR-11).
# Bash 3.2 compatible (MEM001, Constitution IX).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    *) echo "sidecar-init-pending.sh: unknown flag: $1" >&2; exit 2 ;;
  esac
done

TEMPLATE="${PROJECT_ROOT}/templates/github-integration-sidecar.json"
TARGET_DIR="${PROJECT_ROOT}/.orchestrator/integrations"
TARGET="${TARGET_DIR}/github.json"

if [ ! -f "$TEMPLATE" ]; then
  echo "sidecar-init-pending.sh: template missing at $TEMPLATE" >&2
  exit 1
fi

if [ -f "$TARGET" ]; then
  echo "sidecar-init-pending.sh: $TARGET already exists — delete first to reset" >&2
  exit 2
fi

mkdir -p "$TARGET_DIR"

# Strip the _schema_docs key. Use awk (no jq hard dependency per MEM001).
# The _schema_docs block spans multiple lines; track brace depth from the
# opening "{" on the same line as the key through to its matching "}".
awk '
  BEGIN { skip=0; depth=0 }
  skip==0 && /"_schema_docs"[ \t]*:/ {
    skip=1
    n=gsub(/\{/, "{")
    m=gsub(/\}/, "}")
    depth = depth + n - m
    if (depth <= 0) { skip=0 }
    next
  }
  skip==1 {
    n=gsub(/\{/, "{")
    m=gsub(/\}/, "}")
    depth = depth + n - m
    if (depth <= 0) { skip=0 }
    next
  }
  { print }
' "$TEMPLATE" > "$TARGET"

echo "WROTE: $TARGET"
exit 0
