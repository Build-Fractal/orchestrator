#!/usr/bin/env bash
# scripts/diagnostics/check-docs.sh — Documentation completeness check
#
# Verifies all 19 required documentation files exist:
#   14 reference docs, 4 user guides, 1 contributor guide.
# Reports DOCTOR:DOCS structured output for consumption by run-doctor.sh.
#
# Usage:
#   check-docs.sh [--root <project-root>]
#
# Options:
#   --root  Project root directory (default: PROJECT_ROOT env or two levels up)
#
# Bash 3.2 compatible.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    *) echo "check-docs.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

# --- Required documentation files (19 total) ---

# Reference docs (14)
DOCS="references/architecture.md
references/engine.md
references/events.md
references/errors.md
references/hooks.md
references/recipes.md
references/routing.md
references/file-formats.md
references/state-machine.md
references/verification-ladder.md
references/tier-definitions.md
references/installation.md
references/provider-convention.md
references/constitution-walkthrough.md
docs/getting-started.md
docs/recipe-authoring.md
docs/hook-development.md
docs/knowledge-management.md
scripts/AGENTS.md"

# --- Check each file ---
total=0
found=0
missing_list=""

for doc in $DOCS; do
  total=$((total + 1))
  if [ -f "$PROJECT_ROOT/$doc" ]; then
    found=$((found + 1))
  else
    missing_list="${missing_list}  MISSING: ${doc}
"
  fi
done

# --- Report ---
if [ "$found" -eq "$total" ]; then
  status="ok"
else
  status="missing"
fi

printf 'DOCTOR:DOCS status=%s found=%d total=%d\n' "$status" "$found" "$total"

if [ "$status" = "missing" ] && [ -n "$missing_list" ]; then
  printf '%s' "$missing_list"
fi

if [ "$status" = "missing" ]; then
  exit 1
fi
exit 0
