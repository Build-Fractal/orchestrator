#!/usr/bin/env bash
# m016-p03-task-template-clean.sh — Verify task-plan.md references run-suite.sh
# Bash 3.2 compatible. Standalone.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET="$PROJECT_ROOT/templates/task-plan.md"

if [ ! -f "$TARGET" ]; then
  echo "FAIL: templates/task-plan.md not found"
  exit 1
fi

if grep -q 'run-suite\.sh' "$TARGET"; then
  echo "PASS: templates/task-plan.md references run-suite.sh"
  exit 0
else
  echo "FAIL: templates/task-plan.md does not reference run-suite.sh"
  exit 1
fi
