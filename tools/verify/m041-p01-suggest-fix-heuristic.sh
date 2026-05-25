#!/usr/bin/env bash
# tools/verify/m041-p01-suggest-fix-heuristic.sh
# Verifies that --suggest-fix with a missing-file symptom activates
# the heuristic engine (output differs from the default no-fix text).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

output="$(bash "$PROJECT_ROOT/scripts/diagnostics/triage-issue.sh" \
  --symptom "scripts/diagnostics/nonexistent-file-for-test.sh not found" \
  --suggest-fix 2>/dev/null)"

case "$output" in
  *"## Suggested Fix"*) : ;;
  *)
    echo "FAIL: ## Suggested Fix section missing from output"
    exit 1 ;;
esac

case "$output" in
  *"No simple fix identified -- run with --suggest-fix"*)
    echo "FAIL: heuristic did not activate -- still showing default no-fix text"
    exit 1 ;;
  *)
    echo "PASS: --suggest-fix heuristic activated (no default text present)"
    ;;
esac
