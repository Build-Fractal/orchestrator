#!/usr/bin/env bash
# scripts/verify/check-scope.sh — Check modified files against declared scope
# Compares modified files against the "Files Likely Touched" section of a phase plan.
# Out-of-scope files are warnings (not failures).
#
# Usage: check-scope.sh <phase-plan-file> [--files file1,file2,file3]
#   --files   Comma-separated list of modified files (for testing without git)
#             If omitted, uses git diff --name-only HEAD
#
# Output: OK/WARN lines to stdout. Errors to stderr.
# Exit: Always 0 (scope violations are warnings, not failures).

set -euo pipefail

# --- Argument parsing ---
PLAN_FILE=""
FILES_LIST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --files)
      FILES_LIST="$2"; shift 2 ;;
    -*)
      echo "check-scope.sh: unknown option '$1'" >&2; exit 1 ;;
    *)
      if [[ -z "$PLAN_FILE" ]]; then
        PLAN_FILE="$1"
      fi
      shift ;;
  esac
done

if [[ -z "$PLAN_FILE" ]]; then
  echo "check-scope.sh: missing phase plan file argument" >&2
  echo "Usage: check-scope.sh <phase-plan-file> [--files file1,file2,file3]" >&2
  exit 1
fi

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "check-scope.sh: phase plan file not found: $PLAN_FILE" >&2
  exit 1
fi

# --- Extract declared scope from "Files Likely Touched" section ---

DECLARED_FILES=()
IN_SECTION=false

while IFS= read -r line; do
  if echo "$line" | grep -qE '^## Files Likely Touched'; then
    IN_SECTION=true
    continue
  fi
  # Next section header ends our section
  if [[ "$IN_SECTION" = "true" ]] && echo "$line" | grep -qE '^## '; then
    break
  fi
  if [[ "$IN_SECTION" = "true" ]]; then
    # Extract file paths from "- path/to/file" lines
    if echo "$line" | grep -qE '^- '; then
      file_path=$(echo "$line" | sed 's/^- //' | sed 's/[[:space:]]*$//')
      if [[ -n "$file_path" ]]; then
        DECLARED_FILES+=("$file_path")
      fi
    fi
  fi
done < "$PLAN_FILE"

# If no Files Likely Touched section found, also try Artifacts section
if [[ ${#DECLARED_FILES[@]} -eq 0 ]]; then
  IN_SECTION=false
  while IFS= read -r line; do
    if echo "$line" | grep -qE '^### Artifacts'; then
      IN_SECTION=true
      continue
    fi
    if [[ "$IN_SECTION" = "true" ]] && echo "$line" | grep -qE '^### |^## '; then
      break
    fi
    if [[ "$IN_SECTION" = "true" ]]; then
      if echo "$line" | grep -qE '^- '; then
        file_path=$(echo "$line" | sed 's/^- //' | sed 's/ *(.*//' | sed 's/[[:space:]]*$//')
        if [[ -n "$file_path" ]]; then
          DECLARED_FILES+=("$file_path")
        fi
      fi
    fi
  done < "$PLAN_FILE"
fi

# --- Get modified files ---

MODIFIED_FILES=()
if [[ -n "$FILES_LIST" ]]; then
  IFS=',' read -ra MODIFIED_FILES <<< "$FILES_LIST"
else
  # Use git diff
  while IFS= read -r line; do
    if [[ -n "$line" ]]; then
      MODIFIED_FILES+=("$line")
    fi
  done < <(git diff --name-only HEAD 2>/dev/null || true)
fi

if [[ ${#MODIFIED_FILES[@]} -eq 0 ]]; then
  echo "OK: no modified files to check"
  exit 0
fi

# --- Compare modified files against declared scope ---

WARN_COUNT=0

for mod_file in "${MODIFIED_FILES[@]}"; do
  mod_file=$(echo "$mod_file" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
  if [[ -z "$mod_file" ]]; then
    continue
  fi

  in_scope=false
  for declared in "${DECLARED_FILES[@]}"; do
    if [[ "$mod_file" = "$declared" ]]; then
      in_scope=true
      break
    fi
  done

  if [[ "$in_scope" = "true" ]]; then
    echo "OK: $mod_file"
  else
    echo "WARN: $mod_file (not declared in phase plan)"
    WARN_COUNT=$((WARN_COUNT + 1))
  fi
done

# Always exit 0 — scope violations are warnings, not failures
exit 0
