#!/usr/bin/env bash
# scripts/verify/m024-p06-revise-script.sh
# M024/P06/T02 — Verifies revise.sh archives the prior proposal,
# re-emits with overrides + rederives, resets approval, and is idempotent on no-op.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
REVISE="$ROOT/scripts/intake/revise.sh"

[ -x "$EMIT" ]   || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$REVISE" ] || { echo "FAIL: $REVISE not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Generate a paragraph proposal at Tier B (31-80 word range).
para="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers needing fresh data, plus verbose mode and structured output."
emit_out=$(bash "$EMIT" --input "$para" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

grep -q '^scope_tier: "B"' "$proposal" || { echo "FAIL: pre-state scope_tier not B"; exit 1; }

# Revise scope_tier B → C.
rev_out=$(bash "$REVISE" --proposal "$proposal" --axis scope_tier --value C)
echo "$rev_out" | grep -q '^revised_to=' || { echo "FAIL: revise did not emit revised_to (got: $rev_out)"; exit 1; }

new_path=$(echo "$rev_out" | sed -n 's/^revised_to=//p')
[ -f "$new_path" ] || { echo "FAIL: revise pointed at non-existent file: $new_path"; exit 1; }

# proposal.md should now have scope_tier=C and rederived dependent axes.
grep -q '^scope_tier: "C"' "$new_path" || { echo "FAIL: revised proposal scope_tier not C"; exit 1; }
grep -q '^decomposition: "milestone-with-phases"' "$new_path" || { echo "FAIL: dependent decomposition not rederived"; exit 1; }
grep -q '^recommended_command: "orchestrator:specify"' "$new_path" || { echo "FAIL: dependent recommended_command not rederived"; exit 1; }

# Approval state should be reset.
grep -q '^pending_approval: true' "$new_path" || { echo "FAIL: pending_approval not reset to true"; exit 1; }
grep -q '^approved_at: null' "$new_path"      || { echo "FAIL: approved_at not reset to null"; exit 1; }
grep -q '^cancelled_at: null' "$new_path"     || { echo "FAIL: cancelled_at not reset to null"; exit 1; }

# proposal-v1.md should exist with the prior content.
v1="$(dirname "$proposal")/proposal-v1.md"
[ -f "$v1" ] || { echo "FAIL: proposal-v1.md not archived"; exit 1; }
grep -q '^scope_tier: "B"' "$v1" || { echo "FAIL: archived v1 lost prior scope_tier"; exit 1; }

# FR-14 idempotency: revising with the same value as current is a no-op.
idem_out=$(bash "$REVISE" --proposal "$new_path" --axis scope_tier --value C)
echo "$idem_out" | grep -q '^revised=false reason=identical-axes' || { echo "FAIL: idempotent revise did not emit identical-axes (got: $idem_out)"; exit 1; }
[ ! -f "$(dirname "$proposal")/proposal-v2.md" ] || { echo "FAIL: idempotent revise produced an unexpected v2 archive"; exit 1; }

# input_shape revision must be rejected (exit 2).
if bash "$REVISE" --proposal "$new_path" --axis input_shape --value spec >/dev/null 2>&1; then
  echo "FAIL: input_shape revision should be rejected"
  exit 1
fi

# Unknown axis must be rejected (exit 2).
if bash "$REVISE" --proposal "$new_path" --axis frobnicate --value X >/dev/null 2>&1; then
  echo "FAIL: unknown axis should be rejected"
  exit 1
fi

echo "PASS: revise.sh — archives v1, re-emits with overrides + rederives, resets approval, idempotent on no-op"
exit 0
