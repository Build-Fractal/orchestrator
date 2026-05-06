#!/usr/bin/env bash
# scripts/knowledge/extract-reference.sh -- M036 P02 driver for
# orchestrator:extract synchronous Tier 0/1 path. Reads a manifest,
# iterates documents, computes content_hash, preserves binaries under
# .orchestrator/knowledge/reference/_originals/, emits Tier 1 plain-text
# files (T03 wires the adapter call), and writes Tier 0 chunk files.
#
# Usage:
#   scripts/knowledge/extract-reference.sh --manifest <path>
#                                          [--reference-root <path>]
#                                          [--originals-root <path>]
#                                          [--summary-mode <operator|stub|auto>]
#                                          [--size-cap-bytes <int>]
#
# Output contract (stdout):
#   EXTRACTED: <cite_id> tier=<n> bytes=<n> hash=<sha256-prefix>
#   SKIPPED:   <cite_id> reason=<unchanged|external-pointer>
# Errors to stderr; non-zero exit on any error.
#
# Bash 3.2 / POSIX-sh per CON-2. Idempotent (CON-4): re-running on
# unchanged inputs produces zero modifications.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${ORCHESTRATOR_ROOT:-$(cd "$HERE/../.." && pwd)}"
# Export so subprocess helpers (Tier 1 adapters, classify-reference, etc.)
# re-resolve to the SAME ROOT instead of falling back to $0-relative
# resolution — which silently misbehaves when this script is invoked from
# a parent project that has the orchestrator installed under it.
export ORCHESTRATOR_ROOT="$ROOT"

# shellcheck disable=SC1091
. "$HERE/lib/extract-manifest.sh"
# shellcheck disable=SC1091
. "$HERE/lib/extract-binary-preservation.sh"
# shellcheck disable=SC1091
. "$HERE/lib/extract-tier-0-summary.sh"
# shellcheck disable=SC1091
. "$HERE/lib/extract-tier-2-llm.sh"        # M036/P03 T02
# shellcheck disable=SC1091
. "$HERE/lib/extract-tier-2-gate.sh"       # M036/P03 T03
# shellcheck disable=SC1091
. "$HERE/lib/extract-supersede.sh"          # M036/P06 T01

MANIFEST=""
REF_ROOT="$ROOT/knowledge/reference"
ORIGINALS_ROOT="$ROOT/.orchestrator/knowledge/reference/_originals"
SUMMARY_MODE_OVERRIDE=""
SIZE_CAP_OVERRIDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --manifest) MANIFEST="$2"; shift 2 ;;
    --reference-root) REF_ROOT="$2"; shift 2 ;;
    --originals-root) ORIGINALS_ROOT="$2"; shift 2 ;;
    --summary-mode) SUMMARY_MODE_OVERRIDE="$2"; shift 2 ;;
    --size-cap-bytes) SIZE_CAP_OVERRIDE="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,16p' "$0"
      exit 0
      ;;
    *)
      echo "extract-reference.sh: unknown flag: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$MANIFEST" ] || [ ! -f "$MANIFEST" ]; then
  echo "extract-reference.sh: --manifest <path> required (got: '$MANIFEST')" >&2
  exit 1
fi

MANIFEST_DIR="$(cd "$(dirname "$MANIFEST")" && pwd)"

SIZE_CAP="$(extract_manifest_top_field "$MANIFEST" size_cap_bytes)"
if [ -z "$SIZE_CAP" ]; then SIZE_CAP=10485760; fi
if [ -n "$SIZE_CAP_OVERRIDE" ]; then SIZE_CAP="$SIZE_CAP_OVERRIDE"; fi

SOURCE_TYPES_YAML="$ROOT/references/reference-source-types.yaml"
REGISTRY_TSV="$ROOT/scripts/dispatch/adapters/format/registry.tsv"

DOC_COUNT="$(extract_manifest_doc_count "$MANIFEST")"
i=1
while [ "$i" -le "$DOC_COUNT" ]; do
  cite_id=$(extract_manifest_doc_field "$MANIFEST" "$i" cite_id)
  source_path_rel=$(extract_manifest_doc_field "$MANIFEST" "$i" source_path)
  category=$(extract_manifest_doc_field "$MANIFEST" "$i" category)
  source=$(extract_manifest_doc_field "$MANIFEST" "$i" source)
  tier=$(extract_manifest_doc_field "$MANIFEST" "$i" tier)
  summary_mode=$(extract_manifest_doc_field "$MANIFEST" "$i" summary_mode)
  size_cap_override_doc=$(extract_manifest_doc_field "$MANIFEST" "$i" size_cap_bytes_override)

  if [ -z "$tier" ]; then
    tier=$(extract_manifest_resolve_tier "$category" "$SOURCE_TYPES_YAML")
  fi
  if [ -z "$summary_mode" ]; then summary_mode="operator"; fi
  if [ -n "$SUMMARY_MODE_OVERRIDE" ]; then summary_mode="$SUMMARY_MODE_OVERRIDE"; fi

  effective_cap="$SIZE_CAP"
  if [ -n "$size_cap_override_doc" ]; then effective_cap="$size_cap_override_doc"; fi

  # Resolve source binary
  if [ "${source_path_rel#/}" != "$source_path_rel" ]; then
    src_abs="$source_path_rel"
  else
    src_abs="$MANIFEST_DIR/$source_path_rel"
  fi
  if [ ! -f "$src_abs" ]; then
    echo "extract-reference.sh: source not found for $cite_id at $src_abs" >&2
    exit 1
  fi

  hash=$(preservation_sha256 "$src_abs")
  size=$(preservation_size_bytes "$src_abs")

  # Chunk path
  chunk_dir="$REF_ROOT/$category"
  chunk_file="$chunk_dir/REF-${category}-${cite_id}.md"
  mkdir -p "$chunk_dir"

  # Idempotency gate: if existing chain-tip chunk has matching content_hash, SKIP.
  # Supersede branch (M036/P06 T01): if existing chain-tip chunk has different
  # content_hash, write a versioned successor and amend the prior
  # chain-tip with superseded_by: rather than silently overwriting.
  # When no chain exists, chain-tip == bare-suffix and behaviour is
  # byte-equivalent to the P02 fast path.
  prior_chunk_id_for_supersede=""
  new_version_slot=""
  if [ -f "$chunk_file" ]; then
    tip_file=$(supersede_find_chain_tip "$chunk_dir" "$category" "$cite_id")
    prior=$(grep -E '^content_hash:' "$tip_file" | head -n 1 | sed -E 's/^content_hash:[[:space:]]*//' | tr -d '"')
    if [ "$prior" = "$hash" ]; then
      echo "SKIPPED: $cite_id reason=unchanged"
      i=$((i + 1))
      continue
    fi
    # Hashes differ: walk to the chain tip, compute next slot, retarget
    # the chunk_file path to the new versioned successor file, and stash
    # the prior chain-tip path for post-write amendment.
    new_version_slot=$(supersede_next_version "$chunk_dir" "$category" "$cite_id")
    prior_chunk_id_for_supersede=$(basename "$tip_file" .md)
    chunk_file="$chunk_dir/REF-${category}-${cite_id}-v${new_version_slot}.md"
  fi

  # Binary preservation OR external pointer
  external_pointer=""
  if preservation_above_cap "$src_abs" "$effective_cap"; then
    external_pointer=$(preservation_external_pointer_shape "$src_abs")
  else
    preservation_copy_under_originals "$src_abs" "$source" "$ORIGINALS_ROOT"
  fi

  # Tier 1 leg: invoke registry-resolved adapter when tier >= 1.
  # T03 fills this in (currently no-op stub here).
  text_file=""
  if [ "$tier" -ge 1 ]; then
    text_file="$chunk_dir/REF-${category}-${cite_id}.text.md"
    extract_tier_1_via_registry "$src_abs" "$text_file" "$REGISTRY_TSV" || {
      echo "extract-reference.sh: Tier 1 adapter dispatch failed for $cite_id" >&2
      exit 1
    }
  fi

  # Tier 0 summary (T03 helper).
  operator_summary=$(extract_manifest_doc_field "$MANIFEST" "$i" summary)
  summary_text=$(generate_tier_0_summary "$summary_mode" "$category" "$cite_id" "$operator_summary" "$tier") || {
    echo "extract-reference.sh: summary generation failed for $cite_id" >&2
    exit 1
  }

  # Tier 2 dispatch + gate + promote/retain (M036/P03).
  # Triggered when generate_tier_0_summary returned the sentinel.
  tier_2_verdict=""
  if [ "$summary_text" = "__TIER_2_AUTO__" ]; then
    summary_text="[tier-2-auto] structured Markdown gated by conversus tier-2-fidelity preset"
    log_dir="$ROOT/.orchestrator/knowledge/reference/_extraction-log"
    mkdir -p "$log_dir"
    tmp_struct=$(mktemp "${TMPDIR:-/tmp}/m036-p03-struct.XXXXXX.md")
    gate_out=$(mktemp "${TMPDIR:-/tmp}/m036-p03-gate.XXXXXX.md")
    # Capture stub metrics (stderr name=value pairs) for unit_close.
    metrics_file=$(mktemp "${TMPDIR:-/tmp}/m036-p03-metrics.XXXXXX.txt")
    extract_tier_2_dispatch "$src_abs" "$tmp_struct" "$category" "$cite_id" 2>"$metrics_file" || {
      echo "extract-reference.sh: Tier 2 dispatch failed for $cite_id" >&2
      rm -f "$tmp_struct" "$gate_out" "$metrics_file"
      exit 1
    }
    set +e
    extract_tier_2_invoke_gate "$tmp_struct" "$gate_out"
    gate_rc=$?
    set -e
    case "$gate_rc" in
      0) tier_2_verdict="PASS" ;;
      2) tier_2_verdict="BLOCK" ;;
      *)
        echo "extract-reference.sh: Tier 2 gate adapter error for $cite_id (rc=$gate_rc)" >&2
        rm -f "$tmp_struct" "$gate_out" "$metrics_file"
        exit 1
        ;;
    esac
    extract_tier_2_promote_or_retain "$gate_rc" "$tmp_struct" "$chunk_dir" "$cite_id" "$category" "$gate_out" "$log_dir" || {
      echo "extract-reference.sh: Tier 2 promote/retain failed for $cite_id" >&2
      rm -f "$gate_out" "$metrics_file"
      exit 1
    }
    # Parse stub metrics from the metrics_file (name=value lines) and
    # emit the unit_close record.
    t2_model=$(grep -E '^MODEL=' "$metrics_file" | sed -E 's/^MODEL=//' | head -n 1)
    t2_in=$(grep -E '^TOKENS_IN=' "$metrics_file" | sed -E 's/^TOKENS_IN=//' | head -n 1)
    t2_out=$(grep -E '^TOKENS_OUT=' "$metrics_file" | sed -E 's/^TOKENS_OUT=//' | head -n 1)
    t2_cost=$(grep -E '^COST_USD=' "$metrics_file" | sed -E 's/^COST_USD=//' | head -n 1)
    t2_qual=$(grep -E '^QUALITY_SCORE=' "$metrics_file" | sed -E 's/^QUALITY_SCORE=//' | head -n 1)
    [ -z "$t2_model" ] && t2_model="unknown"
    [ -z "$t2_in" ]    && t2_in=0
    [ -z "$t2_out" ]   && t2_out=0
    [ -z "$t2_cost" ]  && t2_cost=0
    [ -z "$t2_qual" ]  && t2_qual=0
    extract_tier_2_emit_unit_close "$cite_id" "$t2_model" "$t2_in" "$t2_out" "$t2_cost" "$t2_qual"
    rm -f "$gate_out" "$metrics_file"
  fi

  # Emit chunk frontmatter + body.
  {
    printf -- "---\n"
    printf 'schema_version: "1.0"\n'
    printf 'type: reference-chunk\n'
    printf 'milestone: "M036"\n'
    printf 'category: "%s"\n' "$category"
    printf 'chunk_id: "REF-%s-%s"\n' "$category" "$cite_id"
    printf 'cite_id: "%s"\n' "$cite_id"
    printf 'source: "%s"\n' "$source"
    printf 'published: "%s"\n' "$(extract_manifest_doc_field "$MANIFEST" "$i" published)"
    if [ -n "${new_version_slot:-}" ]; then
      printf 'version: %s\n' "$new_version_slot"
      printf 'supersedes: "%s"\n' "$prior_chunk_id_for_supersede"
    else
      printf 'version: "%s"\n' "$(extract_manifest_doc_field "$MANIFEST" "$i" version)"
    fi
    printf 'topic_tags: %s\n' "$(extract_manifest_doc_list_field "$MANIFEST" "$i" topic_tags)"
    printf 'applies_to_field: %s\n' "$(extract_manifest_doc_list_field "$MANIFEST" "$i" applies_to_field)"
    printf 'tier: %s\n' "$tier"
    printf 'content_hash: "%s"\n' "$hash"
    printf 'size_bytes: %s\n' "$size"
    if [ -n "$external_pointer" ]; then
      printf 'external_pointer: "%s"\n' "$external_pointer"
    fi
    printf 'summary_mode: "%s"\n' "$summary_mode"
    if [ -n "$tier_2_verdict" ]; then
      printf 'tier_2_verdict: "%s"\n' "$tier_2_verdict"
    fi
    printf -- "---\n\n"
    printf '%s\n' "$summary_text"
  } > "$chunk_file"

  # M036/P06 T01: if we just wrote a versioned successor, amend the
  # prior chain-tip's frontmatter with superseded_by: pointing at us.
  if [ -n "${new_version_slot:-}" ] && [ -n "${prior_chunk_id_for_supersede:-}" ]; then
    new_chunk_id="REF-${category}-${cite_id}-v${new_version_slot}"
    prior_tip_file="$chunk_dir/${prior_chunk_id_for_supersede}.md"
    supersede_amend_prior_chunk "$prior_tip_file" "$new_chunk_id"
    echo "SUPERSEDED: $prior_chunk_id_for_supersede -> $new_chunk_id"
  fi

  if [ "$tier_2_verdict" = "BLOCK" ]; then
    echo "BLOCKED: $cite_id reason=fidelity-gate"
  else
    if [ -n "$tier_2_verdict" ]; then
      echo "EXTRACTED: $cite_id tier=$tier bytes=$size hash=${hash%${hash#????????}} verdict=$tier_2_verdict"
    else
      echo "EXTRACTED: $cite_id tier=$tier bytes=$size hash=${hash%${hash#????????}}"
    fi
  fi
  i=$((i + 1))
done
exit 0
