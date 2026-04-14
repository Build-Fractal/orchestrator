#!/usr/bin/env bash
# scripts/diagnostics/check-events.sh — Event emission conformance check
#
# Scans engine-path scripts for emit_event calls per Constitution Principle II.
# Reports DOCTOR:EVENTS structured output for consumption by run-doctor.sh.
#
# Usage:
#   check-events.sh [--root <project-root>]
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
    *) echo "check-events.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

# --- Engine-path directories (excludes scripts/lib/) ---
ENGINE_DIRS="scripts/state scripts/dispatch scripts/lifecycle scripts/knowledge scripts/telemetry"

# --- Collect engine-path scripts ---
total=0
compliant=0
missing_list=""

for dir in $ENGINE_DIRS; do
  full_dir="$PROJECT_ROOT/$dir"
  [ -d "$full_dir" ] || continue
  for f in "$full_dir"/*.sh; do
    [ -f "$f" ] || continue
    total=$((total + 1))
    if grep -q 'emit_event' "$f"; then
      compliant=$((compliant + 1))
    else
      rel_path="${f#"$PROJECT_ROOT"/}"
      missing_list="${missing_list}  MISSING: ${rel_path}
"
    fi
  done
done

# --- Report ---
if [ "$total" -eq 0 ]; then
  printf 'DOCTOR:EVENTS status=ok compliant=0 total=0\n'
  exit 0
fi

if [ "$compliant" -eq "$total" ]; then
  status="ok"
else
  status="warn"
fi

printf 'DOCTOR:EVENTS status=%s compliant=%d total=%d\n' "$status" "$compliant" "$total"

if [ "$status" = "warn" ] && [ -n "$missing_list" ]; then
  printf '%s' "$missing_list"
fi

if [ "$status" = "warn" ]; then
  exit 1
fi
exit 0
