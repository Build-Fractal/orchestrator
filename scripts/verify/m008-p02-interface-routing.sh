#!/usr/bin/env bash
# Verifies dispatch-interface.sh routes to the correct adapter and
# emits either the adapter's result (success) or a dispatch-error
# (failure).
set -u

f="scripts/dispatch/dispatch-interface.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/task-plan.md" <<'EOF'
---
schema_version: "1.0"
type: task-plan
task: "T77"
phase: "P02"
milestone: "M008"
name: "Routing fixture"
depends_on: []
---

## Description

Fixture.
EOF

echo "payload" > "$tmp/payload.md"
echo "metadata" > "$tmp/metadata.md"

# Route explicitly to local-agent (always exists after T03)
output="$(SPECKIT_AGENT_TOOL=1 bash "$f" \
  --task-plan "$tmp/task-plan.md" \
  --payload "$tmp/payload.md" \
  --intensity-metadata "$tmp/metadata.md" \
  --backend local-agent 2>/dev/null)"
rc=$?
if [[ $rc -ne 0 ]]; then
  echo "FAIL: --backend local-agent exited $rc (expected 0)"; exit 1
fi
echo "$output" | grep -q '^type: "dispatch-result"' || { echo "FAIL: routing to local-agent did not emit dispatch-result"; exit 1; }
echo "$output" | grep -q '^backend: "local-agent"' || { echo "FAIL: routing to local-agent did not emit backend: local-agent"; exit 1; }
echo "$output" | grep -q '^task_id: "T77"' || { echo "FAIL: routing did not propagate task_id"; exit 1; }

# Request a non-existent backend -> dispatch-error on stderr
err="$(bash "$f" \
  --task-plan "$tmp/task-plan.md" \
  --payload "$tmp/payload.md" \
  --intensity-metadata "$tmp/metadata.md" \
  --backend does-not-exist 2>&1 >/dev/null || true)"
echo "$err" | grep -q '^type: "dispatch-error"' || { echo "FAIL: nonexistent backend did not emit dispatch-error"; exit 1; }
echo "$err" | grep -q 'backend_unavailable' || { echo "FAIL: nonexistent backend did not emit error_type=backend_unavailable"; exit 1; }

echo "PASS: dispatch-interface.sh routes correctly and emits structured errors on failure"
