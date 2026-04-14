#!/usr/bin/env bash
# scripts/diagnostics/check-instructions.sh — Instruction schema conformance check
#
# Scans agent instruction files (commands/*.md) for required section headings
# as defined by templates/instruction-schema.md. Reports DOCTOR:INSTRUCTIONS
# structured output for consumption by run-doctor.sh.
#
# Usage:
#   check-instructions.sh [--root <project-root>] [--target <file>]
#
# Options:
#   --root    Project root directory (default: two levels up from script)
#   --target  Check a single file instead of all commands/*.md files
#
# Bash 3.2 compatible.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
TARGET=""

while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    *) echo "check-instructions.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

# --- Required section groups ---
# Format: GroupName|alias1|alias2|alias3
REQUIRED_GROUPS="Context|Context|Prerequisites|State Context|State Derivation|Context Gathering
Task|Task|Scope|Phase Planning|What It Checks|Usage|Context Construction|Dispatch Strategy
Constraints|Constraints|Error Handling|Gotchas|Idempotency|Concurrent Safety|Budget Gates
Verification|Verification|Post-Dispatch|Validation|Must-Haves|Tier 1
Output Format|Output Format|Expected Output|Output|Referenced Templates|Payload Size Guidance"

# --- Build file list ---
if [ -n "$TARGET" ]; then
  # Resolve relative to PROJECT_ROOT if not absolute
  case "$TARGET" in
    /*) file_list="$TARGET" ;;
    *)  file_list="$PROJECT_ROOT/$TARGET" ;;
  esac
  if [ ! -f "$file_list" ]; then
    echo "check-instructions.sh: target not found: $file_list" >&2
    exit 1
  fi
else
  file_list=""
  for f in "$PROJECT_ROOT"/commands/*.md; do
    # Skip README.md
    case "$(basename "$f")" in
      README.md) continue ;;
    esac
    [ -f "$f" ] && file_list="${file_list}${file_list:+
}$f"
  done
fi

if [ -z "$file_list" ]; then
  printf 'DOCTOR:INSTRUCTIONS status=ok files=0 missing=0\n'
  exit 0
fi

# --- Extract ## headings from a file ---
extract_headings() {
  local file="$1"
  # Match lines starting with "## " and capture the heading text
  while IFS= read -r line; do
    case "$line" in
      "## "*)
        heading="${line#\#\# }"
        printf '%s\n' "$heading"
        ;;
    esac
  done < "$file"
}

# --- Check one file against required groups ---
# Returns missing group names (one per line), empty if all present
check_file() {
  local file="$1"
  local headings
  headings="$(extract_headings "$file")"

  local missing=""

  # Save and restore IFS for outer loop
  local old_ifs="$IFS"
  IFS='
'
  for group_line in $REQUIRED_GROUPS; do
    IFS="$old_ifs"
    # Extract group name (first field before |)
    local group_name="${group_line%%|*}"

    # Check each alias in the group
    local found=false
    local remaining="$group_line"
    while [ -n "$remaining" ]; do
      local alias="${remaining%%|*}"
      if [ "$remaining" = "$alias" ]; then
        remaining=""
      else
        remaining="${remaining#*|}"
      fi
      # Check if this alias appears in headings
      if printf '%s\n' "$headings" | while IFS= read -r h; do
        [ "$h" = "$alias" ] && exit 0
      done; then
        found=true
        break
      fi
    done

    if [ "$found" = false ]; then
      missing="${missing}${missing:+
}$group_name"
    fi
    IFS='
'
  done
  IFS="$old_ifs"

  printf '%s' "$missing"
}

# --- Main scan ---
total_files=0
total_missing=0
warn_details=""

IFS='
'
for file in $file_list; do
  IFS=' '
  [ -f "$file" ] || continue
  total_files=$((total_files + 1))

  missing="$(check_file "$file")"
  if [ -n "$missing" ]; then
    # Count missing groups for this file
    file_missing=0
    IFS='
'
    for m in $missing; do
      IFS=' '
      file_missing=$((file_missing + 1))
      total_missing=$((total_missing + 1))
    done
    IFS=' '

    rel_path="${file#"$PROJECT_ROOT"/}"
    warn_details="${warn_details}  ${rel_path}: missing [${missing}]
"
  fi
  IFS='
'
done
IFS=' '

# --- Report ---
if [ "$total_missing" -eq 0 ]; then
  status="ok"
else
  status="warn"
fi

printf 'DOCTOR:INSTRUCTIONS status=%s files=%d missing=%d\n' "$status" "$total_files" "$total_missing"

if [ "$status" = "warn" ] && [ -n "$warn_details" ]; then
  printf '%s' "$warn_details"
fi

if [ "$status" = "warn" ]; then
  exit 1
fi
exit 0
