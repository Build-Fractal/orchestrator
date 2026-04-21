#!/usr/bin/env bash
# scripts/verify/m012-p04-wiki-removable.sh — M012/P04 SC-10 gate (deploy surface slice).
#
# Asserts that no repo file OUTSIDE the allowed tree sources, imports,
# or bash-invokes scripts/wiki/wiki-deploy.sh. Mirrors the P03
# self-contained invariant for the P04 deploy wrapper.
#
# Allowed tree:
#   wiki/**
#   scripts/wiki/**
#   scripts/diagnostics/wiki-*.sh
#   scripts/verify/m012-p0[1-4]-*.sh
#   .orchestrator/milestones/M012/**
#   .orchestrator/archive/**
#   .orchestrator/KNOWLEDGE.md / .orchestrator/DECISIONS.md / .orchestrator/knowledge/**
#   .orchestrator/memory/**
#   .orchestrator/milestone-summary.md
#   KNOWLEDGE-INDEX.md / CHANGELOG.md
#   tests/fixtures/**
#
# Read-only scan. Writes only to /tmp. Bash 3.2 compliant.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ROOT="${1:-$DEFAULT_ROOT}"

SCAN_TMP="/tmp/m012-p04-rem-scan.$$.tmp"
# shellcheck disable=SC2064
trap "rm -f '$SCAN_TMP'" EXIT INT TERM

cd "$ROOT" || {
  printf 'FAIL: cannot cd %s\n' "$ROOT" >&2
  exit 1
}

# Search for the literal wrapper basename across likely host extensions.
grep -rln 'wiki-deploy\.sh' . \
  --include='*.sh' \
  --include='*.md' \
  --include='*.yml' \
  --include='*.yaml' \
  --include='*.json' \
  --include='*.txt' \
  2>/dev/null > "$SCAN_TMP" || true

bad=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in
    ./*) f="${f#./}" ;;
  esac
  case "$f" in
    wiki/*) continue ;;
    scripts/wiki/*) continue ;;
    scripts/diagnostics/wiki-*) continue ;;
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
    CLAUDE.md) continue ;;
    tests/fixtures/*) continue ;;
  esac
  printf 'FAIL: unexpected reference to wiki-deploy.sh in %s\n' "$f" >&2
  bad=$((bad + 1))
done < "$SCAN_TMP"

if [ "$bad" -gt 0 ]; then
  printf 'FAIL: %d unexpected wiki-deploy.sh references outside allowed tree\n' "$bad" >&2
  exit 1
fi

printf 'PASS: wiki-deploy.sh surface contained in allowed tree\n'
exit 0
