#!/usr/bin/env bash
# scripts/dispatch/adapters/backend/local-codex.sh — Codex CLI SDK adapter
#
# Dispatch backend adapter that routes tasks through the `codex` command-
# line tool. Probe mode checks whether the `codex` binary is on PATH.
# Normal mode invokes the CLI as a subprocess with the assembled payload
# and emits a dispatch-result.md conforming document.
#
# Exact Codex CLI invocation is not yet runtime-validated (see the
# TODO(M008-P02) comment below). The placeholder `codex run --prompt-file
# "$PAYLOAD"` preserves the interface contract; swapping it for the
# correct Codex CLI syntax is a follow-up that does not require changes
# to any other orchestrator file.
#
# Usage:
#   local-codex.sh --probe
#     Emits: available=true|false
#
#   local-codex.sh --task-plan <path> --payload <path> --intensity-metadata <path>
#     Emits a dispatch-result.md conforming document on stdout.
#
# Bash 3.2 compatible.

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
  reason="codex-not-on-path"
  if command -v codex >/dev/null 2>&1; then
    available="true"
    reason="codex-binary-found"
  fi
  echo "available=${available}"
  echo "backend=local-codex"
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

: "${task_id:=unknown}"
: "${phase_id:=unknown}"
: "${milestone_id:=unknown}"

dispatched_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
start_ts="$(date -u +%s)"

# Prepare capture files
tmp_stdout="$(mktemp)"
tmp_stderr="$(mktemp)"
trap 'rm -f "$tmp_stdout" "$tmp_stderr"' EXIT

# Check codex is on PATH; if not, emit a failure result immediately.
if ! command -v codex >/dev/null 2>&1; then
  completed_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cat <<EOF
---
schema_version: "1.0"
type: "dispatch-result"
status: "failure"
backend: "local-codex"
task_id: "${task_id}"
phase_id: "${phase_id}"
milestone_id: "${milestone_id}"
dispatched_at: "${dispatched_at}"
completed_at: "${completed_at}"
duration_s: "0"
---

# Dispatch Result

## Status

failure -- codex CLI is not installed on PATH

## Summary

The local-codex adapter could not dispatch task ${task_id} because the
\`codex\` binary is not on PATH.

## Artifacts

## Notes

Install the Codex CLI and ensure \`codex\` is on PATH, or dispatch via a
different backend (e.g., --backend local-agent).
EOF
  exit 0
fi

# TODO(M008-P02): Replace the placeholder invocation below with the
# validated Codex CLI syntax. This is a wiring scaffold -- probe +
# result-emission contract is complete; the exact CLI argument shape is
# a runtime-validation follow-up that does not alter this file's
# structure or any other orchestrator file.
#
# Placeholder rationale: `codex run --prompt-file <file>` is a common
# CLI convention; the real CLI may use different flags.

codex_rc=0
codex run --prompt-file "$PAYLOAD" >"$tmp_stdout" 2>"$tmp_stderr" || codex_rc=$?

end_ts="$(date -u +%s)"
completed_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
duration_s=$((end_ts - start_ts))

if [[ $codex_rc -eq 0 ]]; then
  status="success"
  status_note="task dispatched successfully via codex CLI"
else
  status="failure"
  status_note="codex CLI exited with code ${codex_rc}"
fi

cat <<EOF
---
schema_version: "1.0"
type: "dispatch-result"
status: "${status}"
backend: "local-codex"
task_id: "${task_id}"
phase_id: "${phase_id}"
milestone_id: "${milestone_id}"
dispatched_at: "${dispatched_at}"
completed_at: "${completed_at}"
duration_s: "${duration_s}"
---

# Dispatch Result

## Status

${status} -- ${status_note}

## Summary

Task ${task_id} in phase ${phase_id} of milestone ${milestone_id} was
dispatched via the local-codex backend. The codex CLI stdout follows:

\`\`\`
$(cat "$tmp_stdout")
\`\`\`

## Artifacts

<!-- The codex CLI is responsible for creating artifacts. The adapter
     does not attempt to parse stdout for artifact paths in v1; the
     orchestrator's verification layer inspects the workspace instead. -->

## Notes

Backend: local-codex
codex exit code: ${codex_rc}
codex stderr:
\`\`\`
$(cat "$tmp_stderr")
\`\`\`

Reference: TODO(M008-P02) -- the codex CLI invocation syntax above is a
placeholder pending runtime validation.
EOF

exit 0
