#!/usr/bin/env bash
# Verifies templates/dispatch-error.md defines the structured-error schema.
set -eu

f="templates/dispatch-error.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# YAML frontmatter fields
for field in schema_version type error_type retry_eligible escalation backend occurred_at; do
  grep -q "^${field}:" "$f" || { echo "FAIL: $f missing frontmatter field '${field}'"; exit 1; }
done

# Type value
grep -q '^type: "dispatch-error"' "$f" || { echo "FAIL: $f type must be dispatch-error"; exit 1; }

# Body sections
grep -q '^# Dispatch Error' "$f" || { echo "FAIL: $f missing '# Dispatch Error' heading"; exit 1; }
grep -q '^## Error Type' "$f" || { echo "FAIL: $f missing '## Error Type' section"; exit 1; }
grep -q '^## Retry Eligibility' "$f" || { echo "FAIL: $f missing '## Retry Eligibility' section"; exit 1; }
grep -q '^## Escalation' "$f" || { echo "FAIL: $f missing '## Escalation' section"; exit 1; }
grep -q '^## Error Message' "$f" || { echo "FAIL: $f missing '## Error Message' section"; exit 1; }
grep -q '^## Suggested Action' "$f" || { echo "FAIL: $f missing '## Suggested Action' section"; exit 1; }

# Enumerated error_type values
for et in backend_unavailable backend_crashed backend_malformed input_invalid timeout registry_error; do
  grep -q "$et" "$f" || { echo "FAIL: $f missing error_type value '$et' documentation"; exit 1; }
done

# Escalation values
for ev in "none" "developer" "abort"; do
  grep -q "$ev" "$f" || { echo "FAIL: $f missing escalation value '$ev' documentation"; exit 1; }
done

echo "PASS: templates/dispatch-error.md defines the structured-error schema"
