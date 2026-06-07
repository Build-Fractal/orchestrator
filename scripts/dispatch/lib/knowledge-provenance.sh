#!/usr/bin/env bash
# scripts/dispatch/lib/knowledge-provenance.sh
# M044/P01/T02 (FR-5) — fail-loud knowledge consumer helpers: index-state
# detection, an always-on provenance header, and a deterministic, budget-bounded
# index-free grep fallback over the raw corpus.
#
# Pure library (MEM004): function definitions only, no top-level execution, so
# it is safe to source under `set -euo pipefail`. The functions themselves are
# written defensively (every fallible command guarded) so they never abort a
# caller running under `set -e`.
#
# Contract:
#   kp_index_state <index_path> <knowledge_dir>  -> missing|empty|stale|present
#   kp_index_age   <index_path>                  -> <integer seconds> | none
#   kp_grep_fallback <knowledge_dir> <touched_csv> <budget_tokens>  -> entry bodies
#   kp_emit_header <source> <index_age> <entries_considered>        -> provenance block
#
# Determinism (CON-3): LC_ALL=C sort, stable file order, no wall-clock in the
# fallback body. kp_index_age is the only time-relative value and is surfaced
# ONLY in the header (never in the fallback artifact body); it resolves to
# `none` for the missing/empty index — which is the case the SC-6 byte-equality
# regression asserts.
#
# Bash 3.2 compatible.

# Provenance byte-contract version. Pinned now (#Q-4) so the P1 resolved-id /
# freshness surface can extend the header without a breaking byte-contract bump.
KP_PROVENANCE_VERSION="1"

# --- Resolve a knowledge entry's id from its path ---
_kp_entry_id() {
  basename "$1" .md 2>/dev/null || printf '%s' "$1"
}

# --- Stable per-file token estimate: ceil(chars / 4). No wall-clock, no RNG. ---
_kp_token_estimate() {
  local f="$1" chars
  chars="$(wc -c < "$f" 2>/dev/null | tr -d ' ')"
  if [ -z "$chars" ]; then
    printf '0'
    return 0
  fi
  printf '%s' "$(( (chars + 3) / 4 ))"
}

# --- kp_index_state <index_path> <knowledge_dir> ---
# missing  : index file does not exist
# empty    : index exists but carries no MEM/REF/SPEC data rows
# stale    : index exists + non-empty + some knowledge/**/*.md is newer than it
# present  : otherwise (healthy)
kp_index_state() {
  local index_path="$1" kdir="$2"
  if [ -z "$index_path" ] || [ ! -f "$index_path" ]; then
    printf 'missing'
    return 0
  fi
  if ! grep -qE '^(MEM|REF-|SPEC-)[0-9A-Za-z]' "$index_path" 2>/dev/null; then
    printf 'empty'
    return 0
  fi
  if [ -n "$kdir" ] && [ -d "$kdir" ]; then
    local newer
    newer="$(find "$kdir" -type f -name '*.md' -newer "$index_path" -print 2>/dev/null | head -1 || true)"
    if [ -n "$newer" ]; then
      printf 'stale'
      return 0
    fi
  fi
  printf 'present'
  return 0
}

# --- kp_index_age <index_path> -> integer seconds since index mtime, or none ---
# Portable across darwin (stat -f %m) and GNU (stat -c %Y). Time-relative: used
# ONLY in the header; resolves to `none` when the index is absent.
kp_index_age() {
  local index_path="$1"
  if [ -z "$index_path" ] || [ ! -f "$index_path" ]; then
    printf 'none'
    return 0
  fi
  local mtime now
  mtime="$(stat -f %m "$index_path" 2>/dev/null || stat -c %Y "$index_path" 2>/dev/null || printf '')"
  now="$(date +%s 2>/dev/null || printf '')"
  if [ -z "$mtime" ] || [ -z "$now" ]; then
    printf 'none'
    return 0
  fi
  local age=$(( now - mtime ))
  if [ "$age" -lt 0 ]; then
    age=0
  fi
  printf '%s' "$age"
  return 0
}

# --- kp_grep_fallback <knowledge_dir> <touched_csv> <budget_tokens> ---
# Deterministic grep over raw knowledge/**/*.md (excluding archive). When the
# touched-file set yields matches, those entries are emitted; otherwise ALL
# entries are emitted (visibly degraded, never silently empty). Bounded by the
# M036a governor (reference_apply_budget). Emits resolved entry bodies in
# LC_ALL=C id order, blank-line separated — the same shape resolve-entries.sh
# produces. Echoes nothing when the corpus is empty (caller flags `degraded`).
kp_grep_fallback() {
  local kdir="$1" touched_csv="$2" budget="${3:-2000}"
  if [ -z "$kdir" ] || [ ! -d "$kdir" ]; then
    return 0
  fi

  # Source the M036a token-budget governor relative to this lib (same dir).
  local _kp_self_dir
  _kp_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if ! command -v reference_apply_budget >/dev/null 2>&1; then
    if [ -r "$_kp_self_dir/reference-budget.sh" ]; then
      # shellcheck source=reference-budget.sh
      . "$_kp_self_dir/reference-budget.sh" 2>/dev/null || true
    fi
  fi

  # 1. Enumerate candidate entry files (stable order, archive excluded).
  local all_tmp matched_tmp
  all_tmp="$(mktemp 2>/dev/null || printf '/tmp/kp_all_%s' "$$")"
  matched_tmp="$(mktemp 2>/dev/null || printf '/tmp/kp_match_%s' "$$")"
  find "$kdir" -type f \( -name 'MEM*.md' -o -name 'REF-*.md' \) 2>/dev/null \
    | grep -v '/archive/' 2>/dev/null \
    | LC_ALL=C sort > "$all_tmp" || true

  if [ ! -s "$all_tmp" ]; then
    rm -f "$all_tmp" "$matched_tmp"
    return 0
  fi

  # 2. Touched-file scoping. Build a fixed-string pattern from the CSV terms
  #    (basenames, no extension) and keep candidate files that mention any term.
  #    No matches (or no terms) -> use ALL candidates (degrade visibly).
  local use_file="$all_tmp"
  if [ -n "$touched_csv" ]; then
    local terms_tmp
    terms_tmp="$(mktemp 2>/dev/null || printf '/tmp/kp_terms_%s' "$$")"
    printf '%s' "$touched_csv" | tr ',' '\n' \
      | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
      | sed 's#.*/##;s#\.[A-Za-z0-9]*$##' \
      | grep -v '^$' > "$terms_tmp" || true
    if [ -s "$terms_tmp" ]; then
      local f
      while IFS= read -r f; do
        [ -f "$f" ] || continue
        if grep -qFf "$terms_tmp" "$f" 2>/dev/null; then
          printf '%s\n' "$f" >> "$matched_tmp"
        fi
      done < "$all_tmp"
    fi
    rm -f "$terms_tmp"
    if [ -s "$matched_tmp" ]; then
      use_file="$matched_tmp"
    fi
  fi

  # 3. Build the governor input list: <id>|<token_estimate>|<path>, id order.
  local list_tmp
  list_tmp="$(mktemp 2>/dev/null || printf '/tmp/kp_list_%s' "$$")"
  local f id toks
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    id="$(_kp_entry_id "$f")"
    toks="$(_kp_token_estimate "$f")"
    printf '%s|%s|%s\n' "$id" "$toks" "$f" >> "$list_tmp"
  done < "$use_file"

  # 4. Apply the budget governor (order-preserving; at-least-one-chunk).
  local bounded_tmp
  bounded_tmp="$(mktemp 2>/dev/null || printf '/tmp/kp_bounded_%s' "$$")"
  if command -v reference_apply_budget >/dev/null 2>&1 && [ -s "$list_tmp" ]; then
    reference_apply_budget "$list_tmp" "$budget" 2>/dev/null > "$bounded_tmp" || cp "$list_tmp" "$bounded_tmp"
  else
    cp "$list_tmp" "$bounded_tmp" 2>/dev/null || true
  fi

  # 5. Emit the selected entry bodies in order, blank-line separated.
  local first=1 path
  while IFS='|' read -r id toks path; do
    [ -n "$path" ] || continue
    [ -f "$path" ] || continue
    if [ "$first" -eq 1 ]; then
      first=0
    else
      printf '\n'
    fi
    cat "$path" 2>/dev/null || true
  done < "$bounded_tmp"

  rm -f "$all_tmp" "$matched_tmp" "$list_tmp" "$bounded_tmp"
  return 0
}

# --- kp_emit_header <source> <index_age> <entries_considered> ---
# Byte-stable provenance block, ALWAYS emitted into the payload (even on a
# healthy source=index). Field order is frozen (byte-contract).
kp_emit_header() {
  local source="${1:-index}" index_age="${2:-none}" entries="${3:-0}"
  printf 'knowledge_provenance:\n'
  printf '  provenance_version: %s\n' "$KP_PROVENANCE_VERSION"
  printf '  source: %s\n' "$source"
  printf '  index_age: %s\n' "$index_age"
  printf '  entries_considered: %s\n' "$entries"
}
