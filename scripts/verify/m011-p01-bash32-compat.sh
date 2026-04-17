#!/usr/bin/env bash
set -euo pipefail
# Verify all modified scripts pass Bash 3.2 syntax check
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Scripts modified in M011/P01
scripts=(
  "scripts/knowledge/create-entry.sh"
  "scripts/knowledge/rebuild-index.sh"
  "scripts/knowledge/lib/index-utils.sh"
  "scripts/dispatch/scope-filter.sh"
)

fail_count=0

for script in "${scripts[@]}"; do
  full_path="$PROJECT_ROOT/$script"
  if [ ! -f "$full_path" ]; then
    echo "FAIL: script not found: $script"
    fail_count=$((fail_count + 1))
    continue
  fi

  # Syntax check
  if ! /bin/bash -n "$full_path" 2>/dev/null; then
    echo "FAIL: syntax error in $script"
    fail_count=$((fail_count + 1))
    continue
  fi

  # Check for Bash 3.2 incompatible constructs
  if grep -nE 'declare -A|mapfile|\$\{[a-zA-Z_]+,,\}|\$\{[a-zA-Z_]+\^\^\}' "$full_path" >/dev/null 2>&1; then
    echo "FAIL: Bash 3.2 incompatible construct found in $script"
    grep -nE 'declare -A|mapfile|\$\{[a-zA-Z_]+,,\}|\$\{[a-zA-Z_]+\^\^\}' "$full_path"
    fail_count=$((fail_count + 1))
  fi
done

if [ "$fail_count" -gt 0 ]; then
  echo "FAIL: $fail_count scripts failed Bash 3.2 compatibility check"
  exit 1
fi

echo "PASS: all modified scripts are Bash 3.2 compatible"
exit 0
