#!/usr/bin/env bash
# scripts/verify/m013-p04-github-common-p04.sh — T01 gate: behavioral smoke for the
# three P04 additive helpers (http_probe, sidecar_update_item_cache,
# emit_tier1_record). jq-optional, bash 3.2 target, fixture-driven via
# M013_GH_STUB_DIR + ORCHESTRATOR_ROOT.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMMON="${REPO_ROOT}/scripts/integrations/github-common.sh"
FX="${REPO_ROOT}/tests/fixtures/m013-p04/sync-cycle"
STUB_DIR="${FX}/gh-stub-responses"

passed=0
failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

# shellcheck source=/dev/null
. "$COMMON"

# Scratch working dir for sidecar + jsonl emission.
TMPROOT="$(mktemp -d -t m013-p04-helpers.XXXXXX)"
trap 'rm -rf "$TMPROOT"' EXIT INT TERM

# --- Assertion 1: http_probe reads stub and emits STATUS+RATE_LIMIT lines -----
probe_out_file="${TMPROOT}/probe.out"
M013_GH_STUB_DIR="$STUB_DIR" http_probe rate_limit > "$probe_out_file" 2>/dev/null
probe_rc=$?
if [ "$probe_rc" -eq 0 ]; then
  pass "http_probe rc=0 on 2xx stub"
else
  fail "http_probe rc=${probe_rc} (expected 0)"
fi
if grep -qE '^STATUS=200$' "$probe_out_file"; then
  pass "http_probe emits STATUS=200"
else
  fail "http_probe missing STATUS=200 line"
fi
if grep -qE '^RATE_LIMIT_REMAINING=4500$' "$probe_out_file"; then
  pass "http_probe emits RATE_LIMIT_REMAINING=4500"
else
  fail "http_probe missing RATE_LIMIT_REMAINING=4500 line"
fi
if grep -qE '^RATE_LIMIT_RESET=1745000000$' "$probe_out_file"; then
  pass "http_probe emits RATE_LIMIT_RESET=1745000000"
else
  fail "http_probe missing RATE_LIMIT_RESET=1745000000 line"
fi

# --- Assertion 2: http_probe rc=1 on missing stub + empty response ------------
EMPTY_DIR="${TMPROOT}/empty-stubs"
mkdir -p "$EMPTY_DIR"
# Create an empty file at the expected slug so stub takes over (avoids live gh).
: > "${EMPTY_DIR}/http-probe-rate_limit.txt"
M013_GH_STUB_DIR="$EMPTY_DIR" http_probe rate_limit >/dev/null 2>&1
probe_empty_rc=$?
if [ "$probe_empty_rc" -eq 1 ]; then
  pass "http_probe rc=1 on empty response"
else
  fail "http_probe rc=${probe_empty_rc} on empty response (expected 1)"
fi

# --- Assertion 3: sidecar_update_item_cache writes the four mutable fields ----
WORK_ROOT="${TMPROOT}/sidecar-work"
mkdir -p "${WORK_ROOT}/.orchestrator/integrations"
cp "${FX}/orchestrator-state/.orchestrator/integrations/github.json" \
   "${WORK_ROOT}/.orchestrator/integrations/github.json"
sidecar_update_item_cache "M013-FIX-P01-FIX-T01" "2026-04-22T12:34:56Z" "null" "true" "true" "$WORK_ROOT"
sc_rc=$?
if [ "$sc_rc" -eq 0 ]; then
  pass "sidecar_update_item_cache rc=0 on populated sidecar"
else
  fail "sidecar_update_item_cache rc=${sc_rc} (expected 0)"
fi
# Pull the T01 line and assert the four fields updated.
UPDATED_LINE="$(grep '"M013-FIX-P01-FIX-T01"' "${WORK_ROOT}/.orchestrator/integrations/github.json" | head -n 1)"
if echo "$UPDATED_LINE" | grep -q '"last_attempt_at": "2026-04-22T12:34:56Z"'; then
  pass "sidecar last_attempt_at updated"
else
  fail "sidecar last_attempt_at not updated (line=${UPDATED_LINE})"
fi
if echo "$UPDATED_LINE" | grep -q '"last_error": null'; then
  pass "sidecar last_error=null preserved"
else
  fail "sidecar last_error not set to null (line=${UPDATED_LINE})"
fi
if echo "$UPDATED_LINE" | grep -q '"status_field_synced": true'; then
  pass "sidecar status_field_synced updated to true"
else
  fail "sidecar status_field_synced not updated (line=${UPDATED_LINE})"
fi
if echo "$UPDATED_LINE" | grep -q '"project_v2_attached": true'; then
  pass "sidecar project_v2_attached preserved/updated to true"
else
  fail "sidecar project_v2_attached not updated (line=${UPDATED_LINE})"
fi
# issue_number must remain 303 (preserved).
if echo "$UPDATED_LINE" | grep -q '"issue_number": 303'; then
  pass "sidecar issue_number preserved (303)"
else
  fail "sidecar issue_number NOT preserved (line=${UPDATED_LINE})"
fi

# --- Assertion 4: sidecar_update_item_cache rc=2 when sidecar absent ----------
ABSENT_ROOT="${TMPROOT}/absent-root"
mkdir -p "${ABSENT_ROOT}/.orchestrator/integrations"
sidecar_update_item_cache "OID" "2026-04-22T00:00:00Z" "null" "false" "false" "$ABSENT_ROOT" 2>/dev/null
absent_rc=$?
if [ "$absent_rc" -eq 2 ]; then
  pass "sidecar_update_item_cache rc=2 on absent sidecar (FR-11)"
else
  fail "sidecar_update_item_cache rc=${absent_rc} on absent sidecar (expected 2)"
fi

# --- Assertion 5: sidecar_update_item_cache rc=2 on pending sentinel ----------
PENDING_ROOT="${TMPROOT}/pending-root"
mkdir -p "${PENDING_ROOT}/.orchestrator/integrations"
printf '%s\n' '{ "schema_version": "1.0", "repo_slug": "pending", "project_v2_id": "pending", "items": {} }' \
  > "${PENDING_ROOT}/.orchestrator/integrations/github.json"
sidecar_update_item_cache "OID" "2026-04-22T00:00:00Z" "null" "false" "false" "$PENDING_ROOT" 2>/dev/null
pending_rc=$?
if [ "$pending_rc" -eq 2 ]; then
  pass "sidecar_update_item_cache rc=2 on pending sentinel (FR-11)"
else
  fail "sidecar_update_item_cache rc=${pending_rc} on pending sentinel (expected 2)"
fi

# --- Assertion 6: emit_tier1_record writes JSONL with source=runtime ----------
EMIT_ROOT="${TMPROOT}/emit-root"
mkdir -p "$EMIT_ROOT"
ORCHESTRATOR_ROOT="$EMIT_ROOT" emit_tier1_record unit_close \
  milestone=M013-FIX \
  oid=M013-FIX-P01-FIX \
  issue_number=302 \
  outcome=status-synced
LOG_FILE="${EMIT_ROOT}/execution-log.jsonl"
if [ -f "$LOG_FILE" ]; then
  pass "emit_tier1_record created execution-log.jsonl"
else
  fail "emit_tier1_record did not create execution-log.jsonl"
fi
if grep -q '"event":"unit_close"' "$LOG_FILE"; then
  pass "emit_tier1_record wrote event=unit_close"
else
  fail "emit_tier1_record missing event=unit_close"
fi
if grep -q '"source":"runtime"' "$LOG_FILE"; then
  pass "emit_tier1_record hard-codes source=runtime (FR-17)"
else
  fail "emit_tier1_record missing source=runtime (FR-17)"
fi
if grep -q '"milestone":"M013-FIX"' "$LOG_FILE"; then
  pass "emit_tier1_record wrote string kv (milestone)"
else
  fail "emit_tier1_record missing string kv (milestone)"
fi
if grep -q '"issue_number":302' "$LOG_FILE"; then
  pass "emit_tier1_record numeric kv not quoted (issue_number)"
else
  fail "emit_tier1_record numeric kv quoted or missing (issue_number)"
fi

# --- Assertion 7: emit_tier1_record append-only (two records appear) ---------
ORCHESTRATOR_ROOT="$EMIT_ROOT" emit_tier1_record unit_close oid=OID2
line_count="$(wc -l < "$LOG_FILE" | tr -d ' ')"
if [ "$line_count" -ge 2 ]; then
  pass "emit_tier1_record append-only (line_count=${line_count})"
else
  fail "emit_tier1_record not append-only (line_count=${line_count})"
fi

echo "SUMMARY: m013-p04-github-common-p04.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-github-common-p04.sh"
  exit 0
fi
echo "FAIL: m013-p04-github-common-p04.sh" >&2
exit 1
