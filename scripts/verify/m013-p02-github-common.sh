#!/usr/bin/env bash
# scripts/verify/m013-p02-github-common.sh — Verify scripts/integrations/github-common.sh
# meets the T01 contract: orchestrator-id derivation, marker primitives,
# sidecar read/write (top-level + per-item upsert), Bash 3.2 clean,
# anti-pattern-lint clean, sources cleanly under `set -u`.
#
# Exits 0 on full pass (13 assertions + final summary), 1 otherwise.
# Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="${REPO_ROOT}/scripts/integrations/github-common.sh"
TEMPLATE="${REPO_ROOT}/templates/github-integration-sidecar.json"

fail_count=0
pass_count=0

_pass() {
  echo "PASS: $1"
  pass_count=$((pass_count + 1))
}
_fail() {
  echo "FAIL: $1" >&2
  fail_count=$((fail_count + 1))
}

# --- Assertion 1: library file exists -----------------------------------------
if [ -f "$LIB" ]; then
  _pass "github-common.sh present at scripts/integrations/github-common.sh"
else
  _fail "github-common.sh not found at $LIB"
  echo "FAIL: m013-p02-github-common.sh (library missing)" >&2
  exit 1
fi

# Source the library for function-level assertions.
# shellcheck disable=SC1090
. "$LIB"

# --- Assertions 2-4: orchestrator_id_for --------------------------------------
# Use a synthetic dir so we don't depend on the real .orchestrator layout.
SYN_M="${REPO_ROOT}/tests/fixtures/m013-p02/orchestrator-state/.orchestrator/milestones/M013"
expected_phase="M013-P02"
expected_task="M013-P02-T03"

got_phase="$(orchestrator_id_for "$SYN_M" "P02" 2>/dev/null || true)"
if [ "$got_phase" = "$expected_phase" ]; then
  _pass "orchestrator_id_for emits M013-P02 for (M013-dir, P02)"
else
  _fail "orchestrator_id_for (M013-dir, P02) expected '$expected_phase', got '$got_phase'"
fi

got_task="$(orchestrator_id_for "$SYN_M" "P02" "T03" 2>/dev/null || true)"
if [ "$got_task" = "$expected_task" ]; then
  _pass "orchestrator_id_for emits M013-P02-T03 for (M013-dir, P02, T03)"
else
  _fail "orchestrator_id_for (M013-dir, P02, T03) expected '$expected_task', got '$got_task'"
fi

# Malformed phase id — expect non-zero exit, no stdout.
if orchestrator_id_for "$SYN_M" "P2" >/dev/null 2>&1; then
  _fail "orchestrator_id_for accepted malformed phase id 'P2'"
else
  _pass "orchestrator_id_for rejects malformed phase id"
fi

# --- Assertion 5: emit_marker -------------------------------------------------
expected_marker='<!-- orchestrator-id: M013-P02 -->'
got_marker="$(emit_marker "M013-P02" 2>/dev/null || true)"
if [ "$got_marker" = "$expected_marker" ]; then
  _pass "emit_marker emits '<!-- orchestrator-id: M013-P02 -->'"
else
  _fail "emit_marker expected '$expected_marker', got '$got_marker'"
fi

# --- Assertions 6-7: find_marker_in_body --------------------------------------
tmp_body_unique="$(mktemp -t m013-p02-body-u.XXXXXX)"
tmp_body_dup="$(mktemp -t m013-p02-body-d.XXXXXX)"
trap 'rm -f "$tmp_body_unique" "$tmp_body_dup"' EXIT

{
  echo "Issue body preface."
  emit_marker "M013-P02"
  echo "closing line"
} > "$tmp_body_unique"

{
  echo "Issue body preface."
  emit_marker "M013-P02"
  echo "middle"
  emit_marker "M013-P02"
  echo "closing line"
} > "$tmp_body_dup"

if find_marker_in_body "$tmp_body_unique" "M013-P02"; then
  _pass "find_marker_in_body finds unique marker (exit 0)"
else
  _fail "find_marker_in_body on unique-marker body returned non-zero"
fi

find_marker_in_body "$tmp_body_dup" "M013-P02" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 2 ]; then
  _pass "find_marker_in_body reports duplicate (exit 2)"
else
  _fail "find_marker_in_body on duplicate-marker body expected exit 2, got $rc"
fi

# --- Assertion 8: sidecar_path resolves to expected path ----------------------
SANDBOX="$(mktemp -d -t m013-p02-sb.XXXXXX)"
# Mirror repo template so sidecar-init-pending can run from the sandbox root.
mkdir -p "$SANDBOX/templates"
cp "$TEMPLATE" "$SANDBOX/templates/github-integration-sidecar.json"

expected_sidecar="$SANDBOX/.orchestrator/integrations/github.json"
got_sidecar="$(sidecar_path "$SANDBOX" 2>/dev/null || true)"
if [ "$got_sidecar" = "$expected_sidecar" ]; then
  _pass "sidecar_path resolves to .orchestrator/integrations/github.json"
else
  _fail "sidecar_path expected '$expected_sidecar', got '$got_sidecar'"
fi

# Bootstrap sidecar using P01's pending-sentinel helper.
bash "${REPO_ROOT}/scripts/integrations/sidecar-init-pending.sh" --root "$SANDBOX" >/dev/null 2>&1

# --- Assertion 9: sidecar_get_field returns pending for fresh sentinel --------
got_field="$(sidecar_get_field "repo_slug" "$SANDBOX" 2>/dev/null || true)"
if [ "$got_field" = "pending" ]; then
  _pass "sidecar_get_field returns pending for fresh sentinel"
else
  _fail "sidecar_get_field repo_slug expected 'pending', got '$got_field'"
fi

# --- Assertion 10: sidecar_set_top_field replaces repo_slug in place ----------
sidecar_set_top_field "repo_slug" "owner/repo" "$SANDBOX" >/dev/null 2>&1
got_updated="$(sidecar_get_field "repo_slug" "$SANDBOX" 2>/dev/null || true)"
if [ "$got_updated" = "owner/repo" ]; then
  _pass "sidecar_set_top_field replaces repo_slug in place"
else
  _fail "sidecar_set_top_field: expected 'owner/repo' after update, got '$got_updated'"
fi

# --- Assertion 11: sidecar_upsert_item inserts items.M013-P02 -----------------
sidecar_upsert_item "M013-P02" "42" "true" "true" "2026-04-21T19:00:00Z" "$SANDBOX" >/dev/null 2>&1
if sidecar_item_exists "M013-P02" "$SANDBOX"; then
  _pass "sidecar_upsert_item inserts items.M013-P02 entry"
else
  _fail "sidecar_upsert_item did not produce a readable items.M013-P02 entry"
fi

rm -rf "$SANDBOX"

# --- Assertions 12a-12c: manifest_header / upsert_line / footer ---------------
expected_header='MANIFEST: 5 0 0'
got_header="$(manifest_header 5 0 0 2>/dev/null || true)"
if [ "$got_header" = "$expected_header" ]; then
  _pass "manifest_header 5 0 0 prints '${expected_header}'"
else
  _fail "manifest_header expected '${expected_header}', got '${got_header}'"
fi

expected_upsert='UPSERT: phase-issue M013-P02 - create'
got_upsert="$(manifest_upsert_line phase-issue M013-P02 - create 2>/dev/null || true)"
if [ "$got_upsert" = "$expected_upsert" ]; then
  _pass "manifest_upsert_line prints '${expected_upsert}'"
else
  _fail "manifest_upsert_line expected '${expected_upsert}', got '${got_upsert}'"
fi

expected_footer='upserts=5 skipped=0 errors=0'
got_footer="$(manifest_footer 5 0 0 2>/dev/null || true)"
if [ "$got_footer" = "$expected_footer" ]; then
  _pass "manifest_footer 5 0 0 prints '${expected_footer}'"
else
  _fail "manifest_footer expected '${expected_footer}', got '${got_footer}'"
fi

# --- Assertion 12: bash -n parse check ----------------------------------------
if bash -n "$LIB" 2>/dev/null; then
  _pass "bash -n github-common.sh (Bash 3.2 syntax check)"
else
  _fail "bash -n github-common.sh reported a parse error"
fi

# --- Assertion 13: anti-pattern-lint clean ------------------------------------
LINT="${REPO_ROOT}/scripts/verify/anti-pattern-lint.sh"
if [ -f "$LINT" ]; then
  if bash "$LINT" --fixture "$LIB" >/dev/null 2>&1; then
    _pass "anti-pattern-lint clean"
  else
    _fail "anti-pattern-lint.sh reports violations in github-common.sh"
  fi
else
  _fail "anti-pattern-lint.sh not present (M016/M021 invariant broken)"
fi

# --- Final summary ------------------------------------------------------------
if [ "$fail_count" -eq 0 ]; then
  echo "PASS: github-common.sh ${pass_count}/${pass_count} assertions, Bash 3.2 clean."
  exit 0
fi
echo "FAIL: m013-p02-github-common.sh (${fail_count} failures, ${pass_count} passes)" >&2
exit 1
