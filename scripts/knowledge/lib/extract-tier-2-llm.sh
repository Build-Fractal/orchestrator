#!/usr/bin/env bash
# scripts/knowledge/lib/extract-tier-2-llm.sh -- M036 P03 T02 helper.
# Pure functions for Tier 2 LLM extraction dispatch + unit_close emission.
# Sourced by scripts/knowledge/extract-reference.sh. No top-level I/O
# (MEM004 pure-lib pattern). Bash 3.2 / POSIX-sh per CON-2.
#
# Mock contract (CON-3: no live LLM in CI):
#   EXTRACT_TIER_2_DISPATCH=live          (default) -- call M030 + LLM
#   EXTRACT_TIER_2_DISPATCH=stub:pass     -- copy canned-structured.md to <out>
#   EXTRACT_TIER_2_DISPATCH=stub:block    -- copy canned-structured-low-fidelity.md
#
# In stub modes the helper emits stub model/token/cost values to stderr
# in NAME=VALUE form (one pair per line) so the driver can parse them
# back into unit_close fields.

# extract_tier_2_dispatch <input-path> <out-path> <category> <cite_id>
#   Returns 0 on success, 1 on error.
#   Always emits to stderr (one pair per line, NAME=VALUE form):
#     MODEL=<model-id>
#     TOKENS_IN=<n>
#     TOKENS_OUT=<n>
#     COST_USD=<float>
#     QUALITY_SCORE=<float>
extract_tier_2_dispatch() {
  local input="$1"
  local out="$2"
  local category="$3"
  local cite_id="$4"
  local mode="${EXTRACT_TIER_2_DISPATCH:-live}"
  local fx_dir="${ORCHESTRATOR_ROOT:-$(pwd)}/tests/fixtures/m036-p03-tier-2"
  case "$mode" in
    stub:pass)
      if [ ! -f "$fx_dir/canned-structured.md" ]; then
        echo "extract_tier_2_dispatch: canned-structured.md missing at $fx_dir" >&2
        return 1
      fi
      cp "$fx_dir/canned-structured.md" "$out"
      printf 'MODEL=claude-haiku-4-5\nTOKENS_IN=512\nTOKENS_OUT=2048\nCOST_USD=0.0123\nQUALITY_SCORE=0.92\n' >&2
      return 0
      ;;
    stub:block)
      if [ ! -f "$fx_dir/canned-structured-low-fidelity.md" ]; then
        echo "extract_tier_2_dispatch: canned-structured-low-fidelity.md missing at $fx_dir" >&2
        return 1
      fi
      cp "$fx_dir/canned-structured-low-fidelity.md" "$out"
      printf 'MODEL=claude-haiku-4-5\nTOKENS_IN=512\nTOKENS_OUT=1800\nCOST_USD=0.0119\nQUALITY_SCORE=0.61\n' >&2
      return 0
      ;;
    live)
      # Live path: route through M030, dispatch LLM, write structured-md.
      # NOT exercised in CI per CON-3. Implementation surface:
      #   - resolve model via select-model.sh against task_type=extraction
      #   - call backend dispatch with the source text + extraction prompt
      #   - persist real model+tokens+cost values for the unit_close record
      echo "extract_tier_2_dispatch: live mode not yet implemented (use EXTRACT_TIER_2_DISPATCH=stub:pass|stub:block in CI)" >&2
      return 1
      ;;
    *)
      echo "extract_tier_2_dispatch: unknown mode '$mode' (expected: live|stub:pass|stub:block)" >&2
      return 1
      ;;
  esac
}

# extract_tier_2_emit_unit_close <cite_id> <model> <tokens_in> <tokens_out> <cost_usd> <quality_score>
#   Appends one JSONL record to ${ORCHESTRATOR_ROOT}/.orchestrator/execution-log.jsonl.
#   Returns 0 on success, 1 on error.
extract_tier_2_emit_unit_close() {
  local cite_id="$1"
  local model="$2"
  local tokens_in="$3"
  local tokens_out="$4"
  local cost_usd="$5"
  local quality_score="$6"
  local root="${ORCHESTRATOR_ROOT:-$(pwd)}"
  local log="$root/.orchestrator/execution-log.jsonl"
  mkdir -p "$(dirname "$log")"
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  printf '{"event":"unit_close","task_type":"extraction","cite_id":"%s","model":"%s","tokens_in":%s,"tokens_out":%s,"cost_usd":%s,"quality_score":%s,"timestamp":"%s","source":"runtime"}\n' \
    "$cite_id" "$model" "$tokens_in" "$tokens_out" "$cost_usd" "$quality_score" "$ts" >> "$log"
}
