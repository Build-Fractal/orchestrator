#!/usr/bin/env bash
# scripts/verify/m013-p04-verify-cache.sh — T06 gate: --verify-cache divergence probe (FR-18).
#
# Single-script-file (AD-19) shape. Bash 3.2 compatible. AP-009 compliant.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATUS="${REPO_ROOT}/scripts/integrations/github-status.sh"

passed=0
failed=0
fail() {
  echo "FAIL: $1"
  failed=$((failed + 1))
}
pass() {
  echo "PASS: $1"
  passed=$((passed + 1))
}

# Assertion 1: --verify-cache flag recognized in --help output.
help_out=$(bash "$STATUS" --help 2>&1 || true)
if printf '%s\n' "$help_out" | grep -q -- "--verify-cache"; then
  pass "--verify-cache in help"
else
  fail "--verify-cache not in help"
fi

# Assertion 2: absent sidecar + --verify-cache -> pending-sentinel no-op (rc=0).
tmpdir=$(mktemp -d -t m013-p04-vc.XXXXXX)
mkdir -p "${tmpdir}/.orchestrator/integrations"
# no sidecar file at this point
export ORCHESTRATOR_ROOT="${tmpdir}/.orchestrator"
abs_out=$(bash "$STATUS" --verify-cache 2>&1 || true)
unset ORCHESTRATOR_ROOT
if printf '%s\n' "$abs_out" | grep -q 'pending-operator-complete'; then
  pass "absent sidecar yields pending-sentinel no-op"
else
  fail "absent sidecar did not yield pending-sentinel (out=${abs_out})"
fi

# Assertion 3: configured sidecar with matching remote -> divergences=0 rc=0.
cat > "${tmpdir}/.orchestrator/integrations/github.json" <<'SC'
{
  "schema_version": 1,
  "repo_slug": "t/r",
  "project_v2_id": "P1",
  "sync_mode": "manual",
  "sub_issue_mode": "native",
  "recommended_cron": "*/15 * * * *",
  "custom_field_mappings": [],
  "items": {
    "M013-X": { "issue_number": 401, "project_v2_attached": true, "status_field_synced": true, "last_attempt_at": "", "last_error": null }
  }
}
SC
stub_dir=$(mktemp -d -t m013-p04-vc-stub.XXXXXX)
mkdir -p "${stub_dir}/stubs"
# gh_marker_search_remote helper looks for issue-list-<oid>.json under M013_GH_STUB_DIR.
printf '[{"number":401}]\n' > "${stub_dir}/stubs/issue-list-M013-X.json"

export ORCHESTRATOR_ROOT="${tmpdir}/.orchestrator"
export M013_GH_STUB_DIR="${stub_dir}/stubs"
bash "$STATUS" --verify-cache > /tmp/t06-vc-ok.out 2>&1
rc=$?
unset ORCHESTRATOR_ROOT M013_GH_STUB_DIR
if [ "$rc" -eq 0 ]; then
  pass "matching cache yields rc=0"
else
  fail "matching cache yields rc=${rc} (see /tmp/t06-vc-ok.out)"
fi
if grep -q 'divergences=0' /tmp/t06-vc-ok.out; then
  pass "SUMMARY reports divergences=0"
else
  fail "SUMMARY missing divergences=0 on matching cache"
fi

# Assertion 4: configured sidecar with missing-remote -> divergences=1 rc=5.
# Replace the stub with an empty-array result to simulate zero marker hits.
printf '[]\n' > "${stub_dir}/stubs/issue-list-M013-X.json"

export ORCHESTRATOR_ROOT="${tmpdir}/.orchestrator"
export M013_GH_STUB_DIR="${stub_dir}/stubs"
bash "$STATUS" --verify-cache > /tmp/t06-vc-fail.out 2>&1
rc=$?
unset ORCHESTRATOR_ROOT M013_GH_STUB_DIR
if [ "$rc" -eq 5 ]; then
  pass "missing-remote yields rc=5"
else
  fail "missing-remote yields rc=${rc} (see /tmp/t06-vc-fail.out)"
fi
if grep -q 'DIVERGENCE: missing-remote' /tmp/t06-vc-fail.out; then
  pass "DIVERGENCE missing-remote line emitted"
else
  fail "DIVERGENCE line missing on missing-remote path"
fi

# Assertion 5: --verify-cache never writes to sidecar (byte-identity).
sha_before=$(shasum -a 256 "${tmpdir}/.orchestrator/integrations/github.json" | awk '{print $1}')
export ORCHESTRATOR_ROOT="${tmpdir}/.orchestrator"
export M013_GH_STUB_DIR="${stub_dir}/stubs"
bash "$STATUS" --verify-cache > /dev/null 2>&1 || true
unset ORCHESTRATOR_ROOT M013_GH_STUB_DIR
sha_after=$(shasum -a 256 "${tmpdir}/.orchestrator/integrations/github.json" | awk '{print $1}')
if [ "$sha_before" = "$sha_after" ]; then
  pass "--verify-cache never writes to sidecar"
else
  fail "--verify-cache wrote to sidecar (byte-identity violation)"
fi

# Assertion 6: pending-valued sidecar + --verify-cache -> pending-sentinel no-op.
cat > "${tmpdir}/.orchestrator/integrations/github.json" <<'SC'
{
  "schema_version": 1,
  "repo_slug": "pending",
  "project_v2_id": "pending",
  "sync_mode": "pending",
  "sub_issue_mode": "pending",
  "recommended_cron": "*/15 * * * *",
  "custom_field_mappings": [],
  "items": {}
}
SC
export ORCHESTRATOR_ROOT="${tmpdir}/.orchestrator"
pending_out=$(bash "$STATUS" --verify-cache 2>&1 || true)
pending_rc=$?
unset ORCHESTRATOR_ROOT
if [ "$pending_rc" -eq 0 ] && printf '%s\n' "$pending_out" | grep -q 'pending-operator-complete'; then
  pass "pending sidecar yields pending-sentinel no-op (rc=0)"
else
  fail "pending sidecar path broken (rc=${pending_rc} out=${pending_out})"
fi

# Cleanup.
rm -rf "$tmpdir" "$stub_dir"

echo "SUMMARY: m013-p04-verify-cache.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-verify-cache.sh"
  exit 0
fi
echo "FAIL: m013-p04-verify-cache.sh" >&2
exit 1
