#!/usr/bin/env bash
# scripts/verify/m013-p04-dry-run-manifest.sh — T02 gate: dry-run manifest
# byte-identical-shape to init --dry-run (FR-15).
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FX="${REPO_ROOT}/tests/fixtures/m013-p04/sync-cycle"
SYNC="${REPO_ROOT}/scripts/integrations/github-sync.sh"

passed=0
failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }

export M013_GH_STUB_DIR="${FX}/gh-stub-responses"
bash "$SYNC" --root "${FX}/orchestrator-state" --i-am-operator \
  --repo-slug test/sync-fixture --dry-run \
  >/tmp/t02-dryrun.out 2>/dev/null || true

# Shape assertion: DRY-RUN header
if grep -qE '^DRY-RUN:' /tmp/t02-dryrun.out; then
  pass "DRY-RUN: header"
else
  fail "DRY-RUN: header"
fi

# Shape assertion: per-row regex — at least 3 upsert rows match.
row_count="$(grep -cE '^UPSERT: [a-z\-]+ [^ ]+ [^ ]+ [a-z\-]+$' /tmp/t02-dryrun.out || true)"
if [ "${row_count:-0}" -ge 3 ]; then
  pass "3 or more UPSERT rows shape-match"
else
  fail "UPSERT rows shape-match (found ${row_count:-0})"
fi

# Shape assertion: footer P02 3-field shape (no adopted= suffix)
if grep -qE '^upserts=[0-9]+ skipped=[0-9]+ errors=[0-9]+$' /tmp/t02-dryrun.out; then
  pass "footer P02 3-field shape"
else
  fail "footer shape"
fi

# Byte-identity vs expected snapshot (AD-19 temp-file + diff — no <(...) ).
if diff "${FX}/expected-sync-dryrun-manifest.txt" /tmp/t02-dryrun.out \
    >/dev/null 2>&1; then
  pass "manifest byte-identical"
else
  fail "manifest byte-identity regression"
fi

echo "SUMMARY: m013-p04-dry-run-manifest.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-dry-run-manifest.sh"
  exit 0
fi
echo "FAIL: m013-p04-dry-run-manifest.sh" >&2
exit 1
