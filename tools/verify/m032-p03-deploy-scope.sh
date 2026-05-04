#!/usr/bin/env bash
# tools/verify/m032-p03-deploy-scope.sh — FR-9 + MIT-007 + MIT-008 verifier.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WI="$REPO_ROOT/scripts/lifecycle/wiki-init.sh"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# Static text checks for the FR-9 + MIT-007 + MIT-008 surface.
for tok in '--deploy' '--force-pages-reconfigure' 'M032_DEPLOY_GH_API_STUB' \
           'M032_DEPLOY_GH_API_STUB_DIR' 'wiki-deploy-mutation' \
           'discussions_enabled' 'gh_pages_branch_created' 'pages_source_configured' \
           'pages-already-configured' 'has_discussions=true' \
           'audit_failure' 'execution-log.jsonl' 'MIT-007' 'MIT-008' 'FR-9'; do
  if grep -qF -e "$tok" "$WI"; then
    say_pass "wiki-init.sh contains: $tok"
  else
    say_fail "wiki-init.sh missing: $tok"
  fi
done

# Hermetic stub-mode: happy path (no existing Pages).
TMPDIR_F=$(mktemp -d -t m032-p03-deploy.XXXXXX)
trap 'rm -rf "$TMPDIR_F"' EXIT
mkdir -p "$TMPDIR_F/.orchestrator"
(cd "$TMPDIR_F" && git init -q && git remote add origin https://github.com/fixture-owner/m032-p03-deploy.git)

M032_DEPLOY_GH_API_STUB=1 bash "$WI" --deploy --project-dir "$TMPDIR_F" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ] && [ -f "$TMPDIR_F/.orchestrator/execution-log.jsonl" ] && \
   grep -qF '"event_type":"wiki-deploy-mutation"' "$TMPDIR_F/.orchestrator/execution-log.jsonl" && \
   grep -qF '"result":"success"' "$TMPDIR_F/.orchestrator/execution-log.jsonl" && \
   grep -qF '"discussions_enabled"' "$TMPDIR_F/.orchestrator/execution-log.jsonl" && \
   grep -qF '"pages_source_configured"' "$TMPDIR_F/.orchestrator/execution-log.jsonl"; then
  say_pass "stub happy path: rc=0, audit record present with all three mutations"
else
  say_fail "stub happy path: rc=$rc; audit record absent or missing mutations"
fi

# Hermetic stub-mode: Pages already configured for gh-pages root → no-op skip-PUT.
STUB_DIR=$(mktemp -d -t m032-p03-deploy-stub.XXXXXX)
printf '{"source":{"branch":"gh-pages","path":"/"},"html_url":"https://example.github.io/x/"}' \
  > "$STUB_DIR/pages-get.json"
rm -f "$TMPDIR_F/.orchestrator/execution-log.jsonl"
M032_DEPLOY_GH_API_STUB=1 M032_DEPLOY_GH_API_STUB_DIR="$STUB_DIR" bash "$WI" --deploy --project-dir "$TMPDIR_F" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ] && grep -qF '"discussions_enabled"' "$TMPDIR_F/.orchestrator/execution-log.jsonl" && \
   grep -qF '"gh_pages_branch_created"' "$TMPDIR_F/.orchestrator/execution-log.jsonl" && \
   ! grep -qF '"pages_source_configured"' "$TMPDIR_F/.orchestrator/execution-log.jsonl"; then
  say_pass "stub MIT-007 no-op: rc=0, audit record omits pages_source_configured (true no-op skip-PUT)"
else
  say_fail "stub MIT-007 no-op: rc=$rc; audit record shape unexpected"
fi
rm -rf "$STUB_DIR"

# Hermetic stub-mode: Pages incompatible source without --force-pages-reconfigure → exit 12.
STUB_DIR=$(mktemp -d -t m032-p03-deploy-incompat.XXXXXX)
printf '{"source":{"branch":"main","path":"/docs"},"html_url":"https://example.github.io/x/"}' \
  > "$STUB_DIR/pages-get.json"
rm -f "$TMPDIR_F/.orchestrator/execution-log.jsonl"
err_out="$(M032_DEPLOY_GH_API_STUB=1 M032_DEPLOY_GH_API_STUB_DIR="$STUB_DIR" bash "$WI" --deploy --project-dir "$TMPDIR_F" 2>&1)"
rc=$?
if [ "$rc" -eq 12 ] && \
   printf '%s' "$err_out" | grep -qF 'existing Pages deployment from a different source' && \
   grep -qF '"result":"failure"' "$TMPDIR_F/.orchestrator/execution-log.jsonl"; then
  say_pass "stub MIT-007 incompatible: rc=12, diagnostic emitted, failure audit record appended"
else
  say_fail "stub MIT-007 incompatible: rc=$rc; expected exit 12 + diagnostic + failure record"
fi
rm -rf "$STUB_DIR"

printf 'SUMMARY: m032-p03-deploy-scope pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
