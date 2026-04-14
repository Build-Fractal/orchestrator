#!/usr/bin/env bash
# Verifies local-agent.sh normal mode emits a dispatch-result conforming document.
set -u

f="scripts/dispatch/adapters/backend/local-agent.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Create a minimal task plan fixture
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/task-plan.md" <<'EOF'
---
schema_version: "1.0"
type: task-plan
task: "T99"
phase: "P99"
milestone: "M999"
name: "Fixture task for adapter verification"
depends_on: []
---

## Description

Fixture.
EOF

echo "Fixture payload" > "$tmp/payload.md"
echo "Fixture metadata" > "$tmp/metadata.md"

# Invoke the adapter
output="$(bash "$f" --task-plan "$tmp/task-plan.md" --payload "$tmp/payload.md" --intensity-metadata "$tmp/metadata.md" 2>/dev/null)"
rc=$?
if [[ $rc -ne 0 ]]; then
  echo "FAIL: adapter exited $rc (expected 0)"; exit 1
fi

# Check frontmatter fields
echo "$output" | grep -q '^schema_version: "1.0"' || { echo "FAIL: output missing schema_version"; exit 1; }
echo "$output" | grep -q '^type: "dispatch-result"' || { echo "FAIL: output missing type: dispatch-result"; exit 1; }
echo "$output" | grep -q '^status: "success"' || { echo "FAIL: output missing status: success"; exit 1; }
echo "$output" | grep -q '^backend: "local-agent"' || { echo "FAIL: output missing backend: local-agent"; exit 1; }
echo "$output" | grep -q '^task_id: "T99"' || { echo "FAIL: output did not propagate task_id from task plan"; exit 1; }
echo "$output" | grep -q '^phase_id: "P99"' || { echo "FAIL: output did not propagate phase_id from task plan"; exit 1; }
echo "$output" | grep -q '^milestone_id: "M999"' || { echo "FAIL: output did not propagate milestone_id from task plan"; exit 1; }
echo "$output" | grep -qE '^dispatched_at: "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"' || { echo "FAIL: output missing ISO 8601 dispatched_at"; exit 1; }

# Check body sections
echo "$output" | grep -q '^# Dispatch Result' || { echo "FAIL: output missing '# Dispatch Result' heading"; exit 1; }
echo "$output" | grep -q '^## Status' || { echo "FAIL: output missing '## Status' section"; exit 1; }
echo "$output" | grep -q '^## Summary' || { echo "FAIL: output missing '## Summary' section"; exit 1; }
echo "$output" | grep -q '^## Artifacts' || { echo "FAIL: output missing '## Artifacts' section"; exit 1; }
echo "$output" | grep -q '^## Notes' || { echo "FAIL: output missing '## Notes' section"; exit 1; }

echo "PASS: local-agent.sh emits a dispatch-result conforming document"
