#!/usr/bin/env bash
# scripts/lifecycle/review-gate-mcp-server.sh — M034 P03 (FR-10 Cursor MCP renderer).
#
# Orchestrator-owned stdio MCP review-gate server. Exposes review gates via the
# JSON-RPC `elicitation/create` server->client request. Registered in
# .cursor/mcp.json (CON-6); Cursor spawns it per session and tears it down on
# stdin EOF (#Q-5 / D-P03-3 — no long-lived daemon, state is filesystem-scoped
# via resolve-root.sh).
#
# PURE TRANSPORT (AD-1 / D-P03-2): the server NEVER writes REVIEW.md/SIGNOFF.md
# itself. It collects elicitation responses and delegates to the P02
# interactive-review.sh stage:
#   - accept  -> build the PC-3 recorded-response fixture, call
#                interactive-review.sh --test-responses (byte-identical to CC).
#   - decline / cancel / read-timeout / elicitation-capability-absent
#             -> ORCH_HEADLESS=1 interactive-review.sh --policy=<declared>
#                (the headless auto-mode policy path; FR-8; writes QUESTIONS.md
#                on the capability-absent degrade — the spec edge case).
#
# stdio transport = newline-delimited JSON-RPC. The elicitation exchange is
# strictly SEQUENTIAL (send request, read response on the same stdin), so no
# concurrent I/O is needed — bash read/printf + jq suffice (D-P03-1).
#
# CON-1: bash 3.2 / POSIX-sh single file. jq REQUIRED (same posture as
# interactive-review.sh).

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
INTERACTIVE_REVIEW="$SCRIPT_DIR/interactive-review.sh"
READER="$REPO_ROOT/scripts/knowledge/read-decisions.sh"
RESOLVE_ROOT="$REPO_ROOT/scripts/state/resolve-root.sh"

# Bounded read for elicitation responses (no-hang guarantee). Override for tests.
ELICIT_TIMEOUT="${ORCH_MCP_ELICIT_TIMEOUT:-25}"

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' '{"jsonrpc":"2.0","id":null,"error":{"code":-32099,"message":"review-gate-mcp-server requires jq"}}'
  exit 1
fi

# --- JSON-RPC I/O helpers. ---------------------------------------------------

# Send one JSON-RPC object (already built by jq -c). Newline-delimited.
_send() { printf '%s\n' "$1"; }

# Read one line from stdin with an optional timeout (seconds). Prints the line;
# returns 1 on EOF, 2 on timeout. bash `read -t` is the no-hang lever.
_read_line() {
  _rl_to="${1:-}"
  if [ -n "$_rl_to" ]; then
    IFS= read -r -t "$_rl_to" _rl || {
      _rl_rc=$?
      # read returns >128 on timeout, !=0 + empty on EOF.
      if [ "$_rl_rc" -gt 128 ]; then return 2; fi
      return 1
    }
  else
    IFS= read -r _rl || return 1
  fi
  printf '%s' "$_rl"
  return 0
}

# --- Delegation + fixture helpers (defined ABOVE _handle_review_gate). --------

# Append one {id,action,value?,rationale?} object to the fixture JSON array.
# Prints the (possibly new) fixture path. jq -n builds the object safely
# (no shell metacharacter hazard — RISK-1 parity with write-decisions.sh).
_append_fixture() {
  _f="$1"; _id="$2"; _act="$3"; _val="$4"; _rat="$5"
  _cur="$(cat "$_f")"
  printf '%s' "$_cur" | jq -c \
    --arg id "$_id" --arg action "$_act" --arg value "$_val" --arg rationale "$_rat" \
    '. + [ ({id:$id,action:$action} + (if $value=="" then {} else {value:$value} end) + (if $rationale=="" then {} else {rationale:$rationale} end)) ]' \
    > "$_f.tmp" && mv -f "$_f.tmp" "$_f"
  printf '%s' "$_f"
}

# decline / capability-absent delegate: the headless auto-mode policy path.
_delegate_headless() {
  _pkt="$1"; _gid="$2"; _ms="$3"; _ph="$4"; _pol="$5"
  ORCH_HEADLESS=1 bash "$INTERACTIVE_REVIEW" \
    --packet="$_pkt" --gate-id="$_gid" \
    --milestone="$_ms" --phase="$_ph" --policy="$_pol" >/dev/null 2>&1 || true
}

# --- _handle_review_gate: the elicitation transport + the three delegations. --
_handle_review_gate() {
  _req="$1"; _mid="$2"
  args="$(printf '%s' "$_req" | jq -c '.params.arguments // {}')"
  packet="$(printf '%s' "$args" | jq -r '.packet // ""')"
  gate_id="$(printf '%s' "$args" | jq -r '.gate_id // ""')"
  milestone="$(printf '%s' "$args" | jq -r '.milestone // ""')"
  phase="$(printf '%s' "$args" | jq -r '.phase // ""')"
  policy="$(printf '%s' "$args" | jq -r '.policy // "defer"')"

  # Filesystem-scoped state resolution (#Q-5 / D-P03-3): a relative packet
  # resolves against the orchestrator root; an absolute path is used as-is.
  case "$packet" in
    /*) : ;;
    *) _root="$(bash "$RESOLVE_ROOT" --absolute 2>/dev/null)"
       [ -n "$_root" ] && packet="$_root/$packet" ;;
  esac

  # Edge case (D-P03-2): client lacks elicitation -> degrade to headless
  # QUESTIONS.md hand-off via the policy path. Do NOT error.
  if [ "$CLIENT_HAS_ELICIT" != "1" ]; then
    _delegate_headless "$packet" "$gate_id" "$milestone" "$phase" "$policy"
    _send "$(jq -nc --argjson id "$_mid" \
      '{jsonrpc:"2.0",id:$id,result:{content:[{type:"text",text:"elicitation unavailable; degraded to QUESTIONS.md hand-off + declared policy"}]}}')"
    return 0
  fi

  # Build the recorded-response fixture by eliciting each active decision.
  fixture="$(mktemp 2>/dev/null || printf '/tmp/orch_mcp_fixture_%d' "$$")"
  printf '[]' > "$fixture"
  declined=0
  eid=0
  for id in $(bash "$READER" active-ids "$packet"); do
    [ -n "$id" ] || continue
    eid=$((eid + 1))
    # server->client elicitation/create for this decision.
    _send "$(jq -nc --arg eid "elicit-$eid" --arg msg "Review decision $id" \
      '{jsonrpc:"2.0",id:$eid,method:"elicitation/create",params:{message:$msg,requestedSchema:{type:"object",properties:{action:{type:"string"},value:{type:"string"},rationale:{type:"string"}},required:["action"]}}}')"
    # Read the matching response (bounded; timeout -> treat as decline).
    resp=""
    while :; do
      l="$(_read_line "$ELICIT_TIMEOUT")"; rc=$?
      [ "$rc" -ne 0 ] && break              # EOF or timeout -> decline
      respid="$(printf '%s' "$l" | jq -r '.id // empty' 2>/dev/null)"
      if [ "$respid" = "elicit-$eid" ]; then resp="$l"; break; fi
    done
    action="$(printf '%s' "$resp" | jq -r '.result.action // "decline"' 2>/dev/null)"
    case "$action" in
      accept|override|pushback|na)
        value="$(printf '%s' "$resp" | jq -r '.result.value // ""')"
        rationale="$(printf '%s' "$resp" | jq -r '.result.rationale // ""')"
        # accept maps to the test-responses `accept` action; override/pushback/na
        # carry through verbatim (valid DECISIONS_ACTION_VALUES enum members).
        fixture="$(_append_fixture "$fixture" "$id" "$action" "$value" "$rationale")"
        ;;
      *)   # decline | cancel | (timeout/EOF)
        declined=1; break ;;
    esac
  done

  if [ "$declined" = "1" ]; then
    rm -f "$fixture"
    _delegate_headless "$packet" "$gate_id" "$milestone" "$phase" "$policy"
    _send "$(jq -nc --argjson id "$_mid" \
      '{jsonrpc:"2.0",id:$id,result:{content:[{type:"text",text:"elicitation declined; applied declared auto-mode policy"}]}}')"
    return 0
  fi

  # accept path: delegate the writes to the P02 deterministic stage.
  bash "$INTERACTIVE_REVIEW" \
    --packet="$packet" --gate-id="$gate_id" \
    --milestone="$milestone" --phase="$phase" \
    --test-responses="$fixture" >/dev/null 2>&1
  rm -f "$fixture"
  _send "$(jq -nc --argjson id "$_mid" \
    '{jsonrpc:"2.0",id:$id,result:{content:[{type:"text",text:"review captured to REVIEW.md + SIGNOFF.md"}]}}')"
}

# --- The handshake loop. -----------------------------------------------------
# Track whether the client declared elicitation support at `initialize` (the
# capability-absent edge case, D-P03-2). The `review_gate` tool takes packet,
# gate_id, milestone, phase, and optional policy in its arguments.

CLIENT_HAS_ELICIT=0
PROTO="2025-06-18"

while :; do
  line="$(_read_line)" || break        # EOF -> exit (per-session lifecycle)
  [ -n "$line" ] || continue
  method="$(printf '%s' "$line" | jq -r '.method // empty' 2>/dev/null)"
  mid="$(printf '%s' "$line" | jq -c '.id // null' 2>/dev/null)"

  case "$method" in
    initialize)
      has_e="$(printf '%s' "$line" | jq -r '.params.capabilities.elicitation // empty' 2>/dev/null)"
      [ -n "$has_e" ] && CLIENT_HAS_ELICIT=1
      PROTO="$(printf '%s' "$line" | jq -r '.params.protocolVersion // "2025-06-18"')"
      _send "$(jq -nc --argjson id "$mid" --arg p "$PROTO" \
        '{jsonrpc:"2.0",id:$id,result:{protocolVersion:$p,capabilities:{tools:{}},serverInfo:{name:"orchestrator-review-gate",version:"1.0.0"}}}')"
      ;;
    notifications/initialized)
      : ;;   # notification, no response
    tools/list)
      _send "$(jq -nc --argjson id "$mid" \
        '{jsonrpc:"2.0",id:$id,result:{tools:[{name:"review_gate",description:"Walk an interactive-review decision packet via MCP elicitation.",inputSchema:{type:"object",properties:{packet:{type:"string"},gate_id:{type:"string"},milestone:{type:"string"},phase:{type:"string"},policy:{type:"string"}},required:["packet","gate_id","milestone","phase"]}}]}}')"
      ;;
    tools/call)
      _handle_review_gate "$line" "$mid"
      ;;
    *)
      if [ "$mid" != "null" ]; then
        _send "$(jq -nc --argjson id "$mid" --arg m "$method" \
          '{jsonrpc:"2.0",id:$id,error:{code:-32601,message:("method not found: "+$m)}}')"
      fi
      ;;
  esac
done
exit 0
