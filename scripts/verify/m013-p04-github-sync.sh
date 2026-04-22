#!/usr/bin/env bash
# scripts/verify/m013-p04-github-sync.sh — T02 gate: github-sync.sh core
# shape assertions + fixture-driven --dry-run manifest byte-identity.
#
# Bash 3.2 compatible. AD-19 single-script-file shape. No process
# substitution, no compound chains, no command substitutions of pipelines
# in Check: commands.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FX="${REPO_ROOT}/tests/fixtures/m013-p04/sync-cycle"
SYNC="${REPO_ROOT}/scripts/integrations/github-sync.sh"

passed=0
failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }

# Assertion 1: script exists + is executable
if [ -x "$SYNC" ]; then
  pass "github-sync.sh present + executable"
else
  fail "github-sync.sh missing or not executable"
fi

# Assertion 2: script sources github-common.sh
if grep -qE '^\. .*github-common\.sh"?$' "$SYNC"; then
  pass "github-common.sh sourced"
elif grep -qE '^source .*github-common\.sh' "$SYNC"; then
  pass "github-common.sh sourced"
else
  fail "github-common.sh not sourced"
fi

# Assertion 3: script contains updateProjectV2ItemFieldValue mutation shape
if grep -qE 'mutation.*\{.*updateProjectV2ItemFieldValue' "$SYNC"; then
  pass "updateProjectV2ItemFieldValue mutation shape present"
else
  fail "updateProjectV2ItemFieldValue mutation shape missing"
fi

# Assertion 4: FR-5 lint still passes with the new mutation
if bash "${REPO_ROOT}/scripts/verify/graphql-call-shape.sh" >/dev/null 2>&1; then
  pass "FR-5 lint green with new mutation"
else
  fail "FR-5 lint REGRESSION on new mutation"
fi

# Assertion 5: script invokes lock-manager (create subcommand). Accept either
# a literal `lock-manager.sh ... create` invocation or the idiomatic shape
# where a LOCK_MGR variable points at lock-manager.sh and is invoked with
# `create` on a later line — the contract is "lock-manager.sh is called with
# the create op", not a stylistic one-line match.
has_lit_create=0
has_var_lockmgr=0
has_var_create=0
if grep -qE 'lock-manager\.sh.*create' "$SYNC"; then
  has_lit_create=1
fi
if grep -qE 'LOCK_MGR=.*lock-manager\.sh' "$SYNC"; then
  has_var_lockmgr=1
fi
if grep -qE 'bash .*LOCK_MGR.* create' "$SYNC"; then
  has_var_create=1
fi
if [ "$has_lit_create" -eq 1 ]; then
  pass "lock-manager.sh invoked"
elif [ "$has_var_lockmgr" -eq 1 ] && [ "$has_var_create" -eq 1 ]; then
  pass "lock-manager.sh invoked (via LOCK_MGR variable)"
else
  fail "lock-manager.sh not invoked"
fi

# Assertion 6: EXIT trap set for lock release
if grep -qE "trap.*release_lock.*EXIT" "$SYNC"; then
  pass "EXIT trap releases lock"
else
  fail "EXIT trap missing"
fi

# Assertion 7: auto-mode short-circuit present
if grep -qE 'pending-operator-complete' "$SYNC"; then
  pass "auto-mode short-circuit present"
else
  fail "auto-mode short-circuit missing"
fi

# Assertion 8: --dry-run flag recognized in help output
bash "$SYNC" --help >/tmp/t02-sync-help.out 2>&1 || true
if grep -q -- "--dry-run" /tmp/t02-sync-help.out; then
  pass "--dry-run in help"
else
  fail "--dry-run not in help"
fi

# Assertion 9a + 9b: auto-mode (no TTY + no --i-am-operator) exits 0 with
# pending-sentinel STATUS line AND issues ZERO gh calls.
shim_dir="$(mktemp -d -t m013-p04-t02-shim.XXXXXX)"
call_log="${shim_dir}/calls.log"
: > "$call_log"
cat > "${shim_dir}/gh" <<'SHIM'
#!/usr/bin/env bash
printf 'gh %s\n' "$*" >> "${SHIM_CALL_LOG:-/tmp/gh-calls.log}"
exit 0
SHIM
chmod +x "${shim_dir}/gh"
PATH="${shim_dir}:${PATH}" SHIM_CALL_LOG="$call_log" \
  bash "$SYNC" --root "${FX}/orchestrator-state" --dry-run \
  </dev/null >/tmp/t02-automode.out 2>&1 || true
if grep -q 'pending-operator-complete' /tmp/t02-automode.out; then
  pass "auto-mode emits pending-sentinel"
else
  fail "auto-mode did NOT emit pending-sentinel"
fi
if [ -s "$call_log" ]; then
  call_count="$(wc -l < "$call_log" | tr -d ' ')"
  fail "auto-mode issued ${call_count} gh calls (should be zero)"
else
  pass "zero gh calls under auto-mode"
fi

# Assertion 10-13: dry-run fixture run (operator mode, stub-selector set).
export M013_GH_STUB_DIR="${FX}/gh-stub-responses"
bash "$SYNC" --root "${FX}/orchestrator-state" --i-am-operator \
  --repo-slug test/sync-fixture --dry-run \
  >/tmp/t02-manifest-actual.out 2>/dev/null || true

# Assertion 10: dry-run manifest header emitted
if grep -qE '^DRY-RUN:' /tmp/t02-manifest-actual.out; then
  pass "dry-run manifest header emitted"
else
  fail "dry-run manifest header missing"
fi

# Assertion 11: manifest contains UPSERT rows with the pinned shape
if grep -qE '^UPSERT: [a-z\-]+ [^ ]+ [^ ]+ [a-z\-]+$' /tmp/t02-manifest-actual.out; then
  pass "UPSERT rows present"
else
  fail "no UPSERT rows"
fi

# Assertion 12: footer has P02 3-field shape (no adopted= suffix)
if grep -qE '^upserts=[0-9]+ skipped=[0-9]+ errors=[0-9]+$' /tmp/t02-manifest-actual.out; then
  pass "footer has P02 3-field shape"
else
  fail "footer shape mismatch"
fi

# Assertion 13: byte-identical diff vs expected snapshot (AD-19 temp-file +
# diff shape — NO process substitution).
if diff "${FX}/expected-sync-dryrun-manifest.txt" /tmp/t02-manifest-actual.out \
    >/tmp/t02-manifest-diff.out 2>&1; then
  pass "manifest byte-identical to expected snapshot"
else
  fail "manifest diff vs expected snapshot (see /tmp/t02-manifest-diff.out)"
fi

rm -rf "$shim_dir"

echo "SUMMARY: m013-p04-github-sync.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-github-sync.sh"
  exit 0
fi
echo "FAIL: m013-p04-github-sync.sh" >&2
exit 1
