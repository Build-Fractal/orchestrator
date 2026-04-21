#!/usr/bin/env bash
# scripts/verify/m012-p01-nav-structure.sh — nav top-level + completeness.
#
# Checks:
#   1. wiki/mkdocs.yml has exactly one `nav:` at column 0.
#   2. Marker pair `# >>> M012-P01 nav ...` / `# <<< M012-P01 nav end`
#      both appear, once each.
#   3. Top-level nav labels appear in the fixed order:
#        Home, Constitution, Decisions, Knowledge, Milestone Summary,
#        Milestones, Archive (last two are optional iff the scanner has
#        no records for them).
#   4. For every scanner record, the corresponding <rel-path> appears at
#      least once in the marker-bounded nav block (completeness).
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
CONFIG="$ROOT/wiki/mkdocs.yml"
SCANNER="$ROOT/scripts/wiki/wiki-scan-sources.sh"

FAIL_COUNT=0
fail() {
  printf 'FAIL: m012-p01-nav-structure %s\n' "$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

if [ ! -f "$CONFIG" ]; then
  fail "wiki/mkdocs.yml not found"
  exit 1
fi

MARKER_START="# >>> M012-P01 nav"
MARKER_END="# <<< M012-P01 nav end"

# 1. Exactly one column-0 nav:.
NAV_HITS=$(grep -c '^nav:' "$CONFIG" 2>/dev/null)
[ -z "$NAV_HITS" ] && NAV_HITS=0
if [ "$NAV_HITS" -ne 1 ]; then
  fail "expected exactly one column-0 'nav:' line, found $NAV_HITS"
fi

# 2. Marker pair exists once.
START_HITS=$(grep -c -F "$MARKER_START" "$CONFIG" 2>/dev/null)
[ -z "$START_HITS" ] && START_HITS=0
END_HITS=$(grep -c -F "$MARKER_END" "$CONFIG" 2>/dev/null)
[ -z "$END_HITS" ] && END_HITS=0
if [ "$START_HITS" -ne 1 ]; then
  fail "start marker count != 1 (found $START_HITS): $MARKER_START"
fi
if [ "$END_HITS" -ne 1 ]; then
  fail "end marker count != 1 (found $END_HITS): $MARKER_END"
fi

# Extract marker-bounded block to a tmp file.
TMP_NAV="/tmp/m012-p01-nav-body-$$.yml"
TMP_LABELS="/tmp/m012-p01-nav-labels-$$.list"
TMP_SCAN="/tmp/m012-p01-nav-scan-$$.list"
trap 'rm -f "$TMP_NAV" "$TMP_LABELS" "$TMP_SCAN"' EXIT INT TERM

awk -v s="$MARKER_START" -v e="$MARKER_END" '
  BEGIN { state = "pre" }
  {
    if (state == "pre") {
      if (index($0, s) == 1) { state = "in" }
      next
    }
    if (state == "in") {
      if (index($0, e) == 1) { state = "post"; exit }
      print
    }
  }
' "$CONFIG" > "$TMP_NAV"

if [ ! -s "$TMP_NAV" ]; then
  fail "marker-bounded nav block is empty"
fi

# 3. Top-level labels in order. Only check presence + relative order among
# labels that actually appear. The required prefix (presence-required):
#   Home, Constitution, Decisions, Knowledge, Milestone Summary
# Optional (if scanner has records): Milestones, Archive
REQUIRED_LABELS="Home Constitution Decisions Knowledge"
OPTIONAL_LABELS="Milestone_Summary Milestones Archive"

# Build an ordered list of top-level labels found (indent exactly 2 spaces
# in the generator's emit_leaf/emit_group level-1 output -> "  - Label:").
grep -n '^  - [A-Z][A-Za-z ]*:' "$TMP_NAV" > "$TMP_LABELS" 2>/dev/null || true

# Enforce order for the required prefix. Parse labels in file order from
# the "<line-no>:  - <Label>:" entries. Walk the file line-by-line so that
# labels containing spaces (e.g. "Milestone Summary") stay intact.
pos_home=0
pos_const=0
pos_dec=0
pos_know=0
pos_msum=0
pos_miles=0
pos_arch=0

idx=0
while IFS= read -r l; do
  [ -n "$l" ] || continue
  # Strip "<line-no>:  - " prefix and ":" suffix (and anything after the colon).
  lab=$(printf '%s' "$l" | sed 's/^[0-9][0-9]*:  - //' | sed 's/:.*//')
  idx=$((idx + 1))
  case "$lab" in
    "Home") pos_home=$idx ;;
    "Constitution") pos_const=$idx ;;
    "Decisions") pos_dec=$idx ;;
    "Knowledge") pos_know=$idx ;;
    "Milestone Summary") pos_msum=$idx ;;
    "Milestones") pos_miles=$idx ;;
    "Archive") pos_arch=$idx ;;
  esac
done < "$TMP_LABELS"

# Required labels present.
if [ "$pos_home" -eq 0 ]; then fail "missing top-level label: Home"; fi
if [ "$pos_const" -eq 0 ]; then fail "missing top-level label: Constitution"; fi
if [ "$pos_dec" -eq 0 ]; then fail "missing top-level label: Decisions"; fi
if [ "$pos_know" -eq 0 ]; then fail "missing top-level label: Knowledge"; fi

# Required order: Home < Constitution < Decisions < Knowledge.
if [ "$pos_home" -gt 0 ] && [ "$pos_const" -gt 0 ] && [ "$pos_home" -ge "$pos_const" ]; then
  fail "Home must precede Constitution (positions: $pos_home vs $pos_const)"
fi
if [ "$pos_const" -gt 0 ] && [ "$pos_dec" -gt 0 ] && [ "$pos_const" -ge "$pos_dec" ]; then
  fail "Constitution must precede Decisions (positions: $pos_const vs $pos_dec)"
fi
if [ "$pos_dec" -gt 0 ] && [ "$pos_know" -gt 0 ] && [ "$pos_dec" -ge "$pos_know" ]; then
  fail "Decisions must precede Knowledge (positions: $pos_dec vs $pos_know)"
fi

# Optional: if Milestone Summary exists, it must come after Knowledge.
if [ "$pos_msum" -gt 0 ] && [ "$pos_know" -gt 0 ] && [ "$pos_msum" -le "$pos_know" ]; then
  fail "Milestone Summary must follow Knowledge (positions: $pos_msum vs $pos_know)"
fi

# Optional: if Milestones exists, it must come after Milestone Summary (or Knowledge if no msum).
if [ "$pos_miles" -gt 0 ]; then
  ref=$pos_msum
  [ "$ref" -eq 0 ] && ref=$pos_know
  if [ "$ref" -gt 0 ] && [ "$pos_miles" -le "$ref" ]; then
    fail "Milestones must follow Milestone Summary/Knowledge (positions: $pos_miles vs $ref)"
  fi
fi

# Optional: if Archive exists, it must come after Milestones.
if [ "$pos_arch" -gt 0 ]; then
  ref=$pos_miles
  [ "$ref" -eq 0 ] && ref=$pos_msum
  [ "$ref" -eq 0 ] && ref=$pos_know
  if [ "$ref" -gt 0 ] && [ "$pos_arch" -le "$ref" ]; then
    fail "Archive must follow Milestones (positions: $pos_arch vs $ref)"
  fi
fi

# 4. Completeness: every scanner record's rel-path appears somewhere in the
# nav block (at minimum the canonical path appears in some stub path).
if [ ! -f "$SCANNER" ]; then
  fail "scanner not found for completeness check"
else
  bash "$SCANNER" --root "$ROOT" > "$TMP_SCAN" 2>/dev/null || true
  missing=0
  sample=""
  # The nav references paths like "milestones/M###/..." and the scanner emits
  # relative paths under .orchestrator/. For milestone artifacts, the scanner
  # rel-path already begins with "milestones/" so a direct substring match
  # works; for top-level records the nav uses short fixed paths.
  while IFS='|' read -r CAT REL TITLE; do
    [ -n "$CAT" ] || continue
    case "$CAT" in
      top:constitution)      nav_path="constitution.md" ;;
      top:decisions)         nav_path="decisions.md" ;;
      top:knowledge)         nav_path="knowledge.md" ;;
      top:milestone-summary) nav_path="milestone-summary.md" ;;
      milestone:*)           nav_path="$REL" ;;
      archive:*)             nav_path="$REL" ;;
      *)                     nav_path="$REL" ;;
    esac
    if ! grep -qF "$nav_path" "$TMP_NAV"; then
      missing=$((missing + 1))
      if [ -z "$sample" ]; then
        sample="$nav_path"
      fi
    fi
  done < "$TMP_SCAN"
  if [ "$missing" -gt 0 ]; then
    fail "nav missing $missing scanner record(s); sample: $sample"
  fi
fi

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: m012-p01-nav-structure top-level order + completeness OK\n'
  exit 0
fi
exit 1
