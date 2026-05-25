#!/usr/bin/env bash
# tools/verify/m041-p01-suggest-fix-unconditional.sh
# Verifies that without --suggest-fix the report still includes
# ## Suggested Fix and shows the default "run with --suggest-fix" text.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

output="$(bash "$PROJECT_ROOT/scripts/diagnostics/triage-issue.sh" \
  --symptom "test symptom" 2>/dev/null)"

case "$output" in
  *"## Suggested Fix"*) : ;;
  *)
    echo "FAIL: ## Suggested Fix section missing from output"
    exit 1 ;;
esac

case "$output" in
  *"No simple fix identified"*)
    echo "PASS: ## Suggested Fix present with default no-fix text"
    ;;
  *)
    echo "FAIL: expected 'No simple fix identified' text in Suggested Fix section"
    exit 1 ;;
esac
