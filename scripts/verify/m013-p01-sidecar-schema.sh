#!/usr/bin/env bash
# scripts/verify/m013-p01-sidecar-schema.sh — M013/P01/T01 gate.
#
# Asserts the sidecar-config schema contract:
#   1. templates/github-integration-sidecar.json exists.
#   2. Template round-trips through a JSON validator (python3, then jq, else SKIP).
#   3. Every FR-6 top-level field is present:
#      schema_version, repo_slug, project_v2_id, sync_mode,
#      recommended_cron, custom_field_mappings, items.
#   4. sync_mode value is one of manual|on-transition|cron.
#   5. sidecar-init-pending.sh writes a pending-sentinel file on fresh run,
#      the written file contains "repo_slug": "pending", and re-running
#      refuses to clobber with exit code 2.
#
# Single-script-file shape (AD-19). Bash 3.2 compatible (MEM001).
# No jq/python3 hard dependency; graceful-absent-tool SKIP path.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMPLATE="${REPO_ROOT}/templates/github-integration-sidecar.json"
HELPER="${REPO_ROOT}/scripts/integrations/sidecar-init-pending.sh"

fail_count=0
assert_ok() {
  if [ "$1" -eq 0 ]; then
    echo "PASS: $2"
  else
    echo "FAIL: $2"
    fail_count=$((fail_count + 1))
  fi
}

# 1. Template exists
[ -f "$TEMPLATE" ]
assert_ok $? "template present"

# 2. JSON parse-clean (prefer python3, fall back to jq, else SKIP)
if command -v python3 >/dev/null 2>&1; then
  python3 -c "import json,sys;json.load(open('$TEMPLATE'))" >/dev/null 2>&1
  assert_ok $? "template is valid JSON (python3)"
elif command -v jq >/dev/null 2>&1; then
  jq . "$TEMPLATE" >/dev/null 2>&1
  assert_ok $? "template is valid JSON (jq)"
else
  echo "SKIP: JSON validator (no python3 or jq); gate passes"
fi

# 3. FR-6 top-level fields present
for field in schema_version repo_slug project_v2_id sync_mode recommended_cron custom_field_mappings items; do
  grep -q "\"${field}\"" "$TEMPLATE"
  assert_ok $? "template has field: ${field}"
done

# 4. sync_mode enum membership
grep -E '"sync_mode"[ \t]*:[ \t]*"(manual|on-transition|cron)"' "$TEMPLATE" >/dev/null
assert_ok $? "sync_mode enum membership"

# 5. Helper behavior in an isolated fixture root
TMPROOT="$(mktemp -d)"
mkdir -p "${TMPROOT}/templates" "${TMPROOT}/scripts/integrations"
cp "$TEMPLATE" "${TMPROOT}/templates/"
cp "$HELPER" "${TMPROOT}/scripts/integrations/"

bash "${TMPROOT}/scripts/integrations/sidecar-init-pending.sh" --root "$TMPROOT" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ]
assert_ok $? "sidecar-init-pending.sh exits 0 on fresh write"

[ -f "${TMPROOT}/.orchestrator/integrations/github.json" ]
assert_ok $? "github.json written"

grep -q '"repo_slug": "pending"' "${TMPROOT}/.orchestrator/integrations/github.json"
assert_ok $? "written file has pending sentinel"

bash "${TMPROOT}/scripts/integrations/sidecar-init-pending.sh" --root "$TMPROOT" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 2 ]
assert_ok $? "second invocation refuses with exit 2"

rm -rf "$TMPROOT"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m013-p01-sidecar-schema.sh"
  exit 0
fi
echo "FAIL: m013-p01-sidecar-schema.sh ($fail_count failures)"
exit 1
