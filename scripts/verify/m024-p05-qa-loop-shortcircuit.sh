#!/usr/bin/env bash
# scripts/verify/m024-p05-qa-loop-shortcircuit.sh
# M024/P05/T02 verify — `enough` token short-circuits the loop.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOOP="$ROOT/scripts/intake/qa-loop.sh"

[ -x "$LOOP" ] || { echo "FAIL: $LOOP not executable"; exit 1; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
ans="$tmp/answers.txt"
tx="$tmp/transcript.md"

cat > "$ans" <<'EOF'
first answer
second answer
enough
never seen
EOF

out=$(bash "$LOOP" --answers-from "$ans" --transcript-out "$tx")
echo "$out" | grep -q '^qa_short_circuited=true$' || { echo "FAIL: short_circuited not true (got: $out)"; exit 1; }
echo "$out" | grep -q '^qa_turns=2$'              || { echo "FAIL: qa_turns not 2 (got: $out)";        exit 1; }

grep -q '^### Q1$' "$tx" || { echo "FAIL: transcript missing ### Q1"; exit 1; }
grep -q '^### Q2$' "$tx" || { echo "FAIL: transcript missing ### Q2"; exit 1; }
grep -q '^### Q3$' "$tx" && { echo "FAIL: transcript should not contain ### Q3 after enough"; exit 1; }
grep -q 'never seen' "$tx" && { echo "FAIL: post-enough answer leaked"; exit 1; }

# Case-insensitivity probe: ENOUGH should also trigger the short-circuit.
ans2="$tmp/answers2.txt"
tx2="$tmp/transcript2.md"
cat > "$ans2" <<'EOF'
answer one
ENOUGH
EOF
out2=$(bash "$LOOP" --answers-from "$ans2" --transcript-out "$tx2")
echo "$out2" | grep -q '^qa_short_circuited=true$' || { echo "FAIL: ENOUGH (uppercase) did not short-circuit"; exit 1; }

echo "PASS: qa-loop.sh — enough (case-insensitive) short-circuits at turn 2; qa_short_circuited=true"
exit 0
