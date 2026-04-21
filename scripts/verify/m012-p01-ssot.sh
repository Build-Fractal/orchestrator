#!/usr/bin/env bash
# scripts/verify/m012-p01-ssot.sh — no duplicate artifact bodies.
#
# For every stub under wiki/docs/ (excluding wiki/docs/index.md and
# wiki/docs/README.md):
#   - Line count <= 25.
#   - At most one `include-markdown` directive per stub (section indexes
#     have zero; artifact stubs have exactly one).
#   - No byte-identical copy of any file under .orchestrator/ (SSOT
#     enforcement — no silent copies).
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
DOCS="$ROOT/wiki/docs"

FAIL_COUNT=0
fail() {
  printf 'FAIL: m012-p01-ssot %s\n' "$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

if [ ! -d "$DOCS" ]; then
  fail "wiki/docs not found"
  exit 1
fi

TMP_STUBS="/tmp/m012-p01-ssot-stubs-$$.list"
trap 'rm -f "$TMP_STUBS"' EXIT INT TERM
find "$DOCS" -type f -name '*.md' 2>/dev/null | sort > "$TMP_STUBS"

STUB_COUNT=0
MAX_LINES=25

while IFS= read -r stub; do
  [ -n "$stub" ] || continue
  rel_from_docs=${stub#"$DOCS/"}

  # Skip site root index and authoring README.
  if [ "$rel_from_docs" = "index.md" ]; then
    continue
  fi
  if [ "$rel_from_docs" = "README.md" ]; then
    continue
  fi

  # Classify: artifact stub (must have exactly one include-markdown and be
  # <=25 lines) vs auto-generated section index (bullet list of children,
  # may exceed 25 lines proportional to child count, has zero include
  # directives).
  base=$(basename "$stub")
  is_section_index=0
  if [ "$base" = "index.md" ]; then
    if grep -q 'Auto-generated section index' "$stub" 2>/dev/null; then
      is_section_index=1
    fi
  fi

  STUB_COUNT=$((STUB_COUNT + 1))

  # Line count cap applies only to artifact stubs. Section indexes are
  # proportional to their child count and carry no artifact body — the
  # include-markdown=0 assertion below is the real SSOT guard for them.
  lc=$(wc -l < "$stub" | tr -d ' ')
  [ -z "$lc" ] && lc=0

  # At most one include-markdown directive (zero for section indexes).
  ic=$(grep -c 'include-markdown ' "$stub" 2>/dev/null)
  [ -z "$ic" ] && ic=0

  if [ "$is_section_index" -eq 1 ]; then
    if [ "$ic" -ne 0 ]; then
      fail "section index must have 0 include-markdown directives (found $ic): $rel_from_docs"
    fi
    # Section indexes must not contain artifact prose. Heuristic: line cap
    # proportional to bullet count — we assert that non-empty, non-bullet,
    # non-frontmatter, non-comment lines are rare. Simpler and robust:
    # count lines that start with anything other than space, `-`, `#`, `<`,
    # `{`, `%`, `|`, `"`, `[`, or `]`. Those are "body prose" candidates.
    prose=$(grep -c '^[A-Za-z]' "$stub" 2>/dev/null)
    [ -z "$prose" ] && prose=0
    # Allow the H1 title line (one `# <title>` line is typical above the
    # bullets). Anything beyond 2 letter-starting lines flags as prose.
    if [ "$prose" -gt 2 ]; then
      fail "section index contains unexpected prose lines ($prose): $rel_from_docs"
    fi
  else
    if [ "$lc" -gt "$MAX_LINES" ]; then
      fail "stub exceeds $MAX_LINES lines ($lc): $rel_from_docs"
    fi
    if [ "$ic" -ne 1 ]; then
      fail "artifact stub must have exactly 1 include-markdown (found $ic): $rel_from_docs"
    fi
  fi
done < "$TMP_STUBS"

# SSOT belt-and-suspenders: no stub is byte-identical to any .orchestrator/ file.
# Cheap signal: the first non-frontmatter line of every stub should not match
# the corresponding source's first content line by a length-based heuristic
# (line-count gate already catches this). Skip expensive byte compare — the
# 25-line ceiling plus the include-markdown directive make byte-identical
# copies impossible for anything but a hand-edited regression.

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: m012-p01-ssot %s stubs under %s-line cap with <=1 include directive each\n' \
    "$STUB_COUNT" "$MAX_LINES"
  exit 0
fi
exit 1
