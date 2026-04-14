#!/usr/bin/env bash
# Verify references/routing.md documents budget controls and fallback config.
set -eu
f="references/routing.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Budget controls
grep -q "budget_ceiling" "$f" || { echo "FAIL: missing 'budget_ceiling' documentation"; exit 1; }
grep -q "history_weight" "$f" || { echo "FAIL: missing 'history_weight' documentation"; exit 1; }

# Fallback config
grep -q "recoverable_errors" "$f" || { echo "FAIL: missing 'recoverable_errors' documentation"; exit 1; }
grep -q "max_retries" "$f" || { echo "FAIL: missing 'max_retries' documentation"; exit 1; }
grep -q "retry_delay" "$f" || { echo "FAIL: missing 'retry_delay' documentation"; exit 1; }

echo "PASS: routing.md budget controls and fallback config"
