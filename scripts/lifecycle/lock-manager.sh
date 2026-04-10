#!/usr/bin/env bash
# --- Portable sed -i helper (BSD/GNU compatible) ---
sed_i() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}
# scripts/lifecycle/lock-manager.sh — Lock file management for autonomous dispatch
# Creates, checks, and breaks lock files with PID validation to prevent
# concurrent orchestrator sessions and detect stale locks from crashed runs.
#
# Usage: lock-manager.sh <operation> <lock-file> [args...]
#   Operations:
#     create <lock-file> <unit-type> <unit-id>  — create a new lock file
#     status <lock-file>                        — check lock file state (ACTIVE/STALE/NONE)
#     break  <lock-file>                        — remove the lock file
#     update <lock-file> <completed-unit-id>    — append completed unit, update timestamps
#
# Structured output (stdout):
#   LOCK:CREATED <lock-file>
#   LOCK:ACTIVE pid=<pid> unit=<unit-id> started=<timestamp>
#   LOCK:STALE pid=<pid> unit=<unit-id> started=<timestamp>
#   LOCK:NONE
#   LOCK:BROKEN <lock-file>
#   LOCK:UPDATED <lock-file>
#
# Exit 0 on success. Exit 1 on error (usage/conflict to stderr).

set -euo pipefail

# --- Argument validation ---
if [[ $# -lt 1 ]]; then
  echo "lock-manager.sh: missing operation argument" >&2
  echo "Usage: lock-manager.sh <operation> <lock-file> [args...]" >&2
  echo "Operations: create, status, break, update" >&2
  exit 1
fi

OPERATION="$1"
shift

# --- Helper: ISO 8601 timestamp ---
iso_timestamp() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

# --- Helper: Read a JSON field value (shared utility, no jq required) ---
SCRIPT_DIR_LM="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_LM/../util/json-field.sh"

# --- Helper: Check if a PID is running ---
# kill -0 returns 0 if we can signal, or non-zero if:
#   - process doesn't exist (ESRCH) → dead
#   - permission denied (EPERM) → alive but not ours
# We check stderr to distinguish these cases.
pid_alive() {
  local pid="$1"
  if kill -0 "$pid" 2>/dev/null; then
    return 0
  fi
  # Check if the error is EPERM (process exists but we can't signal it)
  local err
  err=$(kill -0 "$pid" 2>&1) || true
  if echo "$err" | grep -qi "perm"; then
    return 0
  fi
  return 1
}

# --- Operation: create ---
op_create() {
  if [[ $# -lt 3 ]]; then
    echo "lock-manager.sh create: requires <lock-file> <unit-type> <unit-id>" >&2
    exit 1
  fi

  local lock_file="$1"
  local unit_type="$2"
  local unit_id="$3"
  local now
  now="$(iso_timestamp)"

  # Check for existing lock with living holder
  if [[ -f "$lock_file" ]]; then
    local existing_pid
    existing_pid="$(json_field "$lock_file" "pid")"
    if [[ -n "$existing_pid" ]] && pid_alive "$existing_pid"; then
      echo "lock-manager.sh create: lock file exists and holder PID $existing_pid is still running" >&2
      exit 1
    fi
    # Stale lock — remove it before creating new one
    rm -f "$lock_file"
  fi

  # Get feature branch if in a git repo
  local feature_branch=""
  feature_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"

  # Capture git tree hash for external modification detection (FR-064)
  local phase_start_tree=""
  phase_start_tree="$(git rev-parse HEAD 2>/dev/null || echo "")"

  # Create lock directory if needed
  mkdir -p "$(dirname "$lock_file")"

  # Write JSON lock file
  cat > "$lock_file" <<EOF
{
  "pid": $$,
  "startedAt": "$now",
  "unitType": "$unit_type",
  "unitId": "$unit_id",
  "unitStartedAt": "$now",
  "completedUnits": [],
  "featureBranch": "$feature_branch",
  "phase_start_tree": "$phase_start_tree"
}
EOF

  echo "LOCK:CREATED $lock_file"
}

# --- Operation: status ---
op_status() {
  if [[ $# -lt 1 ]]; then
    echo "lock-manager.sh status: requires <lock-file>" >&2
    exit 1
  fi

  local lock_file="$1"

  if [[ ! -f "$lock_file" ]]; then
    echo "LOCK:NONE"
    return 0
  fi

  local pid unit_id started
  pid="$(json_field "$lock_file" "pid")"
  unit_id="$(json_field "$lock_file" "unitId")"
  started="$(json_field "$lock_file" "startedAt")"

  if [[ -n "$pid" ]] && pid_alive "$pid"; then
    echo "LOCK:ACTIVE pid=$pid unit=$unit_id started=$started"
  else
    echo "LOCK:STALE pid=$pid unit=$unit_id started=$started"
  fi
}

# --- Operation: break ---
op_break() {
  if [[ $# -lt 1 ]]; then
    echo "lock-manager.sh break: requires <lock-file>" >&2
    exit 1
  fi

  local lock_file="$1"

  if [[ ! -f "$lock_file" ]]; then
    echo "LOCK:NONE"
    return 0
  fi

  rm -f "$lock_file"
  echo "LOCK:BROKEN $lock_file"
}

# --- Operation: update ---
op_update() {
  if [[ $# -lt 2 ]]; then
    echo "lock-manager.sh update: requires <lock-file> <completed-unit-id>" >&2
    exit 1
  fi

  local lock_file="$1"
  local completed_unit_id="$2"

  if [[ ! -f "$lock_file" ]]; then
    echo "lock-manager.sh update: lock file not found: $lock_file" >&2
    exit 1
  fi

  local now
  now="$(iso_timestamp)"

  # Try jq first, fall back to sed
  if command -v jq >/dev/null 2>&1; then
    local tmp_file="${lock_file}.tmp"
    jq --arg uid "$completed_unit_id" --arg ts "$now" \
      '.completedUnits += [$uid] | .unitStartedAt = $ts' \
      "$lock_file" > "$tmp_file"
    mv "$tmp_file" "$lock_file"
  else
    # Fallback: sed-based JSON manipulation
    # 1. Update unitStartedAt
    sed_i "s/\"unitStartedAt\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"unitStartedAt\": \"$now\"/" "$lock_file"
    # 2. Append to completedUnits array
    # Handle empty array: [] → ["unit-id"]
    if grep -q '"completedUnits"[[:space:]]*:[[:space:]]*\[\]' "$lock_file"; then
      sed_i "s/\"completedUnits\"[[:space:]]*:[[:space:]]*\[\]/\"completedUnits\": [\"$completed_unit_id\"]/" "$lock_file"
    else
      # Non-empty array: [...] → [..., "unit-id"]
      sed_i "s/\"completedUnits\"[[:space:]]*:[[:space:]]*\[/\"completedUnits\": [/;s/\]/,\"$completed_unit_id\"]/" "$lock_file"
    fi
  fi

  echo "LOCK:UPDATED $lock_file"
}

# --- Dispatch operation ---
case "$OPERATION" in
  create) op_create "$@" ;;
  status) op_status "$@" ;;
  break)  op_break "$@" ;;
  update) op_update "$@" ;;
  *)
    echo "lock-manager.sh: unknown operation '$OPERATION'" >&2
    echo "Usage: lock-manager.sh <operation> <lock-file> [args...]" >&2
    echo "Operations: create, status, break, update" >&2
    exit 1
    ;;
esac
