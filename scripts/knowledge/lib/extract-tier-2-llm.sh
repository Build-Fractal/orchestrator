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
      # Live path: shells out to `claude -p --output-format json` for a
      # real model invocation. CON-3 default-closed: opt-in via
      # ORCHESTRATOR_TIER2_LIVE=1. Without the flag, returns the same
      # deferred-error shape the original stub used so existing M036/P03
      # tests (which exercise stub:pass / stub:block / no-flag-set paths)
      # are unaffected.
      #
      # First exercised by tools/m036-p03-live-smoke.sh as the M036a
      # pre-pilot live-LLM smoke test (2026-05-07). Production-grade
      # routing (M030 task_type=extraction → smart tier) and prompt
      # templating are M036b post-launch work.
      if [ "${ORCHESTRATOR_TIER2_LIVE:-0}" != "1" ]; then
        echo "extract_tier_2_dispatch: live mode requires ORCHESTRATOR_TIER2_LIVE=1 (CON-3 default-closed; use stub:pass|stub:block in CI)" >&2
        return 1
      fi
      if ! command -v claude >/dev/null 2>&1; then
        echo "extract_tier_2_dispatch: live mode requires 'claude' CLI on PATH" >&2
        return 1
      fi
      if ! command -v python3 >/dev/null 2>&1; then
        echo "extract_tier_2_dispatch: live mode requires python3 (JSON parsing)" >&2
        return 1
      fi
      if [ ! -f "$input" ]; then
        echo "extract_tier_2_dispatch: input file not found: $input" >&2
        return 1
      fi
      local input_chars
      input_chars=$(wc -c < "$input" | tr -d ' ')
      # Pre-flight cap: refuse inputs over 256KB (~64k tokens) to keep
      # smoke-test single-doc cost well under the operator-set cap.
      if [ "$input_chars" -gt 262144 ]; then
        echo "extract_tier_2_dispatch: input ${input_chars} bytes exceeds smoke-test pre-flight cap (262144)" >&2
        return 1
      fi
      local tmp_json tmp_meta tmp_body
      tmp_json=$(mktemp "${TMPDIR:-/tmp}/m036-tier2-live-resp.XXXXXX.json")
      tmp_meta=$(mktemp "${TMPDIR:-/tmp}/m036-tier2-live-meta.XXXXXX.txt")
      tmp_body=$(mktemp "${TMPDIR:-/tmp}/m036-tier2-live-body.XXXXXX.md")
      # Build prompt on stdin: header + source body. Keeping it on stdin
      # avoids shell argument-size limits and quoting hazards.
      {
        printf '%s\n' "You are extracting a reference document into clean structured Markdown for ingest into a knowledge graph."
        printf '%s\n' ""
        printf '%s\n' "Preserve: heading structure (use ATX-style # / ## / ###), definitions, numbered rules, tables (as Markdown tables), and key calculations."
        printf '%s\n' ""
        printf '%s\n' "Output: Markdown only. No commentary, no preamble, no \"Here is the extracted content:\" header. Start with the first heading."
        printf '%s\n' ""
        printf '%s\n' "Source document follows after the --- separator."
        printf '%s\n' ""
        printf '%s\n' "---"
        printf '%s\n' ""
        printf '# Source: %s\n' "$cite_id"
        printf '%s\n' ""
        cat "$input"
      } | claude -p --output-format json > "$tmp_json" 2>/dev/null
      local claude_rc=$?
      if [ "$claude_rc" -ne 0 ]; then
        echo "extract_tier_2_dispatch: claude -p failed (rc=$claude_rc)" >&2
        rm -f "$tmp_json" "$tmp_meta" "$tmp_body"
        return 1
      fi
      python3 - "$tmp_json" "$tmp_meta" "$tmp_body" <<'PYEOF'
import json, sys
src, meta_out, body_out = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    d = json.load(open(src))
except Exception as exc:
    sys.stderr.write("python3 JSON parse failed: " + str(exc) + "\n")
    sys.exit(1)
if d.get("is_error"):
    sys.stderr.write("claude returned is_error=true\n")
    sys.exit(1)
mu = d.get("modelUsage") or {}
model = next(iter(mu)) if mu else "unknown"
usage = d.get("usage") or {}
with open(meta_out, "w") as f:
    f.write("MODEL=" + str(model) + "\n")
    f.write("TOKENS_IN=" + str(usage.get("input_tokens", 0)) + "\n")
    f.write("TOKENS_OUT=" + str(usage.get("output_tokens", 0)) + "\n")
    f.write("COST_USD=" + str(d.get("total_cost_usd", 0.0)) + "\n")
with open(body_out, "w") as f:
    f.write(d.get("result", ""))
PYEOF
      local py_rc=$?
      rm -f "$tmp_json"
      if [ "$py_rc" -ne 0 ]; then
        echo "extract_tier_2_dispatch: python3 JSON parse failed (rc=$py_rc)" >&2
        rm -f "$tmp_meta" "$tmp_body"
        return 1
      fi
      local model tokens_in tokens_out cost_usd
      model=$(grep '^MODEL=' "$tmp_meta" | head -n 1 | sed 's/^MODEL=//')
      tokens_in=$(grep '^TOKENS_IN=' "$tmp_meta" | head -n 1 | sed 's/^TOKENS_IN=//')
      tokens_out=$(grep '^TOKENS_OUT=' "$tmp_meta" | head -n 1 | sed 's/^TOKENS_OUT=//')
      cost_usd=$(grep '^COST_USD=' "$tmp_meta" | head -n 1 | sed 's/^COST_USD=//')
      rm -f "$tmp_meta"
      # Cost-cap post-check: ORCHESTRATOR_TIER2_LIVE_COST_CAP_USD
      # (default 1.0) is an operator-set hard ceiling.
      local cap="${ORCHESTRATOR_TIER2_LIVE_COST_CAP_USD:-1.0}"
      local cap_exceeded
      cap_exceeded=$(awk -v c="$cost_usd" -v k="$cap" 'BEGIN { print (c+0 > k+0) ? "1" : "0" }')
      if [ "$cap_exceeded" = "1" ]; then
        echo "extract_tier_2_dispatch: cost \$${cost_usd} exceeds cap \$${cap} (set ORCHESTRATOR_TIER2_LIVE_COST_CAP_USD to override)" >&2
        rm -f "$tmp_body"
        return 1
      fi
      if [ ! -s "$tmp_body" ]; then
        echo "extract_tier_2_dispatch: empty result body from claude -p" >&2
        rm -f "$tmp_body"
        return 1
      fi
      mv "$tmp_body" "$out"
      # QUALITY_SCORE=0 is a placeholder for live mode — `claude -p`
      # doesn't return a verdict-style score. The fidelity gate's
      # PASS|BLOCK is the load-bearing quality signal; quality_score in
      # the unit_close record is reserved for future per-extraction
      # heuristics and stays numeric to keep the JSONL well-formed.
      printf 'MODEL=%s\nTOKENS_IN=%s\nTOKENS_OUT=%s\nCOST_USD=%s\nQUALITY_SCORE=0\n' \
        "$model" "$tokens_in" "$tokens_out" "$cost_usd" >&2
      return 0
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
