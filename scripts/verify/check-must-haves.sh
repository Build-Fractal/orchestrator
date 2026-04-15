#!/usr/bin/env bash
# scripts/verify/check-must-haves.sh — Tier 1 static verification
# Parses Must-Haves section from P##-PLAN.md and mechanically checks each item.
# Checks: Truths (grep patterns), Artifacts (existence, min lines, contains), Key Links (cross-refs).
#
# Usage: check-must-haves.sh <phase-dir>
#   <phase-dir>  Directory containing P##-PLAN.md
#
# Output: Structured PASS/FAIL lines to stdout. Errors to stderr.
# Exit: 0 if all checks pass, 1 if any check fails.

set -euo pipefail

# Engine integration libraries (standalone-safe)
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="$(cd "$_SCRIPT_DIR/../lib" && pwd)"
. "$_LIB_DIR/errors.sh"
. "$_LIB_DIR/events.sh"

# --- Result emission on exit (stderr, not stdout) ---
_CMH_RESULT_EMITTED=0
_cmh_final_result() {
  local rc=$?
  if [ "$_CMH_RESULT_EMITTED" -eq 0 ] && [ -n "${ORCH_RUN_ID:-}" ]; then
    if [ "$rc" -eq 0 ]; then
      emit_result ok "" "must-haves verified" >&2
    else
      emit_result error VERIFY "check-must-haves failed rc=$rc" >&2
    fi
    _CMH_RESULT_EMITTED=1
  fi
}
trap _cmh_final_result EXIT

# --- Argument validation ---
if [[ $# -lt 1 ]]; then
  echo "check-must-haves.sh: missing phase directory argument" >&2
  echo "Usage: check-must-haves.sh <phase-dir>" >&2
  exit 1
fi

PHASE_DIR="$1"

if [[ ! -d "$PHASE_DIR" ]]; then
  echo "check-must-haves.sh: phase directory not found: $PHASE_DIR" >&2
  exit 1
fi

# Find the P##-PLAN.md file
PLAN_FILE=""
for f in "$PHASE_DIR"/P[0-9]*-PLAN.md; do
  if [[ -f "$f" ]]; then
    PLAN_FILE="$f"
    break
  fi
done

if [[ -z "$PLAN_FILE" ]]; then
  echo "check-must-haves.sh: no P##-PLAN.md found in $PHASE_DIR" >&2
  exit 1
fi

if [ -n "${ORCH_RUN_ID:-}" ]; then
  emit_event VERIFY_START stage=check_must_haves plan="$(basename "$PLAN_FILE")" >&2
fi

# Resolve project root: walk up from phase dir to find .git or orchestrator config
PROJECT_ROOT=""
candidate="$(cd "$PHASE_DIR" && pwd)"
while [ "$candidate" != "/" ]; do
  if [ -d "$candidate/.git" ] || [ -d "$candidate/.orchestrator" ]; then
    PROJECT_ROOT="$candidate"
    break
  fi
  candidate="$(dirname "$candidate")"
done

if [ -z "$PROJECT_ROOT" ]; then
  # Fallback for test fixtures: use the old walk-up-to-phases-parent logic
  candidate="$(cd "$PHASE_DIR" && pwd)"
  while [ "$candidate" != "/" ]; do
    parent_name="$(basename "$(dirname "$candidate")")"
    if [ "$parent_name" = "phases" ]; then
      PROJECT_ROOT="$(dirname "$(dirname "$candidate")")"
      break
    fi
    candidate="$(dirname "$candidate")"
  done
fi

if [ -z "$PROJECT_ROOT" ]; then
  # Last-resort fallback
  PROJECT_ROOT="$(cd "$PHASE_DIR/../.." 2>/dev/null && pwd)"
fi

FAILURES=0

# --- Parse Must-Haves section ---

# Extract the section between ## Must-Haves and the next ## heading
MUST_HAVES_SECTION=$(sed -n '/^## Must-Haves/,/^## [^#]/p' "$PLAN_FILE" | sed '$d')

if [[ -z "$MUST_HAVES_SECTION" ]]; then
  # Try without trailing delimiter (Must-Haves is the last section)
  MUST_HAVES_SECTION=$(sed -n '/^## Must-Haves/,$p' "$PLAN_FILE")
fi

if [[ -z "$MUST_HAVES_SECTION" ]]; then
  echo "check-must-haves.sh: no Must-Haves section found in $PLAN_FILE" >&2
  exit 1
fi

# --- Extract and check Truths ---

CURRENT_SECTION=""
PENDING_TRUTH=""

while IFS= read -r line; do
  # Track which subsection we're in
  if echo "$line" | grep -qE '^### Truths'; then
    CURRENT_SECTION="truths"
    continue
  elif echo "$line" | grep -qE '^### Artifacts'; then
    CURRENT_SECTION="artifacts"
    continue
  elif echo "$line" | grep -qE '^### Key Links'; then
    CURRENT_SECTION="keylinks"
    continue
  elif echo "$line" | grep -qE '^### '; then
    CURRENT_SECTION=""
    continue
  fi

  case "$CURRENT_SECTION" in
    truths)
      # Top-level truth item: starts with "- " (not indented sub-item)
      if echo "$line" | grep -qE '^- [^[:space:]]'; then
        # Store description for potential Tier 3 logging
        PENDING_TRUTH=$(echo "$line" | sed 's/^- //')
      fi
      # Sub-item with Check: command
      if echo "$line" | grep -qE '^[[:space:]]+- Check:'; then
        # Extract command from backticks
        check_cmd=$(echo "$line" | sed 's/.*`\(.*\)`.*/\1/')
        if [[ -n "$check_cmd" ]]; then
          # Run the check command relative to project root
          # TRUST BOUNDARY: eval runs commands authored by the orchestrator in phase plans.
          # These are trusted check commands (e.g., grep patterns) — not user input.
          if (cd "$PROJECT_ROOT" && eval "$check_cmd") >/dev/null 2>&1; then
            echo "PASS: truth '$PENDING_TRUTH'"
          else
            echo "FAIL: truth '$PENDING_TRUTH' (check command failed: $check_cmd)"
            FAILURES=$((FAILURES + 1))
          fi
        fi
        PENDING_TRUTH=""
      fi
      ;;

    artifacts)
      # Artifact line: "- path/to/file" with optional "(min N lines)" and/or "(contains "pattern")"
      if echo "$line" | grep -qE '^- [^[:space:]]'; then
        # Extract path (everything before the first parenthesis, or the whole line minus "- ")
        # Strip surrounding backticks if present (markdown code-span quoting).
        artifact_path=$(echo "$line" | sed 's/^- //' | sed 's/ *(.*$//' | sed 's/[[:space:]]*$//' | sed 's/^`//' | sed 's/`$//')
        
        # Extract min lines if specified
        min_lines=""
        if echo "$line" | grep -qE '\(min [0-9]+ lines'; then
          min_lines=$(echo "$line" | grep -oE 'min [0-9]+ lines' | grep -oE '[0-9]+')
        fi

        # Extract contains pattern if specified
        contains_pattern=""
        if echo "$line" | grep -qE 'contains "'; then
          contains_pattern=$(echo "$line" | sed 's/.*contains "\([^"]*\)".*/\1/')
        fi

        # Check 1: File exists
        full_path="$PROJECT_ROOT/$artifact_path"
        if [[ -f "$full_path" ]]; then
          echo "PASS: artifact $artifact_path exists"
        else
          echo "FAIL: artifact $artifact_path not found (expected at $full_path)"
          FAILURES=$((FAILURES + 1))
          # Skip remaining checks for this artifact
          continue
        fi

        # Check 2: Min lines
        if [[ -n "$min_lines" ]]; then
          actual_lines=$(wc -l < "$full_path" | tr -d ' ')
          if [[ "$actual_lines" -ge "$min_lines" ]]; then
            echo "PASS: artifact $artifact_path has $actual_lines lines (min $min_lines)"
          else
            echo "FAIL: artifact $artifact_path has $actual_lines lines (expected min $min_lines)"
            FAILURES=$((FAILURES + 1))
          fi
        fi

        # Check 3: Contains pattern
        if [[ -n "$contains_pattern" ]]; then
          if grep -q -- "$contains_pattern" "$full_path" 2>/dev/null; then
            echo "PASS: artifact $artifact_path contains '$contains_pattern'"
          else
            echo "FAIL: artifact $artifact_path does not contain '$contains_pattern' (pattern not found)"
            FAILURES=$((FAILURES + 1))
          fi
        fi
      fi
      ;;

    keylinks)
      # Key link line: "- from_path → to_path (description)"
      if echo "$line" | grep -qE '^- .* → '; then
        from_path=$(echo "$line" | sed 's/^- //' | sed 's/ →.*//' | sed 's/[[:space:]]*$//' | sed 's/^`//' | sed 's/`$//')
        # Handle both → (UTF-8) properly
        to_path=$(echo "$line" | sed 's/.*→ //' | sed 's/ *(.*//' | sed 's/[[:space:]]*$//' | sed 's/^`//' | sed 's/`$//')
        
        from_full="$PROJECT_ROOT/$from_path"
        to_basename=$(basename "$to_path")

        if [[ ! -f "$from_full" ]]; then
          echo "FAIL: key-link $from_path → $to_path (source file $from_path not found)"
          FAILURES=$((FAILURES + 1))
          continue
        fi

        if grep -q "$to_basename" "$from_full" 2>/dev/null; then
          echo "PASS: key-link $from_path → $to_path (reference found)"
        else
          echo "FAIL: key-link $from_path → $to_path (no reference to '$to_basename' in $from_path)"
          FAILURES=$((FAILURES + 1))
        fi
      fi
      ;;
  esac
done <<< "$MUST_HAVES_SECTION"

if [ -n "${ORCH_RUN_ID:-}" ]; then
  emit_event VERIFY_COMPLETE stage=check_must_haves failures="$FAILURES" >&2
fi

# --- Exit ---
if [[ "$FAILURES" -gt 0 ]]; then
  exit 1
fi
exit 0
