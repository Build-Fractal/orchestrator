#!/usr/bin/env bash
set -euo pipefail
# Verify write-summary.sh accepts --completed_at=now
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
  --completed_at=now \
  --body="Test summary with completed_at=now"

if grep -q 'completed_at:' "$TMP_OUT"; then
  ts=$(grep 'completed_at:' "$TMP_OUT" | head -1)
  if echo "$ts" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}T'; then
    echo "PASS: completed_at=now resolved to ISO timestamp"
    exit 0
  fi
fi
echo "FAIL: completed_at=now not resolved"
exit 1
