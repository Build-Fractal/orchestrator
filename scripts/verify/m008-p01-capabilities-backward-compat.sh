#!/usr/bin/env bash
# Verifies detect-capabilities.sh preserves all original output fields and adds
# new graph_db, mcp_servers, ci_pipeline fields.
set -eu

f="scripts/dispatch/detect-capabilities.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Check all original fields are still present in the script
for field in subagent_dispatch agent_tool_available shell_execution git_available git_worktree github_actions runtime host_claude_code host_cursor host_copilot; do
  grep -q "echo \"${field}=" "$f" || { echo "FAIL: $f missing original field $field in text output"; exit 1; }
done

# Check new fields are present
for field in graph_db mcp_servers ci_pipeline; do
  grep -q "$field=" "$f" || { echo "FAIL: $f missing new field $field"; exit 1; }
done

# Check JSON output includes new fields
grep -q '"graph_db"' "$f" || { echo "FAIL: $f missing graph_db in JSON output"; exit 1; }
grep -q '"mcp_servers"' "$f" || { echo "FAIL: $f missing mcp_servers in JSON output"; exit 1; }
grep -q '"ci_pipeline"' "$f" || { echo "FAIL: $f missing ci_pipeline in JSON output"; exit 1; }

# Run the script and verify output contains expected fields
output="$(bash "$f" 2>/dev/null)"
echo "$output" | grep -q "^subagent_dispatch=" || { echo "FAIL: text output missing subagent_dispatch"; exit 1; }
echo "$output" | grep -q "^graph_db=" || { echo "FAIL: text output missing graph_db"; exit 1; }
echo "$output" | grep -q "^mcp_servers=" || { echo "FAIL: text output missing mcp_servers"; exit 1; }
echo "$output" | grep -q "^ci_pipeline=" || { echo "FAIL: text output missing ci_pipeline"; exit 1; }

echo "PASS: detect-capabilities.sh preserves all original fields and adds graph_db, mcp_servers, ci_pipeline"
