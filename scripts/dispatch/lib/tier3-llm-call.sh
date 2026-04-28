#!/usr/bin/env bash
# scripts/dispatch/lib/tier3-llm-call.sh
#
# M018/P06/T01 — Tier 3 LLM-call shim.
#
# Isolates the runtime-portability surface for the Tier 3 auto-compact
# helper (`_bc_apply_tier3` in `scripts/dispatch/build-context.sh`) so the
# multi-runtime parity work (P07) can swap providers without touching the
# helper body.
#
# Contract:
#
#   bash tier3-llm-call.sh \
#     --prompt-file <path-to-rendered-prompt> \
#     --capture-output <path-for-summary-out> \
#     --max-output-tokens <integer> \
#     --timeout-seconds <integer>
#
#   exit 0  -> success; summary text written to <capture-output> file.
#   exit !0 -> failure; caller treats as failure-passthrough (FR-9). The
#              caller does NOT read <capture-output> on non-zero exit.
#
# Provider selection:
#
#   - $ORCH_TIER3_LLM_BIN — explicit binary path. The shim invokes:
#       "$ORCH_TIER3_LLM_BIN" --prompt-file <p> --output <o> \
#                             --max-tokens <N> --timeout <S>
#     and forwards its exit code. This is the operator-provided escape
#     hatch — anything that honors the four-flag contract works.
#
#   - $ORCH_BACKEND=claude-code AND `claude` on PATH — invoke claude with
#     the prompt-file body on stdin and capture stdout. Honors
#     --max-output-tokens via the model's `--max-tokens` flag when the
#     installed claude CLI exposes it; otherwise falls through to the
#     default and lets `output_max_ratio` discard oversize summaries.
#
#   - Otherwise — exit 1 (no provider wired). The caller's
#     failure-passthrough records `tier3_failed reason=llm-call-nonzero`
#     and the dispatch proceeds without compaction.
#
# Bash 3.2 compatible (MEM001). No `declare -A`. Single-script-file shape
# (AD-19 / AP-009). Sourceable: NO `set -eu` at file scope (the helper
# returns non-zero rather than aborting the dispatch).

set -u

PROMPT_FILE=""
CAPTURE_OUTPUT=""
MAX_OUTPUT_TOKENS=""
TIMEOUT_SECONDS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --prompt-file)
      PROMPT_FILE="${2:-}"; shift 2 ;;
    --capture-output)
      CAPTURE_OUTPUT="${2:-}"; shift 2 ;;
    --max-output-tokens)
      MAX_OUTPUT_TOKENS="${2:-}"; shift 2 ;;
    --timeout-seconds)
      TIMEOUT_SECONDS="${2:-}"; shift 2 ;;
    --help|-h)
      sed -n '1,40p' "$0"
      exit 0 ;;
    *)
      shift ;;
  esac
done

if [ -z "$PROMPT_FILE" ] || [ ! -f "$PROMPT_FILE" ]; then
  printf 'tier3-llm-call.sh: --prompt-file required and must exist\n' >&2
  exit 2
fi
if [ -z "$CAPTURE_OUTPUT" ]; then
  printf 'tier3-llm-call.sh: --capture-output required\n' >&2
  exit 2
fi

# --- Provider 1: explicit operator binary ------------------------------------
if [ -n "${ORCH_TIER3_LLM_BIN:-}" ] && [ -x "${ORCH_TIER3_LLM_BIN}" ]; then
  "$ORCH_TIER3_LLM_BIN" \
    --prompt-file "$PROMPT_FILE" \
    --output "$CAPTURE_OUTPUT" \
    --max-tokens "${MAX_OUTPUT_TOKENS:-2000}" \
    --timeout "${TIMEOUT_SECONDS:-60}"
  exit $?
fi

# --- Provider 2: claude-code (claude CLI on PATH) ----------------------------
if [ "${ORCH_BACKEND:-}" = "claude-code" ]; then
  if command -v claude >/dev/null 2>&1; then
    # Send prompt-file body to claude on stdin, capture stdout to the output
    # file. The claude CLI's exit code is the success signal; non-zero ->
    # failure-passthrough at the helper layer.
    claude --print < "$PROMPT_FILE" > "$CAPTURE_OUTPUT" 2>/dev/null
    exit $?
  fi
fi

# --- No provider wired — failure-passthrough --------------------------------
_claude_present=no
if command -v claude >/dev/null 2>&1; then
  _claude_present=yes
fi
printf 'tier3-llm-call.sh: no LLM provider wired (ORCH_TIER3_LLM_BIN unset; ORCH_BACKEND=%s; claude on PATH=%s)\n' \
  "${ORCH_BACKEND:-unset}" "$_claude_present" >&2
exit 1
