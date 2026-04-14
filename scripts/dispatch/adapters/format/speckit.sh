#!/usr/bin/env bash
# scripts/dispatch/adapters/format/speckit.sh -- spec-kit format adapter (read-only)
#
# Maps spec-kit's tasks.md/plan.md representation into the orchestrator's
# native task-plan shape (see templates/task-plan.md). This adapter is
# ONE-DIRECTIONAL READ — it never writes back to spec-kit format. M008
# treats spec-kit projects as upstream sources of truth; the orchestrator
# reads their tasks, produces native task-plans internally, and leaves
# spec-kit artifacts untouched.
#
# Usage:
#   speckit.sh --probe
#     Detects presence of a spec-kit `specs/` directory under PROJECT_ROOT
#     (defaults to cwd). Emits available=true|false, format=speckit,
#     reason=<signal>. Exit 0 always.
#
#   speckit.sh --read <path-to-tasks.md>
#     Parses the first T## task entry from tasks.md, reads the companion
#     plan.md (if present) for phase/milestone inference, and emits a
#     native-shape task-plan.md on stdout. Exit 0 on success, 2 on
#     file-not-found.
#
#   speckit.sh --write <anything>
#     REJECTED. Emits FAIL on stderr, exit 4. Preserves spec-kit artifact
#     integrity — writing native task-plans back as spec-kit tasks.md is
#     out of scope for M008.
#
# Bash 3.2 compatible. No jq/python3 dependencies.

set -u

MODE=""
PATH_ARG=""

# Parse arguments -- explicit --write rejection happens inline so it
# short-circuits regardless of where --write appears in the arg list.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --probe)
      MODE="probe"; shift ;;
    --read)
      MODE="read"; PATH_ARG="${2:-}"; shift 2 ;;
    --write)
      echo "FAIL: speckit adapter is one-directional read only" >&2
      exit 4 ;;
    *)
      shift ;;
  esac
done

# --- Probe mode ---

if [[ "$MODE" = "probe" ]]; then
  root="${PROJECT_ROOT:-.}"
  if [[ -d "$root/specs" ]]; then
    echo "available=true"
    echo "format=speckit"
    echo "reason=specs-directory-present"
    exit 0
  fi
  echo "available=false"
  echo "format=speckit"
  echo "reason=no-speckit-specs-directory"
  exit 0
fi

# --- Read mode ---

if [[ "$MODE" = "read" ]]; then
  if [[ -z "$PATH_ARG" ]]; then
    echo "FAIL: --read requires a path argument" >&2
    exit 2
  fi
  if [[ ! -f "$PATH_ARG" ]]; then
    echo "FAIL: file not found: $PATH_ARG" >&2
    exit 2
  fi

  # Resolve absolute path for source_path frontmatter field. Bash 3.2 has
  # no `realpath` builtin; derive via cd/pwd in a subshell.
  abs_path="$(cd "$(dirname "$PATH_ARG")" 2>/dev/null && pwd)/$(basename "$PATH_ARG")"
  : "${abs_path:=$PATH_ARG}"

  # Extract the first T## task line. Spec-kit conventions we tolerate:
  #   ## T01: Name
  #   ## T01 Name
  #   - [ ] T01 Name
  #   - T01: Name
  # We match the first line containing T followed by 1+ digits and grab
  # task_id + trailing label text.
  first_line="$(grep -nE 'T[0-9]+' "$PATH_ARG" | head -n 1 | sed -E 's/^[0-9]+://')"
  if [[ -z "$first_line" ]]; then
    echo "FAIL: no T## task entries found in $PATH_ARG" >&2
    exit 3
  fi

  task_id="$(echo "$first_line" | grep -oE 'T[0-9]+' | head -n 1)"
  # Strip heading/list markers, the task id, and any ':' separator to
  # recover the human-readable name.
  task_name="$(echo "$first_line" \
    | sed -E 's/^[[:space:]]*#+[[:space:]]*//' \
    | sed -E 's/^[[:space:]]*-[[:space:]]*\[[ xX]\][[:space:]]*//' \
    | sed -E 's/^[[:space:]]*-[[:space:]]*//' \
    | sed -E "s/^${task_id}[[:space:]]*:?[[:space:]]*//" \
    | sed -E 's/[[:space:]]+$//')"
  : "${task_name:=$task_id}"

  # Derive phase/milestone from sibling plan.md if present. Fallbacks keep
  # the adapter useful on minimal spec-kit layouts.
  dir="$(dirname "$PATH_ARG")"
  plan_file="$dir/plan.md"
  phase_id="P01"
  milestone_id="M000"
  if [[ -f "$plan_file" ]]; then
    p="$(grep -E '^[[:space:]]*phase:' "$plan_file" | head -n 1 \
      | sed -E 's/^[[:space:]]*phase:[[:space:]]*"?([^"[:space:]]+)"?.*$/\1/')"
    m="$(grep -E '^[[:space:]]*milestone:' "$plan_file" | head -n 1 \
      | sed -E 's/^[[:space:]]*milestone:[[:space:]]*"?([^"[:space:]]+)"?.*$/\1/')"
    if [[ -n "${p:-}" ]]; then phase_id="$p"; fi
    if [[ -n "${m:-}" ]]; then milestone_id="$m"; fi
  fi

  # Extract the first task's body — lines between its heading and the
  # next '## ' heading (or EOF). Fall back to the name if no body found.
  body="$(awk -v tid="$task_id" '
    BEGIN { in_task = 0 }
    /^##[[:space:]]/ {
      if (in_task) { exit }
      if ($0 ~ tid) { in_task = 1; next }
    }
    { if (in_task) print }
  ' "$PATH_ARG" | sed -E 's/^[[:space:]]+$//' )"

  # Trim leading/trailing blank lines from body.
  body="$(echo "$body" | awk 'NF{found=1} found{print}' | awk '{lines[NR]=$0} END{
    end=NR; while (end>0 && lines[end]=="") end--;
    for (i=1; i<=end; i++) print lines[i]
  }')"

  if [[ -z "$body" ]]; then
    body="$task_name"
  fi

  # Emit native-shape task-plan.
  cat <<EOF
---
schema_version: "1.0"
type: "task-plan"
task: "$task_id"
phase: "$phase_id"
milestone: "$milestone_id"
name: "$task_name"
depends_on: []
source_format: "speckit"
source_path: "$abs_path"
---

## Description

$body
EOF
  exit 0
fi

echo "FAIL: no mode specified (expected --probe | --read <path>)" >&2
exit 2
