#!/usr/bin/env bash
# scripts/verify/check-external-mods.sh — Detect files modified outside orchestrator scope
# Compares current HEAD against the phase_start_tree recorded in the lock file
# to find changes made outside the orchestrator's authorized scope.
#
# Usage: check-external-mods.sh <lock-file> [--scope <glob-pattern>]
#
# Output (stdout):
#   PASS: no external modifications
#   WARN: external modification: <file>
#   SKIP: <reason>
#
# Exit codes:
#   0 — clean (PASS or SKIP)
#   1 — usage error
#   2 — external modifications detected

set -euo pipefail

# --- Argument validation ---
if [[ $# -lt 1 ]]; then
  echo "check-external-mods.sh: missing lock-file argument" >&2
  echo "Usage: check-external-mods.sh <lock-file> [--scope <glob-pattern>]" >&2
  exit 1
fi

LOCK_FILE="$1"
shift

SCOPE_PATTERN=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope)
      if [[ $# -lt 2 ]]; then
        echo "check-external-mods.sh: --scope requires a value" >&2
        exit 1
      fi
      SCOPE_PATTERN="$2"
      shift 2
      ;;
    *)
      echo "check-external-mods.sh: unknown argument '$1'" >&2
      exit 1
      ;;
  esac
done

# --- Helper: Read a JSON field value (simple grep-based, no jq required) ---
json_field() {
  local file="$1"
  local key="$2"
  grep "\"${key}\"" "$file" 2>/dev/null \
    | head -1 \
    | sed 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*//' \
    | sed 's/^"//' \
    | sed 's/"[[:space:]]*,*[[:space:]]*$//' \
    | sed 's/,*[[:space:]]*$//' \
    | sed 's/[[:space:]]*$//'
}

# --- Graceful skip: no git available ---
if ! command -v git >/dev/null 2>&1; then
  echo "SKIP: git not available"
  exit 0
fi

# --- Graceful skip: not in a git repo ---
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "SKIP: not in a git repository"
  exit 0
fi

# --- Graceful skip: no lock file ---
if [[ ! -f "$LOCK_FILE" ]]; then
  echo "SKIP: lock file not found"
  exit 0
fi

# --- Read phase_start_tree from lock file ---
TREE_HASH="$(json_field "$LOCK_FILE" "phase_start_tree" || true)"

# --- Graceful skip: no phase_start_tree in lock ---
if [[ -z "$TREE_HASH" ]]; then
  echo "SKIP: no phase_start_tree in lock file"
  exit 0
fi

# --- Get changed files since phase start ---
CHANGED_FILES="$(git diff --name-only "$TREE_HASH" HEAD 2>/dev/null)" || {
  echo "SKIP: git diff failed (tree hash may be invalid)"
  exit 0
}

if [[ -z "$CHANGED_FILES" ]]; then
  echo "PASS: no external modifications"
  exit 0
fi

# --- Filter out authorized scope modifications ---
HAS_EXTERNAL=false

while IFS= read -r file; do
  [[ -z "$file" ]] && continue

  # If scope pattern is set, skip files that match it (authorized modifications)
  if [[ -n "$SCOPE_PATTERN" ]]; then
    # Use bash pattern matching — convert glob to a check
    # shellcheck disable=SC2254
    case "$file" in
      $SCOPE_PATTERN*) continue ;;
    esac
  fi

  echo "WARN: external modification: $file"
  HAS_EXTERNAL=true
done <<< "$CHANGED_FILES"

if [[ "$HAS_EXTERNAL" = true ]]; then
  exit 2
fi

echo "PASS: no external modifications"
exit 0
