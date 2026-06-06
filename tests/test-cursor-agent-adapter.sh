#!/usr/bin/env bash
# tests/test-cursor-agent-adapter.sh — M009 Tier-A acceptance suite
#
# Hermetic acceptance test for the cursor-agent dispatch backend adapter
# (scripts/dispatch/adapters/backend/cursor-agent.sh). Stubs the
# `cursor-agent` binary so the suite runs with NO live CLI, NO network,
# and NO Cursor account — it is safe in CI and on Claude-Code-only machines.
#
# Covers (brief FR-1..FR-2 + SC-003 + risk-6 default-hijack guard):
#   - probe gating: not-opted-in / no-binary / opted-in+authed
#   - registry discovery + NO default-backend hijack without opt-in
#   - success path           -> status:"success" + embedded result JSON
#   - runtime-error (mode 2)  -> exit 0 + is_error:true => status:"failure"
#   - preflight-error (mode 1)-> non-zero exit + stderr => status:"failure"
#   - dispatch-interface routing via explicit --backend cursor-agent
#
# Conventions: pass()/fail() counters, PASS:/FAIL: lines, exit 1 on any fail.
# Bash 3.2 compatible.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ADAPTER="$PROJECT_ROOT/scripts/dispatch/adapters/backend/cursor-agent.sh"
REGISTRY="$PROJECT_ROOT/scripts/dispatch/backend-registry.sh"
INTERFACE="$PROJECT_ROOT/scripts/dispatch/dispatch-interface.sh"
GOLDEN_JSON="$PROJECT_ROOT/.orchestrator/milestones/M009/probe-fixtures/cursor-agent-success.json"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1"; }

# --- Scratch area + cursor-agent stub --------------------------------------
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

STUB_BIN="$WORK/bin"
mkdir -p "$STUB_BIN"
STUB="$STUB_BIN/cursor-agent"
cat > "$STUB" <<'STUBEOF'
#!/usr/bin/env bash
# Hermetic cursor-agent stub. `status` => logged-in; otherwise a dispatch run
# whose behavior is selected by CURSOR_STUB_MODE (success|runtime-error|preflight-fail).
case "${1:-}" in
  status|whoami) echo "Logged in as stub@example.com"; exit 0 ;;
  --version|-v)  echo "stub-0.0.0"; exit 0 ;;
esac
case "${CURSOR_STUB_MODE:-success}" in
  success)
    cat "${CURSOR_STUB_JSON_FILE:?CURSOR_STUB_JSON_FILE unset}"
    exit 0 ;;
  runtime-error)
    printf '%s\n' '{"type":"result","subtype":"error","is_error":true,"duration_ms":1,"result":"runtime boom","session_id":"s","request_id":"r","usage":{"inputTokens":1,"outputTokens":0,"cacheReadTokens":0,"cacheWriteTokens":0}}'
    exit 0 ;;
  preflight-fail)
    echo "Cannot use this model: bogus-model. Available models: auto, composer-2.5" >&2
    exit 1 ;;
esac
STUBEOF
chmod +x "$STUB"

# Fixtures: a minimal task plan + payload + intensity metadata.
PLAN="$WORK/task-plan.md"
PAYLOAD="$WORK/payload.md"
INTENSITY="$WORK/intensity.md"
cat > "$PLAN" <<'EOF'
---
task: "T01"
phase: "P01"
milestone: "M009"
---
# Task
Write the greeting file.
EOF
printf 'Create greeting.txt with "hi".\n' > "$PAYLOAD"
printf -- '---\nintensity: "quick"\n---\n' > "$INTENSITY"

# PATH with the stub shadowing any real cursor-agent; keep coreutils reachable.
STUB_PATH="$STUB_BIN:/usr/bin:/bin"
# PATH with NO cursor-agent anywhere (for the no-binary probe assertion).
NOBIN_PATH="/usr/bin:/bin"

run_adapter() { PATH="$STUB_PATH" CURSOR_STUB_JSON_FILE="$GOLDEN_JSON" bash "$ADAPTER" "$@"; }

# --- 0. Preconditions ------------------------------------------------------
if [ -f "$ADAPTER" ]; then pass "adapter file exists"; else fail "adapter file exists"; fi
if [ -f "$GOLDEN_JSON" ]; then pass "golden success fixture exists"; else fail "golden success fixture exists"; fi

# --- 1. Probe: not opted in (binary present via stub, but opt-in unset) ----
out="$(PATH="$STUB_PATH" ORCHESTRATOR_CURSOR_ENABLE= bash "$ADAPTER" --probe)"
echo "$out" | grep -q '^available=false'        && pass "probe: not-opted-in => available=false" || fail "probe: not-opted-in => available=false (got: $out)"
echo "$out" | grep -q '^reason=not-opted-in'    && pass "probe: not-opted-in reason" || fail "probe: not-opted-in reason (got: $out)"
echo "$out" | grep -q '^backend=cursor-agent'   && pass "probe: backend=cursor-agent" || fail "probe: backend label (got: $out)"

# --- 2. Probe: opted in but binary absent ----------------------------------
out="$(PATH="$NOBIN_PATH" ORCHESTRATOR_CURSOR_ENABLE=1 bash "$ADAPTER" --probe)"
echo "$out" | grep -q '^available=false'              && pass "probe: opted-in, no binary => available=false" || fail "probe: no-binary available=false (got: $out)"
echo "$out" | grep -q '^reason=cursor-agent-not-on-path' && pass "probe: no-binary reason" || fail "probe: no-binary reason (got: $out)"

# --- 3. Probe: opted in + binary + authed (stub) => available --------------
out="$(PATH="$STUB_PATH" ORCHESTRATOR_CURSOR_ENABLE=1 bash "$ADAPTER" --probe)"
echo "$out" | grep -q '^available=true'                 && pass "probe: opted-in+authed => available=true" || fail "probe: opted-in available=true (got: $out)"
echo "$out" | grep -q '^reason=opted-in-and-authenticated' && pass "probe: opted-in reason" || fail "probe: opted-in reason (got: $out)"

# --- 4. Registry discovers cursor-agent ------------------------------------
list="$(bash "$REGISTRY" --list)"
echo "$list" | grep -qx 'cursor-agent' && pass "registry --list includes cursor-agent" || fail "registry --list includes cursor-agent"

# --- 5. NO default-backend hijack without opt-in ---------------------------
# Even with the stub on PATH, default must NOT be cursor-agent when opt-in unset.
summary="$(PATH="$STUB_PATH" ORCHESTRATOR_CURSOR_ENABLE= bash "$REGISTRY")"
default="$(echo "$summary" | grep '^default_backend=' | cut -d= -f2)"
[ "$default" != "cursor-agent" ] && pass "no default hijack without opt-in (default=$default)" || fail "cursor-agent hijacked default without opt-in"
echo "$summary" | grep -q 'backends_discovered=.*cursor-agent' && pass "registry still discovers cursor-agent" || fail "registry discovers cursor-agent"

# --- 6. Success path: status:success + embedded result JSON ----------------
res="$(CURSOR_STUB_MODE=success run_adapter --task-plan "$PLAN" --payload "$PAYLOAD" --intensity-metadata "$INTENSITY")"
echo "$res" | grep -q '^type: "dispatch-result"'   && pass "success: type=dispatch-result" || fail "success: type frontmatter (got: $res)"
echo "$res" | grep -q '^status: "success"'         && pass "success: status=success" || fail "success: status (got: $res)"
echo "$res" | grep -q '^backend: "cursor-agent"'   && pass "success: backend=cursor-agent" || fail "success: backend"
echo "$res" | grep -q '"subtype":"success"'        && pass "success: embeds result JSON" || fail "success: embeds result JSON"
echo "$res" | grep -q 'NO file-diff fields'        && pass "success: documents no-file-diff read-back" || fail "success: no-file-diff note"
echo "$res" | grep -q '^task_id: "T01"'            && pass "success: task_id parsed from plan" || fail "success: task_id"

# --- 7. Runtime-error path (mode 2): exit 0 + is_error:true => failure ------
res="$(CURSOR_STUB_MODE=runtime-error run_adapter --task-plan "$PLAN" --payload "$PAYLOAD" --intensity-metadata "$INTENSITY")"
echo "$res" | grep -q '^status: "failure"' && pass "runtime-error: status=failure" || fail "runtime-error: status (got: $res)"
echo "$res" | grep -q 'runtime error'      && pass "runtime-error: notes the runtime error" || fail "runtime-error: note"

# --- 8. Preflight-error path (mode 1): non-zero exit + stderr => failure ----
res="$(CURSOR_STUB_MODE=preflight-fail run_adapter --task-plan "$PLAN" --payload "$PAYLOAD" --intensity-metadata "$INTENSITY")"
echo "$res" | grep -q '^status: "failure"'  && pass "preflight-error: status=failure" || fail "preflight-error: status (got: $res)"
echo "$res" | grep -q 'exited with code'    && pass "preflight-error: reports exit code" || fail "preflight-error: exit-code note"
echo "$res" | grep -q 'Cannot use this model' && pass "preflight-error: surfaces stderr detail" || fail "preflight-error: stderr detail"

# --- 9. dispatch-interface routes explicit --backend cursor-agent ----------
# The interface resolves the adapter by filename (SC-003) and validates the
# schema_version/type frontmatter; a passing result proves end-to-end routing.
iface="$(PATH="$STUB_PATH" CURSOR_STUB_MODE=success CURSOR_STUB_JSON_FILE="$GOLDEN_JSON" \
  bash "$INTERFACE" --task-plan "$PLAN" --payload "$PAYLOAD" --intensity-metadata "$INTENSITY" --backend cursor-agent 2>/dev/null)"
echo "$iface" | grep -q '^backend: "cursor-agent"' && pass "interface: routes to cursor-agent adapter" || fail "interface: routing (got: $iface)"
echo "$iface" | grep -q '^status: "success"'       && pass "interface: passes adapter result through" || fail "interface: passthrough"

# --- Summary ---------------------------------------------------------------
echo
echo "BATTERY: pass=${PASS_COUNT} fail=${FAIL_COUNT}"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
exit 0
