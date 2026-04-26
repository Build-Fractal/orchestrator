#!/usr/bin/env bash
# scripts/verify/m024-p05-qa-loop-cap.sh
# M024/P05/T02 verify — qa-loop.sh enforces FR-5 cap (truncate to 5 turns).

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
third answer
fourth answer
fifth answer
sixth answer
seventh answer
EOF

out=$(bash "$LOOP" --answers-from "$ans" --transcript-out "$tx")
echo "$out" | grep -q '^qa_short_circuited=false$' || { echo "FAIL: short_circuited not false (got: $out)"; exit 1; }
echo "$out" | grep -q '^qa_turns=5$'                || { echo "FAIL: qa_turns not 5 (got: $out)";        exit 1; }

count=$(grep -c '^### Q' "$tx")
[ "$count" = "5" ] || { echo "FAIL: transcript has $count ### Q blocks (expected 5)"; exit 1; }

grep -q 'sixth answer'   "$tx" && { echo "FAIL: 6th answer leaked into transcript"; exit 1; }
grep -q 'seventh answer' "$tx" && { echo "FAIL: 7th answer leaked into transcript"; exit 1; }

echo "PASS: qa-loop.sh — 7-line answers truncated to 5 turns; qa_short_circuited=false"
exit 0
