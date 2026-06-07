---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M034"
name: "MCP review-gate server + stub harness (PC-6 / #Q-5 / SC-6) + FIXED_TS seam"
depends_on: []
---

## Prerequisites

- `scripts/lifecycle/interactive-review.sh` exists (P02) with: `--test-responses=<path>`, `--policy=<p>`, `--packet=`, `--milestone=`, `--phase=`, `--gate-id=`, `--review-out=`, `--signoff-out=` flags; a `_run_test_responses` deterministic writer; a `_run_headless_policy` path keyed on `$POLICY`; and an `_iso_now()` helper at ~line 106 — verified on disk.
- `scripts/knowledge/read-decisions.sh` exists with `active-ids <packet>` (one id per line, packet order) — verified on disk.
- `scripts/state/resolve-root.sh` exists (4-rule root resolver) — verified on disk.
- `.orchestrator/milestones/M034/fixtures/decisions-packet-baseline.md` exists (8-decision packet: D-1..D-8, D-7 is `type: boundary_translation`) — verified on disk.
- `.orchestrator/milestones/M009/probe-harness/mcp-elicit-server.py` exists (PC-6 reference) — verified on disk.
- `jq` on PATH (already a hard requirement of `interactive-review.sh`).

## Description

Ship the orchestrator-owned **stdio MCP review-gate server** — M034's third
renderer (FR-10), resolving PC-6 (stub JSON-RPC shape + injection + lifecycle) and
#Q-5 (process lifecycle + state auth). The server is **bash 3.2 + jq** (D-P03-1)
and **pure transport**: it speaks MCP over stdin/stdout, issues
`elicitation/create` per decision, and delegates EVERY write to the P02
`interactive-review.sh` stage (D-P03-2). Also add the test-only
`ORCH_REVIEW_FIXED_TS` frozen-timestamp seam to `interactive-review.sh` (D-P03-5),
needed by T03's byte-parity audit.

## Steps

### 1. Add the `ORCH_REVIEW_FIXED_TS` seam to `interactive-review.sh::_iso_now`

Replace the existing `_iso_now` helper (currently at ~line 106-109):

```bash
# --- ISO timestamp. ----------------------------------------------------------
_iso_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}
```

with the FIXED_TS-aware form (D-P03-5 — test-only; default behavior unchanged):

```bash
# --- ISO timestamp. ----------------------------------------------------------
# ORCH_REVIEW_FIXED_TS (test-only, M034 P03 / FR-15): when set, emit the literal
# value so two otherwise-identical runs are byte-equal for the byte-parity audit.
# Unset (production): real UTC timestamp as before.
_iso_now() {
  if [ -n "${ORCH_REVIEW_FIXED_TS:-}" ]; then
    printf '%s' "$ORCH_REVIEW_FIXED_TS"
  else
    date -u +%Y-%m-%dT%H:%M:%SZ
  fi
}
```

This is the ONLY edit to `interactive-review.sh` in P03. Do not change any other
line.

### 2. Author `scripts/lifecycle/review-gate-mcp-server.sh`

A bash 3.2 + jq stdio MCP server. **Architecture** (D-P03-1/2/3): a sequential
`read -r line` loop over stdin (newline-delimited JSON-RPC, no Content-Length
framing — mirrors `mcp-elicit-server.py`), `printf '%s\n'` to stdout for each
message, `jq` for parse/build. The server is **stateless** beyond on-disk
artifacts and exits on stdin EOF (per-session-spawn lifecycle, #Q-5/D-P03-3).

**Header + setup:**

```bash
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
```

**JSON-RPC I/O helpers** (single-line send; line read):

```bash
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
```

**The handshake loop.** Track whether the client declared elicitation support at
`initialize` (the capability-absent edge case, D-P03-2). The `review_gate` tool
takes `packet`, `gate_id`, `milestone`, `phase`, and optional `policy` in its
arguments:

```bash
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
```

NOTE: bash requires functions be defined before use; place `_handle_review_gate`
(below) ABOVE the `while` loop.

**`_handle_review_gate`** — the elicitation transport + the three delegations
(D-P03-2). Reads the tool args, resolves the packet path against the orchestrator
root (D-P03-3), and for each active decision issues one `elicitation/create`:

```bash
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
```

Helper functions (define ABOVE `_handle_review_gate`):

```bash
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
```

CON-1 note: `_append_fixture` chains `cat`/`jq`/`mv` inside a FUNCTION BODY —
exempt from the AP-009 shape-guard per the AD-19 helper-function carve-out
(`references/RUNTIME-ASSUMPTIONS.md` § AD-19). The `&& mv` is a single connector,
well under the gt-2 threshold besides.

### 3. Co-author `tools/verify/m034-p03-mcp-stub.sh`

A hermetic verifier that drives the server over a **stubbed transport** (a
recorded JSON-RPC message stream piped to the server's stdin — the SC-6 "stubbed
transport"). It MUST cover three paths against the baseline packet fixture, in an
isolated scratch dir (copy the fixture in so REVIEW.md/SIGNOFF.md land in scratch,
never the real milestone tree). See `## Verification` for the invocation; the
script body:

1. **accept path** — feed: `initialize` (declaring `capabilities.elicitation.form`)
   → `notifications/initialized` → `tools/call review_gate` (args point at the
   scratch packet, gate_id/milestone/phase set) → then one
   `{"jsonrpc":"2.0","id":"elicit-N","result":{"action":"accept"}}` per active
   decision. Because the message stream must answer elicitation requests the
   server emits, generate the accept responses for `elicit-1`..`elicit-8` (the 8
   active baseline ids) up front and append them after the `tools/call` line — the
   server reads them in order as it loops. Assert: the scratch `*-REVIEW.md` exists
   with 8 `reviewed:` marker lines and `*-SIGNOFF.md` exists with `approved_by`.
2. **decline path** — feed: `initialize` (with elicitation) →
   `notifications/initialized` → `tools/call` → one
   `{"...","id":"elicit-1","result":{"action":"decline"}}`. Assert: a
   `<gate_id>-CONTINUE.md` continue-file exists (the `defer` policy fired) and the
   run exited 0 (no hang). Use `ORCH_MCP_ELICIT_TIMEOUT=3` so even a missing
   response cannot stall the verifier.
3. **capability-absent path** — feed: `initialize` WITHOUT
   `capabilities.elicitation` → `notifications/initialized` → `tools/call`. Assert:
   a `<gate_id>-QUESTIONS.md` hand-off exists (degraded, not errored) and exit 0.

Drive the server by writing the message stream to a temp file and piping it:
`bash review-gate-mcp-server.sh < messages.jsonl` inside the verifier. (A
multi-step pipe lives in the verifier SCRIPT body — fine under AD-19; do not write
it as an inline `Check:` command.) Set `ORCH_EVENT_LOG` to a scratch path so the
delegated `interactive-review.sh` never touches the real execution-log.

Print `PASS: m034-p03 mcp-stub` + exit 0 on success; `FAIL: m034-p03 mcp-stub — <reason>` + exit 1 otherwise.

## Must-Haves

- `scripts/lifecycle/review-gate-mcp-server.sh` exists, is bash+jq, contains `elicitation/create`, completes the handshake, and delegates accept→`interactive-review.sh --test-responses` / decline→headless policy / capability-absent→QUESTIONS.md.
- `interactive-review.sh::_iso_now` honors `ORCH_REVIEW_FIXED_TS`.
- `tools/verify/m034-p03-mcp-stub.sh` exercises accept + decline + capability-absent over a stubbed transport, asserting REVIEW.md/SIGNOFF.md (accept), continue-file (decline), QUESTIONS.md (capability-absent), and no hang.

## Verification

```bash
bash tools/verify/m034-p03-mcp-stub.sh
```

## Inputs

### From Disk (Pre-existing)
- `scripts/lifecycle/interactive-review.sh` — the delegate. Accept: `--test-responses=<json-array-path>` writes one REVIEW.md block per active decision in packet order + populates SIGNOFF.md (`_run_test_responses`). Decline/degrade: `ORCH_HEADLESS=1 … --policy=<defer|accept-with-audit|refuse-entry>` runs `_run_headless_policy` (defer writes `<gate_id>-CONTINUE.md` + `QUESTIONS.md` + `pending_review` JSONL, exit 0). Honors `ORCH_EVENT_LOG` for hermetic logging. `_iso_now` is at ~line 106.
- `scripts/knowledge/read-decisions.sh active-ids <packet>` — one active (non-superseded) id per line, packet order. Baseline fixture yields D-1..D-8.
- `scripts/state/resolve-root.sh --absolute` — prints the resolved orchestrator root.
- `.orchestrator/milestones/M009/probe-harness/mcp-elicit-server.py` — the PC-6 message-sequence reference (initialize→initialized→tools/list→tools/call→elicitation/create→response; headless answers `{"action":"decline"}` instantly).
- `.orchestrator/milestones/M034/fixtures/decisions-packet-baseline.md` — 8 active decisions; copy into scratch for the verifier.

## Constraints

- CON-1: bash 3.2 / POSIX-sh single file; jq permitted (already required by the stage). No `declare -A`, no `${var,,}`, no process substitution. Multi-step pipes live ONLY in function bodies / verifier script bodies (AD-19 carve-out), never as inline `Check:` commands.
- D-P03-2: the server writes NOTHING itself — every artifact write goes through `interactive-review.sh`. This preserves CON-5/SC-5 always-write and the FR-15 byte-parity-by-construction property.
- No-hang (SC-6): every elicitation read is bounded by `ORCH_MCP_ELICIT_TIMEOUT` (`read -t`); timeout/EOF is treated as decline → policy path. The watchdog never needs to fire.
- The `_iso_now` edit is the ONLY change to `interactive-review.sh`; do not touch other lines.

## Expected Output

See `## Notes`.

## Notes

`bash tools/verify/m034-p03-mcp-stub.sh` prints `PASS: m034-p03 mcp-stub` and
exits 0 when the accept stream produces a scratch REVIEW.md (8 `reviewed:` lines)
+ SIGNOFF.md, the decline stream produces a `<gate_id>-CONTINUE.md` with exit 0,
and the capability-absent stream produces a `<gate_id>-QUESTIONS.md` with exit 0.
On any miss it prints `FAIL: m034-p03 mcp-stub — <reason>` and exits 1.
