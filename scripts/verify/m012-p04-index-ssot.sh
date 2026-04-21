#!/usr/bin/env bash
# scripts/verify/m012-p04-index-ssot.sh — M012/P04 T01 SSOT guard.
#
# Asserts wiki/docs/index.md contains zero paragraph-length blocks
# (>= 40 contiguous non-blank characters) that appear verbatim in any
# canonical .orchestrator/**.md artifact. Prevents home-page body-copy
# creep (AD-3 SSOT / Constitution VI).
#
# Exclusions: task plans and task payloads that themselves quote the
# home-page prose as the task specification are skipped — they are the
# spec for this task, not a canonical upstream artifact. The canonical
# upstreams are the constitution, decisions, knowledge MEM entries,
# milestone summaries, and milestone/phase plans.
#
# MEM004 carve-out: internal pipes / find / grep -F permitted inside
# this script. Single-script-file shape honored at the Check layer.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ROOT="${1:-$DEFAULT_ROOT}"

IDX="$ROOT/wiki/docs/index.md"
if [ ! -f "$IDX" ]; then
  printf 'FAIL: %s not found\n' "$IDX" >&2
  exit 1
fi

# Extract candidate paragraph lines from the home page (>=40 chars,
# non-heading, non-blank). These are the strings we forbid from
# appearing verbatim in canonical upstream artifacts.
SCRATCH="/tmp/m012-p04-index-ssot-$$.txt"
CANDIDATES="/tmp/m012-p04-index-ssot-cands-$$.txt"
# shellcheck disable=SC2064
trap "rm -f '$SCRATCH' '$CANDIDATES'" EXIT INT TERM

# Strip headings, blank lines, comment lines; keep only prose lines
# whose length is >= 40 chars. grep -v headings (^#), blanks, HTML
# comments; awk length filter.
grep -v '^#' "$IDX" \
  | grep -v '^[[:space:]]*$' \
  | grep -v '^[[:space:]]*<!--' \
  | awk 'length >= 40' \
  > "$CANDIDATES"

# Scan .orchestrator/**.md for verbatim matches of any candidate line,
# excluding this task's own PLAN/PAYLOAD files (they quote the home
# page prose as the task specification, not as canonical artifact body).
HITS=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  # grep -rF excludes binary and treats quotes literally; exclude
  # task-plan/payload quote-files from the scan.
  grep -rlF \
    --include='*.md' \
    --exclude='T*-PLAN.md' \
    --exclude='T*-PAYLOAD.md' \
    -- "$line" "$ROOT/.orchestrator" 2>/dev/null > "$SCRATCH" || true
  if [ -s "$SCRATCH" ]; then
    printf 'SSOT FAIL: verbatim match for paragraph in .orchestrator/:\n' >&2
    printf '  line: %s\n' "$line" >&2
    printf '  matches:\n' >&2
    sed 's/^/    /' "$SCRATCH" >&2
    HITS=$((HITS + 1))
  fi
done < "$CANDIDATES"

if [ "$HITS" -gt 0 ]; then
  printf 'FAIL: %d home-page paragraph(s) duplicate .orchestrator/ body text\n' "$HITS" >&2
  exit 1
fi

CAND_COUNT=$(wc -l < "$CANDIDATES" | tr -d '[:space:]')
[ -z "$CAND_COUNT" ] && CAND_COUNT=0
printf 'PASS: index SSOT clean (%s paragraph(s) scanned, zero body-copy from canonical .orchestrator/ artifacts)\n' "$CAND_COUNT"
exit 0
