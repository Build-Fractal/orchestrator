#!/usr/bin/env bash
set -euo pipefail
# Verify the 6 spec subdirectories exist under knowledge/spec/ with .gitkeep files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

fail_count=0
expected_dirs="story requirement constraint nfr acceptance non-goal"

for subdir in $expected_dirs; do
  dir_path="$PROJECT_ROOT/knowledge/spec/$subdir"
  if [ ! -d "$dir_path" ]; then
    echo "FAIL: directory missing: knowledge/spec/$subdir/"
    fail_count=$((fail_count + 1))
    continue
  fi
  if [ ! -f "$dir_path/.gitkeep" ]; then
    echo "FAIL: .gitkeep missing in knowledge/spec/$subdir/"
    fail_count=$((fail_count + 1))
  fi
done

if [ "$fail_count" -gt 0 ]; then
  echo "FAIL: $fail_count spec subdirectory checks failed"
  exit 1
fi

echo "PASS: all 6 spec subdirectories exist with .gitkeep files"
exit 0
