#!/usr/bin/env bash
# tools/verify/m034-p03-byte-parity.sh — M034 P03 (FR-15 / SC-9).
#
# The byte-parity audit. Proves the deterministic, zero-LLM review-gate paths
# are byte-IDENTICAL across runtimes (the consolidated M009 FR-8, applied to the
# review stage). Two assertions, all with a FROZEN timestamp so files are truly
# byte-equal (no strip-then-compare — the byte-equality-default discipline):
#
#   1. Backend parity (headline FR-15). Run `interactive-review.sh
#      --test-responses` once under ORCH_BACKEND=cursor and once under the CC
#      default, against SEPARATE scratch packet copies. Assert SHA-256 equality
#      of both *-REVIEW.md and *-SIGNOFF.md. (The deterministic writer has no
#      backend branch, so equality holds — the audit PROVES it.)
#   2. MCP-accept <-> CC parity. Drive the T01 MCP server's accept path over a
#      stubbed JSON-RPC stdin transport (initialize-with-elicitation ->
#      tools/call review_gate -> one {id:"elicit-N",result:{action:"accept"}}
#      per active id) against a third scratch packet copy, SAME frozen env.
#      Assert its *-REVIEW.md SHA-256 == the CC --test-responses *-REVIEW.md.
#
# Frozen env (identical across all three runs): ORCH_REVIEW_FIXED_TS,
# ORCH_REVIEWER, scratch ORCH_EVENT_LOG. The responses fixture is IDENTICAL for
# all runs (all-accept) so the SHA comparison is meaningful.
#
# CON-1: bash 3.2 / POSIX-sh single file. SHA + multi-step setup live in
# function bodies (AD-19 carve-out), never inline.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

INTERACTIVE_REVIEW="$REPO_ROOT/scripts/lifecycle/interactive-review.sh"
MCP_SERVER="$REPO_ROOT/scripts/lifecycle/review-gate-mcp-server.sh"
READER="$REPO_ROOT/scripts/knowledge/read-decisions.sh"
BASELINE="$REPO_ROOT/.orchestrator/milestones/M034/fixtures/decisions-packet-baseline.md"

# Frozen, identical across all three runs (the byte-equality lever, D-P03-5).
export ORCH_REVIEW_FIXED_TS="2026-06-06T00:00:00Z"
export ORCH_REVIEWER="audit"
export ORCH_MCP_ELICIT_TIMEOUT="3"

_fail() {
  echo "FAIL: m034-p03 byte-parity — $1"
  exit 1
}

# SHA-256 of a file's bytes -> the bare digest (AD-19 carve-out; shasum first,
# sha256sum fallback). No strip — whole-file byte digest.
_sha() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

# Run interactive-review.sh --test-responses against a fresh scratch packet copy.
#   $1 = scratch packet path (named *-DECISIONS.md so REVIEW/SIGNOFF derive here)
#   $2 = responses fixture path
# ORCH_BACKEND is inherited from the caller's environment (set per invocation).
# The packet BASENAME is what lands in the REVIEW/SIGNOFF frontmatter (`packet:`
# / `review_md:`), so every run uses the SAME basename (packet-DECISIONS.md) in
# a DISTINCT directory — distinct output paths, byte-identical content.
_run_test_responses() {
  _pkt="$1"; _fix="$2"
  mkdir -p "$(dirname "$_pkt")"
  cp "$BASELINE" "$_pkt"
  bash "$INTERACTIVE_REVIEW" \
    --packet="$_pkt" --gate-id="parity-gate" \
    --milestone="M034" --phase="P03" \
    --test-responses="$_fix" >/dev/null 2>&1
}

# Build the all-accept responses fixture (a JSON array, one {id,action} per
# active id). Identical content for ALL three runs (so SHA comparison holds).
_build_accept_fixture() {
  _out="$1"
  printf '[' > "$_out"
  _first=1
  for _id in $(bash "$READER" active-ids "$BASELINE"); do
    [ -n "$_id" ] || continue
    if [ "$_first" = "1" ]; then _first=0; else printf ',' >> "$_out"; fi
    printf '{"id":"%s","action":"accept"}' "$_id" >> "$_out"
  done
  printf ']' >> "$_out"
}

# Build the stubbed JSON-RPC stdin stream for the MCP server accept path.
#   $1 = output stream file
#   $2 = scratch packet path (absolute) passed as the review_gate tool arg
# Sequence: initialize (elicitation.form capability) -> notifications/initialized
# -> tools/call review_gate -> one accept elicitation response per active id.
_build_mcp_stream() {
  _stream="$1"; _pkt="$2"
  : > "$_stream"
  printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{"elicitation":{"form":{}}},"clientInfo":{"name":"parity-stub","version":"1.0.0"}}}' >> "$_stream"
  printf '%s\n' '{"jsonrpc":"2.0","method":"notifications/initialized"}' >> "$_stream"
  printf '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"review_gate","arguments":{"packet":"%s","gate_id":"parity-gate","milestone":"M034","phase":"P03"}}}\n' "$_pkt" >> "$_stream"
  _eid=0
  for _id in $(bash "$READER" active-ids "$BASELINE"); do
    [ -n "$_id" ] || continue
    _eid=$((_eid + 1))
    printf '{"jsonrpc":"2.0","id":"elicit-%s","result":{"action":"accept"}}\n' "$_eid" >> "$_stream"
  done
}

# --- Scratch setup. ----------------------------------------------------------
SCRATCH="$(mktemp -d 2>/dev/null || printf '/tmp/orch_m034_byteparity_%d' "$$")"
mkdir -p "$SCRATCH"
export ORCH_EVENT_LOG="$SCRATCH/events.jsonl"

cleanup() { rm -rf "$SCRATCH"; }
trap cleanup EXIT

[ -f "$INTERACTIVE_REVIEW" ] || _fail "missing interactive-review.sh"
[ -f "$MCP_SERVER" ] || _fail "missing review-gate-mcp-server.sh"
[ -f "$BASELINE" ] || _fail "missing baseline packet fixture"

FIXTURE="$SCRATCH/responses.json"
_build_accept_fixture "$FIXTURE"

# --- Assertion 1: backend parity (cursor vs CC default). ---------------------
# Identical packet basename (packet-DECISIONS.md) in distinct dirs so the
# embedded `packet:` frontmatter is identical — any SHA difference would be a
# REAL backend divergence, not a filename artifact.
CURSOR_PKT="$SCRATCH/cursor/packet-DECISIONS.md"
CC_PKT="$SCRATCH/cc/packet-DECISIONS.md"

ORCH_BACKEND="cursor" _run_test_responses "$CURSOR_PKT" "$FIXTURE"
unset ORCH_BACKEND 2>/dev/null || true
_run_test_responses "$CC_PKT" "$FIXTURE"

CURSOR_REVIEW="$SCRATCH/cursor/packet-REVIEW.md"
CURSOR_SIGNOFF="$SCRATCH/cursor/packet-SIGNOFF.md"
CC_REVIEW="$SCRATCH/cc/packet-REVIEW.md"
CC_SIGNOFF="$SCRATCH/cc/packet-SIGNOFF.md"

[ -f "$CURSOR_REVIEW" ] || _fail "cursor run produced no REVIEW.md"
[ -f "$CC_REVIEW" ] || _fail "cc run produced no REVIEW.md"
[ -f "$CURSOR_SIGNOFF" ] || _fail "cursor run produced no SIGNOFF.md"
[ -f "$CC_SIGNOFF" ] || _fail "cc run produced no SIGNOFF.md"

if [ "$(_sha "$CURSOR_REVIEW")" != "$(_sha "$CC_REVIEW")" ]; then
  _fail "REVIEW.md SHA-256 differs between ORCH_BACKEND=cursor and CC default"
fi
if [ "$(_sha "$CURSOR_SIGNOFF")" != "$(_sha "$CC_SIGNOFF")" ]; then
  _fail "SIGNOFF.md SHA-256 differs between ORCH_BACKEND=cursor and CC default"
fi

# --- Assertion 2: MCP-accept output == CC --test-responses output. -----------
# Same packet basename (packet-DECISIONS.md) in its own dir so the embedded
# `packet:` frontmatter matches the CC run.
MCP_PKT="$SCRATCH/mcp/packet-DECISIONS.md"
mkdir -p "$SCRATCH/mcp"
cp "$BASELINE" "$MCP_PKT"
STREAM="$SCRATCH/mcp-stream.jsonl"
_build_mcp_stream "$STREAM" "$MCP_PKT"

bash "$MCP_SERVER" < "$STREAM" >/dev/null 2>&1

MCP_REVIEW="$SCRATCH/mcp/packet-REVIEW.md"
[ -f "$MCP_REVIEW" ] || _fail "MCP server accept path produced no REVIEW.md"

if [ "$(_sha "$MCP_REVIEW")" != "$(_sha "$CC_REVIEW")" ]; then
  _fail "MCP-accept REVIEW.md SHA-256 differs from CC --test-responses REVIEW.md"
fi

echo "PASS: m034-p03 byte-parity"
exit 0
