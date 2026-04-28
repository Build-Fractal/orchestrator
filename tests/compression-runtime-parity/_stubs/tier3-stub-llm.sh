#!/usr/bin/env bash
# tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh
#
# M018/P07/T02 — Deterministic stub for the Tier 3 LLM-call shim's
# operator-binary contract.
#
# scripts/dispatch/lib/tier3-llm-call.sh, when ORCH_TIER3_LLM_BIN is set
# and executable, invokes the operator binary with this exact four-flag
# shape:
#
#   "$ORCH_TIER3_LLM_BIN" \
#     --prompt-file <path> \
#     --output      <path> \
#     --max-tokens  <integer> \
#     --timeout     <integer>
#
# This stub honors that contract, writes a deterministic envelope to
# <output> (so SHA-256 over the post-pipeline payload is byte-identical
# across runtimes), and exits 0. ORCH_TIER3_STUB_FAIL=1 flips the stub
# to exit 1 so the parity runner can exercise the FR-9
# failure-passthrough path in _bc_apply_tier3.
#
# Why "operator-binary" — the shim's provider-resolution ladder is
# (1) ORCH_TIER3_LLM_BIN, (2) ORCH_BACKEND=claude-code + claude on PATH,
# (3) exit 1. Setting ORCH_TIER3_LLM_BIN to this stub takes the highest
# precedence path on every runtime, so the parity assertion is
# hermetic — no installed `claude` CLI is ever invoked.
#
# Side effect: appends one '<iso8601>\t<runtime>' line per fire to
# $ORCH_TIER3_STUB_INVOCATIONS_LOG (defaults to /dev/null when unset)
# so the parity runner can count invocations per runtime.
#
# Bash 3.2 (MEM001), AD-19 / AP-009 compliant — single-script-file, no
# compound chains > 2, no $(... | ...).

set -u

PROMPT_FILE=""
OUTPUT=""
MAX_TOKENS=""
TIMEOUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --prompt-file)
      PROMPT_FILE="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT="${2:-}"
      shift 2
      ;;
    --max-tokens)
      MAX_TOKENS="${2:-}"
      shift 2
      ;;
    --timeout)
      TIMEOUT="${2:-}"
      shift 2
      ;;
    -h|--help)
      sed -n '1,40p' "$0"
      exit 0
      ;;
    *)
      shift
      ;;
  esac
done

if [ -z "$OUTPUT" ]; then
  printf 'tier3-stub-llm.sh: --output required\n' >&2
  exit 2
fi

# Failure-passthrough exercise — FR-9. Caller sees non-zero exit; the
# helper writes savings_tokens=0 invocations=0 stats and emits
# tier3_failed JSONL. The dispatch survives.
if [ "${ORCH_TIER3_STUB_FAIL:-}" = "1" ]; then
  printf 'tier3-stub-llm.sh: ORCH_TIER3_STUB_FAIL=1 — failure-passthrough exercise\n' >&2
  # Still record the invocation so the parity runner can prove the stub
  # fired before exiting non-zero.
  TS_FAIL="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  LOG_FAIL="${ORCH_TIER3_STUB_INVOCATIONS_LOG:-/dev/null}"
  printf '%s\t%s\n' "$TS_FAIL" "${ORCH_BACKEND:-unknown}" >> "$LOG_FAIL"
  exit 1
fi

# Compute prompt-file byte size so the deterministic envelope carries a
# stable input_tokens marker. `wc -c < file` is a single-command
# substitution with input redirection — NOT $(... | ...).
INPUT_TOKENS=0
if [ -f "$PROMPT_FILE" ]; then
  INPUT_TOKENS=$(wc -c < "$PROMPT_FILE")
  # Strip whitespace some wc implementations prepend.
  INPUT_TOKENS=$(printf '%s' "$INPUT_TOKENS" | tr -d '[:space:]')
fi

# Deterministic envelope. The marker `compressed:tier3
# model=stub-deterministic` is what the parity runner greps for to
# confirm the stub's output reached the post-pipeline payload.
{
  printf '<!-- compressed:tier3 model=stub-deterministic input_tokens=%s output_tokens=42 -->\n' "$INPUT_TOKENS"
  printf 'stub-deterministic-summary-body\n'
} > "$OUTPUT"

# Side-effect: invocation counter line. Each fire appends exactly one
# line. ORCH_BACKEND tags which runtime made the call.
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
LOG="${ORCH_TIER3_STUB_INVOCATIONS_LOG:-/dev/null}"
printf '%s\t%s\n' "$TS" "${ORCH_BACKEND:-unknown}" >> "$LOG"

exit 0
