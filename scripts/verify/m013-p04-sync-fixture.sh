#!/usr/bin/env bash
# scripts/verify/m013-p04-sync-fixture.sh — T01 gate: verify sync fixture tree shape
#   + source-presence for the three new github-common.sh helpers.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FX="${REPO_ROOT}/tests/fixtures/m013-p04/sync-cycle"

passed=0
failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

# --- Assertion 1: fixture root exists
if [ -d "$FX" ]; then
  pass "fixture root exists"
else
  fail "fixture root missing: $FX"
fi

# --- Assertion 2: orchestrator-state seed files present
for f in \
  orchestrator-state/.orchestrator/milestones/M013-FIX/M013-FIX-ROADMAP.md \
  orchestrator-state/.orchestrator/milestones/M013-FIX/phases/P01-FIX/P01-FIX-PLAN.md \
  orchestrator-state/.orchestrator/milestones/M013-FIX/phases/P01-FIX/P01-FIX-SUMMARY.md \
  orchestrator-state/.orchestrator/milestones/M013-FIX/phases/P02-FIX/P02-FIX-PLAN.md \
  orchestrator-state/.orchestrator/integrations/github.json; do
  if [ -f "${FX}/${f}" ]; then
    pass "seed ${f}"
  else
    fail "missing ${f}"
  fi
done

# --- Assertion 3: sidecar is populated (no pending sentinels)
if grep -q '"pending"' "${FX}/orchestrator-state/.orchestrator/integrations/github.json"; then
  fail "sidecar contains pending sentinels (expected populated)"
else
  pass "sidecar is populated (no pending)"
fi

# --- Assertion 4: gh-stub-responses canonical set present
for s in auth-status-green.txt rate-limit-ample.json \
         issue-list-M013-FIX-P01-FIX.json issue-list-M013-FIX-P02-FIX.json \
         issue-view-302-state-body.json issue-view-305-state-body.json \
         graphql-update-status-field-success.json http-probe-rate_limit.txt; do
  if [ -f "${FX}/gh-stub-responses/${s}" ]; then
    pass "stub ${s}"
  else
    fail "missing stub ${s}"
  fi
done

# --- Assertion 5: expected-* snapshots present
for e in expected-sync-dryrun-manifest.txt expected-unit-close.jsonl expected-conversus-gate-invocation.jsonl; do
  if [ -f "${FX}/${e}" ]; then
    pass "snapshot ${e}"
  else
    fail "missing snapshot ${e}"
  fi
done

# --- Assertion 6: dryrun manifest has >=3 UPSERT rows + P02-shape footer
upsert_count=0
if [ -f "${FX}/expected-sync-dryrun-manifest.txt" ]; then
  upsert_count="$(grep -cE '^UPSERT: ' "${FX}/expected-sync-dryrun-manifest.txt" || true)"
fi
if [ "${upsert_count:-0}" -ge 3 ]; then
  pass "expected manifest has >=3 UPSERT rows (found ${upsert_count})"
else
  fail "expected manifest has <3 UPSERT rows (found ${upsert_count})"
fi
if grep -qE '^upserts=[0-9]+ skipped=[0-9]+ errors=[0-9]+$' "${FX}/expected-sync-dryrun-manifest.txt"; then
  pass "expected manifest has P02-shape footer"
else
  fail "expected manifest footer shape mismatch"
fi

# --- Assertion 7: FR-4 marker invariant — every issue-view body embeds the oid marker
for pair in \
  "302:M013-FIX-P01-FIX" \
  "303:M013-FIX-P01-FIX-T01" \
  "304:M013-FIX-P01-FIX-T02" \
  "305:M013-FIX-P02-FIX" \
  "306:M013-FIX-P02-FIX-T01"; do
  n="${pair%%:*}"
  oid="${pair#*:}"
  f="${FX}/gh-stub-responses/issue-view-${n}-state-body.json"
  if [ -f "$f" ] && grep -q "<!-- orchestrator-id: ${oid} -->" "$f"; then
    pass "issue-view-${n} embeds FR-4 marker for ${oid}"
  else
    fail "issue-view-${n} missing FR-4 marker for ${oid}"
  fi
done

# --- Assertion 8: three new helpers defined in github-common.sh
for fn in http_probe sidecar_update_item_cache emit_tier1_record; do
  if grep -qE "^${fn}\(\)" "${REPO_ROOT}/scripts/integrations/github-common.sh"; then
    pass "helper ${fn} defined"
  else
    fail "helper ${fn} missing from github-common.sh"
  fi
done

echo "SUMMARY: m013-p04-sync-fixture.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-sync-fixture.sh"
  exit 0
fi
echo "FAIL: m013-p04-sync-fixture.sh" >&2
exit 1
