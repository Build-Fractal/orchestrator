#!/usr/bin/env bash
# tools/verify/m034-p03-mcp-stub.sh — M034 P03 T01 (SC-6 / PC-6).
#
# Hermetic stubbed-transport verifier for scripts/lifecycle/review-gate-mcp-server.sh.
# Drives the server by piping a recorded newline-delimited JSON-RPC message
# stream into its stdin (the SC-6 "stubbed transport"), in an isolated scratch
# dir so REVIEW.md/SIGNOFF.md/CONTINUE/QUESTIONS files land in scratch and NEVER
# in the real .orchestrator/milestones/M034/ tree. ORCH_EVENT_LOG and
# ORCH_MCP_ELICIT_TIMEOUT keep the run hermetic + no-hang.
#
# Covers three paths against the 8-decision baseline packet (D-1..D-8):
#   1. accept            -> *-REVIEW.md (8 reviewed: lines) + *-SIGNOFF.md (approved_by)
#   2. decline           -> <gate>-CONTINUE.md (defer policy), exit 0, no hang
#   3. capability-absent -> <gate>-QUESTIONS.md (degraded, not errored), exit 0
#
# Prints "PASS: m034-p03 mcp-stub" + exit 0 on success;
# "FAIL: m034-p03 mcp-stub — <reason>" + exit 1 otherwise.
# Bash 3.2 / POSIX-sh single file (CON-1 / AD-19 — multi-step pipes in the
# script body only, never as inline Check: commands).

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

SERVER="$REPO_ROOT/scripts/lifecycle/review-gate-mcp-server.sh"
FIXTURE_PACKET="$REPO_ROOT/.orchestrator/milestones/M034/fixtures/decisions-packet-baseline.md"

fail() { echo "FAIL: m034-p03 mcp-stub — $1"; exit 1; }

if ! command -v jq >/dev/null 2>&1; then fail "jq not on PATH"; fi
[ -f "$SERVER" ] || fail "server missing: $SERVER"
[ -f "$FIXTURE_PACKET" ] || fail "baseline packet missing: $FIXTURE_PACKET"

# Isolated scratch dir (hermetic). All artifacts land here.
SCRATCH="$(mktemp -d 2>/dev/null || printf '/tmp/orch_m034_p03_%d' "$$")"
[ -d "$SCRATCH" ] || fail "could not create scratch dir"
trap 'rm -rf "$SCRATCH"' EXIT

export ORCH_EVENT_LOG="$SCRATCH/event-log.jsonl"
export ORCH_MCP_ELICIT_TIMEOUT=3
# Freeze the orchestrator root resolution to the real repo so relative-packet
# resolution is deterministic; but we always pass ABSOLUTE packet paths in scratch
# so nothing touches the real tree regardless.

# ===========================================================================
# Path 1: accept.
# ===========================================================================
P1_PKT="$SCRATCH/acc-gate-DECISIONS.md"
cp "$FIXTURE_PACKET" "$P1_PKT"
P1_STREAM="$SCRATCH/acc-stream.jsonl"

{
  printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{"elicitation":{"form":{}}}}}'
  printf '%s\n' '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"review_gate\",\"arguments\":{\"packet\":\"$P1_PKT\",\"gate_id\":\"acc-gate\",\"milestone\":\"M034\",\"phase\":\"P03\"}}}"
  # 8 accept responses for elicit-1..elicit-8 (server reads them in order).
  e=1
  while [ "$e" -le 8 ]; do
    printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":\"elicit-$e\",\"result\":{\"action\":\"accept\"}}"
    e=$((e + 1))
  done
} > "$P1_STREAM"

bash "$SERVER" < "$P1_STREAM" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] || fail "accept run exited non-zero ($rc)"

P1_REVIEW="$SCRATCH/acc-gate-REVIEW.md"
P1_SIGNOFF="$SCRATCH/acc-gate-SIGNOFF.md"
[ -f "$P1_REVIEW" ] || fail "accept: REVIEW.md not written ($P1_REVIEW)"
[ -f "$P1_SIGNOFF" ] || fail "accept: SIGNOFF.md not written ($P1_SIGNOFF)"

reviewed_n=$(grep -c '^reviewed: ' "$P1_REVIEW" 2>/dev/null || true)
[ -n "$reviewed_n" ] || reviewed_n=0
[ "$reviewed_n" -eq 8 ] || fail "accept: expected 8 reviewed: lines, got $reviewed_n"

grep -q '^approved_by: ' "$P1_SIGNOFF" || fail "accept: SIGNOFF.md missing approved_by"

# Hermeticity: the real milestone tree must NOT have grown a gate artifact.
if [ -f "$REPO_ROOT/.orchestrator/milestones/M034/fixtures/acc-gate-REVIEW.md" ]; then
  fail "hermeticity breach: acc-gate-REVIEW.md leaked into the real fixtures dir"
fi

# ===========================================================================
# Path 2: decline (defer policy -> continue-file, no hang).
# ===========================================================================
P2_PKT="$SCRATCH/dec-gate-DECISIONS.md"
cp "$FIXTURE_PACKET" "$P2_PKT"
P2_STREAM="$SCRATCH/dec-stream.jsonl"

{
  printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{"elicitation":{"form":{}}}}}'
  printf '%s\n' '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"review_gate\",\"arguments\":{\"packet\":\"$P2_PKT\",\"gate_id\":\"dec-gate\",\"milestone\":\"M034\",\"phase\":\"P03\",\"policy\":\"defer\"}}}"
  printf '%s\n' '{"jsonrpc":"2.0","id":"elicit-1","result":{"action":"decline"}}'
} > "$P2_STREAM"

bash "$SERVER" < "$P2_STREAM" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] || fail "decline run exited non-zero ($rc)"

P2_CONTINUE="$SCRATCH/dec-gate-CONTINUE.md"
[ -f "$P2_CONTINUE" ] || fail "decline: continue-file not written ($P2_CONTINUE — defer policy)"

# ===========================================================================
# Path 3: capability-absent (initialize WITHOUT elicitation -> QUESTIONS.md).
# ===========================================================================
P3_PKT="$SCRATCH/cap-gate-DECISIONS.md"
cp "$FIXTURE_PACKET" "$P3_PKT"
P3_STREAM="$SCRATCH/cap-stream.jsonl"

{
  printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{}}}'
  printf '%s\n' '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"review_gate\",\"arguments\":{\"packet\":\"$P3_PKT\",\"gate_id\":\"cap-gate\",\"milestone\":\"M034\",\"phase\":\"P03\",\"policy\":\"defer\"}}}"
} > "$P3_STREAM"

bash "$SERVER" < "$P3_STREAM" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] || fail "capability-absent run exited non-zero ($rc)"

P3_QUESTIONS="$SCRATCH/cap-gate-QUESTIONS.md"
[ -f "$P3_QUESTIONS" ] || fail "capability-absent: QUESTIONS.md hand-off not written ($P3_QUESTIONS)"

echo "PASS: m034-p03 mcp-stub"
exit 0
