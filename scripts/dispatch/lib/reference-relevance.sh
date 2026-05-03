#!/usr/bin/env bash
# scripts/dispatch/lib/reference-relevance.sh — M036 P07 T02 relevance
# ranker. Pure-lib MEM004; sourceable. Bash 3.2 / POSIX-sh.
#
# Resolves Open Question #Q-2 (relevance-ordering-signal) from the
# M036/033-reference-corpus-ingest spec with a deterministic hybrid
# four-key tie-break. Decision is captured here at the implementation
# site (matches M036's key_decisions: none posture across P02/P03/P04/P05
# — reusable conventions, not architectural commitments).
#
# Sort keys (descending priority):
#   1. topic-tag overlap count (higher = more relevant)
#   2. applies_to_field overlap count (higher = more relevant)
#   3. published date (newer wins; ISO YYYY-MM-DD lex-sortable)
#   4. chunk_id lexicographic (deterministic tie-break)
#
# Exposes:
#   reference_rank <candidate_list_file> <task_topic_tags> <task_applies_to_field>
#     args:   candidate_list_file — path to file, one record per line:
#                 "<chunk_id>|<chunk_path>|<chunk_topic_tags_csv>|<chunk_applies_to_field_csv>|<published_iso>"
#             task_topic_tags — comma-separated list of task-plan topic_tags
#             task_applies_to_field — comma-separated list of task-plan applies_to_field
#     stdout: ranked records, same format as input, sorted descending by
#             the four keys. Deterministic byte-for-byte across invocations.
#     exit:   0 always

_ref_overlap_count() {
  # _ref_overlap_count <chunk_csv> <task_csv>
  # Emits integer count of tokens present in both CSVs. Comma-separated
  # input. Empty inputs return 0.
  local chunk="$1" task="$2"
  local count=0 t c
  [ -z "$chunk" ] || [ -z "$task" ] && { echo 0; return 0; }
  local IFS_save="$IFS"
  IFS=','
  for t in $task; do
    t="$(printf '%s' "$t" | sed 's/^ *//; s/ *$//')"
    [ -z "$t" ] && continue
    for c in $chunk; do
      c="$(printf '%s' "$c" | sed 's/^ *//; s/ *$//')"
      [ "$c" = "$t" ] && count=$((count + 1))
    done
  done
  IFS="$IFS_save"
  echo "$count"
}

reference_rank() {
  local cand_file="$1" task_topics="$2" task_fields="$3"
  local sortkey_file
  sortkey_file="$(mktemp)"
  local chunk_id chunk_path chunk_topics chunk_fields published
  local topic_overlap field_overlap

  while IFS='|' read -r chunk_id chunk_path chunk_topics chunk_fields published; do
    [ -z "$chunk_id" ] && continue
    topic_overlap="$(_ref_overlap_count "$chunk_topics" "$task_topics")"
    field_overlap="$(_ref_overlap_count "$chunk_fields" "$task_fields")"
    # Sort key: pad ints with zeros for lex sort; reverse for descending.
    # Format: <topic_pad>|<field_pad>|<published_neg>|<chunk_id>|<original-record>
    # We use sort -t'|' -k1,1nr -k2,2nr -k3,3r -k4,4 for descending intent.
    printf '%d|%d|%s|%s|%s|%s|%s|%s|%s\n' \
      "$topic_overlap" "$field_overlap" "$published" "$chunk_id" \
      "$chunk_id" "$chunk_path" "$chunk_topics" "$chunk_fields" "$published" \
      >> "$sortkey_file"
  done < "$cand_file"

  # Sort: -k1nr (topic desc) -k2nr (field desc) -k3r (published desc lex)
  # -k4 (chunk_id ascending lex). Then strip the four sort-key prefix fields.
  sort -t'|' -k1,1nr -k2,2nr -k3,3r -k4,4 "$sortkey_file" \
    | awk -F'|' 'BEGIN{OFS="|"} {print $5,$6,$7,$8,$9}'
  rm -f "$sortkey_file"
  return 0
}
