#!/usr/bin/env bash
# tools/verify/m041-p01-pipe-input.sh
# Verifies triage-issue.sh reads symptom from stdin via input redirection.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

printf 'piped test symptom for verification' > "$tmpfile"

output="$(bash "$PROJECT_ROOT/scripts/diagnostics/triage-issue.sh" < "$tmpfile" 2>/dev/null)"

case "$output" in
  *"piped test symptom for verification"*)
    : ;;
  *)
    echo "FAIL: piped symptom text not found in output"
    exit 1 ;;
esac

case "$output" in
  *"## Symptom"*)
    echo "PASS: stdin input read and ## Symptom section present"
    ;;
  *)
    echo "FAIL: ## Symptom section missing from output"
    exit 1 ;;
esac
