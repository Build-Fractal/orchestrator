#!/usr/bin/env bash
# Verifies references/provider-convention.md exists with required sections.
set -eu
f="references/provider-convention.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'Provider Shell Convention' "$f" || grep -q 'Provider Convention' "$f" || { echo "FAIL: title heading missing"; exit 1; }
grep -q '\-\-task' "$f" || { echo "FAIL: --task argument not documented"; exit 1; }
grep -q '\-\-output' "$f" || { echo "FAIL: --output argument not documented"; exit 1; }
grep -q 'ORCH_RUN_ID' "$f" || { echo "FAIL: ORCH_RUN_ID env var not documented"; exit 1; }
grep -q 'cost_source' "$f" || { echo "FAIL: cost_source not documented"; exit 1; }
grep -q 'VERDICT' "$f" || { echo "FAIL: verdict integration not documented"; exit 1; }
lines="$(wc -l < "$f" | tr -d ' ')"
test "$lines" -ge 80 || { echo "FAIL: expected at least 80 lines, found $lines"; exit 1; }
echo "PASS: provider-convention.md exists with required sections ($lines lines)"
