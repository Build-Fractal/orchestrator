#!/usr/bin/env bash
# scripts/knowledge/lib/extract-tier-2-gate.sh -- M036 P03 T03 helper.
# Pure functions for Tier 2 conversus fidelity-gate invocation +
# PASS/BLOCK retention logic. Sourced by extract-reference.sh.
# No top-level I/O (MEM004). Bash 3.2 / POSIX-sh per CON-2.

# extract_tier_2_invoke_gate <source-path> <structured-md-path> <gate-output-path>
#   Invokes scripts/dispatch/adapters/tool/conversus.sh with the
#   tier-2-fidelity preset; writes gate-result.md to <gate-output-path>.
#   The source-path is plumbed via --source so the fidelity-advocate
#   can compare the structured-md extraction against the actual source
#   document (the Tier 1 plain-text floor for binary sources, or the
#   source markdown directly for markdown sources). Without --source,
#   tier-2-fidelity refuses to run (requires_source: true).
#   Returns: 0 on PASS, 2 on BLOCK, 1 on adapter error or missing inputs.
extract_tier_2_invoke_gate() {
  local source_doc="$1"
  local artifact="$2"
  local out="$3"
  local root="${ORCHESTRATOR_ROOT:-$(pwd)}"
  local adapter="$root/scripts/dispatch/adapters/tool/conversus.sh"
  if [ ! -f "$source_doc" ]; then
    echo "extract_tier_2_invoke_gate: source missing at $source_doc" >&2
    return 1
  fi
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
    bash "$adapter" gate --source "$source_doc" tier-2-fidelity "$artifact" "$out"
  local rc=$?
  case "$rc" in
    0) return 0 ;;   # PASS
    2) return 2 ;;   # BLOCK
    *) return 1 ;;   # adapter error
  esac
}

# _t2g_copy_advisories <gate-output-path> <log-dir> <cite_id>
#   Internal helper. On PASS, parse `conversus_output_dir:` from the
#   gate-result.md frontmatter and copy <conversus_output_dir>/summary/final.md
#   to <log-dir>/<cite_id>.advisories.md. Silently no-ops when:
#     - no conversus_output_dir line (e.g. stub-mode fixtures)
#     - the directory or final.md does not exist
#     - the gate-output is missing
#   This is best-effort discoverability, not load-bearing — failure to
#   produce an advisories.md never blocks a PASS promotion. Returns 0.
#
#   Background: the gate's PASS verdict is calibrated to "did the advocates
#   converge?" not "is the extraction perfect?" — a PASS can carry P1/P2
#   advisory corrections in the synthesis that improve fidelity without
#   rising to BLOCK-class disputes. Copying the synthesis next to the
#   chunk (and pointing at it from chunk frontmatter) gives operators a
#   single-indirection surface instead of a three-indirection drill-down
#   (chunk → gate-result.md → conversus-deliberation/summary/final.md).
#   See .orchestrator/proposals/papercut-m036a-p03-smoke-pass-with-concerns.md
_t2g_copy_advisories() {
  local gate_out="$1"
  local log_dir="$2"
  local cite_id="$3"
  [ -f "$gate_out" ] || return 0
  local cod
  cod="$(grep -E '^conversus_output_dir:' "$gate_out" 2>/dev/null \
    | head -n 1 \
    | sed -E 's/^conversus_output_dir:[[:space:]]*"?([^"]*)"?.*/\1/')"
  [ -n "$cod" ] || return 0
  local synthesis="$cod/summary/final.md"
  [ -f "$synthesis" ] || return 0
  cp "$synthesis" "$log_dir/${cite_id}.advisories.md" 2>/dev/null || return 0
  return 0
}

# extract_tier_2_promote_or_retain <verdict> <structured-tmp-path> <chunk-dir> <cite_id> <category> <gate-output-path> <log-dir>
#   verdict: 0 (PASS) | 2 (BLOCK)
#   PASS: mv <structured-tmp> -> <chunk-dir>/REF-<category>-<cite_id>.structured.md
#         cp <gate-output-path> -> <log-dir>/<cite_id>.pass.md
#         cp <cod>/summary/final.md -> <log-dir>/<cite_id>.advisories.md (best-effort; see _t2g_copy_advisories)
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
      _t2g_copy_advisories "$gate_out" "$log_dir" "$cite_id"
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
