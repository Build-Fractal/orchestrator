#!/usr/bin/env bash
# scripts/verify/m012-p03-wiki-removable.sh — M012/P03 SC-10 gate (Giscus surface slice).
#
# Asserts that no repo file OUTSIDE the allowed tree sources, imports,
# or bash-invokes any wiki-giscus-* script. Mirrors the P01
# self-contained invariant for the P03 surface.
#
# Allowed tree:
#   wiki/**
#   scripts/wiki/**
#   scripts/diagnostics/wiki-giscus-*.sh
#   scripts/verify/m012-p03-*.sh
#   .orchestrator/milestones/M012/**
#
# Read-only scan. Writes only to /tmp. Bash 3.2 compliant.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ROOT="${1:-$DEFAULT_ROOT}"

SCAN_TMP="/tmp/m012-p03-rem-scan.$$.tmp"
# shellcheck disable=SC2064
trap "rm -f '$SCAN_TMP'" EXIT INT TERM

cd "$ROOT" || {
  printf 'FAIL: cannot cd %s\n' "$ROOT" >&2
  exit 1
}

# BRE pattern (default grep) matches wiki-giscus-(config-check|smoke|remap).sh
grep -rln 'wiki-giscus-\(config-check\|smoke\|remap\)\.sh' . \
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
    ./wiki/*) ;;
    ./scripts/wiki/*) ;;
    ./scripts/diagnostics/wiki-giscus-*) ;;
    ./scripts/verify/m012-p03-*) ;;
    ./scripts/verify/m012-p04-*) ;;
    ./.orchestrator/milestones/M012/*) ;;
    *)
      printf 'FAIL: unexpected import of wiki-giscus script from %s\n' "$f" >&2
      bad=$((bad + 1))
      ;;
  esac
done < "$SCAN_TMP"

if [ "$bad" -gt 0 ]; then
  printf 'FAIL: %d unexpected wiki-giscus references outside allowed tree\n' "$bad" >&2
  exit 1
fi

printf 'PASS: wiki-giscus surface contained in allowed tree\n'
exit 0
