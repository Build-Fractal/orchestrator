#!/usr/bin/env bash
# m016-p03-payload-prohibited.sh — Verify handle_template constraints includes prohibited patterns
# Bash 3.2 compatible. Standalone.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HANDLERS="$PROJECT_ROOT/scripts/dispatch/lib/section-handlers.sh"

# Source section-handlers.sh
source "$HANDLERS"

# Call handle_template with constraints section
_output="$(handle_template /tmp test P01 T01 constraints 2>&1)"

# Check for "Prohibited inline bash patterns"
_found_prohibited=0
case "$_output" in
  *"Prohibited inline bash patterns"*)
    _found_prohibited=1
    ;;
esac

# Check for "ANTIPATTERNS.md"
_found_antipatterns=0
case "$_output" in
  *"ANTIPATTERNS.md"*)
    _found_antipatterns=1
    ;;
esac

if [ "$_found_prohibited" -eq 1 ] && [ "$_found_antipatterns" -eq 1 ]; then
  echo "PASS: handle_template constraints contains prohibited patterns section with ANTIPATTERNS.md reference"
  exit 0
else
  echo "FAIL: handle_template constraints missing expected content"
  if [ "$_found_prohibited" -eq 0 ]; then
    echo "  Missing: 'Prohibited inline bash patterns'"
  fi
  if [ "$_found_antipatterns" -eq 0 ]; then
    echo "  Missing: 'ANTIPATTERNS.md'"
  fi
  exit 1
fi
