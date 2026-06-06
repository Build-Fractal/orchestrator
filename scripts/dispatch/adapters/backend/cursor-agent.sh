#!/usr/bin/env bash
# scripts/dispatch/adapters/backend/cursor-agent.sh — Cursor headless CLI adapter
#
# Dispatch backend adapter that routes tasks through the `cursor-agent`
# headless CLI (`cursor-agent -p --force --trust --output-format json`).
# Unlike the local-codex.sh TODO(M008-P02) placeholder, this invocation
# shape was runtime-validated by a live probe on 2026-06-06 — see
# .orchestrator/milestones/M009/M009-PROBE-FINDINGS-2026-06-06.md (the
# golden success fixture lives at probe-fixtures/cursor-agent-success.json).
#
# Probe mode (--probe) reports availability. To avoid hijacking the
# registry default_backend on a machine where Claude Code is the intended
# runtime (cursor-agent.sh sorts alphabetically BEFORE local-agent.sh, so
# an unconditionally-available probe would win the default slot), the probe
# reports available=true ONLY under an explicit opt-in:
#   ORCHESTRATOR_CURSOR_ENABLE=1   (auto-default opt-in), AND
#   cursor-agent on PATH, AND
#   authenticated (cursor-agent logged in OR CURSOR_API_KEY set).
# Explicit selection via `dispatch-interface.sh --backend cursor-agent`
# bypasses the probe entirely (the interface resolves the adapter file by
# name), so the opt-in gate never blocks deliberate use — it only governs
# whether Cursor becomes the *auto-selected* default.
#
# Normal mode runs the validated invocation under a pure-bash watchdog
# (macOS ships no `timeout` binary), then classifies the result via the
# two failure modes the probe established:
#   1. preflight/arg errors  -> non-zero exit + plaintext stderr (no JSON)
#   2. runtime errors         -> exit 0 with is_error:true / subtype!=success
# A result is success only when exit==0 AND is_error==false.
#
# Usage:
#   cursor-agent.sh --probe
#     Emits: available=true|false / backend=cursor-agent / reason=...
#
#   cursor-agent.sh --task-plan <p> --payload <p> --intensity-metadata <p> [--model <id>]
#     Emits a dispatch-result.md conforming document on stdout (exit 0).
#     Exits 2 only on malformed input (missing required flags/files).
#
# Tunables (env):
#   ORCHESTRATOR_CURSOR_ENABLE     "1" to opt cursor in as auto-default (probe)
#   ORCHESTRATOR_CURSOR_TIMEOUT    watchdog seconds (default 600)
#   ORCHESTRATOR_CURSOR_WORKSPACE  workspace dir (default: $PWD)
#   ORCHESTRATOR_CURSOR_MODEL      fallback model when --model not passed
#                                  (default: empty -> cursor account default)
#
# Bash 3.2 compatible.

set -u

MODE="normal"
TASK_PLAN=""
PAYLOAD=""
INTENSITY_METADATA=""
MODEL=""

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
    --model)
      MODEL="${2:-}"; shift 2 ;;
    *)
      shift ;;
  esac
done

# --- Auth helper: logged-in OR CURSOR_API_KEY present ---
_cursor_authed() {
  if [ -n "${CURSOR_API_KEY:-}" ]; then
    return 0
  fi
  # `cursor-agent status` prints "Logged in as ..." on success; check rc + text.
  if command -v cursor-agent >/dev/null 2>&1; then
    if cursor-agent status 2>/dev/null | grep -qi 'logged in'; then
      return 0
    fi
  fi
  return 1
}

# --- Probe mode ---

if [[ "$MODE" = "probe" ]]; then
  available="false"
  reason="not-opted-in"
  if [ "${ORCHESTRATOR_CURSOR_ENABLE:-0}" != "1" ]; then
    reason="not-opted-in"            # set ORCHESTRATOR_CURSOR_ENABLE=1 to auto-default
  elif ! command -v cursor-agent >/dev/null 2>&1; then
    reason="cursor-agent-not-on-path"
  elif ! _cursor_authed; then
    reason="cursor-agent-not-authenticated"
  else
    available="true"
    reason="opted-in-and-authenticated"
  fi
  echo "available=${available}"
  echo "backend=cursor-agent"
  echo "reason=${reason}"
  exit 0
fi

# --- Normal mode ---

# Validate required inputs (malformed input is the only non-zero exit).
if [[ -z "$TASK_PLAN" ]] || [[ ! -f "$TASK_PLAN" ]]; then
  echo "ERROR: --task-plan is required and must point to an existing file" >&2
  exit 2
fi
if [[ -z "$PAYLOAD" ]] || [[ ! -f "$PAYLOAD" ]]; then
  echo "ERROR: --payload is required and must point to an existing file" >&2
  exit 2
fi

# Extract task/phase/milestone IDs from task plan YAML frontmatter.
task_id="$(grep -E '^task:' "$TASK_PLAN" | head -n 1 | sed -E 's/^task:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
phase_id="$(grep -E '^phase:' "$TASK_PLAN" | head -n 1 | sed -E 's/^phase:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
milestone_id="$(grep -E '^milestone:' "$TASK_PLAN" | head -n 1 | sed -E 's/^milestone:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
: "${task_id:=unknown}"
: "${phase_id:=unknown}"
: "${milestone_id:=unknown}"

dispatched_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
start_ts="$(date -u +%s)"

# Resolve model: explicit --model wins, else env fallback, else empty (Cursor
# account default — composer-2.5-fast as of the 2026-06-06 probe).
if [ -z "$MODEL" ]; then
  MODEL="${ORCHESTRATOR_CURSOR_MODEL:-}"
fi
WORKSPACE="${ORCHESTRATOR_CURSOR_WORKSPACE:-$PWD}"
WATCHDOG="${ORCHESTRATOR_CURSOR_TIMEOUT:-600}"

# --- Helper: emit a failure dispatch-result and exit 0 ---
# The adapter contract is: exit 0 with a status:"failure" dispatch-result on
# operational failure (missing binary, auth, timeout, runtime error). Non-zero
# exit is reserved for malformed *input* (handled above). dispatch-interface.sh
# treats a status:"failure" document as a normal (parseable) result.
_emit_failure() {
  local status_note="$1"
  local detail="$2"
  local completed_at duration_s end_ts
  end_ts="$(date -u +%s)"
  completed_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  duration_s=$((end_ts - start_ts))
  cat <<EOF
---
schema_version: "1.0"
type: "dispatch-result"
status: "failure"
backend: "cursor-agent"
task_id: "${task_id}"
phase_id: "${phase_id}"
milestone_id: "${milestone_id}"
dispatched_at: "${dispatched_at}"
completed_at: "${completed_at}"
duration_s: "${duration_s}"
---

# Dispatch Result

## Status

failure -- ${status_note}

## Summary

The cursor-agent adapter could not complete task ${task_id} in phase
${phase_id} of milestone ${milestone_id}.

## Artifacts

## Notes

Backend: cursor-agent
Detail:
\`\`\`
${detail}
\`\`\`
EOF
  exit 0
}

# Precondition: binary present.
if ! command -v cursor-agent >/dev/null 2>&1; then
  _emit_failure "cursor-agent CLI is not installed on PATH" \
"Install the Cursor CLI (https://cursor.com/docs/cli/overview) and ensure
cursor-agent is on PATH, or dispatch via a different backend (e.g.
--backend local-agent)."
fi

# Precondition: authenticated.
if ! _cursor_authed; then
  _emit_failure "cursor-agent is not authenticated" \
"Run 'cursor-agent login' (browser OAuth) or export CURSOR_API_KEY, then
re-dispatch. Auth is a hard precondition for headless cursor-agent runs
(no air-gapped dispatch -- see RUNTIME-ASSUMPTIONS RA-M009-CURSOR-01)."
fi

# Capture files for the subprocess.
tmp_stdout="$(mktemp 2>/dev/null || printf '/tmp/cursor_adapter_out_%d' "$$")"
tmp_stderr="$(mktemp 2>/dev/null || printf '/tmp/cursor_adapter_err_%d' "$$")"
trap 'rm -f "$tmp_stdout" "$tmp_stderr"' EXIT

# The assembled context payload is passed as the agent prompt (positional).
prompt_text="$(cat "$PAYLOAD")"

# --- Launch headless agent under a pure-bash watchdog (risk 1 mitigation) ---
# Two explicit invocation paths preserve word-splitting safety: include
# --model only when a model id was resolved (empty -> Cursor account default).
if [ -n "$MODEL" ]; then
  cursor-agent -p --force --trust --output-format json \
    --model "$MODEL" --workspace "$WORKSPACE" "$prompt_text" \
    >"$tmp_stdout" 2>"$tmp_stderr" &
else
  cursor-agent -p --force --trust --output-format json \
    --workspace "$WORKSPACE" "$prompt_text" \
    >"$tmp_stdout" 2>"$tmp_stderr" &
fi
agent_pid=$!

elapsed=0
timed_out=0
while kill -0 "$agent_pid" 2>/dev/null; do
  sleep 2
  elapsed=$((elapsed + 2))
  if [ "$elapsed" -ge "$WATCHDOG" ]; then
    kill -TERM "$agent_pid" 2>/dev/null
    sleep 3
    kill -KILL "$agent_pid" 2>/dev/null
    timed_out=1
    break
  fi
done

if [ "$timed_out" -eq 1 ]; then
  _emit_failure "cursor-agent timed out after ${WATCHDOG}s (watchdog killed it)" \
"The headless run exceeded ORCHESTRATOR_CURSOR_TIMEOUT=${WATCHDOG}s. Raise the
timeout for long tasks, or investigate a possible cursor-agent -p hang
(see M009 probe risk 1)."
fi

agent_rc=0
wait "$agent_pid"
agent_rc=$?

end_ts="$(date -u +%s)"
completed_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
duration_s=$((end_ts - start_ts))

# --- Failure mode 1: preflight/arg error -> non-zero exit + stderr, no JSON ---
if [ "$agent_rc" -ne 0 ]; then
  _emit_failure "cursor-agent exited with code ${agent_rc}" "$(cat "$tmp_stderr")"
fi

# --- Failure mode 2: runtime error -> exit 0 with is_error:true / subtype!=success ---
# Robust scalar extraction (no jq dependency): is_error / subtype appear as
# simple top-level fields in the result JSON.
is_error="$(grep -oE '"is_error":[[:space:]]*(true|false)' "$tmp_stdout" | head -n 1 | sed -E 's/.*:[[:space:]]*//')"
subtype="$(grep -oE '"subtype":[[:space:]]*"[^"]*"' "$tmp_stdout" | head -n 1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')"

if [ "$is_error" = "true" ] || { [ -n "$subtype" ] && [ "$subtype" != "success" ]; }; then
  _emit_failure "cursor-agent reported a runtime error (subtype=${subtype:-?}, is_error=${is_error:-?})" \
"$(cat "$tmp_stdout")"
fi

# Defensive: exit 0 but no recognizable result JSON.
if [ -z "$is_error" ] && [ -z "$subtype" ]; then
  _emit_failure "cursor-agent exit 0 but emitted no parseable result JSON" \
"stdout:
$(cat "$tmp_stdout")
stderr:
$(cat "$tmp_stderr")"
fi

# --- Success path ---
# Surface usage tokens for cost observability (dispatch-interface.sh owns the
# JSONL cost rollup; the adapter just reports). No USD in the JSON, so cost
# accounting degrades to a rate-card lookup / pricing_warning upstream.
result_json="$(cat "$tmp_stdout")"

cat <<EOF
---
schema_version: "1.0"
type: "dispatch-result"
status: "success"
backend: "cursor-agent"
task_id: "${task_id}"
phase_id: "${phase_id}"
milestone_id: "${milestone_id}"
dispatched_at: "${dispatched_at}"
completed_at: "${completed_at}"
duration_s: "${duration_s}"
---

# Dispatch Result

## Status

success -- task dispatched via cursor-agent headless CLI (model=${MODEL:-<account-default>})

## Summary

Task ${task_id} in phase ${phase_id} of milestone ${milestone_id} was
dispatched via the cursor-agent backend against workspace ${WORKSPACE}.
The cursor-agent result JSON follows:

\`\`\`json
${result_json}
\`\`\`

## Artifacts

<!-- cursor-agent's result JSON carries NO file-diff fields (M009 probe Q2).
     File changes must be inspected from the workspace by the orchestrator's
     verification layer, not parsed from this result. -->

## Notes

Backend: cursor-agent
Model: ${MODEL:-<account-default>}
Workspace: ${WORKSPACE}
Duration: ${duration_s}s (watchdog=${WATCHDOG}s)
Cost: token usage is in the result JSON's "usage" object (inputTokens /
outputTokens / cacheReadTokens / cacheWriteTokens). No USD is reported by
cursor-agent; upstream cost rollup applies a rate card or degrades to
estimated_cost_usd:null + pricing_warning.
Reference: M009 probe findings 2026-06-06; validated invocation
'cursor-agent -p --force --trust --output-format json [--model <id>] --workspace <dir> <prompt>'.
EOF

exit 0
