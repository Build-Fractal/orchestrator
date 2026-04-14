#!/usr/bin/env bash
# Verify references/recipes.md documents all section fields and source types.
set -eu
f="references/recipes.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Section fields
grep -qi "source" "$f" || { echo "FAIL: missing 'source' field documentation"; exit 1; }
grep -qi "priority" "$f" || { echo "FAIL: missing 'priority' field documentation"; exit 1; }
grep -qi "order" "$f" || { echo "FAIL: missing 'order' field documentation"; exit 1; }
grep -qi "filter" "$f" || { echo "FAIL: missing 'filter' field documentation"; exit 1; }
grep -qi "cache_hint" "$f" || { echo "FAIL: missing 'cache_hint' field documentation"; exit 1; }

# Priority values
grep -q "required" "$f" || { echo "FAIL: missing priority value 'required'"; exit 1; }
grep -q "compressible" "$f" || { echo "FAIL: missing priority value 'compressible'"; exit 1; }
grep -q "optional" "$f" || { echo "FAIL: missing priority value 'optional'"; exit 1; }

# Filter values
grep -q "scope" "$f" || { echo "FAIL: missing filter value 'scope'"; exit 1; }
grep -q "staleness" "$f" || { echo "FAIL: missing filter value 'staleness'"; exit 1; }
grep -q "confidence" "$f" || { echo "FAIL: missing filter value 'confidence'"; exit 1; }

# Cache hint values
grep -q "static" "$f" || { echo "FAIL: missing cache_hint value 'static'"; exit 1; }
grep -q "semi-static" "$f" || { echo "FAIL: missing cache_hint value 'semi-static'"; exit 1; }
grep -q "dynamic" "$f" || { echo "FAIL: missing cache_hint value 'dynamic'"; exit 1; }

# Source types
grep -q "computed" "$f" || { echo "FAIL: missing source type 'computed'"; exit 1; }
grep -q "phase_summaries" "$f" || { echo "FAIL: missing source type 'phase_summaries'"; exit 1; }
grep -q "phase_plan" "$f" || { echo "FAIL: missing source type 'phase_plan'"; exit 1; }
grep -q "task_plan" "$f" || { echo "FAIL: missing source type 'task_plan'"; exit 1; }
grep -q "template" "$f" || { echo "FAIL: missing source type 'template'"; exit 1; }

echo "PASS: recipes.md section fields and source types"
