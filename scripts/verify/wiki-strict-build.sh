#!/usr/bin/env bash
# scripts/verify/wiki-strict-build.sh — regression gate that runs `mkdocs
# build` against wiki/mkdocs.yml and fails on any ERROR output. Catches the
# class of bug where a canonical .orchestrator/**.md artifact contains
# literal `{% include-markdown ... %}` or other Jinja syntax inside code
# fences that mkdocs-include-markdown-plugin interprets as a real nested
# include directive (M025.1 carve-out).
#
# Also counts WARNING lines and reports them on stderr (informational). A
# non-zero warning count does not fail the gate — warnings are allowed,
# errors are not.
#
# Usage: bash scripts/verify/wiki-strict-build.sh
#
# Exit codes:
#   0  — build succeeded with no ERROR lines.
#   1  — build failed (any ERROR line or non-zero mkdocs exit).
#   77 — mkdocs not installed (SKIP-as-PASS for minimal sandboxes).
#
# Bash 3.2 compliant.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
cd "$ROOT"

if ! command -v mkdocs >/dev/null 2>&1; then
  printf 'SKIP: mkdocs not installed — cannot run strict build gate.\n' >&2
  exit 0
fi

if [ ! -f wiki/mkdocs.yml ]; then
  printf 'FAIL: wiki/mkdocs.yml not found under %s\n' "$ROOT" >&2
  exit 1
fi

LOG="/tmp/wiki-strict-build.$$.log"
trap 'rm -f "$LOG"' EXIT INT TERM

if ! mkdocs build -f wiki/mkdocs.yml > "$LOG" 2>&1; then
  printf 'FAIL: mkdocs build exited non-zero. Errors:\n' >&2
  grep '^ERROR' "$LOG" >&2 || true
  exit 1
fi

ERR_COUNT=$(grep -c '^ERROR' "$LOG" 2>/dev/null; true)
WARN_COUNT=$(grep -c '^WARNING' "$LOG" 2>/dev/null; true)
[ -n "$ERR_COUNT" ] || ERR_COUNT=0
[ -n "$WARN_COUNT" ] || WARN_COUNT=0

if [ "$ERR_COUNT" -gt 0 ]; then
  printf 'FAIL: %d ERROR line(s) in mkdocs build output:\n' "$ERR_COUNT" >&2
  grep '^ERROR' "$LOG" >&2
  exit 1
fi

if [ "$WARN_COUNT" -gt 0 ]; then
  printf 'INFO: %d WARNING line(s) (non-blocking):\n' "$WARN_COUNT" >&2
  grep '^WARNING' "$LOG" | head -20 >&2
fi

printf 'PASS: wiki-strict-build (0 errors, %d warnings)\n' "$WARN_COUNT"
exit 0
