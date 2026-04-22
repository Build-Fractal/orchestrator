#!/usr/bin/env bash
# scripts/verify/m013-p01-github-status.sh — gate for T02 status script.
#
# Asserts:
#   1. github-status.sh present.
#   2. STATUS: absent in empty tempdir.
#   3. STATUS: pending-operator-complete after --init-pending.
#   4. PENDING_FIELDS enumerates repo_slug+project_v2_id at least.
#   5. STATUS: configured after sed-replacing pending values.
#   6. Configured branch emits REPO_SLUG / SYNC_MODE / LAST_SYNC / CACHE_ITEMS.
#   7. schema-mismatch exits 1 when a required field is removed.
#   8. Unknown flag exits 2.
#   9. Absent on default root exits 0.
#  10. Help flag exits 0.
#  11. Zero direct gh subprocess invocations in the script source.
#  12. Script sources no jq hard dependency (grep/sed only).
#  13. Pending->init-pending idempotent (second --init-pending does not crash).
#  14. Invoking --init-pending with pre-existing sidecar still reports pending.
#  15. Clean teardown (tempdir removed).
#
# Single-script-file (AD-19) shape.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/scripts/integrations/github-status.sh"
TEMPLATE="${REPO_ROOT}/templates/github-integration-sidecar.json"
INIT_HELPER="${REPO_ROOT}/scripts/integrations/sidecar-init-pending.sh"

fail_count=0
assert_eq() {
  if [ "$2" = "$3" ]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 (expected='$2' actual='$3')"
    fail_count=$((fail_count + 1))
  fi
}
assert_ok() {
  if [ "$1" -eq 0 ]; then
    echo "PASS: $2"
  else
    echo "FAIL: $2 (rc=$1)"
    fail_count=$((fail_count + 1))
  fi
}
assert_contains() {
  case "$2" in
    *"$3"*) echo "PASS: $1" ;;
    *) echo "FAIL: $1 (expected substring '$3' in '$2')"; fail_count=$((fail_count + 1)) ;;
  esac
}

# 1. Script present
if [ -f "$SCRIPT" ]; then
  echo "PASS: github-status.sh present"
else
  echo "FAIL: github-status.sh present"
  fail_count=$((fail_count + 1))
fi

# 2. Absent in a fresh tempdir
TMP="$(mktemp -d)"
out=$(bash "$SCRIPT" --root "$TMP" 2>/dev/null | head -1)
assert_eq "absent status on empty tempdir" "STATUS: absent" "$out"

# Set up a self-contained project root at the tempdir so --init-pending
# finds both the template and the bootstrap helper.
mkdir -p "${TMP}/templates" "${TMP}/scripts/integrations"
cp "$TEMPLATE" "${TMP}/templates/"
cp "$INIT_HELPER" "${TMP}/scripts/integrations/"

# 3. Pending after --init-pending
bash "$SCRIPT" --root "$TMP" --init-pending >/dev/null 2>&1
out=$(bash "$SCRIPT" --root "$TMP" 2>/dev/null | head -1)
assert_eq "pending-operator-complete after --init-pending" "STATUS: pending-operator-complete" "$out"

# 4. PENDING_FIELDS enumerates repo_slug + project_v2_id
pending_line=$(bash "$SCRIPT" --root "$TMP" 2>/dev/null | grep '^PENDING_FIELDS:')
assert_contains "PENDING_FIELDS includes repo_slug" "$pending_line" "repo_slug"
assert_contains "PENDING_FIELDS includes project_v2_id" "$pending_line" "project_v2_id"

# 14. Second --init-pending with pre-existing sidecar still reports pending,
# exit code 0 (github-status.sh swallows the helper's clobber-refuse exit 2
# because the SIDECAR -f check short-circuits the helper call).
bash "$SCRIPT" --root "$TMP" --init-pending >/dev/null 2>&1
rc=$?
assert_eq "second --init-pending exits 0" "0" "$rc"
out=$(bash "$SCRIPT" --root "$TMP" 2>/dev/null | head -1)
assert_eq "second --init-pending still pending" "STATUS: pending-operator-complete" "$out"

# 5. Configured after sed-replacing pending values
# P02/T06 extended schema with sub_issue_mode; any pending-sentinel field
# must be non-"pending" to reach the configured branch.
SIDECAR="${TMP}/.orchestrator/integrations/github.json"
sed -i.bak 's#"repo_slug": "pending"#"repo_slug": "owner/repo"#' "$SIDECAR"
sed -i.bak 's#"project_v2_id": "pending"#"project_v2_id": "PVT_abc123"#' "$SIDECAR"
sed -i.bak 's#"sub_issue_mode": "pending"#"sub_issue_mode": "labeled-fallback"#' "$SIDECAR"
rm -f "${SIDECAR}.bak"
out=$(bash "$SCRIPT" --root "$TMP" 2>/dev/null | head -1)
assert_eq "configured after completing pending fields" "STATUS: configured" "$out"

# 6. Configured output contains REPO_SLUG, SYNC_MODE, LAST_SYNC, CACHE_ITEMS
cfg_out=$(bash "$SCRIPT" --root "$TMP" 2>/dev/null)
assert_contains "configured output has REPO_SLUG" "$cfg_out" "REPO_SLUG: owner/repo"
assert_contains "configured output has SYNC_MODE" "$cfg_out" "SYNC_MODE: manual"
assert_contains "configured output has LAST_SYNC" "$cfg_out" "LAST_SYNC:"
assert_contains "configured output has CACHE_ITEMS" "$cfg_out" "CACHE_ITEMS:"

# 7. Schema mismatch on doctored file (remove schema_version line)
grep -v '"schema_version"' "$SIDECAR" > "${SIDECAR}.tmp"
mv "${SIDECAR}.tmp" "$SIDECAR"
bash "$SCRIPT" --root "$TMP" >/dev/null 2>&1
rc=$?
assert_eq "schema-mismatch exits 1" "1" "$rc"

# 8. Unknown flag exits 2
bash "$SCRIPT" --unknown-flag >/dev/null 2>&1
rc=$?
assert_eq "unknown flag exits 2" "2" "$rc"

# 9. Help flag exits 0
bash "$SCRIPT" --help >/dev/null 2>&1
rc=$?
assert_eq "--help exits 0" "0" "$rc"

# 11. Zero direct gh subprocess invocations
count=$(grep -cE '^[[:space:]]*gh[[:space:]]' "$SCRIPT")
if [ -z "$count" ]; then
  count=0
fi
assert_eq "zero direct gh subprocess calls" "0" "$count"

# 12. No jq hard dependency (script may reference it in comments only;
# gate is that no invocation line starts with jq).
jq_count=$(grep -cE '^[[:space:]]*jq[[:space:]]' "$SCRIPT")
if [ -z "$jq_count" ]; then
  jq_count=0
fi
assert_eq "no hard jq invocation" "0" "$jq_count"

# 15. Teardown
rm -rf "$TMP"
if [ ! -d "$TMP" ]; then
  echo "PASS: tempdir teardown clean"
else
  echo "FAIL: tempdir teardown clean"
  fail_count=$((fail_count + 1))
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m013-p01-github-status.sh"
  exit 0
fi
echo "FAIL: m013-p01-github-status.sh ($fail_count failures)"
exit 1
