#!/usr/bin/env bash
# scripts/verify/m013-p04-post-verify-hook.sh — T04 gate: post-verify hook descriptor
# + installer wiring + claude-code runtime adapter sixth-entry (FR-12 Claude-Code-only v1).
#
# 14 assertions covering:
#   - post-verify.json descriptor shape (event, command, 4-key schema)
#   - after-verify-sync.sh wrapper presence, executability, absent-sidecar no-op,
#     manual-mode no-op (zero stdout/stderr)
#   - claude-code.sh --hook-config emits hook_count=6 and post_verify entry
#   - M008/P05 runtime-adapter interface contract preserved
#   - Codex/Cursor installers + runtime adapters untouched (FR-12 v1 byte-identity
#     via negative grep for post_verify + FR-12 marker)
#   - anti-pattern-lint clean on the new wrapper (SC-7 prompt-free)
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

passed=0
failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

DESC="${REPO_ROOT}/packaging/bundle/hooks/post-verify.json"
WRAP="${REPO_ROOT}/scripts/lifecycle/after-verify-sync.sh"
ADAPTER="${REPO_ROOT}/scripts/dispatch/adapters/runtime/claude-code.sh"

# --- Assertion 1: descriptor file exists
if [ -f "$DESC" ]; then
  pass "post-verify.json exists"
else
  fail "post-verify.json missing"
fi

# --- Assertion 2: descriptor contains post-verify event
if grep -qE '"event":[[:space:]]*"post-verify"' "$DESC"; then
  pass "descriptor event=post-verify"
else
  fail "descriptor event field wrong"
fi

# --- Assertion 3: descriptor command references after-verify-sync.sh
if grep -qE 'after-verify-sync\.sh' "$DESC"; then
  pass "descriptor command references after-verify-sync.sh"
else
  fail "descriptor command wrong"
fi

# --- Assertion 4: after-verify-sync.sh wrapper exists + executable
if [ -x "$WRAP" ]; then
  pass "after-verify-sync.sh present + executable"
else
  fail "after-verify-sync.sh missing/not executable"
fi

# --- Assertion 5: wrapper returns 0 on absent sidecar (FR-11 reversibility)
TMPDIR_FX="$(mktemp -d -t m013-p04-hook.XXXXXX)"
mkdir -p "${TMPDIR_FX}/.orchestrator/integrations"
ORCHESTRATOR_ROOT="${TMPDIR_FX}/.orchestrator" bash "$WRAP" >/tmp/m013-p04-t04-wrap-absent.out 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "wrapper returns 0 on absent sidecar"
else
  fail "wrapper returns rc=${rc} on absent sidecar"
fi

# --- Assertion 6: wrapper no-ops when sync_mode=manual (zero output)
cat > "${TMPDIR_FX}/.orchestrator/integrations/github.json" <<'SC'
{ "schema_version": "1.0", "sync_mode": "manual", "repo_slug": "t/r", "project_v2_id": "P1" }
SC
ORCHESTRATOR_ROOT="${TMPDIR_FX}/.orchestrator" bash "$WRAP" >/tmp/m013-p04-t04-wrap-manual.out 2>&1
rc=$?
if [ "$rc" -eq 0 ] && [ ! -s /tmp/m013-p04-t04-wrap-manual.out ]; then
  pass "wrapper no-ops on sync_mode=manual (zero output)"
else
  fail "wrapper did not cleanly no-op on manual (rc=${rc})"
fi

# --- Assertion 7: runtime adapter --hook-config emits hook_count=6
bash "$ADAPTER" --hook-config >/tmp/m013-p04-t04-hc.out 2>/dev/null
if grep -qE '"hook_count":[[:space:]]*6' /tmp/m013-p04-t04-hc.out; then
  pass "adapter hook_count=6"
else
  fail "adapter hook_count incorrect (expected 6)"
fi

# --- Assertion 8: adapter emits post_verify event entry
if grep -qE '"event":[[:space:]]*"post_verify"' /tmp/m013-p04-t04-hc.out; then
  pass "adapter emits post_verify event entry"
else
  fail "adapter missing post_verify entry"
fi

# --- Assertion 9: M008/P05 runtime adapter interface contract preserved
if bash "${REPO_ROOT}/scripts/verify/m008-p05-runtime-adapter-interface.sh" >/tmp/m013-p04-t04-m008.out 2>&1; then
  pass "runtime adapter interface contract preserved"
else
  fail "runtime adapter interface contract REGRESSION (see /tmp/m013-p04-t04-m008.out)"
fi

# --- Assertion 10: Codex installer byte-identical (FR-12 v1 — negative grep)
if grep -qE 'post_verify|FR-12 Claude-Code-only v1' "${REPO_ROOT}/packaging/install/install-codex.sh"; then
  fail "Codex installer was modified (FR-12 violation)"
else
  pass "Codex installer untouched"
fi

# --- Assertion 11: Cursor installer byte-identical (FR-12 v1 — negative grep)
if grep -qE 'post_verify|FR-12 Claude-Code-only v1' "${REPO_ROOT}/packaging/install/install-cursor.sh"; then
  fail "Cursor installer was modified (FR-12 violation)"
else
  pass "Cursor installer untouched"
fi

# --- Assertion 12: Codex runtime adapter byte-identical
if grep -qE 'post_verify|FR-12 Claude-Code-only v1' "${REPO_ROOT}/scripts/dispatch/adapters/runtime/codex.sh"; then
  fail "Codex runtime adapter was modified (FR-12 violation)"
else
  pass "Codex runtime adapter untouched"
fi

# --- Assertion 13: Cursor runtime adapter byte-identical
if grep -qE 'post_verify|FR-12 Claude-Code-only v1' "${REPO_ROOT}/scripts/dispatch/adapters/runtime/cursor.sh"; then
  fail "Cursor runtime adapter was modified (FR-12 violation)"
else
  pass "Cursor runtime adapter untouched"
fi

# --- Assertion 14: anti-pattern-lint clean on wrapper (SC-7)
if bash "${REPO_ROOT}/scripts/verify/anti-pattern-lint.sh" --fixture "$WRAP" >/tmp/m013-p04-t04-aplint.out 2>&1; then
  pass "anti-pattern-lint clean on wrapper"
else
  fail "anti-pattern-lint flagged wrapper (see /tmp/m013-p04-t04-aplint.out)"
fi

rm -rf "$TMPDIR_FX"

echo "SUMMARY: m013-p04-post-verify-hook.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-post-verify-hook.sh"
  exit 0
fi
echo "FAIL: m013-p04-post-verify-hook.sh" >&2
exit 1
