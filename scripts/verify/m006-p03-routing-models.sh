#!/usr/bin/env bash
# Verify references/routing.md documents model tiers, fallback, and classification.
set -eu
f="references/routing.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# All 3 model tiers
grep -q "heavy" "$f" || { echo "FAIL: missing 'heavy' tier documentation"; exit 1; }
grep -q "standard" "$f" || { echo "FAIL: missing 'standard' tier documentation"; exit 1; }
grep -q "light" "$f" || { echo "FAIL: missing 'light' tier documentation"; exit 1; }

# Context budget
grep -q "context_budget" "$f" || { echo "FAIL: missing 'context_budget' documentation"; exit 1; }

# Fallback chains
grep -qi "fallback" "$f" || { echo "FAIL: missing fallback chain documentation"; exit 1; }

# Classification rules
grep -qi "classification" "$f" || { echo "FAIL: missing classification rules documentation"; exit 1; }

# Built-in keywords (at least one from each tier)
grep -q "subsystem\|rewrite\|architect" "$f" || { echo "FAIL: missing heavy classification keywords"; exit 1; }
grep -q "implement\|feature\|modify" "$f" || { echo "FAIL: missing standard classification keywords"; exit 1; }
grep -q "config\|test\|document" "$f" || { echo "FAIL: missing light classification keywords"; exit 1; }

echo "PASS: routing.md model tiers, fallback, and classification"
