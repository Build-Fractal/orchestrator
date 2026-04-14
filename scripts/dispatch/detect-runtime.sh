#!/usr/bin/env bash
# scripts/dispatch/detect-runtime.sh — Runtime auto-detection
#
# Pure read-only detector. Identifies which agent runtime (Claude Code,
# Codex CLI, Cursor, or unknown) is currently executing the orchestrator
# by probing environment variables and filesystem markers.
#
# Usage: detect-runtime.sh [--verbose] [--force <runtime>]
#   --verbose       — emit probed_env= and probed_path= diagnostic lines
#   --force <name>  — override detection; <name> in {claude-code,codex,cursor,unknown}
#
# Output (key=value lines on stdout):
#   runtime=<claude-code|codex|cursor|unknown>
#   confidence=<high|medium|low|forced>
#   (verbose) probed_env=<VAR>=<value-or-empty>
#   (verbose) probed_path=<PATH>=<exists|missing>
#   (forced) source=force-flag
#
# Confidence rules:
#   high   — env-var hit AND filesystem-marker hit
#   medium — env-var hit XOR filesystem-marker hit
#   low    — no signals for any runtime
#
# Precedence (first runtime with any hit wins): claude-code > codex > cursor.
#
# READ-ONLY: no file creation, no modification, no side effects.
# Bash 3.2 compatible: no associative arrays, no readarray, no |&.
# Always exits 0 except for malformed --force value (exits 2).

set -u

# --- Defaults / state ---

VERBOSE=0
FORCE=""
HOME="${HOME:-}"
PWD_DIR="${PWD:-$(pwd 2>/dev/null || echo '.')}"

# --- Parse arguments ---

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose)
      VERBOSE=1; shift ;;
    --force)
      FORCE="${2:-}"; shift 2 || { echo "error: --force requires an argument" >&2; exit 2; } ;;
    --force=*)
      FORCE="${1#--force=}"; shift ;;
    *)
      shift ;;
  esac
done

# --- Forced override ---

if [[ -n "$FORCE" ]]; then
  case "$FORCE" in
    claude-code|codex|cursor|unknown)
      echo "source=force-flag"
      echo "runtime=${FORCE}"
      echo "confidence=forced"
      exit 0
      ;;
    *)
      echo "error: --force value must be one of: claude-code, codex, cursor, unknown (got: ${FORCE})" >&2
      exit 2
      ;;
  esac
fi

# --- Signal tables (parallel indexed arrays, bash 3.2 safe per MEM001) ---

claude_envs=(CLAUDECODE CLAUDE_CODE_SSE_PORT CLAUDE_CODE_ENTRYPOINT)
claude_paths=("${PWD_DIR}/.claude" "${HOME}/.claude")

codex_envs=(CODEX_HOME CODEX_SANDBOX CODEX_CLI_VERSION)
codex_paths=("${PWD_DIR}/.codex" "${HOME}/.codex")

cursor_envs=(CURSOR_TRACE_ID CURSOR_SESSION_ID CURSOR_USER)
cursor_paths=("${PWD_DIR}/.cursor")

# --- Probe helpers ---

env_value() {
  # Portable indirect expansion for bash 3.2.
  eval "printf '%s' \"\${$1:-}\""
}

# Result state — populated by probe functions below (globals, bash 3.2 safe).
LAST_HITS=0

# probe_envs <env-var>...
# Emits verbose probe_env= lines to stdout if VERBOSE. Sets LAST_HITS.
probe_envs() {
  local hits=0
  local var val
  for var in "$@"; do
    val="$(env_value "$var")"
    if [[ $VERBOSE -eq 1 ]]; then
      echo "probed_env=${var}=${val}"
    fi
    if [[ -n "$val" ]]; then
      hits=$((hits + 1))
    fi
  done
  LAST_HITS=$hits
}

# probe_paths <path>...
# Emits verbose probed_path= lines to stdout if VERBOSE. Sets LAST_HITS.
probe_paths() {
  local hits=0
  local p status
  for p in "$@"; do
    if [[ -d "$p" ]]; then
      status="exists"
      hits=$((hits + 1))
    else
      status="missing"
    fi
    if [[ $VERBOSE -eq 1 ]]; then
      echo "probed_path=${p}=${status}"
    fi
  done
  LAST_HITS=$hits
}

# --- Probe all three runtimes (always probe so verbose output is complete) ---

probe_envs "${claude_envs[@]}";   claude_env_hits=$LAST_HITS
probe_paths "${claude_paths[@]}"; claude_path_hits=$LAST_HITS

probe_envs "${codex_envs[@]}";    codex_env_hits=$LAST_HITS
probe_paths "${codex_paths[@]}";  codex_path_hits=$LAST_HITS

probe_envs "${cursor_envs[@]}";   cursor_env_hits=$LAST_HITS
probe_paths "${cursor_paths[@]}"; cursor_path_hits=$LAST_HITS

# --- confidence_for <env-hits> <path-hits> ---

confidence_for() {
  local e="$1"; local p="$2"
  if [[ $e -gt 0 && $p -gt 0 ]]; then
    printf 'high'
  elif [[ $e -gt 0 || $p -gt 0 ]]; then
    printf 'medium'
  else
    printf 'none'
  fi
}

# --- Select runtime by precedence: first with any hit wins ---

selected_runtime="unknown"
selected_confidence="low"

claude_conf="$(confidence_for "$claude_env_hits" "$claude_path_hits")"
codex_conf="$(confidence_for "$codex_env_hits" "$codex_path_hits")"
cursor_conf="$(confidence_for "$cursor_env_hits" "$cursor_path_hits")"

if [[ "$claude_conf" != "none" ]]; then
  selected_runtime="claude-code"
  selected_confidence="$claude_conf"
elif [[ "$codex_conf" != "none" ]]; then
  selected_runtime="codex"
  selected_confidence="$codex_conf"
elif [[ "$cursor_conf" != "none" ]]; then
  selected_runtime="cursor"
  selected_confidence="$cursor_conf"
fi

echo "runtime=${selected_runtime}"
echo "confidence=${selected_confidence}"

exit 0
