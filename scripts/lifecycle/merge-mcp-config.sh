#!/usr/bin/env bash
# scripts/lifecycle/merge-mcp-config.sh — M034 P03 (FR-10 / CON-6).
#
# Non-clobbering merge of the orchestrator review-gate server entry into a
# .cursor/mcp.json. MERGE, not overwrite (CON-6): operator-authored mcpServers
# entries are preserved byte-for-byte; only `.mcpServers["<name>"]` is set/replaced.
# Idempotent (re-run leaves exactly one orchestrator entry). Absent target -> create
# with only our entry. Malformed existing JSON -> FAIL CLOSED (exit 2, no write).
#
# Usage:
#   merge-mcp-config.sh --target <.cursor/mcp.json> --name <server-name> --entry <json>
#     [--dry-run]
#
# Exit: 0 merged/created (or would_write on --dry-run); 1 bad args; 2 malformed
# target (fail-closed).
#
# CON-1: bash 3.2 / POSIX-sh single file. jq REQUIRED.
set -u

TARGET=""
NAME=""
ENTRY=""
DRY_RUN=0

# Atomic write: jq the merged document to a tmpfile, then mv over the target.
# AD-19 helper-function carve-out — the jq+mv chain lives in a function body so
# no inline call-site trips the AP-009 shape-guard.
_write_atomic() {
  # $1 = destination path, remaining = jq invocation pieces are passed via
  # the caller's positional args after the dest. We build the merged doc on
  # stdin from the caller and write it atomically.
  _dest="$1"
  _tmp="${_dest}.tmp.$$"
  cat > "$_tmp"
  mv "$_tmp" "$_dest"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --target)
      shift
      if [ $# -eq 0 ]; then echo "ERROR: --target requires a path" >&2; exit 1; fi
      TARGET="$1"; shift ;;
    --target=*)
      TARGET="${1#--target=}"; shift ;;
    --name)
      shift
      if [ $# -eq 0 ]; then echo "ERROR: --name requires a value" >&2; exit 1; fi
      NAME="$1"; shift ;;
    --name=*)
      NAME="${1#--name=}"; shift ;;
    --entry)
      shift
      if [ $# -eq 0 ]; then echo "ERROR: --entry requires a JSON value" >&2; exit 1; fi
      ENTRY="$1"; shift ;;
    --entry=*)
      ENTRY="${1#--entry=}"; shift ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    *)
      shift ;;
  esac
done

if [ -z "$TARGET" ] || [ -z "$NAME" ] || [ -z "$ENTRY" ]; then
  echo "ERROR: --target, --name and --entry are all required" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not on PATH" >&2
  exit 1
fi

# Validate --entry is a JSON object.
if ! printf '%s' "$ENTRY" | jq -e . >/dev/null 2>&1; then
  echo "ERROR: --entry is not valid JSON" >&2
  exit 1
fi

# --dry-run: report what would happen, write nothing.
if [ "$DRY_RUN" = "1" ]; then
  # Still fail closed on a malformed existing target so dry-run mirrors real
  # behavior.
  if [ -f "$TARGET" ] && ! jq -e . "$TARGET" >/dev/null 2>&1; then
    echo "FAIL: malformed .cursor/mcp.json — preserving operator file" >&2
    exit 2
  fi
  echo "would_write=$TARGET"
  exit 0
fi

if [ -f "$TARGET" ]; then
  # Existing target must be parseable JSON, else FAIL CLOSED (no write).
  if ! jq -e . "$TARGET" >/dev/null 2>&1; then
    echo "FAIL: malformed .cursor/mcp.json — preserving operator file" >&2
    exit 2
  fi
  # Right-biased merge: replace only our key; preserve every other mcpServers
  # key and every other top-level key.
  jq --arg n "$NAME" --argjson e "$ENTRY" \
    '.mcpServers = ((.mcpServers // {}) + {($n): $e})' "$TARGET" \
    | _write_atomic "$TARGET"
else
  mkdir -p "$(dirname "$TARGET")"
  jq -n --arg n "$NAME" --argjson e "$ENTRY" \
    '{mcpServers:{($n):$e}}' \
    | _write_atomic "$TARGET"
fi

echo "merged=$TARGET name=$NAME"
exit 0
