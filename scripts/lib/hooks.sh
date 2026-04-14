#!/usr/bin/env bash
# scripts/lib/hooks.sh — Hook lifecycle dispatcher with sandbox enforcement.
[ -n "${_HOOKS_SOURCED:-}" ] && return 0
_HOOKS_SOURCED=1

# Source this file to get:
#   - run_hooks <lifecycle_point> <state_source> [hooks_yaml_path]
#
# Lifecycle points (US5 AS2):
#   PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE
#
# Principle XII (Hook Isolation): hooks receive a chmod 444 frozen state
# snapshot via $ORCH_HOOK_SNAPSHOT, are killed at timeout (default 30s), and
# cannot modify engine state. Snapshot modification triggers HOOK_VIOLATION
# unconditionally (never downgraded under ORCH_FORCE).
#
# Graceful degradation: if scripts/lib/recipe-parser.sh is unavailable or
# parse_recipe_hooks is not defined, run_hooks emits
# SAFETY_WARNING reason=recipe_parser_unavailable and returns 0. If the
# hooks.yaml file is missing, emits SAFETY_WARNING reason=hooks_yaml_missing
# and returns 0.
#
# Bash 3.2 compatible (NFR-200). Double-sourcing guard per NFR-203 / AP-003.

_hooks_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
. "${_hooks_dir}/errors.sh"
# shellcheck disable=SC1090
. "${_hooks_dir}/events.sh"
# shellcheck disable=SC1090
. "${_hooks_dir}/run-context.sh"
# shellcheck disable=SC1090
. "${_hooks_dir}/verdicts.sh"

# --- Configuration ---
ORCH_HOOK_TIMEOUT_SEC="${ORCH_HOOK_TIMEOUT_SEC:-30}"
ORCH_HOOKS_YAML_DEFAULT="${ORCH_HOOKS_YAML_DEFAULT:-templates/hooks.yaml}"

_hooks_parser_available() {
  local p="${_hooks_dir}/recipe-parser.sh"
  [ -f "$p" ] || return 1
  (
    # shellcheck disable=SC1090
    . "$p" 2>/dev/null || exit 1
    type parse_recipe_hooks >/dev/null 2>&1
  )
}

_hooks_snapshot_create() {
  local src="$1"
  local dest="$2"
  if [ -f "$src" ]; then
    cp "$src" "$dest" || return 1
  elif [ -d "$src" ]; then
    (cd "$src" && tar -cf - .) > "$dest" 2>/dev/null || return 1
  else
    printf 'no-state\n' > "$dest" || return 1
  fi
  chmod 444 "$dest" || return 1
  return 0
}

_hooks_snapshot_unchanged() {
  local p="$1"
  local orig="$2"
  local cur
  cur="$(stat -c '%Y' "$p" 2>/dev/null || stat -f '%m' "$p" 2>/dev/null || echo 0)"
  [ "$cur" = "$orig" ] || return 1
  [ -w "$p" ] && return 1
  return 0
}

_hooks_verdict_severity() {
  case "$1" in
    PASS)         printf '0' ;;
    WARN)         printf '1' ;;
    NEEDS_REVIEW) printf '2' ;;
    BLOCK)        printf '3' ;;
    *)            printf '-1' ;;
  esac
}

# _hooks_extract_verdict <stdout_file>
# Scans a file for VERDICT: lines, returns the most severe verdict.
# Outputs: verdict<TAB>reason (from parse_verdict format)
# Returns 0 if at least one VERDICT line found, 1 otherwise.
_hooks_extract_verdict() {
  local stdout_file="$1"
  local max_severity=-1
  local max_verdict=""
  local max_reason=""
  local found=0

  while IFS= read -r line; do
    case "$line" in
      VERDICT:*)
        local parsed
        parsed="$(parse_verdict "$line")" || continue
        local v r sev
        v="$(printf '%s' "$parsed" | cut -f1)"
        r="$(printf '%s' "$parsed" | cut -f2-)"
        sev="$(_hooks_verdict_severity "$v")"
        if [ "$sev" -gt "$max_severity" ]; then
          max_severity="$sev"
          max_verdict="$v"
          max_reason="$r"
        fi
        found=1
        ;;
    esac
  done < "$stdout_file"

  if [ "$found" -eq 1 ]; then
    printf '%s\t%s\n' "$max_verdict" "$max_reason"
    return 0
  fi
  return 1
}

_hooks_exec_with_timeout() {
  local to="$1"
  shift
  "$@" &
  local cmd_pid=$!
  (
    sleep "$to"
    kill -TERM "$cmd_pid" 2>/dev/null
    sleep 1
    kill -KILL "$cmd_pid" 2>/dev/null
  ) &
  local watchdog_pid=$!
  local rc=0
  if wait "$cmd_pid" 2>/dev/null; then
    rc=0
  else
    rc=$?
  fi
  kill "$watchdog_pid" 2>/dev/null
  wait "$watchdog_pid" 2>/dev/null
  return "$rc"
}

run_hooks() {
  local lifecycle="$1"
  local state_src="$2"
  local yaml="${3:-$ORCH_HOOKS_YAML_DEFAULT}"

  case "$lifecycle" in
    PRE_DISPATCH|POST_DISPATCH|POST_VERIFY|PRE_ADVANCE) ;;
    *)
      emit_event SAFETY_WARNING reason="unknown_lifecycle_point" lifecycle="$lifecycle"
      return 0
      ;;
  esac

  if ! _hooks_parser_available; then
    emit_event SAFETY_WARNING reason=recipe_parser_unavailable lifecycle="$lifecycle"
    return 0
  fi

  if [ ! -f "$yaml" ]; then
    emit_event SAFETY_WARNING reason=hooks_yaml_missing path="$yaml"
    return 0
  fi

  # shellcheck disable=SC1090
  . "${_hooks_dir}/recipe-parser.sh"

  local hook_lines
  hook_lines="$(parse_recipe_hooks "$yaml" "$lifecycle" 2>/dev/null)"
  if [ -z "$hook_lines" ]; then
    return 0
  fi

  local overall_rc=0
  local line key name script enabled block desc
  local snap tmp_mtime rc

  local _tmp
  _tmp="$(mktemp)"
  printf '%s\n' "$hook_lines" > "$_tmp"

  while IFS='|' read -r key name script enabled block desc; do
    [ -z "$key" ] && continue
    case "${enabled:-true}" in
      false|FALSE|0|no|NO) continue ;;
    esac

    if [ ! -x "$script" ] && [ ! -f "$script" ]; then
      emit_event SAFETY_WARNING reason=hook_script_missing hook="$key" script="$script"
      continue
    fi

    snap="$(mktemp)"
    if ! _hooks_snapshot_create "$state_src" "$snap"; then
      emit_event HOOK_BLOCKED hook="$key" reason="snapshot_create_failed"
      rm -f "$snap"
      overall_rc=1
      continue
    fi
    tmp_mtime="$(stat -c '%Y' "$snap" 2>/dev/null || stat -f '%m' "$snap" 2>/dev/null || echo 0)"

    emit_event HOOK_START hook="$key" lifecycle="$lifecycle" script="$script"

    local hook_stdout
    hook_stdout="$(mktemp)"
    ORCH_HOOK_SNAPSHOT="$snap" _hooks_exec_with_timeout "$ORCH_HOOK_TIMEOUT_SEC" \
      bash "$script" >"$hook_stdout" 2>&1
    rc=$?

    if ! _hooks_snapshot_unchanged "$snap" "$tmp_mtime"; then
      emit_event HOOK_VIOLATION hook="$key" reason="snapshot_modified" script="$script"
      rm -f "$snap" "$hook_stdout"
      overall_rc=1
      continue
    fi

    rm -f "$snap"

    # --- Verdict protocol: check for VERDICT lines in hook stdout ---
    local verdict_line verdict_val verdict_reason
    if _hooks_extract_verdict "$hook_stdout"; then
      verdict_line="$(_hooks_extract_verdict "$hook_stdout")"
      verdict_val="$(printf '%s' "$verdict_line" | cut -f1)"
      verdict_reason="$(printf '%s' "$verdict_line" | cut -f2-)"
      rm -f "$hook_stdout"

      case "$verdict_val" in
        BLOCK)
          if orch_is_forced; then
            emit_event HOOK_WARNING hook="$key" lifecycle="$lifecycle" verdict="$verdict_val" reason="$verdict_reason" forced=1
          else
            emit_event HOOK_BLOCKED hook="$key" lifecycle="$lifecycle" verdict="$verdict_val" reason="$verdict_reason"
            overall_rc=1
          fi
          continue
          ;;
        WARN)
          emit_event HOOK_WARNING hook="$key" lifecycle="$lifecycle" verdict="$verdict_val" reason="$verdict_reason"
          continue
          ;;
        PASS|NEEDS_REVIEW)
          emit_event HOOK_COMPLETE hook="$key" lifecycle="$lifecycle" exit_code="$rc" verdict="$verdict_val" reason="$verdict_reason"
          continue
          ;;
      esac
    fi
    rm -f "$hook_stdout"

    if [ "$rc" -eq 0 ]; then
      emit_event HOOK_COMPLETE hook="$key" lifecycle="$lifecycle" exit_code=0
      continue
    fi

    case "${block:-true}" in
      false|FALSE|0|no|NO)
        emit_event HOOK_WARNING hook="$key" lifecycle="$lifecycle" exit_code="$rc"
        ;;
      *)
        if orch_is_forced; then
          emit_event HOOK_WARNING hook="$key" lifecycle="$lifecycle" exit_code="$rc" forced=1
        else
          emit_event HOOK_BLOCKED hook="$key" lifecycle="$lifecycle" exit_code="$rc"
          overall_rc=1
        fi
        ;;
    esac
  done < "$_tmp"

  rm -f "$_tmp"
  return "$overall_rc"
}
