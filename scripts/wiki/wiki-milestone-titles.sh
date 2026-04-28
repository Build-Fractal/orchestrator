#!/usr/bin/env bash
# scripts/wiki/wiki-milestone-titles.sh — emit M### -> Title lookup.
#
# Produces one line per milestone seen in .orchestrator/{milestones,proposals}
# in the form:
#
#   M### <TAB> Title
#
# Used by wiki-generate-nav.sh + wiki-generate-stubs.sh to label milestone
# nav entries and milestone index pages with human-readable names instead
# of bare M### codes.
#
# Source priority (first match wins):
#   1. .orchestrator/milestone-summary.md  — `**M### — Title**` lines
#      (canonical roadmap rollup, freshest)
#   2. .orchestrator/proposals/M###-*.md   — H1 stripped of `Proposal: ` prefix
#      (forward roadmap items not yet kicked off)
#   3. .orchestrator/milestones/M###/M###-SUMMARY.md  — H1 stripped of leading
#      `Milestone Summary: ` / `M### — ` prefix
#   4. .orchestrator/milestones/M###/M###-EVALUATION.md — H1 stripped
#   5. fallback: bare `M###` (caller decides whether to render the bare ID)
#
# Output is sorted lexically by M### so callers can do a single forward scan.
# Bash 3.2 compatible. No deps beyond grep/sed/awk/sort.
#
# Usage:
#   bash scripts/wiki/wiki-milestone-titles.sh [--root PROJECT_ROOT]
#   bash scripts/wiki/wiki-milestone-titles.sh --get M028   # single lookup
#
# Exit 0 on success; 1 on missing root.

set -u

ROOT=""
GET=""

while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      shift
      [ $# -eq 0 ] && { printf 'ERROR: --root requires arg\n' >&2; exit 1; }
      ROOT="$1"; shift ;;
    --get)
      shift
      [ $# -eq 0 ] && { printf 'ERROR: --get requires M### arg\n' >&2; exit 1; }
      GET="$1"; shift ;;
    --help|-h)
      sed -n '2,30p' "$0"; exit 0 ;;
    *)
      printf 'ERROR: unknown arg: %s\n' "$1" >&2; exit 1 ;;
  esac
done

if [ -z "$ROOT" ]; then
  SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
  ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
fi

[ -d "$ROOT" ] || { printf 'ERROR: root not found: %s\n' "$ROOT" >&2; exit 1; }

ORCH="$ROOT/.orchestrator"
SUM="$ORCH/milestone-summary.md"
PROP_DIR="$ORCH/proposals"
MS_DIR="$ORCH/milestones"

# ---- helpers ----------------------------------------------------------------

# strip_title <raw> — strip leading prefixes that duplicate the M### code or
# add boilerplate. Examples:
#   "Milestone Summary: M018 — Context Compression Layer" -> "Context Compression Layer"
#   "Proposal: M028 — Autonomous Hardening v3"           -> "Autonomous Hardening v3"
#   "M025 — GitHub installer coexistence remediation"    -> "GitHub installer coexistence remediation"
#   "M026 Evaluation"                                    -> "Evaluation"   (poor signal but better than M026)
strip_title() {
  _t="$1"
  # Drop leading "Proposal: " or "Milestone Summary: ".
  _t=$(printf '%s' "$_t" | sed -E 's/^[[:space:]]*(Proposal:|Milestone Summary:)[[:space:]]*//')
  # Drop leading "M### —" / "M### -" / "M### " (em-dash, hyphen, or whitespace).
  _t=$(printf '%s' "$_t" | sed -E 's/^M[0-9]{3}[[:space:]]*[—-]?[[:space:]]*//')
  printf '%s' "$_t"
}

# title_from_summary <MID> — scan milestone-summary.md for the milestone's
# rollup heading. Tries (in order):
#   1. `**MID — Title**`   (current/post-2026-04 format)
#   2. `**MID Title**`     (bare-bold, no dash — M019 Tier 1/2/3 format)
#   3. `## MID Title`      (H2 form — M003/M015 standalone-cutover style)
# Returns the first matching title.
title_from_summary() {
  _mid="$1"
  [ -f "$SUM" ] || return 1
  # Pattern 1: `**MID — Title**`
  _line=$(grep -m 1 -E "\*\*${_mid}[[:space:]]*[—-][[:space:]]*[^*]+\*\*" "$SUM" 2>/dev/null)
  if [ -n "$_line" ]; then
    printf '%s' "$_line" | sed -E "s/.*\*\*${_mid}[[:space:]]*[—-][[:space:]]*([^*]+)\*\*.*/\1/" \
      | sed -E 's/[[:space:]]+$//'
    return 0
  fi
  # Pattern 2: `**MID Title**` (no dash). Capture the next 1-6 words inside the bold.
  _line=$(grep -m 1 -E "\*\*${_mid}[[:space:]]+[^—*-][^*]*\*\*" "$SUM" 2>/dev/null)
  if [ -n "$_line" ]; then
    printf '%s' "$_line" | sed -E "s/.*\*\*${_mid}[[:space:]]+([^*]+)\*\*.*/\1/" \
      | sed -E 's/[[:space:]]+$//'
    return 0
  fi
  # Pattern 3: `## MID Title` H2 form
  _line=$(grep -m 1 -E "^##[[:space:]]+${_mid}[[:space:]]+" "$SUM" 2>/dev/null)
  if [ -n "$_line" ]; then
    printf '%s' "$_line" | sed -E "s/^##[[:space:]]+${_mid}[[:space:]]+(.+)$/\1/" \
      | sed -E 's/[[:space:]]*\([0-9-]+\)[[:space:]]*$//' \
      | sed -E 's/[[:space:]]+$//'
    return 0
  fi
  return 1
}

# is_useless_title <title> — return 0 (yes, useless) for bare generic words like
# "Evaluation", "Summary", "Context", "Roadmap" — these come from generic
# fallback H1s like "# M002 Evaluation" and don't tell the reader anything.
# Empty string is also useless.
is_useless_title() {
  case "$1" in
    ""|Evaluation|Summary|Context|Roadmap|"Phase Plan"|Plan|Validation)
      return 0 ;;
  esac
  return 1
}

# title_from_proposal <MID> — read first H1 from any proposals/MID-*.md.
title_from_proposal() {
  _mid="$1"
  [ -d "$PROP_DIR" ] || return 1
  _f=$(ls "$PROP_DIR"/${_mid}-*.md 2>/dev/null | head -n 1)
  [ -n "$_f" ] && [ -f "$_f" ] || return 1
  _h=$(grep -m 1 '^# ' "$_f" 2>/dev/null | sed 's/^# //')
  [ -n "$_h" ] || return 1
  strip_title "$_h"
}

# title_from_milestone_artifact <MID> <basename-without-mid-prefix>
# Example: title_from_milestone_artifact M025 SUMMARY -> reads M025-SUMMARY.md
title_from_milestone_artifact() {
  _mid="$1"
  _kind="$2"
  _f="$MS_DIR/${_mid}/${_mid}-${_kind}.md"
  [ -f "$_f" ] || return 1
  _h=$(grep -m 1 '^# ' "$_f" 2>/dev/null | sed 's/^# //')
  [ -n "$_h" ] || return 1
  strip_title "$_h"
}

# resolve_one <MID> — try sources in priority order; print the resolved title
# or nothing. Skips "useless" generic titles (single words like "Evaluation"
# from generic H1 fallbacks) so the caller can render bare M### instead of a
# misleading label.
resolve_one() {
  _mid="$1"
  _t=$(title_from_summary "$_mid")
  if [ -n "$_t" ] && ! is_useless_title "$_t"; then printf '%s' "$_t"; return 0; fi
  _t=$(title_from_proposal "$_mid")
  if [ -n "$_t" ] && ! is_useless_title "$_t"; then printf '%s' "$_t"; return 0; fi
  _t=$(title_from_milestone_artifact "$_mid" SUMMARY)
  if [ -n "$_t" ] && ! is_useless_title "$_t"; then printf '%s' "$_t"; return 0; fi
  _t=$(title_from_milestone_artifact "$_mid" EVALUATION)
  if [ -n "$_t" ] && ! is_useless_title "$_t"; then printf '%s' "$_t"; return 0; fi
  _t=$(title_from_milestone_artifact "$_mid" CONTEXT)
  if [ -n "$_t" ] && ! is_useless_title "$_t"; then printf '%s' "$_t"; return 0; fi
  return 1
}

# ---- single-lookup short-circuit -------------------------------------------

if [ -n "$GET" ]; then
  _t=$(resolve_one "$GET")
  if [ -n "$_t" ]; then
    printf '%s\t%s\n' "$GET" "$_t"
    exit 0
  fi
  exit 1
fi

# ---- collect all M### IDs --------------------------------------------------

_idlist="/tmp/wiki-milestone-titles-ids-$$.list"
trap 'rm -f "$_idlist"' EXIT INT TERM
: > "$_idlist"

# IDs from milestone subdirectories
if [ -d "$MS_DIR" ]; then
  for _d in "$MS_DIR"/M*/; do
    [ -d "$_d" ] || continue
    _b=$(basename "$_d")
    case "$_b" in
      M[0-9][0-9][0-9]) printf '%s\n' "$_b" >> "$_idlist" ;;
    esac
  done
fi

# IDs from proposal filenames
if [ -d "$PROP_DIR" ]; then
  for _f in "$PROP_DIR"/M*-*.md; do
    [ -f "$_f" ] || continue
    _b=$(basename "$_f")
    case "$_b" in
      M[0-9][0-9][0-9]-*) printf '%s\n' "${_b%%-*}" >> "$_idlist" ;;
    esac
  done
fi

# IDs from milestone-summary.md `**MXXX` markers (covers IDs that have neither
# a milestone subdir nor a proposal file but are referenced in the rollup).
if [ -f "$SUM" ]; then
  grep -oE '\*\*M[0-9]{3}' "$SUM" 2>/dev/null | sed 's/^\*\*//' >> "$_idlist"
fi

# Dedup + sort
sort -u "$_idlist" > "${_idlist}.sorted"
mv "${_idlist}.sorted" "$_idlist"

# ---- emit lookup table -----------------------------------------------------

while IFS= read -r MID; do
  [ -n "$MID" ] || continue
  _t=$(resolve_one "$MID")
  if [ -n "$_t" ]; then
    printf '%s\t%s\n' "$MID" "$_t"
  fi
done < "$_idlist"

exit 0
