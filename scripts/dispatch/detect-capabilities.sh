#!/usr/bin/env bash
# scripts/dispatch/detect-capabilities.sh — Detect runtime and environment capabilities
# Reports available capabilities for graceful degradation across agent runtimes (R008)
# and environment-aware intensity recommendation (FR-024, FR-025, FR-026).
#
# Usage: detect-capabilities.sh [--format json|text] [--profile]
#   --format:  output format (default: text — key=value lines)
#   --profile: output high-level capability summary for intensity recommendation
#
# Capabilities detected:
#   subagent_dispatch   — can dispatch to sub-agents
#   agent_tool_available — in-process agent tools (override via SPECKIT_AGENT_TOOL=1)
#   shell_execution     — always true (running in bash)
#   git_available       — git CLI present
#   git_worktree        — git worktree support
#   github_actions      — running in GitHub Actions
#   runtime             — local or ci-github
#   host_claude_code    — .claude directory present
#   host_cursor         — .cursor directory present
#   host_copilot        — .github/copilot directory present
#   graph_db            — sqlite3 + knowledge graph database present
#   mcp_servers         — MCP server configuration present
#   ci_pipeline         — CI/CD configuration files present
#
# Always exits 0 (capability detection never fails — unknown capabilities default to false).

set -euo pipefail

FORMAT="text"
PROFILE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      FORMAT="$2"; shift 2 ;;
    --profile)
      PROFILE=true; shift ;;
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

# headless_reentry: can we spawn a fresh `claude -p` process for a process-fresh
# self-continue re-entry (M045 / D015)? Requires the claude CLI on PATH.
headless_reentry=false
if command -v claude >/dev/null 2>&1; then
  headless_reentry=true
fi

# agent_tool_available: in-process agent tools (e.g. Claude Code's Agent tool)
# cannot be reliably detected from a shell script because they exist in the
# agent's tool namespace, not as env vars or CLI commands. This field defaults
# to false. The orchestrating agent should self-check its own toolkit instead.
# Set SPECKIT_AGENT_TOOL=1 in the environment to override if needed.
agent_tool_available=false
if [[ -n "${SPECKIT_AGENT_TOOL:-}" ]]; then
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

# Agent host marker directories — which host format the writer should emit.
# Per AD-10, .gsd/ is intentionally NOT detected.
host_claude_code=false
host_cursor=false
host_copilot=false
if [[ -d .claude ]]; then
  host_claude_code=true
fi
if [[ -d .cursor ]]; then
  host_cursor=true
fi
if [[ -d .github/copilot ]]; then
  host_copilot=true
fi

# graph_db: check for sqlite3 AND a knowledge graph database file
graph_db=false
if command -v sqlite3 >/dev/null 2>&1; then
  if [[ -f .orchestrator/knowledge.db ]]; then
    graph_db=true
  fi
fi

# mcp_servers: check for MCP configuration files
mcp_servers=false
if [[ -f .claude/mcp_servers.json ]] || [[ -f .cursor/mcp.json ]] || [[ -f mcp.json ]]; then
  mcp_servers=true
elif [[ -n "${MCP_CONFIG:-}" ]] && [[ -f "${MCP_CONFIG}" ]]; then
  mcp_servers=true
fi

# ci_pipeline: check for CI configuration files
ci_pipeline=false
if [[ -d .github/workflows ]] || [[ -f .gitlab-ci.yml ]] || [[ -f .circleci/config.yml ]] || [[ -f Jenkinsfile ]] || [[ -f .buildkite/pipeline.yml ]]; then
  ci_pipeline=true
fi

# --- Output ---

if [[ "$PROFILE" = true ]]; then
  # Profile mode: high-level summary for intensity recommendation engine
  cap_execution="local"
  if [[ "$runtime" != "local" ]]; then
    cap_execution="ci"
  fi
  cap_graph="$graph_db"
  cap_mcp="$mcp_servers"
  cap_ci="$ci_pipeline"
  cap_subagent="$subagent_dispatch"

  # Count true capabilities for an aggregate score (0..5)
  cap_score=0
  [[ "$cap_graph" = true ]] && cap_score=$((cap_score + 1))
  [[ "$cap_mcp" = true ]] && cap_score=$((cap_score + 1))
  [[ "$cap_ci" = true ]] && cap_score=$((cap_score + 1))
  [[ "$cap_subagent" = true ]] && cap_score=$((cap_score + 1))
  [[ "$cap_execution" = "ci" ]] && cap_score=$((cap_score + 1))

  echo "cap_execution=$cap_execution"
  echo "cap_graph=$cap_graph"
  echo "cap_mcp=$cap_mcp"
  echo "cap_ci=$cap_ci"
  echo "cap_subagent=$cap_subagent"
  echo "cap_score=$cap_score"
elif [[ "$FORMAT" = "json" ]]; then
  cat <<EOF
{
  "subagent_dispatch": $subagent_dispatch,
  "agent_tool_available": $agent_tool_available,
  "shell_execution": $shell_execution,
  "git_available": $git_available,
  "git_worktree": $git_worktree,
  "github_actions": $github_actions,
  "runtime": "$runtime",
  "host_claude_code": $host_claude_code,
  "host_cursor": $host_cursor,
  "host_copilot": $host_copilot,
  "graph_db": $graph_db,
  "mcp_servers": $mcp_servers,
  "ci_pipeline": $ci_pipeline,
  "headless_reentry": $headless_reentry
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
  echo "host_claude_code=$host_claude_code"
  echo "host_cursor=$host_cursor"
  echo "host_copilot=$host_copilot"
  echo "graph_db=$graph_db"
  echo "mcp_servers=$mcp_servers"
  echo "ci_pipeline=$ci_pipeline"
  echo "headless_reentry=$headless_reentry"
fi
