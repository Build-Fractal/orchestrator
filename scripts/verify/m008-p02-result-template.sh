#!/usr/bin/env bash
# Verifies templates/dispatch-result.md defines the success result schema.
set -eu

f="templates/dispatch-result.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# YAML frontmatter fields
for field in schema_version type status backend task_id dispatched_at completed_at duration_s; do
  grep -q "^${field}:" "$f" || { echo "FAIL: $f missing frontmatter field '${field}'"; exit 1; }
done

# Type value
grep -q '^type: "dispatch-result"' "$f" || { echo "FAIL: $f type must be dispatch-result"; exit 1; }

# Body sections
grep -q '^# Dispatch Result' "$f" || { echo "FAIL: $f missing '# Dispatch Result' heading"; exit 1; }
grep -q '^## Status' "$f" || { echo "FAIL: $f missing '## Status' section"; exit 1; }
grep -q '^## Summary' "$f" || { echo "FAIL: $f missing '## Summary' section"; exit 1; }
grep -q '^## Artifacts' "$f" || { echo "FAIL: $f missing '## Artifacts' section"; exit 1; }

# Comment block enumerating status values
grep -q 'success' "$f" || { echo "FAIL: $f missing 'success' status value documentation"; exit 1; }
grep -q 'failure' "$f" || { echo "FAIL: $f missing 'failure' status value documentation"; exit 1; }
grep -q 'retry' "$f" || { echo "FAIL: $f missing 'retry' status value documentation"; exit 1; }
grep -q 'timeout' "$f" || { echo "FAIL: $f missing 'timeout' status value documentation"; exit 1; }

echo "PASS: templates/dispatch-result.md defines the success result schema"
