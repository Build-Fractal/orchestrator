#!/usr/bin/env bash
# scripts/dispatch/detect-capabilities.sh — Detect runtime capabilities
# Reports available capabilities for graceful degradation across agent runtimes (R008).
#
# Usage: detect-capabilities.sh [--format json|text]
#   --format: output format (default: text — key=value lines)
#
# Always exits 0 (capability detection never fails — unknown capabilities default to false).

set -euo pipefail

FORMAT="text"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      FORMAT="$2"; shift 2 ;;
    *)
      shift ;;
  esac
done

# --- Detect capabilities ---

# subagent_dispatch: check for SPECKIT_SUBAGENT env var or agent commands
subagent_dispatch=false
if [[ -n "${SPECKIT_SUBAGENT:-}" ]]; then
  subagent_dispatch=true
elif command -v claude >/dev/null 2>&1; then
  subagent_dispatch=true
elif command -v cursor >/dev/null 2>&1; then
  subagent_dispatch=true
elif command -v copilot >/dev/null 2>&1; then
  subagent_dispatch=true
fi

# agent_tool_available: detect in-process agent tool via environment
agent_tool_available=false
if [[ -n "${CLAUDE_CODE:-}" ]]; then
  agent_tool_available=true
  subagent_dispatch=true
elif [[ -n "${CURSOR_AGENT:-}" ]]; then
  agent_tool_available=true
  subagent_dispatch=true
fi

# shell_execution: always true (we're running in bash)
shell_execution=true

# git_available: check for git command
git_available=false
if command -v git >/dev/null 2>&1; then
  git_available=true
fi

# git_worktree: check if git worktree list works
git_worktree=false
if [[ "$git_available" = true ]] && git worktree list >/dev/null 2>&1; then
  git_worktree=true
fi

# github_actions: check for GITHUB_ACTIONS env var
github_actions=false
if [[ "${GITHUB_ACTIONS:-}" = "true" ]]; then
  github_actions=true
fi

# runtime: derived from environment
runtime="local"
if [[ "$github_actions" = true ]]; then
  runtime="ci-github"
fi

# --- Output ---

if [[ "$FORMAT" = "json" ]]; then
  cat <<EOF
{
  "subagent_dispatch": $subagent_dispatch,
  "agent_tool_available": $agent_tool_available,
  "shell_execution": $shell_execution,
  "git_available": $git_available,
  "git_worktree": $git_worktree,
  "github_actions": $github_actions,
  "runtime": "$runtime"
}
EOF
else
  echo "subagent_dispatch=$subagent_dispatch"
  echo "agent_tool_available=$agent_tool_available"
  echo "shell_execution=$shell_execution"
  echo "git_available=$git_available"
  echo "git_worktree=$git_worktree"
  echo "github_actions=$github_actions"
  echo "runtime=$runtime"
fi
