#!/usr/bin/env bash
set -eu
f="templates/routing.yaml"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'models:' "$f" || { echo "FAIL: missing models: section"; exit 1; }
grep -q 'heavy:' "$f" || { echo "FAIL: missing heavy tier"; exit 1; }
grep -q 'standard:' "$f" || { echo "FAIL: missing standard tier"; exit 1; }
grep -q 'light:' "$f" || { echo "FAIL: missing light tier"; exit 1; }
grep -q 'id:' "$f" || { echo "FAIL: missing id field in model tiers"; exit 1; }
grep -q 'context_budget:' "$f" || { echo "FAIL: missing context_budget field"; exit 1; }
grep -q 'classification:' "$f" || { echo "FAIL: missing classification section"; exit 1; }
grep -q 'history_weight:' "$f" || { echo "FAIL: missing history_weight field"; exit 1; }
grep -q 'budget_ceiling_usd:' "$f" || { echo "FAIL: missing budget_ceiling_usd field"; exit 1; }
echo "PASS: templates/routing.yaml defines complete routing format"
