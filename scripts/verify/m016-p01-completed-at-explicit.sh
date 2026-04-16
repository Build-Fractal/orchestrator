#!/usr/bin/env bash
set -euo pipefail
# Verify write-summary.sh still accepts explicit ISO timestamps
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WRITE_SUMMARY="$PROJECT_ROOT/scripts/knowledge/write-summary.sh"
TMP_OUT="$(mktemp)"
trap 'rm -f "$TMP_OUT"' EXIT

bash "$WRITE_SUMMARY" task "$TMP_OUT" \
  --id=TTEST --parent=PTEST --milestone=MTEST \
  --provides="test" --requires="test" --affects="test" \
  --key_files="test.sh" --key_decisions="DTEST" \
  --patterns_established="test" --drill_down_paths="test" \
  --duration=1 --verification_result=pass \
  --completed_at=2026-01-01T00:00:00Z \
  --body="Test summary with explicit timestamp"

if grep -q '2026-01-01T00:00:00Z' "$TMP_OUT"; then
  echo "PASS: explicit completed_at preserved verbatim"
  exit 0
fi
echo "FAIL: explicit completed_at not preserved"
exit 1
