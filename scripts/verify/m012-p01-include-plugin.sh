#!/usr/bin/env bash
# scripts/verify/m012-p01-include-plugin.sh — every stub references an
# existing .orchestrator/**.md path via include-markdown.
#
# Checks:
#   1. wiki/mkdocs.yml has `include-markdown` listed under `plugins:`.
#   2. For every .md under wiki/docs/ that is NOT wiki/docs/index.md,
#      wiki/docs/README.md, or a section-index `index.md` (auto-generated),
#      the stub contains an `include-markdown "<path>"` directive, the
#      referenced path resolves against the stub's directory, and the
#      target file exists on disk.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
CONFIG="$ROOT/wiki/mkdocs.yml"
DOCS="$ROOT/wiki/docs"

FAIL_COUNT=0
fail() {
  printf 'FAIL: m012-p01-include-plugin %s\n' "$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

if [ ! -f "$CONFIG" ]; then
  fail "wiki/mkdocs.yml not found"
  exit 1
fi
if [ ! -d "$DOCS" ]; then
  fail "wiki/docs not found"
  exit 1
fi

# 1. plugins: must include include-markdown.
if ! grep -q 'include-markdown' "$CONFIG"; then
  fail "wiki/mkdocs.yml does not list include-markdown plugin"
fi

# 2. Walk stubs.
TMP_STUBS="/tmp/m012-p01-include-stubs-$$.list"
trap 'rm -f "$TMP_STUBS"' EXIT INT TERM
find "$DOCS" -type f -name '*.md' 2>/dev/null | sort > "$TMP_STUBS"

STUB_COUNT=0
RESOLVED_COUNT=0

while IFS= read -r stub; do
  [ -n "$stub" ] || continue
  rel_from_docs=${stub#"$DOCS/"}
  base=$(basename "$stub")

  # Skip: site root index, authoring README.
  if [ "$rel_from_docs" = "index.md" ]; then
    continue
  fi
  if [ "$rel_from_docs" = "README.md" ]; then
    continue
  fi

  # Skip section-index files (auto-generated). Detect by basename == index.md
  # AND the file contains the comment "Auto-generated section index".
  if [ "$base" = "index.md" ]; then
    if grep -q 'Auto-generated section index' "$stub" 2>/dev/null; then
      continue
    fi
  fi

  STUB_COUNT=$((STUB_COUNT + 1))

  # Extract include-markdown path(s). Matches:
  #   include-markdown "some/path.md"
  # grep -o captures only the string literal.
  INCLUDE_PATH=$(grep -o 'include-markdown "[^"]*"' "$stub" 2>/dev/null | head -n 1 | sed 's/^include-markdown "//; s/"$//')
  if [ -z "$INCLUDE_PATH" ]; then
    fail "stub has no include-markdown directive: $rel_from_docs"
    continue
  fi

  # Resolve against the stub's directory.
  stub_dir=$(dirname "$stub")
  resolved="$stub_dir/$INCLUDE_PATH"
  # Normalize .. segments with a deterministic canonical path.
  # Use cd/pwd for canonicalization.
  resolved_dir=$(cd "$(dirname "$resolved")" 2>/dev/null && pwd || true)
  if [ -z "$resolved_dir" ]; then
    fail "unresolvable include path from $rel_from_docs: $INCLUDE_PATH"
    continue
  fi
  resolved_file="$resolved_dir/$(basename "$resolved")"

  if [ ! -f "$resolved_file" ]; then
    fail "include target missing for $rel_from_docs -> $INCLUDE_PATH (resolved: $resolved_file)"
    continue
  fi

  # The canonical target must live under either .orchestrator/ (the default
  # SSOT source established in P01) or knowledge/ (the repo-root MEM entry
  # source added in M012/P02/T02 for knowledge:<category> stubs — the MEM
  # files live at knowledge/<cat>/MEM###.md, not under .orchestrator/).
  case "$resolved_file" in
    "$ROOT"/.orchestrator/*) : ;;
    "$ROOT"/knowledge/*)     : ;;
    *)
      fail "include target outside .orchestrator/ or knowledge/ for $rel_from_docs: $resolved_file"
      continue
      ;;
  esac

  RESOLVED_COUNT=$((RESOLVED_COUNT + 1))
done < "$TMP_STUBS"

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: m012-p01-include-plugin %s/%s stubs resolve to .orchestrator/ artifacts\n' \
    "$RESOLVED_COUNT" "$STUB_COUNT"
  exit 0
fi
exit 1
