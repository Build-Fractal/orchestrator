#!/usr/bin/env bash
# scripts/verify/m024-p03-approval-gate.sh
# Verifies the approve verb mutates frontmatter and emits the invoke line.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
GATE="$ROOT/scripts/intake/approval-gate.sh"

[ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$GATE" ] || { echo "FAIL: $GATE not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Generate a fresh proposal (paragraph input — Tier B, recommended specify).
para="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers that need fresh data. Also a verbose mode."
emit_out=$(bash "$EMIT" --input "$para" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

# Pre-state: pending_approval=true, approved_at=null.
grep -q '^pending_approval: true' "$proposal" || { echo "FAIL: pre-state pending_approval not true"; exit 1; }
grep -q '^approved_at: null' "$proposal"      || { echo "FAIL: pre-state approved_at not null"; exit 1; }

# Approve.
approve_out=$(bash "$GATE" --proposal "$proposal" --verb approve)

# Stdout: recommended_command_invoke=<value>.
echo "$approve_out" | grep -q '^recommended_command_invoke=orchestrator:' || {
  echo "FAIL: approve did not emit recommended_command_invoke (got: $approve_out)"
  exit 1
}

# Frontmatter mutation: pending_approval false, approved_at ISO8601.
grep -q '^pending_approval: false' "$proposal" || { echo "FAIL: pending_approval not flipped to false"; exit 1; }
grep -qE '^approved_at: "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"' "$proposal" || {
  echo "FAIL: approved_at not set to ISO8601"
  exit 1
}

# Idempotency guard: re-running approve on already-finalized proposal MUST exit 1.
if bash "$GATE" --proposal "$proposal" --verb approve >/dev/null 2>&1; then
  echo "FAIL: approve on already-finalized proposal should exit non-zero"
  exit 1
fi

echo "PASS: approval-gate.sh — approve mutates frontmatter + emits invoke + idempotency guard"
exit 0
