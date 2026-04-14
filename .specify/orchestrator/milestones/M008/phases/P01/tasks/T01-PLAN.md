---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M008"
name: "Refactor detect-capabilities.sh -- add graph DB, MCP, CI detection + --profile flag"
depends_on: []
---

## Prerequisites

- `scripts/dispatch/detect-capabilities.sh` exists (119 lines, committed on main).
- `sqlite3` CLI available on macOS as `/usr/bin/sqlite3`.

## Description

Extend `scripts/dispatch/detect-capabilities.sh` to detect three new environment
capabilities and add a `--profile` output mode for the intensity recommendation
engine. The three new capabilities are:

1. **graph_db** -- checks whether sqlite3 is available AND the project has a
   `.specify/orchestrator/knowledge.db` or `.orchestrator/knowledge.db` file
   (the SQLite graph backend from M007).
2. **mcp_servers** -- checks whether an MCP configuration file exists at any
   of: `.claude/mcp_servers.json`, `.cursor/mcp.json`, `mcp.json`, or the
   `MCP_CONFIG` environment variable points to a file.
3. **ci_pipeline** -- checks whether CI configuration files exist:
   `.github/workflows/` directory, `.gitlab-ci.yml`, `.circleci/config.yml`,
   `Jenkinsfile`, or `.buildkite/pipeline.yml`.

All existing output fields (subagent_dispatch, agent_tool_available,
shell_execution, git_available, git_worktree, github_actions, runtime,
host_claude_code, host_cursor, host_copilot) must be preserved unchanged.

The new `--profile` flag outputs a high-level capability summary as key=value
pairs designed for consumption by `intensity-recommend.sh`:
- `cap_execution=local|ci` (derived from runtime)
- `cap_graph=true|false` (from graph_db)
- `cap_mcp=true|false` (from mcp_servers)
- `cap_ci=true|false` (from ci_pipeline)
- `cap_subagent=true|false` (from subagent_dispatch)
- `cap_score=0..5` (count of true capabilities -- higher = richer environment)

## Steps

### Step 1 -- Add new capability detection to detect-capabilities.sh

Open `scripts/dispatch/detect-capabilities.sh`. Insert the following detection
blocks AFTER the existing `host_copilot` detection (line ~89) and BEFORE the
`# --- Output ---` section (line ~92).

Add this code between the last detection block and the output section:

```bash
# graph_db: check for sqlite3 AND a knowledge graph database file
graph_db=false
if command -v sqlite3 >/dev/null 2>&1; then
  if [[ -f .specify/orchestrator/knowledge.db ]] || [[ -f .orchestrator/knowledge.db ]]; then
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
```

### Step 2 -- Update the --format argument parsing to accept --profile

Modify the argument parsing section (lines ~15-22) to also accept `--profile`:

Replace the existing argument parsing block:

```bash
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
```

With:

```bash
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
```

### Step 3 -- Add the --profile output mode

Replace the entire `# --- Output ---` section with:

```bash
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
  "ci_pipeline": $ci_pipeline
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
fi
```

### Step 4 -- Update the script header comment

Update the header comment at the top of the file to document the new
capabilities and the `--profile` flag:

Replace:

```bash
# scripts/dispatch/detect-capabilities.sh — Detect runtime capabilities
# Reports available capabilities for graceful degradation across agent runtimes (R008).
#
# Usage: detect-capabilities.sh [--format json|text]
#   --format: output format (default: text — key=value lines)
#
# Always exits 0 (capability detection never fails — unknown capabilities default to false).
```

With:

```bash
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
```

### Step 5 -- Create verification scripts

Create two verification scripts.

**scripts/verify/m008-p01-capabilities-backward-compat.sh:**

```bash
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
```

**scripts/verify/m008-p01-capabilities-profile.sh:**

```bash
#!/usr/bin/env bash
# Verifies detect-capabilities.sh --profile outputs capability summary.
set -eu

f="scripts/dispatch/detect-capabilities.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Check --profile flag is handled
grep -q '\-\-profile' "$f" || { echo "FAIL: $f missing --profile flag handling"; exit 1; }

# Run with --profile and verify output format
output="$(bash "$f" --profile 2>/dev/null)"
echo "$output" | grep -q "^cap_execution=" || { echo "FAIL: profile output missing cap_execution"; exit 1; }
echo "$output" | grep -q "^cap_graph=" || { echo "FAIL: profile output missing cap_graph"; exit 1; }
echo "$output" | grep -q "^cap_mcp=" || { echo "FAIL: profile output missing cap_mcp"; exit 1; }
echo "$output" | grep -q "^cap_ci=" || { echo "FAIL: profile output missing cap_ci"; exit 1; }
echo "$output" | grep -q "^cap_subagent=" || { echo "FAIL: profile output missing cap_subagent"; exit 1; }
echo "$output" | grep -q "^cap_score=" || { echo "FAIL: profile output missing cap_score"; exit 1; }

# Verify cap_score is a number 0-5
score="$(echo "$output" | grep "^cap_score=" | cut -d= -f2)"
if ! echo "$score" | grep -qE '^[0-5]$'; then
  echo "FAIL: cap_score='$score' is not a number 0-5"; exit 1
fi

echo "PASS: detect-capabilities.sh --profile outputs valid capability summary"
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "detect-capabilities.sh adds graph_db, mcp_servers, and ci_pipeline
  detection while preserving all existing output fields" and
  "detect-capabilities.sh supports a --profile flag that outputs a capability
  summary suitable for intensity recommendation."
- **Artifacts**: `scripts/dispatch/detect-capabilities.sh` (modified),
  `scripts/verify/m008-p01-capabilities-backward-compat.sh`,
  `scripts/verify/m008-p01-capabilities-profile.sh`.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m008-p01-capabilities-backward-compat.sh
bash scripts/verify/m008-p01-capabilities-profile.sh
```

Both should print PASS lines and exit 0.

Additionally, verify backward compatibility manually:

```bash
# Default text output should include all original + new fields
bash scripts/dispatch/detect-capabilities.sh

# JSON output should include new fields
bash scripts/dispatch/detect-capabilities.sh --format json

# Profile output should be a compact summary
bash scripts/dispatch/detect-capabilities.sh --profile
```

### Files Touched By This Task

- `scripts/dispatch/detect-capabilities.sh` (modify)
- `scripts/verify/m008-p01-capabilities-backward-compat.sh` (create)
- `scripts/verify/m008-p01-capabilities-profile.sh` (create)

## Inputs

### From Previous Tasks

None -- T01 is independent.

### From Disk (Pre-existing)

- `scripts/dispatch/detect-capabilities.sh` -- the existing 119-line capability
  detection script. Current capabilities detected: subagent_dispatch,
  agent_tool_available, shell_execution, git_available, git_worktree,
  github_actions, runtime, host_claude_code, host_cursor, host_copilot. Supports
  `--format json|text`. Always exits 0.

## Constraints

- Bash 3.2 compatible -- no associative arrays, no readarray, no `|&`.
- Must exit 0 always (capability detection never fails -- unknown capabilities
  default to false).
- Must not break existing callers that parse text or JSON output.
- New fields are appended after existing fields in both text and JSON formats.

## Expected Output

After completing this task:

1. `scripts/dispatch/detect-capabilities.sh` is extended to ~170+ lines.
2. Running `bash scripts/dispatch/detect-capabilities.sh` outputs all 13
   key=value pairs (10 original + 3 new: graph_db, mcp_servers, ci_pipeline).
3. Running `bash scripts/dispatch/detect-capabilities.sh --format json` outputs
   a JSON object with all 13 fields.
4. Running `bash scripts/dispatch/detect-capabilities.sh --profile` outputs 6
   key=value pairs: cap_execution, cap_graph, cap_mcp, cap_ci, cap_subagent,
   cap_score.
5. `bash scripts/verify/m008-p01-capabilities-backward-compat.sh` prints PASS.
6. `bash scripts/verify/m008-p01-capabilities-profile.sh` prints PASS.
7. `git status` shows 1 modified file + 2 new files.
