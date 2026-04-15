#!/usr/bin/env bash
# scripts/diagnostics/check-constitution.sh — Constitution principle coverage check
#
# Scans active phase plan files for references to constitution principles I-XIII.
# Emits DOCTOR:CONSTITUTION structured output for consumption by run-doctor.sh.
#
# Usage:
#   check-constitution.sh [--root <project-root>] [--milestone-dir <dir>]
#
# Options:
#   --root           Project root directory (default: PROJECT_ROOT env or two levels up)
#   --milestone-dir  Specific milestone directory to scan (default: all milestones)
#
# Bash 3.2 compatible.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
MILESTONE_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    --milestone-dir) MILESTONE_DIR="$2"; shift 2 ;;
    *) echo "check-constitution.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

# --- Principle definitions ---
# Each line: NUMERAL|keyword1|keyword2|...
# Roman numeral matching is done via "Principle <NUMERAL>" pattern
PRINCIPLES="I|Context Minimization
II|Evidence Before Claims
III|Design Before Code
IV|Plans Assume Zero Context|Zero Context
V|Fresh Context Per Unit|Fresh Context
VI|State On Disk|Disk Is Truth
VII|Knowledge Compounds
VIII|No Dead Infrastructure|Dead Infrastructure
IX|Reproducibility Over Convenience|Reproducibility
X|Templating Over Inference
XI|Single Source of Truth
XII|Hook Isolation
XIII|Agent Instruction Schema|Instruction Schema"

TOTAL_PRINCIPLES=13

# --- Collect plan files ---
plan_files=""

if [ -n "$MILESTONE_DIR" ]; then
  # Scan specific milestone directory
  if [ -d "$MILESTONE_DIR/phases" ]; then
    for f in "$MILESTONE_DIR"/phases/*/*.md "$MILESTONE_DIR"/phases/*/*/*.md; do
      case "$(basename "$f" 2>/dev/null)" in
        *-PLAN.md|*PLAN*.md)
          [ -f "$f" ] && plan_files="${plan_files}${f}
"
          ;;
      esac
    done
  fi
else
  # Scan all milestone directories
  milestones_root="$PROJECT_ROOT/.orchestrator/milestones"
  if [ -d "$milestones_root" ]; then
    for mdir in "$milestones_root"/*/; do
      [ -d "$mdir" ] || continue
      if [ -d "${mdir}phases" ]; then
        for f in "${mdir}"phases/*/*.md "${mdir}"phases/*/*/*.md; do
          case "$(basename "$f" 2>/dev/null)" in
            *-PLAN.md|*PLAN*.md)
              [ -f "$f" ] && plan_files="${plan_files}${f}
"
              ;;
          esac
        done
      fi
    done
  fi
fi

# If no plan files found, report ok with 0 found
if [ -z "$plan_files" ]; then
  printf 'DOCTOR:CONSTITUTION status=warn principles_found=0 principles_total=%d\n' "$TOTAL_PRINCIPLES"
  printf '  MISSING: all principles (no plan files found)\n'
  exit 1
fi

# --- Concatenate all plan file contents for searching ---
all_content=""
IFS='
'
for pf in $plan_files; do
  [ -z "$pf" ] && continue
  [ -f "$pf" ] || continue
  content="$(cat "$pf")"
  all_content="${all_content}
${content}"
done
IFS=' '

# --- Check each principle ---
found_count=0
missing_list=""

IFS='
'
for principle_line in $PRINCIPLES; do
  IFS=' '

  # Extract numeral (first field)
  numeral="${principle_line%%|*}"
  rest="${principle_line#*|}"

  # Check for "Principle <NUMERAL>" pattern
  principle_found=false
  if printf '%s' "$all_content" | grep -q "Principle ${numeral}[^IV]" 2>/dev/null || \
     printf '%s' "$all_content" | grep -q "Principle ${numeral}\$" 2>/dev/null || \
     printf '%s' "$all_content" | grep -q "Principle ${numeral}[^a-zA-Z]" 2>/dev/null; then
    principle_found=true
  fi

  # If not found by numeral, check keywords
  if [ "$principle_found" = false ]; then
    remaining="$rest"
    while [ -n "$remaining" ]; do
      keyword="${remaining%%|*}"
      if [ "$remaining" = "$keyword" ]; then
        remaining=""
      else
        remaining="${remaining#*|}"
      fi
      if printf '%s' "$all_content" | grep -qi "$keyword" 2>/dev/null; then
        principle_found=true
        break
      fi
    done
  fi

  if [ "$principle_found" = true ]; then
    found_count=$((found_count + 1))
  else
    # Get first keyword for display
    display_name="${rest%%|*}"
    missing_list="${missing_list}  MISSING: Principle ${numeral} — ${display_name}
"
  fi

  IFS='
'
done
IFS=' '

# --- Report ---
if [ "$found_count" -eq "$TOTAL_PRINCIPLES" ]; then
  status="ok"
else
  status="warn"
fi

printf 'DOCTOR:CONSTITUTION status=%s principles_found=%d principles_total=%d\n' "$status" "$found_count" "$TOTAL_PRINCIPLES"

if [ "$status" = "warn" ] && [ -n "$missing_list" ]; then
  printf '%s' "$missing_list"
fi

if [ "$status" = "warn" ]; then
  exit 1
fi
exit 0
