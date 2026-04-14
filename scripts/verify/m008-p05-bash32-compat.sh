#!/usr/bin/env bash
# Verifies all P05 shell scripts are Bash 3.2 compatible.
# macOS ships Bash 3.2; the orchestrator targets this baseline (MEM001).
set -u

FILES=(
  "scripts/dispatch/detect-runtime.sh"
  "scripts/dispatch/adapters/runtime/claude-code.sh"
  "scripts/dispatch/adapters/runtime/codex.sh"
  "scripts/dispatch/adapters/runtime/cursor.sh"
  "scripts/dispatch/adapters/format/native.sh"
  "scripts/dispatch/adapters/format/speckit.sh"
)

for f in "${FILES[@]}"; do
  test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

  # Comment-aware scan: exclude lines whose first non-whitespace char is '#'
  # so documentation strings mentioning forbidden constructs don't trip the
  # scanner. (Known case: detect-runtime.sh documents its non-use of |&.)
  non_comments="$(grep -vE '^[[:space:]]*#' "$f")"

  # Forbidden: declare -A (associative arrays, Bash 4+)
  if printf '%s\n' "$non_comments" | grep -qE '^[[:space:]]*declare[[:space:]]+-A'; then
    echo "FAIL: $f uses 'declare -A' (associative arrays, Bash 4+)"
    exit 1
  fi

  # Forbidden: readarray / mapfile (Bash 4+)
  if printf '%s\n' "$non_comments" | grep -qE '^[[:space:]]*(readarray|mapfile)[[:space:]]'; then
    echo "FAIL: $f uses readarray/mapfile (Bash 4+)"
    exit 1
  fi

  # Forbidden: |& (Bash 4+ shorthand for 2>&1 |)
  if printf '%s\n' "$non_comments" | grep -qE '[^|]\|&[^|]'; then
    echo "FAIL: $f uses '|&' (Bash 4+ shorthand)"
    exit 1
  fi
done

echo "PASS: all P05 scripts are Bash 3.2 compatible"
