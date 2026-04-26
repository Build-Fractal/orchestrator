#!/usr/bin/env bash
# tests/test-approval-gate.sh
# M024/P03 phase test — approval gate verb matrix.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
GATE="$ROOT/scripts/intake/approval-gate.sh"

PASS=0
FAIL=0
NAMES_0=""; NAMES_1=""; NAMES_2=""; NAMES_3=""; NAMES_4=""; NAMES_5=""
i=0
pass() { PASS=$((PASS+1)); eval "NAMES_$i=\"PASS: \$1\""; i=$((i+1)); }
fail() { FAIL=$((FAIL+1)); eval "NAMES_$i=\"FAIL: \$1 — \$2\""; i=$((i+1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

new_proposal() {
  local dir="$1"; local input="$2"
  local out path
  out=$(bash "$EMIT" --input "$input" --intake-root "$dir")
  path=$(echo "$out" | sed -n 's/^proposal_path=//p')
  echo "$path"
}

# Approve.
p1=$(new_proposal "$tmp/d1" "Add a status caching layer for five seconds.")
ao=$(bash "$GATE" --proposal "$p1" --verb approve)
if echo "$ao" | grep -q '^recommended_command_invoke=' && grep -q '^pending_approval: false' "$p1" && grep -qE '^approved_at: "[0-9]{4}-' "$p1"; then
  pass "approve: invoke + frontmatter mutation"
else
  fail "approve: invoke + frontmatter mutation" "stdout=$ao"
fi

# Approve again on finalized proposal — must exit non-zero.
if bash "$GATE" --proposal "$p1" --verb approve >/dev/null 2>&1; then
  fail "approve idempotency guard" "second approve unexpectedly succeeded"
else
  pass "approve idempotency guard"
fi

# Cancel.
p2=$(new_proposal "$tmp/d2" "Add a status caching layer for five seconds.")
co=$(bash "$GATE" --proposal "$p2" --verb cancel)
if [ -z "$co" ] && grep -qE '^cancelled_at: "[0-9]{4}-' "$p2" && grep -q '^pending_approval: false' "$p2"; then
  pass "cancel: silent + frontmatter mutation"
else
  fail "cancel: silent + frontmatter mutation" "stdout=$co"
fi

# Revise (P03 pass-through).
p3=$(new_proposal "$tmp/d3" "Add a status caching layer for five seconds.")
ro=$(bash "$GATE" --proposal "$p3" --verb revise --axis scope_tier --value C --no-apply)
if echo "$ro" | grep -q '^revision_pending=true axis=scope_tier value=C$' && grep -q '^pending_approval: true' "$p3"; then
  pass "revise: emits revision_pending + leaves frontmatter untouched"
else
  fail "revise: emits revision_pending + leaves frontmatter untouched" "stdout=$ro"
fi

# Unsupported axis.
if bash "$GATE" --proposal "$p3" --verb revise --axis frobnicate --value X >/dev/null 2>&1; then
  fail "unsupported axis rejection" "exited 0"
else
  pass "unsupported axis rejection"
fi

# Unknown verb.
if bash "$GATE" --proposal "$p3" --verb yolo >/dev/null 2>&1; then
  fail "unknown verb rejection" "exited 0"
else
  pass "unknown verb rejection"
fi

n=0
while [ $n -lt $i ]; do
  eval "echo \"\$NAMES_$n\""
  n=$((n+1))
done

echo "----- test-approval-gate.sh: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
