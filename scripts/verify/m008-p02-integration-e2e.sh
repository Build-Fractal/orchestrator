#!/usr/bin/env bash
# End-to-end integration smoke test for P02.
#
# Constructs a fixture task plan, payload, and intensity-metadata file,
# then invokes dispatch-interface.sh with --backend local-agent (forced
# available via SPECKIT_AGENT_TOOL=1). Asserts that the emitted stdout
# is a parseable dispatch-result with backend=local-agent and the
# propagated task_id.
set -u

INTERFACE="scripts/dispatch/dispatch-interface.sh"
REGISTRY="scripts/dispatch/backend-registry.sh"
LOCAL_AGENT="scripts/dispatch/adapters/backend/local-agent.sh"
LOCAL_CODEX="scripts/dispatch/adapters/backend/local-codex.sh"
RESULT_TEMPLATE="templates/dispatch-result.md"
ERROR_TEMPLATE="templates/dispatch-error.md"

# All P02 artifacts must exist
for f in "$INTERFACE" "$REGISTRY" "$LOCAL_AGENT" "$LOCAL_CODEX" "$RESULT_TEMPLATE" "$ERROR_TEMPLATE"; do
  test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
done
for f in "$INTERFACE" "$REGISTRY" "$LOCAL_AGENT" "$LOCAL_CODEX"; do
  test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }
done

# Registry must list both adapters
discovered="$(bash "$REGISTRY" --list 2>/dev/null | tr '\n' ',' | sed 's/,$//')"
echo ",${discovered}," | grep -q ',local-agent,' || { echo "FAIL: registry did not discover local-agent (got: $discovered)"; exit 1; }
echo ",${discovered}," | grep -q ',local-codex,' || { echo "FAIL: registry did not discover local-codex (got: $discovered)"; exit 1; }

# Registry summary must succeed
summary="$(bash "$REGISTRY" 2>/dev/null)"
echo "$summary" | grep -q '^backends_discovered=' || { echo "FAIL: registry summary missing backends_discovered"; exit 1; }
echo "$summary" | grep -q '^backends_available=' || { echo "FAIL: registry summary missing backends_available"; exit 1; }
echo "$summary" | grep -q '^default_backend=' || { echo "FAIL: registry summary missing default_backend"; exit 1; }

# Fixture inputs
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/task-plan.md" <<'EOF'
---
schema_version: "1.0"
type: task-plan
task: "T42"
phase: "P02"
milestone: "M008"
name: "E2E fixture"
depends_on: []
---

## Description

Fixture task plan for P02 integration test.
EOF

echo "Integration payload fixture" > "$tmp/payload.md"
echo "Integration metadata fixture" > "$tmp/metadata.md"

# Invoke dispatch-interface.sh routed explicitly to local-agent.
# SPECKIT_AGENT_TOOL=1 forces local-agent probe to report available=true.
output="$(SPECKIT_AGENT_TOOL=1 bash "$INTERFACE" \
  --task-plan "$tmp/task-plan.md" \
  --payload "$tmp/payload.md" \
  --intensity-metadata "$tmp/metadata.md" \
  --backend local-agent 2>/dev/null)"
rc=$?
if [[ $rc -ne 0 ]]; then
  echo "FAIL: dispatch-interface.sh --backend local-agent exited $rc (expected 0)"
  exit 1
fi

# Assert parseable dispatch-result
echo "$output" | grep -q '^schema_version: "1.0"' || { echo "FAIL: output missing schema_version frontmatter"; exit 1; }
echo "$output" | grep -q '^type: "dispatch-result"' || { echo "FAIL: output not a dispatch-result"; exit 1; }
echo "$output" | grep -q '^backend: "local-agent"' || { echo "FAIL: output backend is not local-agent"; exit 1; }
echo "$output" | grep -q '^task_id: "T42"' || { echo "FAIL: output did not propagate task_id from fixture"; exit 1; }
echo "$output" | grep -q '^phase_id: "P02"' || { echo "FAIL: output did not propagate phase_id from fixture"; exit 1; }
echo "$output" | grep -q '^milestone_id: "M008"' || { echo "FAIL: output did not propagate milestone_id from fixture"; exit 1; }
echo "$output" | grep -qE '^status: "(success|failure|retry|timeout)"' || { echo "FAIL: output status not in expected set"; exit 1; }

# Also verify a failure path: non-existent backend -> structured error on stderr
err="$(bash "$INTERFACE" \
  --task-plan "$tmp/task-plan.md" \
  --payload "$tmp/payload.md" \
  --intensity-metadata "$tmp/metadata.md" \
  --backend nonexistent-backend 2>&1 >/dev/null || true)"
echo "$err" | grep -q '^type: "dispatch-error"' || { echo "FAIL: nonexistent backend did not emit dispatch-error"; exit 1; }

echo "PASS: P02 integration -- registry discovers adapters, interface routes to local-agent, result schema conforms"
