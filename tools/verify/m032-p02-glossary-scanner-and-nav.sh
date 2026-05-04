#!/usr/bin/env bash
# tools/verify/m032-p02-glossary-scanner-and-nav.sh
#
# M032/P02/T03 verifier: asserts the FR-15 scanner + nav-generator surface.
#
# Checks:
#   (a) `wiki-scan-sources.sh --root . --include-glossary`     emits a record
#       containing wiki/glossary.md.
#   (b) `wiki-scan-sources.sh --root . --no-include-glossary`  does NOT emit
#       a record containing wiki/glossary.md.
#   (c) `wiki-generate-nav.sh --root .` regenerates wiki/mkdocs.yml such that
#       under the `# >>> M012-P01 nav` marker the entry immediately following
#       the Constitution top-level leaf is the Glossary top-level leaf, and
#       Glossary is followed by some other top-level entry (i.e., Glossary is
#       sandwiched between Constitution and "everything else" per the FR-15
#       contract). The marker shape itself is preserved (no auto/custom split).
#
# Side-effect-free: backs up wiki/mkdocs.yml before regeneration and restores
# it from backup at the end. The orchestrator's resting-state mkdocs.yml is
# whatever the operator committed; this verifier must not mutate that.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.
# Exit 0 on PASS; 1 on FAIL.

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

SCANNER="$ROOT/scripts/wiki/wiki-scan-sources.sh"
NAVGEN="$ROOT/scripts/wiki/wiki-generate-nav.sh"
CONFIG="$ROOT/wiki/mkdocs.yml"

if [ ! -x "$SCANNER" ]; then
  echo "FAIL: $SCANNER not executable"
  exit 1
fi
if [ ! -x "$NAVGEN" ]; then
  echo "FAIL: $NAVGEN not executable"
  exit 1
fi
if [ ! -f "$CONFIG" ]; then
  echo "FAIL: $CONFIG missing"
  exit 1
fi

TMP=$(mktemp -d)
BACKUP="$TMP/mkdocs.yml.bak"
SOURCES_ON="$TMP/sources-on.txt"
SOURCES_OFF="$TMP/sources-off.txt"

# Restore mkdocs.yml from backup on any exit so the verifier is side-effect-free
# against the committed working tree.
restore_and_clean() {
  if [ -f "$BACKUP" ]; then
    cp "$BACKUP" "$CONFIG" 2>/dev/null || :
  fi
  rm -rf "$TMP"
}
trap restore_and_clean EXIT INT TERM

# (a) include-glossary on (explicit flag)
if ! bash "$SCANNER" --root "$ROOT" --include-glossary > "$SOURCES_ON" 2>/dev/null; then
  echo "FAIL: scanner --include-glossary returned non-zero"
  exit 1
fi
if ! grep -q '^top:glossary|wiki/glossary.md|' "$SOURCES_ON"; then
  if ! grep -q 'wiki/glossary.md' "$SOURCES_ON"; then
    echo "FAIL: --include-glossary did not emit wiki/glossary.md"
    exit 1
  fi
fi

# (b) include-glossary off
if ! bash "$SCANNER" --root "$ROOT" --no-include-glossary > "$SOURCES_OFF" 2>/dev/null; then
  echo "FAIL: scanner --no-include-glossary returned non-zero"
  exit 1
fi
if grep -q 'wiki/glossary.md' "$SOURCES_OFF"; then
  echo "FAIL: --no-include-glossary still emitted wiki/glossary.md"
  exit 1
fi

# (c) nav generator placement.
cp "$CONFIG" "$BACKUP"

if ! bash "$NAVGEN" --root "$ROOT" >/dev/null 2>&1; then
  echo "FAIL: wiki-generate-nav.sh returned non-zero"
  exit 1
fi

# Locate the marker line.
MARKER_LINE=$(grep -n '^# >>> M012-P01 nav' "$CONFIG" | head -1 | cut -d: -f1)
if [ -z "$MARKER_LINE" ]; then
  echo "FAIL: '# >>> M012-P01 nav' marker not found in regenerated $CONFIG"
  exit 1
fi

# Extract the ordered list of top-level nav entries (lines starting with `^  - `
# under the marker, in document order). Stop at the marker-end sentinel.
ENTRIES_FILE="$TMP/entries.txt"
awk -v start="$MARKER_LINE" '
  NR > start {
    if ($0 ~ /^# <<< M012-P01 nav end/) { exit }
    if ($0 ~ /^  - /) { print NR ":" $0 }
  }
' "$CONFIG" > "$ENTRIES_FILE"

if [ ! -s "$ENTRIES_FILE" ]; then
  echo "FAIL: no top-level nav entries found under marker"
  exit 1
fi

# Find the line carrying Constitution; assert the next top-level entry is
# Glossary.
CONST_IDX=$(awk -F: '/Constitution/ { print NR; exit }' "$ENTRIES_FILE")
if [ -z "$CONST_IDX" ]; then
  echo "FAIL: Constitution top-level nav entry not found under marker"
  exit 1
fi

NEXT_IDX=$((CONST_IDX + 1))
NEXT_LINE=$(awk -v n="$NEXT_IDX" 'NR == n { print; exit }' "$ENTRIES_FILE")
if [ -z "$NEXT_LINE" ]; then
  echo "FAIL: no top-level nav entry follows Constitution under marker"
  exit 1
fi

if ! printf '%s' "$NEXT_LINE" | grep -q 'Glossary'; then
  echo "FAIL: entry following Constitution is not Glossary; got: $NEXT_LINE"
  exit 1
fi

# Assert there is at least one further top-level entry after Glossary
# (sandwich-between-Constitution-and-everything-else contract).
TAIL_IDX=$((NEXT_IDX + 1))
TAIL_LINE=$(awk -v n="$TAIL_IDX" 'NR == n { print; exit }' "$ENTRIES_FILE")
if [ -z "$TAIL_LINE" ]; then
  echo "FAIL: Glossary is the last top-level entry; expected at least one further entry (Decisions/Knowledge/etc)"
  exit 1
fi

echo "PASS: m032-p02-glossary-scanner-and-nav"
exit 0
