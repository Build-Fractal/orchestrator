#!/usr/bin/env bash
# Verifies local-codex.sh normal mode emits a dispatch-result conforming
# document. The test does NOT require the codex CLI to be installed --
# when it is absent, the adapter must emit a failure-status result with
# backend=local-codex (the uniform contract must hold in both cases).
set -u

f="scripts/dispatch/adapters/backend/local-codex.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Ensure the script contains the TODO marker documenting the placeholder
# invocation (contract: runtime validation follow-up).
grep -q 'TODO(M008-P02)' "$f" || { echo "FAIL: $f missing TODO(M008-P02) marker for placeholder codex invocation"; exit 1; }

# Fixture files
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/task-plan.md" <<'EOF'
---
schema_version: "1.0"
type: task-plan
task: "T99"
phase: "P99"
milestone: "M999"
name: "Fixture"
depends_on: []
---

## Description

Fixture.
EOF

echo "Fixture payload" > "$tmp/payload.md"
echo "Fixture metadata" > "$tmp/metadata.md"

output="$(bash "$f" --task-plan "$tmp/task-plan.md" --payload "$tmp/payload.md" --intensity-metadata "$tmp/metadata.md" 2>/dev/null)"
rc=$?
if [[ $rc -ne 0 ]]; then
  echo "FAIL: adapter exited $rc (expected 0)"; exit 1
fi

# Frontmatter must include identifying fields regardless of codex presence
echo "$output" | grep -q '^type: "dispatch-result"' || { echo "FAIL: output missing type: dispatch-result"; exit 1; }
echo "$output" | grep -q '^backend: "local-codex"' || { echo "FAIL: output missing backend: local-codex"; exit 1; }
echo "$output" | grep -q '^task_id: "T99"' || { echo "FAIL: output did not propagate task_id"; exit 1; }
echo "$output" | grep -q '^phase_id: "P99"' || { echo "FAIL: output did not propagate phase_id"; exit 1; }
echo "$output" | grep -q '^milestone_id: "M999"' || { echo "FAIL: output did not propagate milestone_id"; exit 1; }
echo "$output" | grep -qE '^status: "(success|failure)"' || { echo "FAIL: output missing status: success or failure"; exit 1; }

# Body sections
echo "$output" | grep -q '^# Dispatch Result' || { echo "FAIL: output missing '# Dispatch Result' heading"; exit 1; }
echo "$output" | grep -q '^## Status' || { echo "FAIL: output missing '## Status' section"; exit 1; }
echo "$output" | grep -q '^## Summary' || { echo "FAIL: output missing '## Summary' section"; exit 1; }
echo "$output" | grep -q '^## Artifacts' || { echo "FAIL: output missing '## Artifacts' section"; exit 1; }
echo "$output" | grep -q '^## Notes' || { echo "FAIL: output missing '## Notes' section"; exit 1; }

echo "PASS: local-codex.sh emits a dispatch-result conforming document"
