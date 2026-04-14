#!/usr/bin/env bash
# Verifies all P02 shell scripts are Bash 3.2 compatible.
# macOS ships Bash 3.2; the orchestrator targets this baseline.
set -u

FILES=(
  "scripts/dispatch/backend-registry.sh"
  "scripts/dispatch/dispatch-interface.sh"
  "scripts/dispatch/adapters/backend/local-agent.sh"
  "scripts/dispatch/adapters/backend/local-codex.sh"
)

for f in "${FILES[@]}"; do
  test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

  # Forbidden: declare -A (associative arrays, Bash 4+)
  if grep -qE '^[[:space:]]*declare[[:space:]]+-A' "$f"; then
    echo "FAIL: $f uses 'declare -A' (associative arrays, Bash 4+)"
    exit 1
  fi

  # Forbidden: readarray / mapfile (Bash 4+)
  if grep -qE '^[[:space:]]*(readarray|mapfile)[[:space:]]' "$f"; then
    echo "FAIL: $f uses readarray/mapfile (Bash 4+)"
    exit 1
  fi

  # Forbidden: |& (Bash 4+ shorthand for 2>&1 |)
  if grep -qE '[^|]\|&[^|]' "$f"; then
    echo "FAIL: $f uses '|&' (Bash 4+ shorthand)"
    exit 1
  fi
done

echo "PASS: all P02 scripts are Bash 3.2 compatible"
