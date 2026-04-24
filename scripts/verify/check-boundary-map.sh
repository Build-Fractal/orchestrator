#!/usr/bin/env bash
# scripts/verify/check-boundary-map.sh — Verify phase boundary map produces items
# Reads the roadmap file's boundary map "Produces" entries for a given phase
# and checks that each produced item exists on disk.
#
# Usage: check-boundary-map.sh <roadmap-file> <phase-id> [--root <project-root>]
#
# Output: Structured PASS/FAIL lines to stdout. Errors to stderr.
# Exit: 0 if all produce items exist, 1 if any are missing.

set -euo pipefail

# --- Argument parsing ---
ROADMAP_FILE=""
PHASE_ID=""
PROJECT_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      PROJECT_ROOT="$2"; shift 2 ;;
    -*)
      echo "check-boundary-map.sh: unknown option '$1'" >&2; exit 1 ;;
    *)
      if [[ -z "$ROADMAP_FILE" ]]; then
        ROADMAP_FILE="$1"
      elif [[ -z "$PHASE_ID" ]]; then
        PHASE_ID="$1"
      fi
      shift ;;
  esac
done

if [[ -z "$ROADMAP_FILE" || -z "$PHASE_ID" ]]; then
  echo "check-boundary-map.sh: missing required arguments" >&2
  echo "Usage: check-boundary-map.sh <roadmap-file> <phase-id> [--root <project-root>]" >&2
  exit 1
fi

if [[ ! -f "$ROADMAP_FILE" ]]; then
  echo "check-boundary-map.sh: roadmap file not found: $ROADMAP_FILE" >&2
  exit 1
fi

# Default project root: directory containing the roadmap file
if [[ -z "$PROJECT_ROOT" ]]; then
  PROJECT_ROOT="$(cd "$(dirname "$ROADMAP_FILE")" && pwd)"
fi

# --- Find phase section and extract Produces items ---

# Extract the phase block for the requested phase ID
# Phase blocks start with "- [x] **P##**:" or "- [ ] **P##**:" and end at the next phase or section
PHASE_FOUND=false
IN_PRODUCES=false
FAILURES=0
CHECKS=0

while IFS= read -r line; do
  # Detect phase header
  if echo "$line" | grep -qE "^\- \[(x| )\] \*\*${PHASE_ID}\*\*"; then
    PHASE_FOUND=true
    continue
  fi

  # Detect next phase header (end of our phase)
  if [[ "$PHASE_FOUND" = "true" ]] && echo "$line" | grep -qE '^\- \[(x| )\] \*\*P[0-9]+\*\*'; then
    break
  fi

  if [[ "$PHASE_FOUND" = "true" ]]; then
    # Detect "Produces:" line
    if echo "$line" | grep -qiE 'Produces:'; then
      IN_PRODUCES=true
      # Extract items on the same line after "Produces:"
      items=$(echo "$line" | sed 's/.*Produces:[[:space:]]*//')
      if [[ -n "$items" && "$items" != "$line" ]]; then
        # Strip parenthetical commentary so comma-inside-parens doesn't
        # explode a single path-with-annotation into fragments. Same pattern
        # read-roadmap.sh uses on Risk: and Depends: lines.
        items=$(printf '%s' "$items" | sed 's/([^)]*)//g')
        # Split comma-separated items
        IFS=',' read -ra ITEMS <<< "$items"
        for item in "${ITEMS[@]}"; do
          item=$(echo "$item" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
          # Handle glob patterns like "commands/*.md" or "scripts/state/*.sh"
          if [[ -z "$item" ]]; then
            continue
          fi
          # Skip fragments that aren't path-shaped. Roadmap Produces: cells
          # sometimes carry narrative prose like "patched conversus.sh;
          # edition env-var handling; OAuth auto-preflight" which comma-splits
          # into fragments that aren't files on disk. Heuristic: a path is
          # alnum + [._/*-] with no whitespace, semicolons, or quotes.
          # (Parenthetical annotations were already stripped above.)
          if ! printf '%s' "$item" | grep -qE '^[A-Za-z0-9._/*-]+$'; then
            continue
          fi
          CHECKS=$((CHECKS + 1))
          # Check if it's a glob pattern
          if echo "$item" | grep -q '\*'; then
            # shellcheck disable=SC2086
            matches=$(find "$PROJECT_ROOT" -path "$PROJECT_ROOT/$item" 2>/dev/null | head -1) || true
            # Alternative: use ls with glob
            if ls $PROJECT_ROOT/$item >/dev/null 2>&1; then
              echo "PASS: boundary-map $PHASE_ID produces $item (found)"
            else
              echo "FAIL: boundary-map $PHASE_ID produces $item (no files matching pattern)"
              FAILURES=$((FAILURES + 1))
            fi
          else
            if [[ -f "$PROJECT_ROOT/$item" || -d "$PROJECT_ROOT/$item" ]]; then
              echo "PASS: boundary-map $PHASE_ID produces $item (found)"
            else
              echo "FAIL: boundary-map $PHASE_ID produces $item (not found at $PROJECT_ROOT/$item)"
              FAILURES=$((FAILURES + 1))
            fi
          fi
        done
      fi
      continue
    fi

    # Detect "Consumes:" — end of Produces section
    if echo "$line" | grep -qiE 'Consumes:'; then
      IN_PRODUCES=false
      continue
    fi

    # Detect next sub-section or blank non-indented line
    if echo "$line" | grep -qE '^[[:space:]]*$'; then
      continue
    fi
  fi
done < "$ROADMAP_FILE"

if [[ "$PHASE_FOUND" = "false" ]]; then
  echo "check-boundary-map.sh: phase '$PHASE_ID' not found in $ROADMAP_FILE" >&2
  exit 1
fi

if [[ "$CHECKS" -eq 0 ]]; then
  echo "SKIP: boundary-map $PHASE_ID has no produce items"
  exit 0
fi

# --- Exit ---
if [[ "$FAILURES" -gt 0 ]]; then
  exit 1
fi
exit 0
