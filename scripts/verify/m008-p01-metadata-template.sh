#!/usr/bin/env bash
# Verifies templates/intensity-metadata.md exists with required YAML frontmatter fields.
set -eu

f="templates/intensity-metadata.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Check schema_version and type in frontmatter
grep -q "schema_version:" "$f" || { echo "FAIL: $f missing schema_version"; exit 1; }
grep -q 'type: intensity-metadata' "$f" || { echo "FAIL: $f missing type: intensity-metadata"; exit 1; }

# Check all required fields exist in the template
for field in intensity scope risk_level complexity confidence reasoning overridden_by original_intensity capabilities_used evaluated_at; do
  grep -q "$field:" "$f" || { echo "FAIL: $f missing field: $field"; exit 1; }
done

# Check placeholder syntax
grep -q '{{intensity}}' "$f" || { echo "FAIL: $f missing {{intensity}} placeholder"; exit 1; }
grep -q '{{overridden_by}}' "$f" || { echo "FAIL: $f missing {{overridden_by}} placeholder"; exit 1; }

echo "PASS: templates/intensity-metadata.md exists with all required fields and placeholder syntax"
