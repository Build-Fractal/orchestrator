#!/usr/bin/env bash
# tools/verify/m046-p05-sc5-write-tool-scope.sh
#   M046/P05/T04 -- SC-5 MILESTONE-BLOCKING, NON-STUBBED write/Bash/MCP scope gate.
#
# Proves that a real self-continuing UNATTENDED child, driven through the LIVE
# production PreToolUse hook installed via the REAL M028 install path, is
# BLOCKED (exit 2) on all THREE out-of-scope vectors:
#     (a) an out-of-scope Write (path outside the allow_path work dir),
#     (b) an out-of-scope Bash `git push`,
#     (c) an out-of-scope `mcp__*` tool call.
# The MCP vector is a FIRST-CLASS DENY assertion inside the milestone-blocking
# summary (Problem Statement Gap 2), not a non-blocking example.
#
# HONEST-REALISM DESIGN (why no live remote MCP round-trip):
#   A full `claude -p` agent making a live remote MCP call would need real
#   credentials + network + a connected MCP server -- exactly the surface this
#   hook forbids -- and REACHING the server would prove the hook FAILED. A
#   Claude Code PreToolUse deny fires BEFORE tool dispatch; that exit-2 block IS
#   the containment. So the enforcement path is exercised end-to-end with NO
#   stub in it, and the MCP proof is the exit-2 block, never a network call:
#     1. Real install wiring   -- the REAL install-claude-code.sh genuinely
#        stages the production hook into an ISOLATED scratch HOME's
#        .claude/orchestrator-hooks/ and genuinely merges its
#        `Write|Edit|Bash|mcp__.*` matcher into that HOME's settings.json.
#     2. Real matcher routing  -- the merged settings.json PreToolUse wrapper
#        whose matcher contains `mcp__.*` is parsed and its command is confirmed
#        to resolve to our staged unattended-scope-guard.sh (the wiring is LIVE,
#        not assumed): a real child's mcp__* tool_use WOULD route to this hook.
#     3. Real per-run policy   -- composed via the T03 envelope_write_scope_policy
#        function (the same code the driver runs), exported as
#        ORCHESTRATOR_UNATTENDED_POLICY. NOT a hand-built fixture policy.
#     4. Real hook contract    -- the genuinely-installed hook (resolved from
#        settings.json) is driven via the authentic Claude Code PreToolUse
#        stdin->exit-2 contract with ORCHESTRATOR_UNATTENDED=1, using authentic
#        PreToolUse JSON envelopes. The only non-live element is that no remote
#        MCP server is contacted -- which is definitionally correct.
#
# Env-gate leg: the SAME live installed hook, run with ORCHESTRATOR_UNATTENDED
# UNSET, no-ops (exit 0) on all three vectors -- the operator's interactive
# session is never constrained (D017, safety-critical).
#
# ISOLATION: the installer wires a deny-hook into settings.json, so it MUST run
# against an isolated scratch HOME under a mktemp prefix. A mandatory self-check
# refuses to run if HOME is not under the scratch dir. rm -rf on EXIT. The
# operator's real ~/.claude is NEVER touched.
#
# Single-script, AD-19 compliant (the AD-19 constraint governs Truth `Check:`
# lines; heredocs + pipes inside a verifier body are fine). Bash 3.2. No jq.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/m046-p05-sc5.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT

HOME_ISO="$SCRATCH/home"
mkdir -p "$HOME_ISO/.claude"
PROJ="$SCRATCH/project"
mkdir -p "$PROJ"

PASS=0
FAIL=0
DENY_MISSED=0   # a single missed milestone-blocking DENY fails the gate

pass() { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); echo "    FAIL-DETAIL: $*"; }

# -----------------------------------------------------------------------------
# MANDATORY isolation self-check -- refuse to run if HOME is not under $SCRATCH.
# The operator's real ~/.claude must never receive a deny-hook wiring.
# -----------------------------------------------------------------------------
case "$HOME_ISO" in
  "$SCRATCH"/*) : ;;
  *)
    echo "FAIL: isolation self-check -- HOME_ISO ($HOME_ISO) not under SCRATCH ($SCRATCH)"
    echo "SUMMARY: pass=0 fail=1"
    exit 1
    ;;
esac
echo "isolation=ok home_iso=$HOME_ISO scratch=$SCRATCH"

# -----------------------------------------------------------------------------
# REAL install wiring: run the production installer into the isolated HOME so
# the production hook is genuinely staged + its matcher genuinely merged.
# -----------------------------------------------------------------------------
HOME="$HOME_ISO" bash "$REPO_ROOT/packaging/install/install-claude-code.sh" \
  --project-dir "$PROJ" > "$SCRATCH/install.out" 2>&1
install_rc=$?
if [ "$install_rc" -eq 0 ]; then
  echo "install=ok rc=0"
  pass
else
  echo "install=FAIL rc=$install_rc"
  fail "installer exited $install_rc; see below"
  sed -e 's/^/    install.out: /' "$SCRATCH/install.out"
fi

HOOKS_DIR="$HOME_ISO/.claude/orchestrator-hooks"
SETTINGS="$HOME_ISO/.claude/settings.json"
GUARD="$HOOKS_DIR/unattended-scope-guard.sh"

# -----------------------------------------------------------------------------
# Assert the production hook was genuinely staged + is executable.
# -----------------------------------------------------------------------------
if [ -x "$GUARD" ]; then
  echo "staged-hook=ok guard=$GUARD"
  pass
else
  echo "staged-hook=FAIL guard=$GUARD"
  fail "installed scope guard missing or non-executable at $GUARD"
fi

# -----------------------------------------------------------------------------
# REAL matcher routing: the settings.json PreToolUse wrapper whose matcher
# contains mcp__.* must point at OUR staged hook. Two independent presence
# greps PLUS a same-wrapper extraction that proves the deny will come from real
# wiring (the mcp-covering wrapper's command resolves to the staged guard).
# -----------------------------------------------------------------------------
if [ -f "$SETTINGS" ] && grep -F "mcp__.*" "$SETTINGS" >/dev/null 2>&1; then
  echo "matcher-present=ok token=mcp__.*"
  pass
else
  echo "matcher-present=FAIL token=mcp__.*"
  fail "mcp__.* matcher absent from $SETTINGS"
fi

if [ -f "$SETTINGS" ] && grep -F "bash $GUARD" "$SETTINGS" >/dev/null 2>&1; then
  echo "guard-command-present=ok"
  pass
else
  echo "guard-command-present=FAIL"
  fail "guard command 'bash $GUARD' absent from $SETTINGS"
fi

# Same-wrapper proof: extract the `command` belonging to the PreToolUse wrapper
# whose matcher contains mcp__.* and confirm it resolves to the staged guard.
# Serializer-agnostic (python-json / jq -S both emit 2-space pretty JSON):
# walk PreToolUse array elements by brace depth; for the wrapper carrying
# mcp__.*, print its command line.
MCP_CMD_LINE="$(awk '
  BEGIN { inpre = 0; arrdepth = 0; collecting = 0; depth = 0; buf = ""; cmdline = "" }
  {
    if (inpre == 0) {
      if ($0 ~ /"PreToolUse"[[:space:]]*:/) {
        inpre = 1
        o = $0; naopen = gsub(/\[/, "", o); o = $0; naclose = gsub(/\]/, "", o)
        arrdepth = naopen - naclose
      }
      next
    }
    # inside PreToolUse array region -- maintain array-bracket depth to know
    # when the array closes (so we do not bleed into later settings keys).
    o = $0; nbopen = gsub(/{/, "", o); o = $0; nbclose = gsub(/}/, "", o)
    if (collecting == 0 && nbopen > 0) { collecting = 1; depth = 0; buf = ""; cmdline = "" }
    if (collecting == 1) {
      buf = buf $0 "\n"
      if ($0 ~ /"command"[[:space:]]*:/) { cmdline = $0 }
      depth += nbopen - nbclose
      if (depth <= 0) {
        if (buf ~ /mcp__\.\*/) { print cmdline }
        collecting = 0
      }
    }
    ab = $0; naopen = gsub(/\[/, "", ab); ab = $0; naclose = gsub(/\]/, "", ab)
    arrdepth += naopen - naclose
    if (arrdepth <= 0) { inpre = 0 }
  }
' "$SETTINGS" 2>/dev/null)"

# Pull the JSON string value after "command":
MCP_CMD="$(printf '%s' "$MCP_CMD_LINE" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
if [ "$MCP_CMD" = "bash $GUARD" ] && [ -x "$GUARD" ]; then
  echo "routing-is-real=ok mcp_wrapper_command=[$MCP_CMD] resolves-to-staged-hook=yes"
  pass
else
  echo "routing-is-real=FAIL mcp_wrapper_command=[$MCP_CMD] expected=[bash $GUARD]"
  fail "the mcp__.* wrapper command does not resolve to the staged guard"
fi

# -----------------------------------------------------------------------------
# REAL per-run policy: compose via the T03 envelope function (the driver's
# code), exported to the hook as ORCHESTRATOR_UNATTENDED_POLICY. allow_path is
# $PROJ/, so any write outside $PROJ is out-of-scope; no allow_tool => MCP deny.
# -----------------------------------------------------------------------------
# shellcheck disable=SC1090
. "$REPO_ROOT/scripts/lifecycle/unattended-envelope.sh"
POLICY="$SCRATCH/policy"
mkdir -p "$SCRATCH/mdir"
envelope_write_scope_policy \
  "$POLICY" \
  "$PROJ" \
  "$REPO_ROOT/scripts/hooks/unattended-protected-surface.txt" \
  "$SCRATCH/mdir" \
  "$SCRATCH/mdir/NO-ROADMAP.md" \
  ""
if [ -r "$POLICY" ] && grep -Fq "allow_path $PROJ/" "$POLICY"; then
  echo "policy-composed=ok policy=$POLICY"
  pass
else
  echo "policy-composed=FAIL policy=$POLICY"
  fail "envelope_write_scope_policy did not produce a readable allow_path policy"
fi

# -----------------------------------------------------------------------------
# Authentic PreToolUse envelope fixtures (heredocs are fine inside a verifier).
# -----------------------------------------------------------------------------
cat > "$SCRATCH/oos-write.json" <<'JSON'
{"tool_name":"Write","tool_input":{"file_path":"/etc/evil.txt","content":"x"}}
JSON
cat > "$SCRATCH/oos-bash-gitpush.json" <<'JSON'
{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}
JSON
cat > "$SCRATCH/oos-mcp.json" <<'JSON'
{"tool_name":"mcp__slack__post_message","tool_input":{"channel":"x","text":"y"}}
JSON
# Positive control: in-scope allowlisted Write to the work dir ($PROJ). Built
# with the REAL $PROJ substituted so the allow_path prefix matches.
printf '{"tool_name":"Write","tool_input":{"file_path":"%s/note.txt","content":"x"}}\n' \
  "$PROJ" > "$SCRATCH/inscope-write.json"

# drive_deny <name> <vector> <expected-exit> <payload>
#   Runs the LIVE installed hook with ORCHESTRATOR_UNATTENDED=1 + the real
#   policy. Emits the milestone-blocking case line and tracks DENY misses.
drive_deny() {
  _name="$1"; _vec="$2"; _exp="$3"; _pl="$4"
  ORCHESTRATOR_UNATTENDED=1 ORCHESTRATOR_UNATTENDED_POLICY="$POLICY" \
    bash "$GUARD" < "$_pl" > /dev/null 2> "$SCRATCH/.stderr"
  _act=$?
  if [ "$_act" -eq "$_exp" ]; then
    _res="PASS"; pass
  else
    _res="FAIL"; fail "case=$_name expected exit $_exp got $_act"
    [ "$_exp" -eq 2 ] && DENY_MISSED=$((DENY_MISSED + 1))
  fi
  echo "case=$_name vector=$_vec expected=$_exp actual=$_act result=$_res"
  if [ "$_res" = "FAIL" ] && [ -s "$SCRATCH/.stderr" ]; then
    sed -e 's/^/    reason: /' "$SCRATCH/.stderr"
  fi
  rm -f "$SCRATCH/.stderr"
}

# drive_envgate <name> <payload>
#   SAME live hook, ORCHESTRATOR_UNATTENDED deliberately UNSET: must no-op
#   (exit 0) even for clearly out-of-scope calls (attended session unconstrained).
drive_envgate() {
  _name="$1"; _pl="$2"
  ORCHESTRATOR_UNATTENDED_POLICY="$POLICY" \
    bash "$GUARD" < "$_pl" > /dev/null 2>&1
  _act=$?
  if [ "$_act" -eq 0 ]; then
    _res="PASS"; pass
  else
    _res="FAIL"; fail "env-gate case=$_name expected no-op exit 0 got $_act"
  fi
  echo "case=$_name vector=env-gate expected=0 actual=$_act result=$_res"
}

echo "--- MILESTONE-BLOCKING DENY leg (ORCHESTRATOR_UNATTENDED=1, live installed hook) ---"
drive_deny oos-write        write   2 "$SCRATCH/oos-write.json"
drive_deny oos-bash-gitpush bash    2 "$SCRATCH/oos-bash-gitpush.json"
drive_deny oos-mcp          mcp     2 "$SCRATCH/oos-mcp.json"
drive_deny inscope-write    control 0 "$SCRATCH/inscope-write.json"

echo "--- ENV-GATE leg (ORCHESTRATOR_UNATTENDED unset, same live hook -- must no-op) ---"
drive_envgate oos-write        "$SCRATCH/oos-write.json"
drive_envgate oos-bash-gitpush "$SCRATCH/oos-bash-gitpush.json"
drive_envgate oos-mcp          "$SCRATCH/oos-mcp.json"

echo "SUMMARY: pass=$PASS fail=$FAIL"
if [ "$FAIL" -eq 0 ] && [ "$DENY_MISSED" -eq 0 ]; then
  exit 0
fi
echo "GATE: milestone-blocking SC-5 FAILED (fail=$FAIL deny_missed=$DENY_MISSED)"
exit 1
