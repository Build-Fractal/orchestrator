#!/usr/bin/env bash
# scripts/knowledge/lib/extract-tier-2-gate.sh -- M036 P03 T03 helper.
# Pure functions for Tier 2 conversus fidelity-gate invocation +
# PASS/BLOCK retention logic. Sourced by extract-reference.sh.
# No top-level I/O (MEM004). Bash 3.2 / POSIX-sh per CON-2.

# extract_tier_2_invoke_gate <structured-md-path> <gate-output-path>
#   Invokes scripts/dispatch/adapters/tool/conversus.sh with the
#   tier-2-fidelity preset; writes gate-result.md to <gate-output-path>.
#   Returns: 0 on PASS, 2 on BLOCK, 1 on adapter error or missing inputs.
extract_tier_2_invoke_gate() {
  local artifact="$1"
  local out="$2"
  local root="${ORCHESTRATOR_ROOT:-$(pwd)}"
  local adapter="$root/scripts/dispatch/adapters/tool/conversus.sh"
  if [ ! -f "$artifact" ]; then
    echo "extract_tier_2_invoke_gate: structured-md missing at $artifact" >&2
    return 1
  fi
  if [ ! -x "$adapter" ]; then
    echo "extract_tier_2_invoke_gate: conversus adapter not executable at $adapter" >&2
    return 1
  fi
  # Bypass the conversus TODO-marker preflight: structured Markdown
  # extraction may legitimately contain TODO-shaped strings if the
  # source did. Tests + this gate path always run with the bypass.
  CONVERSUS_GATE_SKIP_TODO_CHECK=1 \
    bash "$adapter" gate tier-2-fidelity "$artifact" "$out"
  local rc=$?
  case "$rc" in
    0) return 0 ;;   # PASS
    2) return 2 ;;   # BLOCK
    *) return 1 ;;   # adapter error
  esac
}

# extract_tier_2_promote_or_retain <verdict> <structured-tmp-path> <chunk-dir> <cite_id> <category> <gate-output-path> <log-dir>
#   verdict: 0 (PASS) | 2 (BLOCK)
#   PASS: mv <structured-tmp> -> <chunk-dir>/REF-<category>-<cite_id>.structured.md
#         cp <gate-output-path> -> <log-dir>/<cite_id>.pass.md
#   BLOCK: cp <gate-output-path> -> <log-dir>/<cite_id>.block.md
#          rm <structured-tmp>     (do NOT promote)
#   Returns 0 on success, 1 on error.
extract_tier_2_promote_or_retain() {
  local verdict="$1"
  local tmp="$2"
  local chunk_dir="$3"
  local cite_id="$4"
  local category="$5"
  local gate_out="$6"
  local log_dir="$7"
  mkdir -p "$log_dir"
  case "$verdict" in
    0)
      local final="$chunk_dir/REF-${category}-${cite_id}.structured.md"
      mkdir -p "$chunk_dir"
      mv "$tmp" "$final"
      cp "$gate_out" "$log_dir/${cite_id}.pass.md"
      return 0
      ;;
    2)
      cp "$gate_out" "$log_dir/${cite_id}.block.md"
      rm -f "$tmp"
      return 0
      ;;
    *)
      echo "extract_tier_2_promote_or_retain: unknown verdict '$verdict' (expected 0|2)" >&2
      return 1
      ;;
  esac
}
