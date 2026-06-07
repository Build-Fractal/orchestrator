#!/usr/bin/env bash
# scripts/dispatch/lib/decisions-digest.sh — M044/P04/T02 (FR-6) bounded,
# budget-bounded Decisions digest for the Quick-profile inject.
#
# Pure-lib (MEM004) — function definitions only, no top-level execution; sourceable
# from anywhere. Bash 3.2 / POSIX-sh.
#
# The Quick inject previously omitted the Decisions section entirely, so a Quick
# project shipped an empty-forever Decisions slot (G-2). This digest reads the
# system-of-record DECISIONS.md, ranks rows newest-first, and routes the
# read-into-payload through the M036a token governor (CON-2 — no silent
# over-inject). Deterministic: file order is the rank, no wall-clock (CON-3).
#
# Exposes:
#   dd_decisions_digest <decisions_file> <budget_tokens> <max_rows>
#     stdout: surviving decision rows (markdown table rows, newest-first), or
#             nothing when the file is absent / has no `| D### |` data rows.
#     exit:   0 always.

# Resolve this lib's own dir so we can defensively source the budget governor.
_DD_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

dd_decisions_digest() {
  local decisions_file="$1" budget_tokens="$2" max_rows="$3"
  [ -f "$decisions_file" ] || return 0
  # Defensive: ensure the M036a governor is loaded (CON-2).
  if ! command -v reference_apply_budget >/dev/null 2>&1; then
    if [ -r "$_DD_SELF_DIR/reference-budget.sh" ]; then
      # shellcheck source=reference-budget.sh
      . "$_DD_SELF_DIR/reference-budget.sh" 2>/dev/null || true
    fi
  fi
  local rows_tmp rev_tmp list_tmp row_dir
  rows_tmp="$(mktemp)"; rev_tmp="$(mktemp)"; list_tmp="$(mktemp)"; row_dir="$(mktemp -d)"
  # Data rows only (| D### | ...), keep the last max_rows (the most recent).
  grep -E '^\|[[:space:]]*D[0-9]' "$decisions_file" 2>/dev/null | tail -n "$max_rows" > "$rows_tmp" || true
  if [ ! -s "$rows_tmp" ]; then
    rm -rf "$rows_tmp" "$rev_tmp" "$list_tmp" "$row_dir"
    return 0
  fi
  # Rank newest-first (reverse) so the governor keeps the newest within budget.
  awk '{a[NR]=$0} END{for(i=NR;i>=1;i--) print a[i]}' "$rows_tmp" > "$rev_tmp"
  local n=0 line rid chars toks rowfile
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    n=$((n + 1))
    rid="$(printf '%s' "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2}')"
    [ -z "$rid" ] && rid="D-$n"
    rowfile="$row_dir/$n.row"
    printf '%s\n' "$line" > "$rowfile"
    chars="$(printf '%s' "$line" | wc -c | tr -d ' ')"
    toks=$(( (chars + 3) / 4 ))
    printf '%s|%s|%s\n' "$rid" "$toks" "$rowfile" >> "$list_tmp"
  done < "$rev_tmp"
  local survivors
  if command -v reference_apply_budget >/dev/null 2>&1; then
    survivors="$(reference_apply_budget "$list_tmp" "$budget_tokens" 2>/dev/null || cat "$list_tmp")"
  else
    survivors="$(cat "$list_tmp")"
  fi
  printf '%s\n' "$survivors" | while IFS='|' read -r _id _tok _path; do
    [ -n "${_path:-}" ] && [ -f "$_path" ] && cat "$_path"
  done
  rm -rf "$rows_tmp" "$rev_tmp" "$list_tmp" "$row_dir"
  return 0
}
