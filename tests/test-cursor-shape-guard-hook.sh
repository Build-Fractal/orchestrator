#!/usr/bin/env bash
# tests/test-cursor-shape-guard-hook.sh — M009 FR-3 acceptance suite
#
# Hermetic tests for the Cursor beforeShellExecution shape-guard:
#   - scripts/hooks/cursor-before-shell-shape-guard.sh translation logic
#   - cursor.sh --hook-config real hooks.json emission
#   - cursor.sh --probe CURSOR_AGENT runtime detection
# No live cursor-agent needed (the live end-to-end block is demonstrated
# separately and recorded in the M009 findings note).
#
# Conventions: pass()/fail() counters, PASS:/FAIL: lines, exit 1 on any fail.
# Bash 3.2 compatible.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WRAPPER="$PROJECT_ROOT/scripts/hooks/cursor-before-shell-shape-guard.sh"
ADAPTER="$PROJECT_ROOT/scripts/dispatch/adapters/runtime/cursor.sh"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1"; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# run_wrapper <json>  -> sets OUT (stdout) and RC (exit code)
run_wrapper() {
  OUT="$(printf '%s' "$1" | bash "$WRAPPER" 2>/dev/null)"
  RC=$?
}

# --- 0. Preconditions ------------------------------------------------------
[ -f "$WRAPPER" ] && pass "wrapper exists" || fail "wrapper exists"
[ -f "$ADAPTER" ] && pass "adapter exists" || fail "adapter exists"

# --- 1. Allow: a benign single command -------------------------------------
run_wrapper '{"command":"echo hi > x.txt","hook_event_name":"beforeShellExecution","cwd":"/tmp"}'
echo "$OUT" | grep -q '"permission":"allow"' && pass "allow: benign command => permission allow" || fail "allow: benign (got: $OUT)"
[ "$RC" -eq 0 ] && pass "allow: exit 0" || fail "allow: exit 0 (got $RC)"

# --- 2. Deny: compound-chain-gt2 (a rejected shape) ------------------------
run_wrapper '{"command":"cd /x && rm y && ls z","hook_event_name":"beforeShellExecution"}'
echo "$OUT" | grep -q '"permission":"deny"' && pass "deny: compound chain => permission deny" || fail "deny: compound chain (got: $OUT)"
echo "$OUT" | grep -q 'compound-chain-gt2' && pass "deny: names the pattern class" || fail "deny: pattern class"
echo "$OUT" | grep -q 'run-probe.sh' && pass "deny: points to the wrapper remedy" || fail "deny: remedy"
[ "$RC" -eq 2 ] && pass "deny: exit 2 (surfaces diagnostic to agent)" || fail "deny: exit 2 (got $RC)"

# --- 3. Non-shell event => passthrough allow -------------------------------
run_wrapper '{"command":"cd /x && rm y && ls z","hook_event_name":"beforeReadFile"}'
echo "$OUT" | grep -q '"permission":"allow"' && pass "non-shell event => allow passthrough" || fail "non-shell event (got: $OUT)"

# --- 4. Empty stdin => allow (fail-open) -----------------------------------
OUT="$(printf '' | bash "$WRAPPER" 2>/dev/null)"; RC=$?
echo "$OUT" | grep -q '"permission":"allow"' && pass "empty stdin => allow" || fail "empty stdin (got: $OUT)"

# --- 5. Missing classifier => fail-OPEN (allow) ----------------------------
# Copy the wrapper alone into an isolated tree where neither classifier
# resolution path resolves, and confirm it allows rather than hard-failing.
mkdir -p "$WORK/iso/scripts/hooks"
cp "$WRAPPER" "$WORK/iso/scripts/hooks/cursor-before-shell-shape-guard.sh"
OUT="$(printf '%s' '{"command":"cd /x && rm y && ls z","hook_event_name":"beforeShellExecution"}' | bash "$WORK/iso/scripts/hooks/cursor-before-shell-shape-guard.sh" 2>/dev/null)"; RC=$?
echo "$OUT" | grep -q '"permission":"allow"' && pass "missing classifier => fail-open allow" || fail "fail-open (got: $OUT)"
[ "$RC" -eq 0 ] && pass "fail-open: exit 0" || fail "fail-open exit 0 (got $RC)"

# --- 6. Adapter --hook-config emits a real hooks.json ----------------------
hc="$(bash "$ADAPTER" --hook-config --project-dir "$WORK/proj" 2>/dev/null)"
echo "$hc" | grep -q '"beforeShellExecution"' && pass "hook-config: wires beforeShellExecution" || fail "hook-config: beforeShellExecution (got: $hc)"
echo "$hc" | grep -q 'cursor-before-shell-shape-guard.sh' && pass "hook-config: references the guard wrapper" || fail "hook-config: guard ref"
echo "$hc" | grep -q "$WORK/proj/scripts/hooks/" && pass "hook-config: resolves project-relative guard path" || fail "hook-config: path"
echo "$hc" | grep -q 'hooks_supported = "false"' && fail "hook-config: STILL emits stale hooks_supported=false" || pass "hook-config: stale hooks_supported=false removed"

# --- 7. Adapter --probe detects the CURSOR_AGENT headless runtime ----------
pr="$(env -u CURSOR_TRACE_ID -u CURSOR_SESSION_ID -u CURSOR_USER CURSOR_AGENT=1 bash "$ADAPTER" --probe --project-dir "$WORK/empty" 2>/dev/null)"
echo "$pr" | grep -q '^available=true' && pass "probe: CURSOR_AGENT=1 => available" || fail "probe: CURSOR_AGENT (got: $pr)"
echo "$pr" | grep -q 'CURSOR_AGENT' && pass "probe: reason names CURSOR_AGENT" || fail "probe: reason (got: $pr)"

echo
echo "BATTERY: pass=${PASS_COUNT} fail=${FAIL_COUNT}"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
exit 0
