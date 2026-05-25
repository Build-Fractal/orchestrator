#!/usr/bin/env bash
# scripts/diagnostics/triage-issue.sh — Core triage report engine
# Emits a structured Markdown report with YAML frontmatter and six sections.
#
# Usage:
#   triage-issue.sh --symptom "template not found: foo.md"
#   triage-issue.sh --symptom "dispatch fails" --errors-only --suggest-fix
#   echo "script crashed" | triage-issue.sh
#
# Arguments:
#   --symptom <text>   Symptom description (required unless stdin is piped)
#   --capture-log      Include execution-log tail (default: on)
#   --errors-only      Filter log to FAIL/ERROR results only
#   --suggest-fix      Run heuristic fix-suggestion engine
#   --log-tail <N>     Number of log entries to include (default: 20)
#
# Exit: 0 on success, 1 on usage error.
# Bash 3.2 compatible (CON-3). Read-only (CON-2).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

symptom=""
capture_log=1
errors_only=0
suggest_fix=0
log_tail=20

while [ $# -gt 0 ]; do
  case "$1" in
    --symptom)      symptom="$2"; shift 2 ;;
    --capture-log)  capture_log=1; shift ;;
    --errors-only)  errors_only=1; shift ;;
    --suggest-fix)  suggest_fix=1; shift ;;
    --log-tail)     log_tail="$2"; shift 2 ;;
    -h|--help)      sed -n '2,18p' "$0"; exit 0 ;;
    *)              echo "ERROR: unknown argument '$1'" >&2; exit 1 ;;
  esac
done

# FR-10: stdin detection
if [ -z "$symptom" ]; then
  if [ ! -t 0 ]; then
    symptom="$(cat)"
  else
    echo "Usage: triage-issue.sh --symptom <text>" >&2
    echo "       echo <text> | triage-issue.sh" >&2
    exit 1
  fi
fi

# Resolve orchestrator root
ORCH_ROOT="$(bash "$PROJECT_ROOT/scripts/state/resolve-root.sh" 2>/dev/null || echo ".orchestrator")"
case "$ORCH_ROOT" in
  /*) : ;;
  *)  ORCH_ROOT="$PROJECT_ROOT/$ORCH_ROOT" ;;
esac

# Version from CHANGELOG.md first ## [X.Y.Z] heading
version="unknown"
if [ -f "$PROJECT_ROOT/CHANGELOG.md" ]; then
  ver_line="$(grep -E '## \[[0-9]+\.' "$PROJECT_ROOT/CHANGELOG.md" | head -1)"
  [ -n "$ver_line" ] && version="$(echo "$ver_line" | sed -E 's/.*\[([0-9][0-9.]*[0-9]).*/\1/')"
fi

captured_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# Config hash (macOS md5 vs Linux md5sum)
config_hash="unavailable"
config_file="$ORCH_ROOT/config.yml"
if [ -f "$config_file" ]; then
  if command -v md5 >/dev/null 2>&1; then
    config_hash="$(md5 -q "$config_file")"
  elif command -v md5sum >/dev/null 2>&1; then
    config_hash="$(md5sum "$config_file" | cut -d' ' -f1)"
  fi
fi

# Active milestone
active_milestone="none"
find_active="$PROJECT_ROOT/scripts/state/find-active-milestone.sh"
if [ -f "$find_active" ]; then
  result="$(bash "$find_active" "$ORCH_ROOT" 2>/dev/null)" || true
  [ -n "$result" ] && [ "$result" != "NONE" ] && active_milestone="$result"
fi

# Lock state
lock_state="unlocked"
lock_file="$ORCH_ROOT/orchestrator.lock"
if [ -f "$lock_file" ]; then
  lock_pid="$(grep -o '"pid":[0-9]*' "$lock_file" 2>/dev/null | head -1 | sed 's/"pid"://')"
  if [ -n "$lock_pid" ]; then lock_state="locked (PID: $lock_pid)"; else lock_state="locked"; fi
fi

# FR-6: Execution log
log_section="No execution log found."
log_file="$ORCH_ROOT/execution-log.jsonl"
if [ "$capture_log" = "1" ] && [ -f "$log_file" ]; then
  if [ "$errors_only" = "1" ]; then
    log_section="$(grep -E '"result":"(FAIL|ERROR)"' "$log_file" | tail -n "$log_tail")"
  else
    log_section="$(tail -n "$log_tail" "$log_file")"
  fi
  [ -z "$log_section" ] && log_section="No matching log entries."
elif [ "$capture_log" != "1" ]; then
  log_section="Log capture disabled."
fi

# Relevant files: extract path tokens from symptom
relevant_files=""
path_tokens="$(echo "$symptom" | grep -oE '[A-Za-z0-9_./-]+\.(sh|md|yml|yaml|json|jsonl)' || true)"
if [ -n "$path_tokens" ]; then
  while IFS= read -r token; do
    if [ -f "$PROJECT_ROOT/$token" ]; then
      relevant_files="${relevant_files}- \`${token}\` (exists on disk)
"
    elif [ -f "$token" ]; then
      relevant_files="${relevant_files}- \`${token}\` (exists, absolute)
"
    else
      relevant_files="${relevant_files}- \`${token}\` (referenced but NOT found)
"
    fi
  done <<EOF
$path_tokens
EOF
fi

# Keyword grep across scripts/, commands/, templates/
keywords="$(echo "$symptom" | tr ' ,.;:!?' '\n' | grep -E '^[a-zA-Z_-]{4,}$' | head -5 || true)"
if [ -n "$keywords" ]; then
  while IFS= read -r kw; do
    matches="$(grep -rl "$kw" "$PROJECT_ROOT/scripts/" "$PROJECT_ROOT/commands/" "$PROJECT_ROOT/templates/" 2>/dev/null | head -10 || true)"
    [ -z "$matches" ] && continue
    while IFS= read -r match; do
      rel="$(echo "$match" | sed "s|^$PROJECT_ROOT/||")"
      case "$relevant_files" in *"$rel"*) continue ;; esac
      relevant_files="${relevant_files}- \`${rel}\` (keyword match: ${kw})
"
    done <<EOF2
$matches
EOF2
  done <<EOF3
$keywords
EOF3
fi
[ -z "$relevant_files" ] && relevant_files="No relevant files identified."

# Disk state snapshot
disk_state="- Orchestrator root: \`$ORCH_ROOT\`"
if [ -d "$ORCH_ROOT" ]; then
  dir_count="$(find "$ORCH_ROOT" -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
  file_count="$(find "$ORCH_ROOT" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
  disk_state="${disk_state}
- Top-level entries: ${dir_count} directories, ${file_count} files"
  [ -f "$lock_file" ] && disk_state="${disk_state}
- Lock file: present"
  if [ -f "$ORCH_ROOT/execution-log.jsonl" ]; then
    log_lines="$(wc -l < "$ORCH_ROOT/execution-log.jsonl" | tr -d ' ')"
    disk_state="${disk_state}
- Execution log: ${log_lines} entries"
  fi
  if [ -d "$ORCH_ROOT/milestones" ]; then
    ms_count="$(find "$ORCH_ROOT/milestones" -maxdepth 1 -type d -name 'M*' 2>/dev/null | wc -l | tr -d ' ')"
    disk_state="${disk_state}
- Milestones on disk: ${ms_count}"
  fi
else
  disk_state="${disk_state}
- WARNING: orchestrator root directory does not exist"
fi

# FR-7: Suggest-fix heuristic (section always present per FR-1)
fix_section=""
if [ "$suggest_fix" = "1" ]; then
  fix_found=0
  # Check referenced paths: missing files + broken symlinks
  if [ -n "$path_tokens" ]; then
    while IFS= read -r token; do
      target="$PROJECT_ROOT/$token"
      if [ -L "$target" ] && [ ! -e "$target" ]; then
        fix_section="${fix_section}- Broken symlink: \`${token}\` points to a non-existent target.
"
        fix_found=1
      elif [ ! -f "$target" ] && [ ! -f "$token" ]; then
        fix_section="${fix_section}- Missing file: \`${token}\` — referenced in symptom but not on disk.
"
        fix_found=1
      fi
    done <<EOF4
$path_tokens
EOF4
  fi
  # Known error patterns
  case "$symptom" in
    *"template not found"*|*"Template not found"*)
      fix_section="${fix_section}- Template resolution failure: verify the template exists under \`templates/\`.
"
      fix_found=1 ;;
    *"script not found"*|*"Script not found"*)
      fix_section="${fix_section}- Script resolution failure: verify the script exists under \`scripts/\` and is executable.
"
      fix_found=1 ;;
  esac
  [ "$fix_found" = "0" ] && fix_section="No simple fix identified — manual investigation required."
else
  fix_section="No simple fix identified — run with --suggest-fix for heuristic analysis."
fi

# Escape symptom for YAML frontmatter
escaped_symptom="$(echo "$symptom" | sed 's/"/\\"/g' | tr '\n' ' ' | sed 's/  */ /g; s/ *$//')"

# Emit report
cat <<REPORT
---
symptom: "${escaped_symptom}"
captured_at: "${captured_at}"
orchestrator_version: "${version}"
config_hash: "${config_hash}"
log_tail_count: ${log_tail}
---

## Symptom

${symptom}

## Environment

- Orchestrator version: ${version}
- Orchestrator root: ${ORCH_ROOT}
- Active milestone: ${active_milestone}
- Lock state: ${lock_state}
- Platform: $(uname -s)
- Shell: ${SHELL}

## Recent Execution Log

${log_section}

## Relevant Files

${relevant_files}

## Disk State

${disk_state}

## Suggested Fix

${fix_section}
REPORT
