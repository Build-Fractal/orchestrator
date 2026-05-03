#!/usr/bin/env bash
# scripts/dispatch/lib/reference-budget.sh — M036 P07 T02 token-budget
# governor. Pure-lib MEM004 — function definitions only, no top-level
# execution; sourceable from anywhere. Bash 3.2 / POSIX-sh.
#
# Exposes:
#   reference_apply_budget <chunk_list_file> <budget_tokens>
#     stdin:  none
#     args:   chunk_list_file — path to a file with one record per line,
#                 format: "<chunk_id>|<token_count>|<chunk_path>"
#             budget_tokens — integer max tokens (chunk-level granularity)
#     stdout: surviving chunk records (same format as input), in the same
#             order as the input. Total of token_count column ≤ budget_tokens.
#     stderr: "WARNING: smallest chunk exceeds budget; emitting one chunk"
#             when at-least-one-chunk invariant fires.
#     exit:   0 always (caller treats stdout=empty as no-matches)
#
# FR-3 + FR-7: chunk-level granularity — chunks are dropped whole, never
#              mid-chunk truncated.
# FR-8: at-least-one-chunk invariant — when budget < smallest matched
#              chunk size, exactly one chunk is still emitted (with stderr
#              warning). Choosing the first chunk in input order is correct
#              because input is already ranked by reference_rank.

reference_apply_budget() {
  local list_file="$1" budget="$2"
  local total=0
  local emitted=0
  local chunk_id token_count chunk_path

  # Pass 1: emit chunks while running total stays under budget.
  while IFS='|' read -r chunk_id token_count chunk_path; do
    [ -z "$chunk_id" ] && continue
    local next=$((total + token_count))
    if [ "$next" -le "$budget" ]; then
      printf '%s|%s|%s\n' "$chunk_id" "$token_count" "$chunk_path"
      total="$next"
      emitted=$((emitted + 1))
    fi
  done < "$list_file"

  # Pass 2: at-least-one-chunk invariant. If pass 1 emitted nothing
  # (every chunk individually exceeded budget), emit the first chunk
  # in input order with a stderr warning.
  if [ "$emitted" -eq 0 ]; then
    local first_line
    first_line="$(head -n 1 "$list_file" 2>/dev/null || true)"
    if [ -n "$first_line" ]; then
      printf 'WARNING: smallest chunk exceeds budget; emitting one chunk\n' >&2
      printf '%s\n' "$first_line"
    fi
  fi
  return 0
}
