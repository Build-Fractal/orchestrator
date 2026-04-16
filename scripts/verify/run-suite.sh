#!/usr/bin/env bash
# scripts/verify/run-suite.sh — Run all gate scripts for a milestone+phase
# Usage: run-suite.sh <milestone> <phase>
#   e.g.: run-suite.sh m016 P01
#
# Discovers scripts/verify/<milestone>-<phase>-*.sh (case-insensitive milestone),
# executes each, prints per-script PASS/FAIL, and a summary line.
# Exit: 0 if all pass, 1 if any fail.
#
# Bash 3.2 compatible.

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: run-suite.sh <milestone> <phase>" >&2
  echo "  e.g.: run-suite.sh m016 P01" >&2
  exit 1
fi

MILESTONE="$1"
PHASE="$2"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Normalize: milestone lowercase, phase lowercase for glob
milestone_lower=$(echo "$MILESTONE" | tr '[:upper:]' '[:lower:]')
phase_lower=$(echo "$PHASE" | tr '[:upper:]' '[:lower:]')

# Discover gate scripts
pattern="${SCRIPT_DIR}/${milestone_lower}-${phase_lower}-*.sh"
scripts=""
script_count=0

for f in $pattern; do
  if [ -f "$f" ]; then
    scripts="${scripts} ${f}"
    script_count=$((script_count + 1))
  fi
done

if [ "$script_count" -eq 0 ]; then
  echo "NO SCRIPTS: no gate scripts found matching ${milestone_lower}-${phase_lower}-*.sh"
  exit 1
fi

echo "=== Verify Suite: ${MILESTONE} ${PHASE} (${script_count} scripts) ==="
echo ""

pass_count=0
fail_count=0
fail_names=""

for f in $scripts; do
  name=$(basename "$f")
  if bash "$f" > /dev/null 2>&1; then
    echo "  PASS: $name"
    pass_count=$((pass_count + 1))
  else
    echo "  FAIL: $name"
    fail_count=$((fail_count + 1))
    fail_names="${fail_names} ${name}"
  fi
done

echo ""
echo "PASS: ${pass_count} / FAIL: ${fail_count}"

if [ "$fail_count" -gt 0 ]; then
  echo "Failed:${fail_names}"
  exit 1
fi

exit 0
