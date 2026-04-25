#!/usr/bin/env bash
# scripts/verify/m014-p03-fetch.sh
# Verifies M014/P03/T01: comment fetcher + idempotency.
#
# Cases:
#   A. Hermetic fetch: stub fixture feeds both GH_API_STUB and GH_GRAPHQL_STUB;
#      records are filtered by source_surface so each appears in exactly one
#      surface. Expect fetched=4, 4 inbox files, unit_close emitted.
#   B. Idempotency: seed actioned.jsonl with one URL; expect fetched=3 skipped=1.
#   C. --dry-run: emits FR-19 cache-comment manifest to stdout, no inbox writes.
#
# Bash 3.2. Single-script-file shape per AD-19.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FETCHER="${REPO_ROOT}/scripts/comments/fetch.sh"
FIXTURE="${REPO_ROOT}/tests/fixtures/m014-p03/sample-inbox.jsonl"

if [ ! -x "$FETCHER" ]; then
  echo "FAIL: $FETCHER missing or not executable" >&2; exit 1
fi
if [ ! -f "$FIXTURE" ]; then
  echo "FAIL: $FIXTURE missing" >&2; exit 1
fi

pass=0; fail=0
_pass() { pass=$((pass+1)); echo "PASS: $1"; }
_fail() { fail=$((fail+1)); echo "FAIL: $1"; }

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
mkdir -p "$SCRATCH/.orchestrator/comments"
touch "$SCRATCH/.orchestrator/execution-log.jsonl"

# ---------------- Case A ----------------
ORCHESTRATOR_PROJECT_ROOT="$SCRATCH" \
GH_API_STUB="$FIXTURE" \
GH_GRAPHQL_STUB="$FIXTURE" \
  bash "$FETCHER" --yes > "$SCRATCH/run-a.out" 2>&1
rc_a=$?
if [ "$rc_a" = "0" ]; then
  _pass "Case A: fetch exits 0 with stub"
else
  _fail "Case A: rc=$rc_a (out: $(cat "$SCRATCH/run-a.out"))"
fi
if grep -q "fetched=4" "$SCRATCH/run-a.out"; then
  _pass "Case A: SUMMARY reports fetched=4"
else
  _fail "Case A: SUMMARY missing fetched=4 (out: $(cat "$SCRATCH/run-a.out"))"
fi
inbox_count=$(ls -1 "$SCRATCH/.orchestrator/comments/inbox/" 2>/dev/null | wc -l | tr -d ' ')
if [ "$inbox_count" = "4" ]; then
  _pass "Case A: 4 inbox files written"
else
  _fail "Case A: inbox count=$inbox_count, expected 4"
fi
if grep -q '"event":"unit_close"' "$SCRATCH/.orchestrator/execution-log.jsonl"; then
  _pass "Case A: unit_close emitted"
else
  _fail "Case A: unit_close missing"
fi
# Inbox record shape: each cached file carries url, body, source_surface,
# fetched_at, body_shasum (FR-8 contract).
sample_inbox="$(ls -1 "$SCRATCH/.orchestrator/comments/inbox/" 2>/dev/null | head -1)"
if [ -n "$sample_inbox" ] && grep -q '"body_shasum"' "$SCRATCH/.orchestrator/comments/inbox/$sample_inbox"; then
  _pass "Case A: inbox records include body_shasum"
else
  _fail "Case A: inbox records missing body_shasum"
fi

# ---------------- Case B ----------------
echo '{"comment_url":"https://github.com/Build-Fractal/spec-kit-orchestrator/issues/1#issuecomment-1","actioned_at":"2026-04-24T00:00:00Z","class":"uat-bug","applied":true}' > "$SCRATCH/.orchestrator/comments/actioned.jsonl"
rm -rf "$SCRATCH/.orchestrator/comments/inbox"
ORCHESTRATOR_PROJECT_ROOT="$SCRATCH" \
GH_API_STUB="$FIXTURE" \
GH_GRAPHQL_STUB="$FIXTURE" \
  bash "$FETCHER" --yes > "$SCRATCH/run-b.out" 2>&1
if grep -q "fetched=3 skipped=1" "$SCRATCH/run-b.out"; then
  _pass "Case B: idempotency skip on actioned URL"
else
  _fail "Case B: expected fetched=3 skipped=1 (out: $(cat "$SCRATCH/run-b.out"))"
fi

# ---------------- Case C ----------------
rm -rf "$SCRATCH/.orchestrator/comments/inbox"
rm -f "$SCRATCH/.orchestrator/comments/actioned.jsonl"
touch "$SCRATCH/.orchestrator/comments/actioned.jsonl"
ORCHESTRATOR_PROJECT_ROOT="$SCRATCH" \
GH_API_STUB="$FIXTURE" \
GH_GRAPHQL_STUB="$FIXTURE" \
  bash "$FETCHER" --yes --dry-run > "$SCRATCH/run-c.out" 2>&1
if grep -q '"action_type":"cache-comment"' "$SCRATCH/run-c.out"; then
  _pass "Case C: dry-run emits FR-19 manifest"
else
  _fail "Case C: missing dry-run JSONL (out: $(cat "$SCRATCH/run-c.out"))"
fi
inbox_dry=$(ls -1 "$SCRATCH/.orchestrator/comments/inbox/" 2>/dev/null | wc -l | tr -d ' ')
if [ "$inbox_dry" = "0" ]; then
  _pass "Case C: dry-run no inbox writes"
else
  _fail "Case C: dry-run wrote $inbox_dry files"
fi

echo "----"
echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
if [ "$fail" -gt 0 ]; then exit 1; fi
echo "PASS: $(basename "$0")"
exit 0
