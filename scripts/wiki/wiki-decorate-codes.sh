#!/usr/bin/env bash
# scripts/wiki/wiki-decorate-codes.sh
# M032/P04/T02 — FR-20 build-time code-shorthand decorator (US-8 P3 stub).
#
# Surface exists; polish deferred to post-launch wiki-UX-deep proposal
# (per Principle XIV: ship the interface so downstream proposals build
# against a known shape; do NOT expand scope without spec amendment).
#
# Interface:
#   bash scripts/wiki/wiki-decorate-codes.sh \
#     --in <input-page>.md \
#     --glossary <glossary-page>.md \
#     --out <output-page>.md
#
# Patterns scanned (verbatim, in this order — first match wins on overlap):
#   [A-Z]{2,4}-\d+   (e.g. AP-009, MIT-001, DR-STACK-001)
#   M\d{3}           (e.g. M032)
#   DR-[A-Z]+-\d+    (subset of pattern 1; explicit for documentation)
#   AP-\d+           (subset of pattern 1; explicit for documentation)
#
# First-occurrence-per-page: CODE -> [CODE (Title)](#anchor)
# Subsequent occurrences:    CODE -> [CODE](#anchor)
# Unresolved patterns:       byte-identical (US-8 AS-1 / Finding G — no
#                            broken-link noise).
#
# Stub-shaped scope (non-negotiable per Principle XIV):
#   - No full-tree rewrite (operator runs the decorator manually against
#     individual pages).
#   - No integration into wiki-generate-nav.sh or mkdocs build hooks.
#   - No glossary auto-derivation from the codebase beyond the simple
#     fallback below (best-effort `### CODE` walk under .orchestrator/,
#     references/, commands/).
#
# Post-launch wiki-UX-deep proposal owns the polish (full-tree rewrite,
# mkdocs hook integration, codebase auto-derivation). Future maintainers:
# do NOT "fix" the narrowness here without a spec amendment.
#
# Bash 3.2 compatible (per MEM001) — no declare -A, no process
# substitution, no compound-chain-gt2.

set -uo pipefail

IN=""
GLOSS=""
OUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --in) IN="$2"; shift 2 ;;
    --in=*) IN="${1#--in=}"; shift ;;
    --glossary) GLOSS="$2"; shift 2 ;;
    --glossary=*) GLOSS="${1#--glossary=}"; shift ;;
    --out) OUT="$2"; shift 2 ;;
    --out=*) OUT="${1#--out=}"; shift ;;
    *) echo "FAIL: wiki-decorate-codes: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

[ -n "$IN" ] || { echo "FAIL: wiki-decorate-codes: --in is required" >&2; exit 2; }
[ -n "$OUT" ] || { echo "FAIL: wiki-decorate-codes: --out is required" >&2; exit 2; }
[ -f "$IN" ] || { echo "FAIL: wiki-decorate-codes: --in file does not exist: $IN" >&2; exit 2; }

# Glossary fallback: missing-or-absent -> debug stderr and copy byte-identical.
# Step 3 of the documented algorithm. Best-effort codebase walk is
# deliberately omitted at this stub scope (deferred to post-launch wiki-UX-
# deep proposal); the simple fallback here is "no glossary -> no decoration".
if [ -z "$GLOSS" ] || [ ! -f "$GLOSS" ]; then
  echo "debug: wiki-decorate-codes: no glossary resolved, skipping decoration" >&2
  cp "$IN" "$OUT"
  exit 0
fi

# Parse glossary: each `### TERM` heading + immediately-following non-blank
# line (capped at 80 chars to keep title-slot decoration concise per the
# documented algorithm step 2). Build parallel-scalar arrays
# G_CODE_<i>=CODE / G_TITLE_<i>=Title (bash 3.2 has no declare -A; parallel
# scalars per MEM001).
G_COUNT=0
_pending_code=""
# bash 3.2 parameter-expansion quirk: ${line#### } parser-confuses with
# literal-`#` strip; resolved via intermediary _prefix=###  +
# ${line#$_prefix} per the P02/T03 patterns-established gotcha (MEM029-class).
_h3_prefix="### "
while IFS= read -r _line || [ -n "$_line" ]; do
  case "$_line" in
    "### "*)
      _pending_code="${_line#$_h3_prefix}"
      # Strip trailing whitespace.
      _pending_code="${_pending_code%"${_pending_code##*[![:space:]]}"}"
      ;;
    "")
      : # blank line — skip; keep waiting for non-blank definition.
      ;;
    *)
      if [ -n "$_pending_code" ]; then
        # First non-blank line after `### TERM` heading is the definition.
        _title="$_line"
        # Strip leading + trailing whitespace.
        _title="${_title#"${_title%%[![:space:]]*}"}"
        _title="${_title%"${_title##*[![:space:]]}"}"
        # Cap at 80 chars per documented algorithm.
        if [ "${#_title}" -gt 80 ]; then
          _title="${_title:0:80}"
        fi
        eval "G_CODE_${G_COUNT}=\"\$_pending_code\""
        eval "G_TITLE_${G_COUNT}=\"\$_title\""
        G_COUNT=$((G_COUNT + 1))
        _pending_code=""
      fi
      ;;
  esac
done < "$GLOSS"

# Lookup helper: given a CODE, prints the matching glossary title to stdout
# or empty string if unresolved. Case-sensitive.
lookup_title() {
  _query="$1"
  _i=0
  while [ "$_i" -lt "$G_COUNT" ]; do
    eval "_c=\"\$G_CODE_${_i}\""
    if [ "$_c" = "$_query" ]; then
      eval "_t=\"\$G_TITLE_${_i}\""
      printf '%s' "$_t"
      return 0
    fi
    _i=$((_i + 1))
  done
  printf ''
}

# Slug: CODE lowercased + non-alphanumeric collapsed to '-'. Used as anchor
# fragment in the rewritten link target.
slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

# Per-page first-occurrence tracker: parallel-scalar array S_SEEN_<i>=CODE.
S_SEEN_COUNT=0
seen_already() {
  _query="$1"
  _i=0
  while [ "$_i" -lt "$S_SEEN_COUNT" ]; do
    eval "_s=\"\$S_SEEN_${_i}\""
    if [ "$_s" = "$_query" ]; then
      return 0
    fi
    _i=$((_i + 1))
  done
  return 1
}
mark_seen() {
  eval "S_SEEN_${S_SEEN_COUNT}=\"\$1\""
  S_SEEN_COUNT=$((S_SEEN_COUNT + 1))
}

# Replace every occurrence of $1 in $2 with $3 using literal-string
# semantics (avoids sed's special-char escape headaches when titles contain
# `&`, `/`, parens, etc. per the Notes section caveat).
literal_replace_all() {
  _needle="$1"
  _haystack="$2"
  _repl="$3"
  _result=""
  while :; do
    case "$_haystack" in
      *"$_needle"*)
        _result="${_result}${_haystack%%"$_needle"*}${_repl}"
        _haystack="${_haystack#*"$_needle"}"
        ;;
      *)
        _result="${_result}${_haystack}"
        break
        ;;
    esac
  done
  printf '%s' "$_result"
}

# Replace ONLY the first occurrence of $1 in $2 with $3.
literal_replace_first() {
  _needle="$1"
  _haystack="$2"
  _repl="$3"
  case "$_haystack" in
    *"$_needle"*)
      printf '%s%s%s' "${_haystack%%"$_needle"*}" "$_repl" "${_haystack#*"$_needle"}"
      ;;
    *)
      printf '%s' "$_haystack"
      ;;
  esac
}

# Walk the input file line-by-line. For each line, regex-scan for the four
# documented code patterns, look up each candidate in the glossary, and
# rewrite per the first-occurrence-titled / subsequent-link-only rule.
# Unresolved candidates are left byte-identical (Finding G).
#
# Pattern unification: the four documented regexes overlap heavily —
# [A-Z]{2,4}-\d+ already matches AP-\d+ and DR-[A-Z]+-\d+ (the latter
# requires the inner [A-Z]+ to be 0-2 chars to fit within the {2,4} outer
# bound; for longer DR-* codes we add a separate scan). M\d{3} is the only
# disjoint pattern. We extract candidates via two passes:
#   (a) M\d{3}
#   (b) [A-Z]{2,}-[A-Z0-9-]*\d+   (broader than the 2,4 documented bound to
#       cover DR-STACK-001 and similar; lookup_title's case-sensitive
#       glossary check filters spurious hits per Finding G).

OUT_TMP=$(mktemp -t m032-decorate-out.XXXXXX)
trap 'rm -f "$OUT_TMP"' EXIT INT TERM

# Use grep -oE to extract candidate codes from each line; iterate uniques
# in order of first appearance to preserve the first-occurrence-per-page
# semantics. Pattern matches use a non-greedy heuristic: walk the file
# once, accumulate a unique-in-order candidate list, then rewrite each.

# Append a sentinel char to preserve trailing newlines through command
# substitution (which strips trailing newlines per POSIX); strip the
# sentinel before write.
_all_input="$(cat "$IN"; printf 'X')"
_all_input="${_all_input%X}"
# Extract candidates: union of M### and [A-Z]{2,}-[A-Z0-9-]*\d+. Sort
# preserves first-appearance order via awk '!seen[$0]++'.
_candidates="$(printf '%s' "$_all_input" \
  | grep -oE '(M[0-9]{3}|[A-Z]{2,}-[A-Z0-9-]*[0-9]+)' \
  | awk '!seen[$0]++' || true)"

_rewritten="$_all_input"

# Iterate candidates; for each, look up title; if resolved, rewrite first
# occurrence with title and remaining occurrences with link-only.
if [ -n "$_candidates" ]; then
  while IFS= read -r _code; do
    [ -z "$_code" ] && continue
    _title="$(lookup_title "$_code")"
    if [ -z "$_title" ]; then
      # Unresolved: byte-identical (Finding G).
      continue
    fi
    _slug="$(slugify "$_code")"
    # First occurrence: titled; rest: link-only. mark_seen tracks which
    # codes have had their first occurrence rewritten in THIS page.
    _titled="[${_code} (${_title})](#${_slug})"
    _link_only="[${_code}](#${_slug})"
    # Replace FIRST occurrence with titled form, then ALL remaining with
    # link-only form. To avoid the nested-link failure mode (where the
    # titled replacement itself contains the original CODE substring),
    # split the haystack at the titled-insertion point and run the
    # link-only replace ONLY on the right-hand suffix.
    # Sentinel-strip pattern preserves trailing newlines through command
    # substitution per POSIX strip-trailing-newline semantics.
    case "$_rewritten" in
      *"$_code"*)
        _prefix_part="${_rewritten%%"$_code"*}"
        _suffix_part="${_rewritten#*"$_code"}"
        _suffix_link_only="$(literal_replace_all "$_code" "$_suffix_part" "$_link_only"; printf 'X')"
        _suffix_link_only="${_suffix_link_only%X}"
        _rewritten="${_prefix_part}${_titled}${_suffix_link_only}"
        mark_seen "$_code"
        ;;
      *)
        : # No occurrence of $_code (shouldn't reach here since uniqued).
        ;;
    esac
  done <<EOF
$_candidates
EOF
fi

# Use printf %s (no trailing newline added) so the trailing-newline
# semantics of the input are preserved verbatim — the sentinel-strip
# above already retained any trailing newlines that command-substitution
# would have stripped.
printf '%s' "$_rewritten" > "$OUT_TMP"
mv "$OUT_TMP" "$OUT"
trap - EXIT INT TERM

exit 0
