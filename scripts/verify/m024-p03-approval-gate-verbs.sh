#!/usr/bin/env bash
# scripts/verify/m024-p03-approval-gate-verbs.sh
# Verifies cancel + revise verbs.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
GATE="$ROOT/scripts/intake/approval-gate.sh"

[ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$GATE" ] || { echo "FAIL: $GATE not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Cancel case.
emit_out=$(bash "$EMIT" --input "Add a status caching layer for five seconds." --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

cancel_out=$(bash "$GATE" --proposal "$proposal" --verb cancel)
[ -z "$cancel_out" ] || { echo "FAIL: cancel emitted unexpected stdout: $cancel_out"; exit 1; }
grep -qE '^cancelled_at: "[0-9]{4}-' "$proposal" || { echo "FAIL: cancelled_at not set"; exit 1; }
grep -q '^pending_approval: false' "$proposal"   || { echo "FAIL: pending_approval not flipped"; exit 1; }

# Revise case (separate fresh proposal so pending_approval is true).
emit_out2=$(bash "$EMIT" --input "Add a verbose flag to the status command." --intake-root "$tmp/intake2")
proposal2=$(echo "$emit_out2" | sed -n 's/^proposal_path=//p')
[ -f "$proposal2" ] || { echo "FAIL: second emit did not produce a proposal"; exit 1; }

revise_out=$(bash "$GATE" --proposal "$proposal2" --verb revise --axis scope_tier --value C --no-apply)
echo "$revise_out" | grep -q '^revision_pending=true axis=scope_tier value=C$' || {
  echo "FAIL: revise did not emit revision_pending line (got: $revise_out)"
  exit 1
}

# Revise must NOT mutate frontmatter in P03.
grep -q '^pending_approval: true' "$proposal2" || { echo "FAIL: revise mutated pending_approval (P03 must not)"; exit 1; }

# Unsupported axis exits 2.
if bash "$GATE" --proposal "$proposal2" --verb revise --axis frobnicate --value X >/dev/null 2>&1; then
  echo "FAIL: revise on unsupported axis should exit non-zero"
  exit 1
fi

# Unknown verb exits 2.
if bash "$GATE" --proposal "$proposal2" --verb yolo >/dev/null 2>&1; then
  echo "FAIL: unknown verb should exit non-zero"
  exit 1
fi

echo "PASS: approval-gate.sh — cancel mutates frontmatter, revise pass-through, unsupported verbs/axes rejected"
exit 0
