#!/usr/bin/env bash
# tools/verify/m041-p01-report-frontmatter.sh
# Verifies triage-issue.sh output contains the three YAML frontmatter fields.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

output="$(bash "$PROJECT_ROOT/scripts/diagnostics/triage-issue.sh" \
  --symptom "frontmatter test" 2>/dev/null)"

missing=""
for field in "symptom:" "captured_at:" "orchestrator_version:"; do
  case "$output" in
    *"$field"*) : ;;
    *) missing="${missing}  ${field}"$'\n' ;;
  esac
done

if [ -n "$missing" ]; then
  printf 'FAIL: triage report frontmatter missing fields:\n%s' "$missing"
  exit 1
fi

echo "PASS: triage report frontmatter contains symptom:, captured_at:, orchestrator_version:"
