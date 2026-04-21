#!/usr/bin/env bash
# scripts/verify/m012-p01-wiki-self-contained.sh — M012/P01 SC-10 gate.
#
# Asserts wiki/ and scripts/wiki/ are the only places M012 P01 code lives,
# so removing those trees does not break the orchestrator itself.
#
# Check list:
#   1. wiki/ exists and contains mkdocs.yml, requirements.txt, docs/.
#   2. scripts/wiki/ exists and contains wiki-scan-sources.sh,
#      wiki-generate-stubs.sh, wiki-generate-nav.sh, wiki-serve.sh.
#   3. No file outside wiki/, scripts/wiki/, scripts/verify/m012-p01-*.sh,
#      and .orchestrator/milestones/M012/ references scripts/wiki/.
#
# Bash 3.2 compatible. Single-script-file shape.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

FAIL_COUNT=0

fail() {
  printf 'FAIL: m012-p01-wiki-self-contained %s\n' "$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

# 1. wiki/ exists and key files present.
if [ ! -d "$ROOT/wiki" ]; then
  fail "missing directory: wiki/"
fi
for rel in "wiki/mkdocs.yml" "wiki/requirements.txt" "wiki/docs"; do
  if [ ! -e "$ROOT/$rel" ]; then
    fail "missing: $rel"
  fi
done

# 2. scripts/wiki/ exists and key scripts present.
if [ ! -d "$ROOT/scripts/wiki" ]; then
  fail "missing directory: scripts/wiki/"
fi
for rel in "scripts/wiki/wiki-scan-sources.sh" \
           "scripts/wiki/wiki-generate-stubs.sh" \
           "scripts/wiki/wiki-generate-nav.sh" \
           "scripts/wiki/wiki-serve.sh"; do
  if [ ! -f "$ROOT/$rel" ]; then
    fail "missing: $rel"
  fi
done

# 3. No file outside the allowed containment areas references scripts/wiki/.
# Allowed locations that may reference scripts/wiki/:
#   - wiki/**
#   - scripts/wiki/**
#   - scripts/verify/m012-p0[1-4]-*.sh
#   - .orchestrator/milestones/M012/**
#   - .orchestrator/archive/** (historical handoff notes)
#   - .orchestrator/KNOWLEDGE.md and knowledge/** (post-consolidation notes)
#
# Search repo for the literal string 'scripts/wiki/'. Any hit outside the
# allowed containment areas is a failure.
TMP_HITS="/tmp/m012-p01-self-contained-hits-$$.list"
trap 'rm -f "$TMP_HITS"' EXIT INT TERM

# Use grep -rlI to find files containing the string. Exclude .git, site/,
# node_modules, and the known allowed paths via a post-filter.
(
  cd "$ROOT" && grep -rlI \
    --exclude-dir=.git \
    --exclude-dir=site \
    --exclude-dir=node_modules \
    --exclude-dir=.venv \
    --exclude-dir=venv \
    'scripts/wiki/' . 2>/dev/null
) > "$TMP_HITS" || true

VIOLATIONS=0
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  # Normalize leading ./
  case "$hit" in
    ./*) hit="${hit#./}" ;;
  esac
  # Allowed containment areas.
  case "$hit" in
    wiki/*) continue ;;
    scripts/wiki/*) continue ;;
    scripts/verify/m012-p01-*.sh) continue ;;
    scripts/verify/m012-p02-*.sh) continue ;;
    scripts/verify/m012-p03-*.sh) continue ;;
    scripts/verify/m012-p04-*.sh) continue ;;
    .orchestrator/milestones/M012/*) continue ;;
    .orchestrator/archive/*) continue ;;
    .orchestrator/KNOWLEDGE.md) continue ;;
    .orchestrator/DECISIONS.md) continue ;;
    .orchestrator/knowledge/*) continue ;;
    .orchestrator/memory/*) continue ;;
    .orchestrator/milestone-summary.md) continue ;;
    KNOWLEDGE-INDEX.md) continue ;;
    CHANGELOG.md) continue ;;
    tests/fixtures/*) continue ;;
  esac
  fail "stray reference to scripts/wiki/ in: $hit"
  VIOLATIONS=$((VIOLATIONS + 1))
done < "$TMP_HITS"

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: m012-p01-wiki-self-contained wiki/ + scripts/wiki/ self-contained\n'
  exit 0
fi
exit 1
