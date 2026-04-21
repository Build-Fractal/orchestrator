#!/usr/bin/env bash
# scripts/verify/m012-p01-exclusion-policy.sh — scanner emits no excluded paths.
#
# Runs scripts/wiki/wiki-scan-sources.sh and asserts:
#   - Zero lines contain `.orchestrator/scratch/`.
#   - Zero lines contain `.orchestrator/tmp/`.
#   - Zero lines contain `.orchestrator/config/`.
#   - Every <rel-path> ends in `.md`.
#   - No <rel-path> contains `PLANNING-PAYLOAD` or `VERIFICATION`.
#   - Every <rel-path> is under .orchestrator/ (i.e. starts without a leading
#     `/` and resolves under .orchestrator/... by construction — the scanner
#     emits paths relative to .orchestrator/, so we check they do not begin
#     with `/`, `..`, or whitespace).
#
# Also walks wiki/docs/**.md stubs and asserts none reference an excluded path
# through include-markdown directives.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
SCANNER="$ROOT/scripts/wiki/wiki-scan-sources.sh"
DOCS="$ROOT/wiki/docs"

FAIL_COUNT=0
fail() {
  printf 'FAIL: m012-p01-exclusion-policy %s\n' "$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

if [ ! -x "$SCANNER" ] && [ ! -f "$SCANNER" ]; then
  fail "scanner not found: scripts/wiki/wiki-scan-sources.sh"
  exit 1
fi

TMP_SCAN="/tmp/m012-p01-excl-scan-$$.list"
trap 'rm -f "$TMP_SCAN"' EXIT INT TERM

bash "$SCANNER" --root "$ROOT" > "$TMP_SCAN" 2>/dev/null || {
  fail "scanner exited non-zero"
}

# Walk scanner records.
LINE_COUNT=0
while IFS='|' read -r CAT REL TITLE; do
  [ -n "$CAT" ] || continue
  LINE_COUNT=$((LINE_COUNT + 1))

  # Excluded trees.
  case "$REL" in
    scratch/*|tmp/*|config/*)
      fail "excluded path emitted by scanner: $REL (category=$CAT)"
      continue
      ;;
    */scratch/*|*/tmp/*|*/config/*)
      # These subpaths inside milestone trees are allowed (e.g.
      # milestones/M###/scratch/ would be suspicious but the exclusion policy
      # is specifically about top-level .orchestrator/{scratch,tmp,config}/).
      :
      ;;
  esac

  # Full-string exclusion guards (belt-and-suspenders).
  case "$REL" in
    *.orchestrator/scratch/*|*.orchestrator/tmp/*|*.orchestrator/config/*)
      fail "excluded path emitted by scanner: $REL"
      continue
      ;;
  esac

  # Must end in .md.
  case "$REL" in
    *.md) : ;;
    *)
      fail "non-.md path emitted by scanner: $REL"
      continue
      ;;
  esac

  # PLANNING-PAYLOAD and VERIFICATION basenames excluded.
  case "$REL" in
    *PLANNING-PAYLOAD*)
      fail "PLANNING-PAYLOAD path emitted by scanner: $REL"
      continue
      ;;
    *VERIFICATION*)
      fail "VERIFICATION path emitted by scanner: $REL"
      continue
      ;;
  esac

  # Must not begin with / or ..
  case "$REL" in
    /*|..*)
      fail "absolute or parent-relative path emitted by scanner: $REL"
      continue
      ;;
  esac
done < "$TMP_SCAN"

# Check stubs do not reference excluded paths via include-markdown.
if [ -d "$DOCS" ]; then
  TMP_STUBS="/tmp/m012-p01-excl-stubs-$$.list"
  TMP_PATHS="/tmp/m012-p01-excl-paths-$$.list"
  find "$DOCS" -type f -name '*.md' 2>/dev/null | sort > "$TMP_STUBS"
  while IFS= read -r stub; do
    [ -n "$stub" ] || continue
    # Find any include-markdown path that matches excluded trees.
    grep -o 'include-markdown "[^"]*"' "$stub" 2>/dev/null \
      | sed 's/^include-markdown "//; s/"$//' > "$TMP_PATHS"
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      case "$path" in
        *.orchestrator/scratch/*|*.orchestrator/tmp/*|*.orchestrator/config/*)
          rel_stub=${stub#"$DOCS/"}
          fail "stub includes excluded path: $rel_stub -> $path"
          ;;
        *PLANNING-PAYLOAD*|*VERIFICATION*)
          rel_stub=${stub#"$DOCS/"}
          fail "stub includes excluded basename: $rel_stub -> $path"
          ;;
      esac
    done < "$TMP_PATHS"
  done < "$TMP_STUBS"
  rm -f "$TMP_STUBS" "$TMP_PATHS"
fi

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: m012-p01-exclusion-policy %s scanner records all in-scope\n' "$LINE_COUNT"
  exit 0
fi
exit 1
