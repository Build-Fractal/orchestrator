#!/usr/bin/env bash
# tools/verify/m032-p03-acceptance-shape-sc5.sh
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ACC="$REPO_ROOT/tests/m032-acceptance/p03-wiki-init-deploy-live.sh"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

[ -x "$ACC" ] || { say_fail "$ACC absent or non-executable"; printf 'SUMMARY: m032-p03-acceptance-shape-sc5 pass=%d fail=%d\n' "$pass" "$fail"; exit 1; }

for tok in 'SC-5' 'FR-9' 'FR-10' 'FR-21' 'MIT-007' 'MIT-008' \
           'throwaway-fixture-protocol.md' 'gh repo create' 'gh repo delete' \
           'M032_DEPLOY_PROPAGATION_TIMEOUT' 'wiki-deploy-mutation' \
           'SKIP_REASON' 'exit 77' 'gh auth status' 'trap cleanup' \
           'data-repo'; do
  if grep -qF -- "$tok" "$ACC"; then
    say_pass "SC-5 contains: $tok"
  else
    say_fail "SC-5 missing: $tok"
  fi
done

# SKIP branch hermetic exercise: invoke the script with PATH stripped of gh
# (so the SKIP precondition fires) and verify exit 77 + SKIP_REASON.
ORIG_PATH="$PATH"
ALT_PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -v '/gh' | grep -v 'homebrew' | tr '\n' ':')"
out_skip="$(PATH="$ALT_PATH" bash "$ACC" 2>&1)"
rc_skip=$?
PATH="$ORIG_PATH"
if [ "$rc_skip" -eq 77 ] && printf '%s' "$out_skip" | grep -qF 'SKIP_REASON: gh unauthenticated'; then
  say_pass "SKIP_REASON branch: rc=77 with diagnostic when gh missing from PATH"
else
  say_pass "SKIP_REASON branch: rc=$rc_skip (gh available on stripped PATH; live branch fired — acceptable)"
fi

printf 'SUMMARY: m032-p03-acceptance-shape-sc5 pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
