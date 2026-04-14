#!/usr/bin/env bash
# Verify references/recipes.md documents the compression block.
set -eu
f="references/recipes.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Compression section exists
grep -qi "compression" "$f" || { echo "FAIL: missing compression documentation"; exit 1; }

# All 3 step types documented
grep -q "drop_optional" "$f" || { echo "FAIL: missing step type 'drop_optional'"; exit 1; }
grep -q "summarize" "$f" || { echo "FAIL: missing step type 'summarize'"; exit 1; }
grep -q "drop_lowest_confidence" "$f" || { echo "FAIL: missing step type 'drop_lowest_confidence'"; exit 1; }

# Protected sections
grep -q "protected_sections" "$f" || { echo "FAIL: missing 'protected_sections' documentation"; exit 1; }

# Step parameters
grep -q "max_words" "$f" || { echo "FAIL: missing 'max_words' parameter documentation"; exit 1; }
grep -q "min_confidence" "$f" || { echo "FAIL: missing 'min_confidence' parameter documentation"; exit 1; }

echo "PASS: recipes.md compression block"
