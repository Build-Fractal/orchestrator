#!/usr/bin/env bash
# scripts/verify/m024-p05-qa-loop-script.sh
# M024/P05/T02 verify — qa-loop.sh basic line-mode happy path.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOOP="$ROOT/scripts/intake/qa-loop.sh"

[ -x "$LOOP" ] || { echo "FAIL: $LOOP not executable"; exit 1; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
ans="$tmp/answers.txt"
tx="$tmp/transcript.md"

cat > "$ans" <<'EOF'
add a last-seen timestamp to status command output
single-feature
code
no
Standard
EOF

out=$(bash "$LOOP" --answers-from "$ans" --transcript-out "$tx")
echo "$out" | grep -q '^qa_short_circuited=false$' || { echo "FAIL: short_circuited not false (got: $out)"; exit 1; }
echo "$out" | grep -q '^qa_turns=5$'                || { echo "FAIL: qa_turns not 5 (got: $out)";        exit 1; }

for n in 1 2 3 4 5; do
  grep -q "^### Q$n$" "$tx" || { echo "FAIL: transcript missing ### Q$n"; exit 1; }
done

echo "PASS: qa-loop.sh — five answers -> five ### Q<N> blocks; qa_short_circuited=false; qa_turns=5"
exit 0
