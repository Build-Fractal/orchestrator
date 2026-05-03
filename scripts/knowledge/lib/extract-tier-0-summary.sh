#!/usr/bin/env bash
# scripts/knowledge/lib/extract-tier-0-summary.sh -- pure helpers for
# Tier 0 summary generation and Tier 1 adapter dispatch via registry.
# Sourced by scripts/knowledge/extract-reference.sh. No top-level I/O.
# Bash 3.2 / POSIX-sh per CON-2.

# generate_tier_0_summary <mode> <category> <cite_id> <operator-summary> <tier>
#   Echoes the chunk-body summary text per the mode enum.
#   Modes:
#     - operator: echo <operator-summary> verbatim. Exits 1 if empty
#                 (manifest violated `summary:` requirement).
#     - stub:     emit a deterministic placeholder: "[stub-summary]
#                 <category>: <cite_id>".
#     - auto:     P02 errors -- exit 1 with stderr "P03 not implemented:
#                 Tier 2 LLM extraction is the P03 deliverable; current
#                 P02 ships the synchronous Tier 0/1 path. Use
#                 summary_mode: operator or stub instead, or wait for
#                 P03 to land."
generate_tier_0_summary() {
  local mode="$1"
  local category="$2"
  local cite_id="$3"
  local op_summary="$4"
  local tier="$5"
  case "$mode" in
    operator)
      if [ -z "$op_summary" ]; then
        echo "generate_tier_0_summary: summary_mode=operator requires manifest summary:" >&2
        return 1
      fi
      printf '%s\n' "$op_summary"
      ;;
    stub)
      printf '[stub-summary] %s: %s\n' "$category" "$cite_id"
      ;;
    auto)
      if [ "$tier" = "2" ]; then
        # P03 (M036): tier=2 + auto returns the sentinel; the driver
        # consumes it and dispatches the Tier 2 helper chain
        # (extract_tier_2_dispatch + extract_tier_2_invoke_gate +
        # extract_tier_2_promote_or_retain + extract_tier_2_emit_unit_close).
        printf '__TIER_2_AUTO__\n'
        return 0
      else
        echo "generate_tier_0_summary: summary_mode=auto deferred to P03 (Tier 2 path). Use summary_mode: operator or stub for tier $tier." >&2
        return 1
      fi
      ;;
    *)
      echo "generate_tier_0_summary: unknown summary_mode '$mode' (expected: operator|stub|auto)" >&2
      return 1
      ;;
  esac
}

# extract_tier_1_via_registry <source-path> <text-output-path> <registry-tsv-path>
#   Resolves the source extension -> adapter via registry; invokes the
#   adapter, writes Tier 1 plain text to <text-output-path>. For
#   adapters with --out-dir contract (xlsx) emits a marker file at
#   <text-output-path> referencing the per-sheet CSV directory.
#   Exit 0 success, 1 missing input, 2 missing host tool (delegated
#   from adapter exit 2 -- caller decides whether to bail or continue).
extract_tier_1_via_registry() {
  local src="$1"
  local out="$2"
  local registry="$3"
  local ext="${src##*.}"
  local fmt
  case "$ext" in
    md|markdown) fmt="markdown" ;;
    pdf)         fmt="pdf" ;;
    docx)        fmt="docx" ;;
    xlsx)        fmt="xlsx" ;;
    *)
      echo "extract_tier_1_via_registry: unknown extension '$ext' for $src" >&2
      return 1
      ;;
  esac
  local adapter
  adapter=$(awk -F'\t' -v f="$fmt" '$1==f {print $2; exit}' "$registry")
  if [ -z "$adapter" ]; then
    echo "extract_tier_1_via_registry: no registry row for format '$fmt'" >&2
    return 1
  fi
  # Registry paths are repo-relative; resolve relative to ORCHESTRATOR_ROOT.
  local adapter_abs
  if [ "${adapter#/}" != "$adapter" ]; then
    adapter_abs="$adapter"
  else
    adapter_abs="${ORCHESTRATOR_ROOT:-$(pwd)}/$adapter"
  fi
  if [ "$fmt" = "xlsx" ]; then
    local outdir="${out}.csv-out"
    mkdir -p "$outdir"
    bash "$adapter_abs" "$src" --out-dir "$outdir" >/dev/null 2>&1 || return $?
    printf '[xlsx Tier 1: per-sheet CSVs at %s]\n' "$outdir" > "$out"
  else
    bash "$adapter_abs" "$src" > "$out" 2>/dev/null || return $?
  fi
  return 0
}
