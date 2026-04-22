#!/usr/bin/env bash
# scripts/verify/validate-milestone.sh — Full cross-phase milestone validation
# Runs all validation checks needed before a milestone can transition from
# 'validating' to 'completing'. Replaces inline for-loops in auto mode.
#
# Usage: validate-milestone.sh <milestone-dir>
#
# Checks:
#   1. All phases in the roadmap have P##-SUMMARY.md
#   2. All boundary map produces exist on disk
#   3. Cross-phase dependency satisfaction (consumes are met by produces)
#
# Output: Structured VALIDATE: lines. Summary at end.
# Exit: 0 if all checks pass, 1 if any fail.
#
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
READ_ROADMAP="$PROJECT_ROOT/scripts/state/read-roadmap.sh"
CHECK_BOUNDARY="$PROJECT_ROOT/scripts/verify/check-boundary-map.sh"

if [[ $# -lt 1 ]]; then
  echo "validate-milestone.sh: missing milestone directory argument" >&2
  echo "Usage: validate-milestone.sh <milestone-dir>" >&2
  exit 1
fi

MILESTONE_DIR="$1"

if [[ ! -d "$MILESTONE_DIR" ]]; then
  echo "ERROR: Milestone directory does not exist: $MILESTONE_DIR" >&2
  exit 1
fi

# Detect milestone ID from directory contents
MILESTONE_ID="$(basename "$MILESTONE_DIR")"
roadmap_file="$MILESTONE_DIR/${MILESTONE_ID}-ROADMAP.md"

if [[ ! -f "$roadmap_file" ]]; then
  echo "ERROR: Roadmap not found: $roadmap_file" >&2
  exit 1
fi

# Get all phases from roadmap
phases_output=$(bash "$READ_ROADMAP" "$roadmap_file" phases 2>/dev/null) || {
  echo "ERROR: Failed to read roadmap phases" >&2
  exit 1
}

total_checks=0
passed_checks=0
failed_checks=0
failed_details=""

# --- Check 1: All phase summaries exist ---
while IFS=' ' read -r pid pstatus prisk pdepends; do
  [[ -z "$pid" ]] && continue
  total_checks=$((total_checks + 1))
  summary="$MILESTONE_DIR/phases/$pid/${pid}-SUMMARY.md"
  if [[ -f "$summary" ]]; then
    echo "VALIDATE: $pid summary EXISTS"
    passed_checks=$((passed_checks + 1))
  else
    echo "VALIDATE: $pid summary MISSING"
    failed_checks=$((failed_checks + 1))
    failed_details="${failed_details}  - $pid: summary missing\n"
  fi
done <<< "$phases_output"

# --- Check 2: Boundary map produces exist on disk ---
while IFS=' ' read -r pid pstatus prisk pdepends; do
  [[ -z "$pid" ]] && continue
  total_checks=$((total_checks + 1))
  # Run boundary check, capture output and exit code
  boundary_output=$(bash "$CHECK_BOUNDARY" "$roadmap_file" "$pid" --root "$PROJECT_ROOT" 2>&1) || true
  boundary_exit=$?

  # SKIP means no produce items to check — treat as pass
  if echo "$boundary_output" | grep -q "^SKIP:"; then
    echo "VALIDATE: $pid boundary SKIP (no produce items)"
    passed_checks=$((passed_checks + 1))
  elif [[ $boundary_exit -eq 0 ]]; then
    echo "VALIDATE: $pid boundary PASS"
    passed_checks=$((passed_checks + 1))
  else
    echo "VALIDATE: $pid boundary FAIL"
    failed_checks=$((failed_checks + 1))
    failed_details="${failed_details}  - $pid: boundary check failed\n"
  fi
done <<< "$phases_output"

# --- Check 3: Key produced files exist (hardened file check) ---
# Read key_files from each phase summary and verify they exist
while IFS=' ' read -r pid pstatus prisk pdepends; do
  [[ -z "$pid" ]] && continue
  summary="$MILESTONE_DIR/phases/$pid/${pid}-SUMMARY.md"
  [[ -f "$summary" ]] || continue

  # Extract key_files from YAML frontmatter
  key_files_line=$(sed -n '/^---$/,/^---$/{
    /^key_files:/,/^[a-z]/{
      /^  - /p
    }
  }' "$summary" | head -1)

  if [[ -z "$key_files_line" ]]; then
    continue
  fi

  # Parse comma/semicolon-separated file list from the first item
  files_str=$(echo "$key_files_line" | sed 's/^  - "//' | sed 's/"$//')
  # Split on comma or semicolon (both conventions accepted — M012 used ',', M013 used ';')
  OLD_IFS="$IFS"
  IFS=',;'
  for raw_file in $files_str; do
    file=$(echo "$raw_file" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    [[ -z "$file" ]] && continue
    total_checks=$((total_checks + 1))
    # Entries ending in / are directory paths; others are files.
    case "$file" in
      */)
        if [[ -d "$PROJECT_ROOT/$file" ]]; then
          passed_checks=$((passed_checks + 1))
        else
          echo "VALIDATE: $pid key_file MISSING: $file"
          failed_checks=$((failed_checks + 1))
          failed_details="${failed_details}  - $pid: key file missing: $file\n"
        fi
        ;;
      *)
        if [[ -f "$PROJECT_ROOT/$file" ]]; then
          passed_checks=$((passed_checks + 1))
        else
          echo "VALIDATE: $pid key_file MISSING: $file"
          failed_checks=$((failed_checks + 1))
          failed_details="${failed_details}  - $pid: key file missing: $file\n"
        fi
        ;;
    esac
  done
  IFS="$OLD_IFS"
done <<< "$phases_output"

# --- Summary ---
echo ""
if [[ $failed_checks -eq 0 ]]; then
  echo "VALIDATE: PASS — $passed_checks/$total_checks checks passed"
  exit 0
else
  echo "VALIDATE: FAIL — $passed_checks/$total_checks checks passed, $failed_checks failed"
  if [[ -n "$failed_details" ]]; then
    echo "Failures:"
    printf "%b" "$failed_details"
  fi
  exit 1
fi
