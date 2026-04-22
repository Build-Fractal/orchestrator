#!/usr/bin/env bash
# scripts/verify/m013-p02-github-init-preflight.sh
#
# Drives the three T02-populated preflight helpers in github-common.sh under
# fixture stubs and asserts diagnostic shapes:
#   1. gh_auth_preflight: green path (AUTH: ok, exit 0)
#   2. gh_auth_preflight: missing-scope path (integration-auth-failed, exit 2)
#   3. gh_subissue_rest_preflight: native (exit 0, SUBISSUE_MODE: native)
#   4. gh_subissue_rest_preflight: labeled-fallback (exit 0, SUBISSUE_MODE: labeled-fallback)
#   5. gh_label_collision_preflight: no-collision with empty labels
#   6. gh_label_collision_preflight: strict-mode refusal on color divergence
#
# No live `gh` calls. Bash 3.2 compatible. Exits 0 on PASS, 1 on FAIL.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STUB_DIR="${REPO_ROOT}/tests/fixtures/m013-p02/gh-stub-responses"
LIB="${REPO_ROOT}/scripts/integrations/github-common.sh"

fail_count=0
pass_count=0
_pass() { echo "PASS: $1"; pass_count=$((pass_count + 1)); }
_fail() { echo "FAIL: $1" >&2; fail_count=$((fail_count + 1)); }

if [ ! -f "$LIB" ]; then
  _fail "github-common.sh missing"
  echo "FAIL: m013-p02-github-init-preflight.sh" >&2
  exit 1
fi

# shellcheck disable=SC1090
. "$LIB"

# --- 1. Auth preflight, green path --------------------------------------------
M013_GH_STUB_DIR="$STUB_DIR"
M013_GH_STUB_AUTH="auth-status-green.txt"
export M013_GH_STUB_DIR M013_GH_STUB_AUTH
auth_out="$(gh_auth_preflight 2>/dev/null || true)"
auth_rc=0
gh_auth_preflight >/dev/null 2>&1 || auth_rc=$?
if [ "$auth_rc" -eq 0 ] && [ "$auth_out" = "AUTH: ok" ]; then
  _pass "gh_auth_preflight green path emits 'AUTH: ok' and exit 0"
else
  _fail "gh_auth_preflight green path: rc=${auth_rc} out='${auth_out}'"
fi

# --- 2. Auth preflight, missing-scope path ------------------------------------
M013_GH_STUB_AUTH="auth-status-missing-scope.txt"
export M013_GH_STUB_AUTH
auth_err="$(gh_auth_preflight 2>&1 1>/dev/null || true)"
auth_rc=0
gh_auth_preflight >/dev/null 2>&1 || auth_rc=$?
case "$auth_err" in
  *"integration-auth-failed: missing scope project"*)
    if [ "$auth_rc" -ne 0 ]; then
      _pass "gh_auth_preflight missing-scope emits 'integration-auth-failed: missing scope project' and non-zero exit"
    else
      _fail "gh_auth_preflight missing-scope path exited 0 (expected non-zero)"
    fi
    ;;
  *)
    _fail "gh_auth_preflight missing-scope path did not emit expected diagnostic: '${auth_err}'"
    ;;
esac

# --- 3. Sub-issue REST preflight, native path ---------------------------------
unset M013_GH_STUB_AUTH
M013_GH_STUB_SUBISSUE="subissue-rest-available.json"
export M013_GH_STUB_SUBISSUE
sub_out="$(gh_subissue_rest_preflight "owner/repo" 2>/dev/null || true)"
if [ "$sub_out" = "SUBISSUE_MODE: native" ]; then
  _pass "gh_subissue_rest_preflight native path emits 'SUBISSUE_MODE: native'"
else
  _fail "gh_subissue_rest_preflight native path: got '${sub_out}'"
fi

# --- 4. Sub-issue REST preflight, labeled-fallback path -----------------------
M013_GH_STUB_SUBISSUE="subissue-rest-unavailable.json"
export M013_GH_STUB_SUBISSUE
sub_out="$(gh_subissue_rest_preflight "owner/repo" 2>/dev/null || true)"
if [ "$sub_out" = "SUBISSUE_MODE: labeled-fallback" ]; then
  _pass "gh_subissue_rest_preflight unavailable path emits 'SUBISSUE_MODE: labeled-fallback'"
else
  _fail "gh_subissue_rest_preflight labeled-fallback path: got '${sub_out}'"
fi

# --- 5. Labels preflight, empty (no-collision) --------------------------------
unset M013_GH_STUB_SUBISSUE
M013_GH_STUB_LABELS="labels-empty.json"
export M013_GH_STUB_LABELS
lbl_out="$(gh_label_collision_preflight "owner/repo" "0" 2>/dev/null || true)"
lbl_rc=0
gh_label_collision_preflight "owner/repo" "0" >/dev/null 2>&1 || lbl_rc=$?
if [ "$lbl_rc" -eq 0 ] && [ "$lbl_out" = "LABELS: no-collision" ]; then
  _pass "gh_label_collision_preflight empty-labels emits 'LABELS: no-collision' and exit 0"
else
  _fail "gh_label_collision_preflight empty-labels: rc=${lbl_rc} out='${lbl_out}'"
fi

# --- 6. Labels preflight, strict-mode collision -------------------------------
M013_GH_STUB_LABELS="labels-collision.json"
export M013_GH_STUB_LABELS
lbl_err="$(gh_label_collision_preflight "owner/repo" "1" 2>&1 1>/dev/null || true)"
lbl_rc=0
gh_label_collision_preflight "owner/repo" "1" >/dev/null 2>&1 || lbl_rc=$?
case "$lbl_err" in
  *"integration-labels-collision"*)
    if [ "$lbl_rc" -ne 0 ]; then
      _pass "gh_label_collision_preflight strict-mode refuses with 'integration-labels-collision' and non-zero exit"
    else
      _fail "gh_label_collision_preflight strict-mode exited 0 (expected non-zero)"
    fi
    ;;
  *)
    _fail "gh_label_collision_preflight strict-mode did not emit collision diagnostic: '${lbl_err}'"
    ;;
esac

# --- 7. Labels preflight, non-strict collision adopts silently ---------------
lbl_out="$(gh_label_collision_preflight "owner/repo" "0" 2>/dev/null || true)"
lbl_rc=0
gh_label_collision_preflight "owner/repo" "0" >/dev/null 2>&1 || lbl_rc=$?
case "$lbl_out" in
  *"adopt-existing-with-diverging-colors"*|*"adopt-existing"*|*"no-collision"*)
    if [ "$lbl_rc" -eq 0 ]; then
      _pass "gh_label_collision_preflight non-strict path adopts silently (exit 0)"
    else
      _fail "gh_label_collision_preflight non-strict path: rc=${lbl_rc}"
    fi
    ;;
  *)
    _fail "gh_label_collision_preflight non-strict path: unexpected stdout '${lbl_out}'"
    ;;
esac

unset M013_GH_STUB_DIR M013_GH_STUB_AUTH M013_GH_STUB_SUBISSUE M013_GH_STUB_LABELS

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: auth/subissue/labels preflights emit FR-2 / AS-4a diagnostic shapes under stub responses (${pass_count}/${pass_count})"
  exit 0
fi
echo "FAIL: m013-p02-github-init-preflight.sh (${fail_count} failures, ${pass_count} passes)" >&2
exit 1
