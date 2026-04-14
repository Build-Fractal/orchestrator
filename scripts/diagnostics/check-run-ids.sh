#!/usr/bin/env bash
# scripts/diagnostics/check-run-ids.sh — JSONL run_id presence check
#
# Scans JSONL log entries for run_id field presence.
#
# Usage: check-run-ids.sh [--root <project-root>] [--jsonl <file>]
#
# Options:
#   --root   Project root directory (default: two levels up from script)
#   --jsonl  Specific JSONL file to scan. If not provided, scans all
#            execution-log.jsonl files under .specify/orchestrator/milestones/
#
# Output: DOCTOR:RUNIDS status=<ok|warn> with_id=N without_id=N
#
# Bash 3.2 compatible. Advisory only — reports state, does not fix it.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
JSONL_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    --jsonl) JSONL_FILE="$2"; shift 2 ;;
    *) echo "check-run-ids.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

# --- Collect JSONL files ---
FILES=""
if [ -n "$JSONL_FILE" ]; then
  # Resolve relative to PROJECT_ROOT if not absolute
  case "$JSONL_FILE" in
    /*) ;;
    *) JSONL_FILE="$PROJECT_ROOT/$JSONL_FILE" ;;
  esac
  if [ ! -f "$JSONL_FILE" ]; then
    echo "check-run-ids.sh: file not found: $JSONL_FILE" >&2
    exit 1
  fi
  FILES="$JSONL_FILE"
else
  # Find all execution-log.jsonl files under milestones
  milestones_dir="$PROJECT_ROOT/.specify/orchestrator/milestones"
  if [ -d "$milestones_dir" ]; then
    # Use find but capture output in a portable way
    FILES="$(find "$milestones_dir" -name 'execution-log.jsonl' -type f 2>/dev/null || true)"
  fi
fi

# --- No JSONL files or empty: report ok with zero counts ---
if [ -z "$FILES" ]; then
  printf 'DOCTOR:RUNIDS status=ok with_id=0 without_id=0\n'
  exit 0
fi

# --- Scan entries ---
with_id=0
without_id=0
warn_files=""

IFS='
'
for file in $FILES; do
  IFS=' '
  [ -f "$file" ] || continue
  file_without=0

  while IFS= read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue

    # Simple string match for "run_id"
    case "$line" in
      *'"run_id"'*)
        with_id=$((with_id + 1))
        ;;
      *)
        without_id=$((without_id + 1))
        file_without=$((file_without + 1))
        ;;
    esac
  done < "$file"

  if [ "$file_without" -gt 0 ]; then
    rel_path="${file#"$PROJECT_ROOT"/}"
    warn_files="${warn_files}  ${rel_path}: ${file_without} entries missing run_id
"
  fi
  IFS='
'
done
IFS=' '

# --- No entries at all: ok ---
if [ "$with_id" -eq 0 ] && [ "$without_id" -eq 0 ]; then
  printf 'DOCTOR:RUNIDS status=ok with_id=0 without_id=0\n'
  exit 0
fi

# --- Report ---
if [ "$without_id" -eq 0 ]; then
  status="ok"
else
  status="warn"
fi

printf 'DOCTOR:RUNIDS status=%s with_id=%d without_id=%d\n' "$status" "$with_id" "$without_id"

if [ "$status" = "warn" ] && [ -n "$warn_files" ]; then
  printf '%s' "$warn_files"
fi

if [ "$status" = "warn" ]; then
  exit 1
fi
exit 0
