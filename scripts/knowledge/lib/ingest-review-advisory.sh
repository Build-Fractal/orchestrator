#!/usr/bin/env bash
# scripts/knowledge/lib/ingest-review-advisory.sh -- M036 P06 T02.
#
# Pure-lib MEM004 helper for the cross-citer REVIEW: advisory pass in
# scripts/knowledge/ingest-reference.sh. No top-level execution.
# Functions take args, emit to stdout / exit code only.
#
# Bash 3.2 / POSIX-sh per CON-2.
#
# Functions:
#   review_emit_for_superseded_chunks <reference-root>
#     -> Scans <reference-root>/<category>/REF-*.md, finds chunks whose
#        frontmatter contains `superseded_by:`, and for each such chunk
#        invokes traverse-graph.sh --start <prior-id> --edge-types cites
#        --reverse --depth 1 to enumerate citers. Emits one stdout line
#        per citer: REVIEW: <citer-id> reason=cites-superseded
#        target=<prior-id> tip=<new-id>
#     -> Returns 0 always (advisory; never blocks ingest).
#
#   review_emit_for_removed_chunks <reference-root> <prior-manifest-file>
#     -> Reads the prior-manifest-file (one chunk-id per line) and
#        enumerates chunk-ids that are present in the manifest but
#        absent from the current reference root. For each missing
#        chunk-id, emits REMOVED: <chunk-id> and invokes traverse-
#        graph.sh to find citers, emitting REVIEW: <citer-id>
#        reason=cites-removed target=<chunk-id> per citer.
#     -> Returns 0 always.
#
set -eu

# Internal: read a single-line frontmatter field from a file.
_review_fm_field() {
  local f="$1"
  local k="$2"
  grep -E "^${k}:" "$f" | head -n 1 | sed -E "s/^${k}:[[:space:]]*//" | sed -E 's/^"//; s/"$//'
}

# Internal: invoke the typed-edge reverse traverser and emit one
# citer-id per stdout line. Tolerates the traverser being absent or
# the index being empty (advisory-only -- never blocks ingest).
_review_find_citers() {
  local prior_id="$1"
  local root="$2"
  local traverser="$root/scripts/knowledge/traverse-graph.sh"
  if [ ! -f "$traverser" ]; then
    return 0
  fi
  # Output format from typed-edge mode: lines of the form
  #   <source-id> -> <target-id> [cites]
  # Source-id is the citer (because --reverse swaps direction).
  bash "$traverser" --start "$prior_id" --edge-types cites --reverse --depth 1 2>/dev/null \
    | awk -v t="$prior_id" '
        /->/ {
          # First whitespace-delimited token is the citer (source-id).
          citer = $1
          # Skip the prior-id itself if the traverser echoes it as root.
          if (citer == t) next
          if (citer == "") next
          print citer
        }
      '
}

review_emit_for_superseded_chunks() {
  local ref_root="$1"
  local root
  root="${ORCHESTRATOR_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
  local category cat_dir chunk superseded_by_id chunk_id citer
  for category in cms-rule training-material glossary regulatory-doc business-doc; do
    cat_dir="$ref_root/$category"
    [ -d "$cat_dir" ] || continue
    for chunk in "$cat_dir"/REF-*.md; do
      [ -f "$chunk" ] || continue
      case "$(basename "$chunk")" in
        *.text.md|*.structured.md) continue ;;
      esac
      superseded_by_id=$(_review_fm_field "$chunk" superseded_by)
      [ -z "$superseded_by_id" ] && continue
      chunk_id=$(_review_fm_field "$chunk" chunk_id)
      [ -z "$chunk_id" ] && chunk_id="$(basename "$chunk" .md)"
      # Walk citers via the typed-edge reverse traverser.
      while IFS= read -r citer; do
        [ -z "$citer" ] && continue
        printf 'REVIEW: %s reason=cites-superseded target=%s tip=%s\n' \
          "$citer" "$chunk_id" "$superseded_by_id"
      done <<EOF
$(_review_find_citers "$chunk_id" "$root")
EOF
    done
  done
  return 0
}

review_emit_for_removed_chunks() {
  local ref_root="$1"
  local prior_manifest="$2"
  [ -f "$prior_manifest" ] || return 0
  local root
  root="${ORCHESTRATOR_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
  local prior_id citer present_anywhere category
  while IFS= read -r prior_id; do
    case "$prior_id" in ''|\#*) continue ;; esac
    # Check presence under any taxonomy category.
    present_anywhere=0
    for category in cms-rule training-material glossary regulatory-doc business-doc; do
      if [ -f "$ref_root/$category/${prior_id}.md" ]; then
        present_anywhere=1
        break
      fi
    done
    if [ "$present_anywhere" -eq 1 ]; then continue; fi
    printf 'REMOVED: %s\n' "$prior_id"
    while IFS= read -r citer; do
      [ -z "$citer" ] && continue
      printf 'REVIEW: %s reason=cites-removed target=%s\n' "$citer" "$prior_id"
    done <<EOF
$(_review_find_citers "$prior_id" "$root")
EOF
  done < "$prior_manifest"
  return 0
}
