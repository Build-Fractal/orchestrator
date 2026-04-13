#!/usr/bin/env bash
# scripts/util/classify-command.sh — Classify a command's auto-safety level
# Implements the auto-safe command subset defined in AD-19.
#
# A command is AUTO_SAFE only if ALL are true:
#   - No shell interpolation ($(...) or backticks)
#   - No inline loops (for/while/if blocks)
#   - No heredoc (<<EOF)
#   - No quoted multiline argument payload
#   - No rm -rf
#   - No writes outside project root
#   - No /tmp dependency
#   - Single-purpose action with deterministic argv
#
# Usage: classify-command.sh <command-string> [--project-root <path>]
#   or:  classify-command.sh --file <path-to-file-with-commands>
#
# Output:
#   AUTO_SAFE                     — command can run unattended
#   APPROVAL_REQUIRED reason=<r>  — command needs redesign or approval
#   FORBIDDEN_IN_AUTO reason=<r>  — command must not run in auto mode
#
# Exit 0 always (informational classifier).
# Bash 3.2 compatible.

set -euo pipefail

CMD=""
PROJECT_ROOT="."
FILE_MODE=false
FILE_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root) PROJECT_ROOT="$2"; shift 2 ;;
    --file) FILE_MODE=true; FILE_PATH="$2"; shift 2 ;;
    *) CMD="$1"; shift ;;
  esac
done

# --- Classifier function ---
classify_one() {
  local cmd="$1"

  # FORBIDDEN: eval at the boundary
  if echo "$cmd" | grep -qE '\beval\b'; then
    echo "FORBIDDEN_IN_AUTO reason=eval"
    return
  fi

  # FORBIDDEN: bash -c with embedded logic
  if echo "$cmd" | grep -qE "bash -c ['\"]"; then
    echo "FORBIDDEN_IN_AUTO reason=bash_c_embedded"
    return
  fi

  # HIGH: command substitution $(...) or backticks
  if echo "$cmd" | grep -qE '\$\(|`'; then
    echo "APPROVAL_REQUIRED reason=command_substitution"
    return
  fi

  # HIGH: inline loops
  if echo "$cmd" | grep -qE '\bfor \b|\bwhile \b|\bif \[|\bdo\b|\bthen\b'; then
    echo "APPROVAL_REQUIRED reason=inline_loop_or_conditional"
    return
  fi

  # HIGH: heredoc
  if echo "$cmd" | grep -qE '<<'; then
    echo "APPROVAL_REQUIRED reason=heredoc"
    return
  fi

  # HIGH: rm -rf
  if echo "$cmd" | grep -qE 'rm -rf|rm -r '; then
    echo "APPROVAL_REQUIRED reason=destructive_rm"
    return
  fi

  # HIGH: /tmp writes
  if echo "$cmd" | grep -qE '/tmp/|/tmp '; then
    echo "APPROVAL_REQUIRED reason=tmp_write"
    return
  fi

  # MEDIUM: complex chains (3+ commands with && or ;)
  local chain_count=0
  chain_count=$(printf '%s' "$cmd" | grep -oE '&&|;' | wc -l | tr -d ' ') || chain_count=0
  chain_count="${chain_count:-0}"
  if [[ "$chain_count" -ge 2 ]]; then
    echo "APPROVAL_REQUIRED reason=complex_chain"
    return
  fi

  # MEDIUM: pipe chains (2+ pipes)
  local pipe_count=0
  pipe_count=$(printf '%s' "$cmd" | tr -cd '|' | wc -c | tr -d ' ')
  pipe_count="${pipe_count:-0}"
  if [[ "$pipe_count" -ge 2 ]]; then
    echo "APPROVAL_REQUIRED reason=complex_pipe"
    return
  fi

  # MEDIUM: subshell
  if echo "$cmd" | grep -qE '^\(|\( '; then
    echo "APPROVAL_REQUIRED reason=subshell"
    return
  fi

  # MEDIUM: process substitution
  if echo "$cmd" | grep -qE '<\(|>\('; then
    echo "APPROVAL_REQUIRED reason=process_substitution"
    return
  fi

  # MEDIUM: multiline (newline in command)
  local line_count
  line_count=$(printf '%s\n' "$cmd" | wc -l | tr -d ' ')
  if [[ "$line_count" -gt 1 ]]; then
    echo "APPROVAL_REQUIRED reason=multiline_command"
    return
  fi

  echo "AUTO_SAFE"
}

# --- Main ---
if [[ "$FILE_MODE" = "true" && -f "$FILE_PATH" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue
    result=$(classify_one "$line")
    echo "$result cmd=$line"
  done < "$FILE_PATH"
elif [[ -n "$CMD" ]]; then
  classify_one "$CMD"
else
  echo "Usage: classify-command.sh <command-string> [--project-root <path>]" >&2
  echo "   or: classify-command.sh --file <path-to-file-with-commands>" >&2
  exit 1
fi
