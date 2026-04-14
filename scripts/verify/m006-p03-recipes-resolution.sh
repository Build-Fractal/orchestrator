#!/usr/bin/env bash
# Verify references/recipes.md documents resolution order and manifest config.
set -eu
f="references/recipes.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Resolution order (FR-211): must mention all 4 levels
grep -qi "resolution" "$f" || { echo "FAIL: missing resolution order documentation"; exit 1; }
grep -qi "task" "$f" || { echo "FAIL: missing 'task' level in resolution order"; exit 1; }
grep -qi "phase" "$f" || { echo "FAIL: missing 'phase' level in resolution order"; exit 1; }
grep -qi "milestone" "$f" || { echo "FAIL: missing 'milestone' level in resolution order"; exit 1; }
grep -qi "default" "$f" || { echo "FAIL: missing 'default' level in resolution order"; exit 1; }

# Manifest configuration
grep -qi "manifest" "$f" || { echo "FAIL: missing manifest documentation"; exit 1; }
grep -q "token_count\|include_token_count" "$f" || { echo "FAIL: missing token count manifest option"; exit 1; }
grep -q "section_list\|include_section_list" "$f" || { echo "FAIL: missing section list manifest option"; exit 1; }

echo "PASS: recipes.md resolution order and manifest config"
