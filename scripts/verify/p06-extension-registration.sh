#!/usr/bin/env bash
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ext="$PROJECT_ROOT/extension.yml"
missing=0
for script in check-constitution.sh check-events.sh check-hashes.sh check-run-ids.sh check-plans.sh; do
  if ! grep -q "$script" "$ext"; then
    echo "FAIL: $script not registered in extension.yml"
    missing=$((missing + 1))
  fi
done
[ "$missing" -eq 0 ] || exit 1
echo "PASS: all P06 diagnostic scripts registered in extension.yml"
