#!/usr/bin/env bash
# tools/verify/m041-p01-triage-report-sections.sh
# Verifies triage-issue.sh emits all 6 section headers in its report.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

output="$(bash "$PROJECT_ROOT/scripts/diagnostics/triage-issue.sh" \
  --symptom "test symptom for verification" --capture-log 2>/dev/null)"

missing=""
for header in "## Symptom" "## Environment" "## Recent Execution Log" \
              "## Relevant Files" "## Disk State" "## Suggested Fix"; do
  case "$output" in
    *"$header"*) : ;;
    *) missing="${missing}  ${header}"$'\n' ;;
  esac
done

if [ -n "$missing" ]; then
  printf 'FAIL: triage report missing section headers:\n%s' "$missing"
  exit 1
fi

echo "PASS: triage report contains all 6 section headers"
