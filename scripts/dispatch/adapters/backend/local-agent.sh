#!/usr/bin/env bash
# scripts/dispatch/adapters/backend/local-agent.sh — Claude Code Agent tool adapter
#
# Dispatch backend adapter for Claude Code's in-process Agent tool. Per
# MEM018, the Agent tool cannot be invoked directly from a shell script;
# it is an in-process capability of the orchestrating agent runtime. This
# adapter therefore functions as a coordination boundary: its normal-mode
# output is a dispatch-result.md conforming document whose Notes section
# instructs the orchestrating agent layer to perform the actual Agent
# invocation.
#
# The uniform dispatch interface is preserved: callers receive a
# parseable dispatch-result, independent of where/how the Agent tool
# ultimately runs.
#
# Usage:
#   local-agent.sh --probe
#     Emits: available=true|false
#
#   local-agent.sh --task-plan <path> --payload <path> --intensity-metadata <path>
#     Emits a dispatch-result.md conforming document on stdout.
#
# Bash 3.2 compatible. Exits 0 on success, non-zero only if input is
# malformed (missing required flags).

set -u

MODE="normal"
TASK_PLAN=""
PAYLOAD=""
INTENSITY_METADATA=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --probe)
      MODE="probe"; shift ;;
    --task-plan)
      TASK_PLAN="${2:-}"; shift 2 ;;
    --payload)
      PAYLOAD="${2:-}"; shift 2 ;;
    --intensity-metadata)
      INTENSITY_METADATA="${2:-}"; shift 2 ;;
    *)
      shift ;;
  esac
done

# --- Probe mode ---

if [[ "$MODE" = "probe" ]]; then
  available="false"
  reason="not-claude-code"
  if [[ "${SPECKIT_AGENT_TOOL:-0}" = "1" ]]; then
    available="true"
    reason="SPECKIT_AGENT_TOOL=1"
  elif [[ -d .claude ]]; then
    available="true"
    reason="claude-directory-present"
  fi
  echo "available=${available}"
  echo "backend=local-agent"
  echo "reason=${reason}"
  exit 0
fi

# --- Normal mode ---

# Validate required inputs
if [[ -z "$TASK_PLAN" ]] || [[ ! -f "$TASK_PLAN" ]]; then
  echo "ERROR: --task-plan is required and must point to an existing file" >&2
  exit 2
fi
if [[ -z "$PAYLOAD" ]] || [[ ! -f "$PAYLOAD" ]]; then
  echo "ERROR: --payload is required and must point to an existing file" >&2
  exit 2
fi

# Extract task/phase/milestone IDs from task plan YAML frontmatter
task_id="$(grep -E '^task:' "$TASK_PLAN" | head -n 1 | sed -E 's/^task:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
phase_id="$(grep -E '^phase:' "$TASK_PLAN" | head -n 1 | sed -E 's/^phase:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
milestone_id="$(grep -E '^milestone:' "$TASK_PLAN" | head -n 1 | sed -E 's/^milestone:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"

# Default empty values to the string "unknown" to keep frontmatter valid
: "${task_id:=unknown}"
: "${phase_id:=unknown}"
: "${milestone_id:=unknown}"

dispatched_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
completed_at="$dispatched_at"

# Emit a dispatch-result.md conforming document. Per MEM018 the adapter
# does not actually execute the Agent tool -- the orchestrating agent
# layer does. This result encodes the coordination boundary: status is
# 'success' (the adapter successfully produced a dispatch descriptor) and
# the Notes section tells the agent layer what to invoke.

cat <<EOF
---
schema_version: "1.0"
type: "dispatch-result"
status: "success"
backend: "local-agent"
task_id: "${task_id}"
phase_id: "${phase_id}"
milestone_id: "${milestone_id}"
dispatched_at: "${dispatched_at}"
completed_at: "${completed_at}"
duration_s: "0"
---

# Dispatch Result

## Status

success -- dispatch descriptor prepared for orchestrating agent layer

## Summary

The local-agent adapter prepared an Agent-tool dispatch descriptor for
task ${task_id} in phase ${phase_id} of milestone ${milestone_id}. Per
MEM018, the actual Agent tool invocation happens at the orchestrating
agent layer (in-process); this adapter defines the coordination boundary
that preserves uniform dispatch-interface semantics.

## Artifacts

<!-- Artifacts are produced by the Agent tool invocation itself. The
     orchestrating agent records them in the task summary after the
     Agent tool returns. This adapter emits an empty artifacts list by
     design. -->

## Notes

Orchestrating-agent action required: invoke the Claude Code Agent tool
with the following inputs:
  - task-plan: ${TASK_PLAN}
  - payload: ${PAYLOAD}
  - intensity-metadata: ${INTENSITY_METADATA}

Backend: local-agent (Claude Code in-process Agent tool)
Reference: MEM018 (Runtime Adapter Interface)
EOF

exit 0
