#!/usr/bin/env bash
# tests/test-revision-flow.sh
# M024/P06/T04 — End-to-end revision flow happy path.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
GATE="$ROOT/scripts/intake/approval-gate.sh"

[ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$GATE" ] || { echo "FAIL: $GATE not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Tier B paragraph (31-80 word range).
para="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers needing fresh data, plus verbose mode and structured output."
emit_out=$(bash "$EMIT" --input "$para" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

grep -q '^scope_tier: "B"' "$proposal" || { echo "FAIL: pre-revise scope_tier not B"; exit 1; }

# Capture the original input echo so we can assert it survives the revision.
original_body=$(awk '/^## Original Input/{flag=1;next}/^## /{flag=0}flag' "$proposal")

# Revise via the approval-gate (the wired path).
rev_out=$(bash "$GATE" --proposal "$proposal" --verb revise --axis scope_tier --value C)
echo "$rev_out" | grep -q '^revised_to=' || { echo "FAIL: revise did not emit revised_to (got: $rev_out)"; exit 1; }

# Prior content archived as proposal-v1.md.
proposal_dir=$(dirname "$proposal")
[ -f "$proposal_dir/proposal-v1.md" ] || { echo "FAIL: proposal-v1.md not archived"; exit 1; }
grep -q '^scope_tier: "B"' "$proposal_dir/proposal-v1.md" || { echo "FAIL: proposal-v1.md does not preserve prior scope_tier=B"; exit 1; }

# Current proposal.md has the new tier and rederived dependents.
grep -q '^scope_tier: "C"' "$proposal" || { echo "FAIL: revised proposal scope_tier not C"; exit 1; }
grep -q '^decomposition: "milestone-with-phases"' "$proposal" || { echo "FAIL: dependent decomposition not rederived"; exit 1; }
grep -q '^recommended_command: "orchestrator:specify"' "$proposal" || { echo "FAIL: dependent recommended_command not rederived"; exit 1; }

# Approval state reset.
grep -q '^pending_approval: true' "$proposal" || { echo "FAIL: pending_approval not reset to true"; exit 1; }
grep -q '^approved_at: null' "$proposal"      || { echo "FAIL: approved_at not reset to null"; exit 1; }
grep -q '^cancelled_at: null' "$proposal"     || { echo "FAIL: cancelled_at not reset to null"; exit 1; }

# Original Input body preserved across the revision.
revised_body=$(awk '/^## Original Input/{flag=1;next}/^## /{flag=0}flag' "$proposal")
[ "$original_body" = "$revised_body" ] || { echo "FAIL: Original Input body changed across revision"; exit 1; }

echo "PASS: revision flow — paragraph Tier B → C; v1 archived; rederives applied; approval reset; input body preserved"
exit 0
